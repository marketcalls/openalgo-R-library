# Shared mock OpenAlgo REST server for the module tests.
#
# One webfakes app runs in a background process for the whole test run. It
# records every request it receives (method, path, query, raw body) and
# answers with responses configured per test through its control routes:
#
#   POST /__mock/reset     forget recorded requests and configured rules
#   POST /__mock/rule      add a rule {path, method, query, status, body,
#                          content_type, delay}; the newest matching rule wins
#   GET  /__mock/requests  the recorded requests as a JSON array
#
# A request no rule matches gets 200 {"status":"success"}.

mock_api_key <- "test_api_key_0123456789abcdef"

mock_state <- new.env(parent = emptyenv())

# Handlers run in the server process, so they only use base R and `::` calls
# and get the global environment instead of this file's environment.
mock_handler <- function(f) {
  environment(f) <- globalenv()
  f
}

mock_app <- function() {
  app <- webfakes::new_app()
  app$locals$requests <- list()
  app$locals$rules <- list()

  app$post("/__mock/reset", mock_handler(function(req, res) {
    req$app$locals$requests <- list()
    req$app$locals$rules <- list()
    res$set_status(200L)$send_json(list(ok = TRUE), auto_unbox = TRUE)
  }))

  app$post("/__mock/rule", mock_handler(function(req, res) {
    rule <- jsonlite::parse_json(rawToChar(req$.body), simplifyVector = FALSE)
    rules <- req$app$locals$rules
    rules[[length(rules) + 1L]] <- rule
    req$app$locals$rules <- rules
    res$set_status(200L)$send_json(list(ok = TRUE), auto_unbox = TRUE)
  }))

  app$get("/__mock/requests", mock_handler(function(req, res) {
    res$set_status(200L)
    res$set_type("application/json")
    res$send(as.character(jsonlite::toJSON(req$app$locals$requests, auto_unbox = TRUE,
                                           null = "null", digits = NA)))
  }))

  app$all(webfakes::new_regexp(".*"), mock_handler(function(req, res) {
    body <- if (length(req$.body) > 0) rawToChar(req$.body) else ""
    query <- req$query
    if (length(query) == 0) query <- stats::setNames(list(), character(0))
    entry <- list(
      method = toupper(req$method),
      path = req$path,
      query = query,
      content_type = if (is.null(ct <- req$get_header("Content-Type"))) "" else ct,
      body = body
    )
    requests <- req$app$locals$requests
    requests[[length(requests) + 1L]] <- entry
    req$app$locals$requests <- requests

    match <- NULL
    for (rule in rev(req$app$locals$rules)) {
      if (!identical(rule$path, req$path)) next
      if (!is.null(rule$method) && !identical(toupper(rule$method), toupper(req$method))) next
      ok <- TRUE
      for (k in names(rule$query)) {
        if (!identical(as.character(query[[k]]), as.character(rule$query[[k]]))) ok <- FALSE
      }
      if (!ok) next
      match <- rule
      break
    }
    if (is.null(match)) {
      match <- list(status = 200L, body = "{\"status\":\"success\"}")
    }
    if (!is.null(match$delay)) Sys.sleep(as.numeric(match$delay))
    res$set_status(as.integer(if (is.null(match$status)) 200L else match$status))
    res$set_type(if (is.null(match$content_type)) "application/json" else match$content_type)
    res$send(if (is.null(match$body)) "" else match$body)
  }))
  app
}

# Start the shared server on first use. It is stopped after the last test
# file through testthat's teardown environment.
mock_url <- function() {
  if (is.null(mock_state$proc)) {
    mock_state$proc <- webfakes::local_app_process(mock_app(), start = TRUE,
                                                   .local_envir = testthat::teardown_env())
  }
  sub("/+$", "", mock_state$proc$url())
}

mock_control <- function(path, body = NULL) {
  h <- curl::new_handle()
  if (!is.null(body)) {
    curl::handle_setopt(h, copypostfields = body)
    curl::handle_setheaders(h, "Content-Type" = "application/json")
  } else {
    curl::handle_setopt(h, post = TRUE, postfieldsize = 0L)
  }
  resp <- curl::curl_fetch_memory(paste0(mock_url(), path), handle = h)
  rawToChar(resp$content)
}

# Forget every recorded request and configured rule. Call at the top of each
# test.
mock_reset <- function() {
  invisible(mock_control("/__mock/reset"))
}

# Configure the answer for `path` (for example "/api/v1/placeorder"). `json`
# is serialized to the body; pass `body` for a raw (possibly invalid) body.
mock_respond <- function(path, json = NULL, status = 200L, body = NULL, method = NULL,
                         query = NULL, delay = NULL, content_type = "application/json") {
  if (is.null(body)) {
    body <- if (is.null(json)) "" else as.character(jsonlite::toJSON(json, auto_unbox = TRUE,
                                                                      null = "null", digits = NA))
  }
  rule <- list(path = path, status = status, body = body, content_type = content_type)
  if (!is.null(method)) rule$method <- method
  if (!is.null(query)) rule$query <- query
  if (!is.null(delay)) rule$delay <- delay
  invisible(mock_control("/__mock/rule", as.character(jsonlite::toJSON(rule, auto_unbox = TRUE))))
}

# Every request recorded since the last reset. Each element has method,
# path, query, content_type, body (raw text) and json (the body parsed the
# way json.loads would, so strings stay strings and numbers stay numbers).
mock_requests <- function() {
  reqs <- jsonlite::parse_json(mock_control_get("/__mock/requests"), simplifyVector = FALSE)
  lapply(reqs, function(r) {
    r$json <- if (nzchar(r$body)) jsonlite::parse_json(r$body, simplifyVector = FALSE) else NULL
    r
  })
}

mock_control_get <- function(path) {
  resp <- curl::curl_fetch_memory(paste0(mock_url(), path))
  rawToChar(resp$content)
}

# The single request recorded since the last reset (fails otherwise).
last_request <- function() {
  reqs <- mock_requests()
  testthat::expect_length(reqs, 1L)
  reqs[[length(reqs)]]
}

# A client pointed at the mock server.
mock_client <- function(timeout = 120) {
  openalgo::api(api_key = mock_api_key, host = mock_url(), timeout = timeout)
}

# The API path for an endpoint.
api_path <- function(endpoint) paste0("/api/v1/", endpoint)

# A local port nothing listens on, for connection refused tests. A free
# port for 127.0.0.1 can still have a listener on 0.0.0.0 on some systems,
# so each candidate is checked to refuse a connection; the result is cached.
closed_port <- function() {
  if (is.null(mock_state$closed_port)) {
    for (i in 1:20) {
      port <- httpuv::randomPort()
      h <- curl::new_handle(connecttimeout = 5, timeout = 5)
      refused <- tryCatch({
        curl::curl_fetch_memory(paste0("http://127.0.0.1:", port, "/"), handle = h)
        FALSE
      }, curl_error_couldnt_connect = function(e) TRUE, error = function(e) FALSE)
      if (refused) {
        mock_state$closed_port <- port
        break
      }
    }
  }
  mock_state$closed_port
}

# Assert a request: method, path and the exact parsed JSON body (names in
# order, values, string versus number versus boolean versus null). Integer
# and double numbers compare equal, as 1 and 1.0 do in JSON.
expect_request <- function(req, endpoint, body, method = "POST") {
  testthat::expect_identical(req$method, method)
  testthat::expect_identical(req$path, api_path(endpoint))
  testthat::expect_equal(req$json, body)
}

# Call `fn` against the mock server with `endpoint` answering `json` and
# return list(result, request).
call_mock <- function(endpoint, fn, json = list(status = "success"), status = 200L) {
  mock_reset()
  mock_respond(api_path(endpoint), json = json, status = status)
  result <- fn()
  list(result = result, request = last_request())
}

# The response handling paths shared by every surface that uses
# make_request (Python: _make_request plus _handle_response). `call` is a
# function(client) performing one request to `endpoint`. Transport failures
# are covered by check_client_transport_errors().
check_make_request_paths <- function(endpoint, call) {
  path <- api_path(endpoint)
  client <- mock_client()

  # 200 success is passed through untouched.
  mock_reset()
  mock_respond(path, json = list(status = "success", data = list(a = 1L, b = "x")))
  testthat::expect_identical(call(client), list(status = "success", data = list(a = 1L, b = "x")))

  # 200 with status "error" becomes an api_error carrying code 200.
  mock_reset()
  mock_respond(path, json = list(status = "error", message = "Invalid symbol"))
  testthat::expect_identical(call(client), list(status = "error", message = "Invalid symbol",
                                                code = 200L, error_type = "api_error"))

  # Without a message the default is "Unknown error".
  mock_reset()
  mock_respond(path, json = list(status = "error"))
  testthat::expect_identical(call(client)$message, "Unknown error")

  # Non-200 becomes "HTTP <code>: <body>" http_error, the JSON body is not read.
  mock_reset()
  mock_respond(path, body = "{\"status\":\"error\",\"message\":\"bad\"}", status = 400L)
  testthat::expect_identical(call(client), list(
    status = "error", message = "HTTP 400: {\"status\":\"error\",\"message\":\"bad\"}",
    code = 400L, error_type = "http_error"))

  mock_reset()
  mock_respond(path, body = "Internal Server Error", status = 500L, content_type = "text/plain")
  testthat::expect_identical(call(client), list(
    status = "error", message = "HTTP 500: Internal Server Error",
    code = 500L, error_type = "http_error"))

  # Invalid JSON on 200 is a json_error with the raw text and no code.
  mock_reset()
  mock_respond(path, body = "not json", content_type = "text/plain")
  testthat::expect_identical(call(client), list(
    status = "error", message = "Invalid JSON response from server",
    raw_response = "not json", error_type = "json_error"))

  # A JSON array on 200: Python calls .get() on a list and reports it.
  mock_reset()
  mock_respond(path, body = "[1,2]")
  testthat::expect_identical(call(client), list(
    status = "error", message = "'list' object has no attribute 'get'",
    error_type = "unknown_error"))

  invisible(NULL)
}

# Transport failures, identical for make_request, BaseAPI._post and the
# webhook: a timeout against a slow route and a refused connection on a
# closed local port. `make` builds a caller from (host, timeout); `call`
# performs one request with it. These take a few seconds, so the tests that
# use them are skipped on CRAN.
check_transport_errors <- function(path, make, call) {
  mock_reset()
  mock_respond(path, json = list(status = "success"), delay = 1)
  testthat::expect_identical(call(make(mock_url(), 0.2)), list(
    status = "error", message = "Request timed out. The server took too long to respond.",
    error_type = "timeout_error"))

  dead <- make(paste0("http://127.0.0.1:", closed_port()), 120)
  testthat::expect_identical(call(dead), list(
    status = "error",
    message = "Failed to connect to the server. Please check if the server is running.",
    error_type = "connection_error"))
  invisible(NULL)
}

# check_transport_errors() for a client method calling `endpoint`.
check_client_transport_errors <- function(endpoint, call) {
  check_transport_errors(api_path(endpoint), function(host, timeout) {
    openalgo::api(api_key = mock_api_key, host = host, timeout = timeout)
  }, call)
}

# The response handling of BaseAPI._post (GTT and strategy module): a
# non-200 JSON object body is passed through with code attached.
# Transport failures are covered by check_client_transport_errors().
check_post_paths <- function(endpoint, call) {
  path <- api_path(endpoint)
  client <- mock_client()

  mock_reset()
  mock_respond(path, json = list(status = "success", trigger_id = "123"))
  testthat::expect_identical(call(client), list(status = "success", trigger_id = "123"))

  # A 200 status "error" body is returned as is (no api_error rewrite).
  mock_reset()
  mock_respond(path, json = list(status = "error", message = "nope"))
  testthat::expect_identical(call(client), list(status = "error", message = "nope"))

  # Non-200 with a JSON body: passthrough plus code.
  mock_reset()
  mock_respond(path, status = 409L, json = list(status = "error", message = "conflict",
                                                stop_pending = TRUE))
  testthat::expect_identical(call(client), list(status = "error", message = "conflict",
                                                stop_pending = TRUE, code = 409L))

  # Non-200 without status: status defaults to "error", appended like
  # dict.setdefault, then code.
  mock_reset()
  mock_respond(path, status = 400L, json = list(message = list(symbol = "required")))
  testthat::expect_identical(call(client), list(message = list(symbol = "required"),
                                                status = "error", code = 400L))

  # Non-200 non-JSON: http_error with the raw text.
  mock_reset()
  mock_respond(path, status = 502L, body = "Bad Gateway", content_type = "text/plain")
  testthat::expect_identical(call(client), list(
    status = "error", message = "HTTP 502: Bad Gateway", raw_response = "Bad Gateway",
    code = 502L, error_type = "http_error"))

  # 200 non-JSON: json_error with code.
  mock_reset()
  mock_respond(path, body = "oops", content_type = "text/plain")
  testthat::expect_identical(call(client), list(
    status = "error", message = "Invalid JSON response from server", raw_response = "oops",
    code = 200L, error_type = "json_error"))

  # JSON that is not an object.
  mock_reset()
  mock_respond(path, body = "[1,2]")
  testthat::expect_identical(call(client), list(
    status = "error", message = "Unexpected JSON response from server",
    raw_response = list(1L, 2L), code = 200L, error_type = "json_error"))

  invisible(NULL)
}
