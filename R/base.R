#' Base class for the OpenAlgo REST client
#'
#' @description
#' Holds the configuration and the shared, connection-reusing HTTP handle used
#' by every REST call, plus the request helpers. You normally do not create it
#' directly: use [api()], which inherits from it.
#'
#' @keywords internal
BaseAPI <- R6::R6Class(
  "BaseAPI",
  cloneable = FALSE,
  public = list(
    # @field api_key User's API key.
    api_key = NULL,
    # @field base_url REST base URL, `"{host}/api/{version}/"`.
    base_url = NULL,
    # @field headers Headers sent with every POST.
    headers = NULL,
    # @field timeout Request timeout in seconds.
    timeout = NULL,

    # @description Initialize the client configuration.
    # @param api_key User's API key.
    # @param host Base URL for the API endpoints.
    # @param version API version.
    # @param timeout Request timeout in seconds.
    initialize = function(api_key, host = "http://127.0.0.1:5000", version = "v1", timeout = 120.0) {
      self$api_key <- api_key
      self$base_url <- paste0(host, "/api/", version, "/")
      self$headers <- list("Content-Type" = "application/json")
      self$timeout <- timeout
      invisible(self)
    },

    # @description Release the pooled HTTP connections.
    close = function() {
      private$post_handle <- NULL
      private$get_handle <- NULL
      invisible(NULL)
    }
  ),
  private = list(
    # One reusable curl handle per method. curl keeps the TCP connection of a
    # handle alive between requests, so repeated calls do not open and tear
    # down a socket each time (the equivalent of the Python SDK's pooled
    # httpx.Client).
    post_handle = NULL,
    get_handle = NULL,

    timeout_ms = function() {
      as.integer(round(as.numeric(self$timeout) * 1000))
    },

    # Perform one HTTP request. Returns the curl response; transport failures
    # are raised as curl_error conditions for the caller to classify.
    perform = function(url, body = NULL, query = NULL) {
      if (is.null(body)) {
        if (is.null(private$get_handle)) {
          private$get_handle <- curl::new_handle()
        }
        h <- private$get_handle
        curl::handle_setopt(h, httpget = TRUE, followlocation = FALSE, timeout_ms = private$timeout_ms(),
                            connecttimeout_ms = private$timeout_ms(),
                            useragent = user_agent_string())
        if (!is.null(query) && length(query) > 0) {
          pairs <- vapply(names(query), function(k) {
            paste0(curl::curl_escape(k), "=", curl::curl_escape(py_str(query[[k]])))
          }, character(1))
          url <- paste0(url, "?", paste(pairs, collapse = "&"))
        }
      } else {
        if (is.null(private$post_handle)) {
          private$post_handle <- curl::new_handle()
        }
        h <- private$post_handle
        curl::handle_setopt(h, copypostfields = body, followlocation = FALSE, timeout_ms = private$timeout_ms(),
                            connecttimeout_ms = private$timeout_ms(),
                            useragent = user_agent_string())
        curl::handle_setheaders(h, .list = self$headers)
      }
      curl::curl_fetch_memory(url, handle = h)
    },

    # The response handling shared by the order, data, account, options,
    # notification and utilities surfaces (Python: _handle_response).
    handle_response = function(resp) {
      code <- resp$status_code
      text <- response_text(resp)
      if (code != 200) {
        return(error_result(sprintf("HTTP %d: %s", code, text), "http_error", code = code))
      }
      parsed <- parse_json_text(text)
      if (!parsed$ok) {
        return(error_result("Invalid JSON response from server", "json_error", raw_response = text))
      }
      data <- parsed$value
      if (!is_json_object(data)) {
        if (is.list(data) && length(data) == 0 && !is.null(names(data))) {
          return(data)
        }
        return(error_result(sprintf("'%s' object has no attribute 'get'", py_type_name(data)),
                            "unknown_error"))
      }
      if (identical(data[["status"]], "error")) {
        message <- if ("message" %in% names(data)) data[["message"]] else "Unknown error"
        out <- list(status = "error")
        out["message"] <- list(message)
        out$code <- code
        out$error_type <- "api_error"
        return(out)
      }
      data
    },

    # POST a JSON payload and run it through handle_response
    # (Python: _make_request).
    make_request = function(endpoint, payload) {
      url <- paste0(self$base_url, endpoint)
      tryCatch({
        resp <- private$perform(url, body = to_json(payload))
        private$handle_response(resp)
      }, error = function(e) transport_error(e))
    },

    # GET with query parameters and run it through handle_response. Transport
    # errors are raised, so the caller decides how to report them.
    get_request = function(endpoint, params) {
      url <- paste0(self$base_url, endpoint)
      resp <- private$perform(url, query = params)
      private$handle_response(resp)
    },

    # POST a JSON payload and return the parsed body (Python: BaseAPI._post).
    # A non-200 answer with a JSON object body is returned as is, with
    # `status` defaulted to "error" and `code` attached, because the strategy
    # and GTT surfaces put the part a caller must act on inside that body.
    post = function(endpoint, payload) {
      url <- paste0(self$base_url, endpoint)
      resp <- tryCatch(private$perform(url, body = to_json(payload)),
                       error = function(e) e)
      if (inherits(resp, "error")) {
        return(transport_error(resp))
      }
      parse_post_response(resp)
    }
  )
)

# Shared by BaseAPI$post and the webhook sender. `non_json_as_http` reproduces
# Strategy.send, which reports a non-JSON body as an http_error even on 200.
parse_post_response <- function(resp, non_json_as_http = FALSE) {
  code <- resp$status_code
  text <- response_text(resp)
  parsed <- parse_json_text(text)
  if (!parsed$ok) {
    if (code != 200 || non_json_as_http) {
      return(error_result(sprintf("HTTP %d: %s", code, text), "http_error",
                          raw_response = text, code = code))
    }
    return(error_result("Invalid JSON response from server", "json_error",
                        raw_response = text, code = code))
  }
  data <- parsed$value
  if (!is_json_object(data)) {
    out <- list(status = "error", message = "Unexpected JSON response from server")
    out["raw_response"] <- list(data)
    out$code <- code
    out$error_type <- "json_error"
    return(out)
  }
  if (code != 200) {
    # dict.setdefault: a missing status is added after the existing keys.
    if (!("status" %in% names(data))) {
      data$status <- "error"
    }
    data$code <- code
  }
  data
}
