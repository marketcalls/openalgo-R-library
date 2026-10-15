# Internal helpers shared by every module. None of these are exported.

`%||%` <- function(x, y) if (is.null(x)) y else x

# An empty named list, which serializes to a JSON object ({}) rather than an
# array ([]). Used wherever the Python SDK returns an empty dict.
empty_named_list <- function() {
  stats::setNames(list(), character(0))
}

# Collect `...` as Python-style keyword arguments. Every element must be named,
# because the Python SDK only accepts extra fields as keywords (**kwargs).
dots_kwargs <- function(...) {
  kwargs <- list(...)
  if (length(kwargs) == 0) {
    return(empty_named_list())
  }
  nms <- names(kwargs)
  if (is.null(nms) || any(is.na(nms) | nms == "")) {
    stop("extra arguments must be named (they are sent as payload fields)", call. = FALSE)
  }
  kwargs
}

# Refuse extra arguments on methods whose Python counterpart takes no **kwargs.
no_extra_args <- function(fn_name, ...) {
  extra <- list(...)
  if (length(extra) > 0) {
    nms <- names(extra)
    label <- if (is.null(nms) || all(nms == "")) "positional" else paste(nms[nms != ""], collapse = ", ")
    stop(sprintf("%s() got unexpected argument(s): %s", fn_name, label), call. = FALSE)
  }
  invisible(NULL)
}

# Emulate Python's str() for the scalar values the SDK stringifies.
# str(10) -> "10", str(750.5) -> "750.5", str(True) -> "True", str(None) -> "None".
py_str <- function(x) {
  if (is.null(x)) {
    return("None")
  }
  if (is.character(x)) {
    return(x)
  }
  if (is.factor(x)) {
    return(as.character(x))
  }
  if (is.logical(x) && length(x) == 1) {
    if (is.na(x)) return("None")
    return(if (x) "True" else "False")
  }
  if (is.numeric(x) && length(x) == 1) {
    if (is.na(x)) return("nan")
    if (is.integer(x)) return(format(x, scientific = FALSE, trim = TRUE))
    if (is.finite(x) && x == trunc(x) && abs(x) < 1e15) {
      return(format(x, scientific = FALSE, trim = TRUE, nsmall = 0))
    }
    return(py_float_repr(x))
  }
  x
}

# Python's repr() of a float: the shortest digit string that reads back as
# the same double, in fixed notation for exponents -4 to 15 and in
# scientific notation otherwise. str(0.1 + 0.2) -> "0.30000000000000004",
# str(1e-05) -> "1e-05", str(1e16) -> "1e+16".
py_float_repr <- function(x) {
  if (is.nan(x)) return("nan")
  if (is.infinite(x)) return(if (x > 0) "inf" else "-inf")
  # The round-trip check parses with jsonlite, which rounds correctly; R's
  # own parser can be off by one unit in the last place beyond 15 digits.
  for (d in 1:17) {
    s <- sprintf(paste0("%.", d - 1L, "e"), x)
    if (jsonlite::parse_json(s) == x) break
  }
  parts <- strsplit(s, "e", fixed = TRUE)[[1]]
  mantissa <- parts[1]
  if (grepl(".", mantissa, fixed = TRUE)) {
    mantissa <- sub("\\.?0+$", "", mantissa)
  }
  e <- as.integer(parts[2])
  if (e < -4 || e >= 16) {
    return(paste0(mantissa, "e", if (e < 0) "-" else "+", sprintf("%02d", abs(e))))
  }
  sign <- if (x < 0) "-" else ""
  digits <- gsub("[-.]", "", mantissa)
  if (e < 0) {
    return(paste0(sign, "0.", strrep("0", -e - 1L), digits))
  }
  if (nchar(digits) <= e + 1L) {
    return(paste0(sign, digits, strrep("0", e + 1L - nchar(digits)), ".0"))
  }
  paste0(sign, substr(digits, 1L, e + 1L), ".", substr(digits, e + 2L, nchar(digits)))
}

# Python truthiness for the values the SDK tests with a bare `if value:`.
py_truthy <- function(x) {
  if (is.null(x) || length(x) == 0) return(FALSE)
  if (is.list(x)) return(length(x) > 0)
  if (length(x) > 1) return(TRUE)
  if (is.na(x)) return(TRUE)
  if (is.character(x)) return(nzchar(x))
  if (is.logical(x)) return(x)
  if (is.numeric(x)) return(x != 0)
  TRUE
}

# Merge keyword arguments into a payload, skipping NULL values the way the
# Python SDK skips None. With stringify = TRUE every value goes through
# py_str() (the order surface sends strings); otherwise values are sent as is.
# With skip_existing = TRUE a key already in the payload is never overwritten.
add_kwargs <- function(payload, kwargs, stringify = FALSE, skip_existing = FALSE) {
  for (key in names(kwargs)) {
    value <- kwargs[[key]]
    if (is.null(value)) next
    if (skip_existing && key %in% names(payload)) next
    payload[key] <- list(if (stringify) py_str(value) else value)
  }
  payload
}

# Build the error dict the Python SDK returns instead of raising.
error_result <- function(message, error_type, ...) {
  c(list(status = "error", message = message), list(...), list(error_type = error_type))
}

# Serialize a payload the way json.dumps does: scalars unboxed, NULL as null,
# full numeric precision.
to_json <- function(x) {
  as.character(jsonlite::toJSON(json_floats(x), auto_unbox = TRUE, null = "null", na = "null",
                                digits = NA, POSIXt = "ISO8601", json_verbatim = TRUE))
}

# jsonlite writes at most 15 significant digits, json.dumps writes the
# shortest round-trip repr (0.30000000000000004). Fractional scalar doubles
# are passed to jsonlite as that repr, verbatim.
json_floats <- function(x) {
  if (is.list(x) && !is.data.frame(x)) {
    for (i in seq_along(x)) {
      if (!is.null(x[[i]])) {
        x[[i]] <- json_floats(x[[i]])
      }
    }
    return(x)
  }
  if (is.double(x) && length(x) == 1 && is.null(attributes(x)) && is.finite(x) &&
      x != trunc(x)) {
    return(structure(py_float_repr(x), class = "json"))
  }
  x
}

# Parse JSON text into plain R lists (objects become named lists, arrays become
# unnamed lists), mirroring json.loads. Returns list(ok, value).
parse_json_text <- function(text) {
  if (is.null(text) || length(text) != 1 || is.na(text) || !nzchar(trimws(text))) {
    return(list(ok = FALSE, value = NULL))
  }
  tryCatch(
    list(ok = TRUE, value = jsonlite::parse_json(text, simplifyVector = FALSE)),
    error = function(e) list(ok = FALSE, value = NULL)
  )
}

# TRUE when a parsed JSON value was an object (Python dict).
is_json_object <- function(x) {
  is.list(x) && !is.null(names(x))
}

# Python's type name for a parsed JSON value, used to reproduce the
# "'list' object has no attribute 'get'" message of the Python SDK.
py_type_name <- function(x) {
  if (is.null(x)) return("NoneType")
  if (is.list(x)) return(if (is.null(names(x))) "list" else "dict")
  if (is.character(x)) return("str")
  if (is.logical(x)) return("bool")
  if (is.integer(x)) return("int")
  if (is.numeric(x)) return(if (x == trunc(x)) "int" else "float")
  class(x)[1]
}

# Convert a list of JSON records (named lists) into a data.frame, the way
# pandas.DataFrame(list_of_dicts) does: columns in order of first appearance,
# missing or null values become NA.
records_to_df <- function(records) {
  if (is.data.frame(records)) {
    return(records)
  }
  if (!is.list(records) || length(records) == 0) {
    return(data.frame())
  }
  cols <- character(0)
  for (rec in records) {
    cols <- c(cols, setdiff(names(rec), cols))
  }
  out <- lapply(cols, function(col) {
    values <- lapply(records, function(rec) {
      v <- rec[[col]]
      if (is.null(v) || length(v) == 0) NA else if (is.list(v)) list(v) else v
    })
    if (any(vapply(values, is.list, logical(1)))) {
      return(I(lapply(values, function(v) if (is.list(v)) v[[1]] else v)))
    }
    unlist(values, use.names = FALSE)
  })
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE, optional = TRUE)
}

# Map a transport-level condition to the Python SDK's error dict.
# Timeouts (httpx.TimeoutException) -> timeout_error, connection failures
# (httpx.ConnectError) -> connection_error, any other transport failure
# (httpx.HTTPError) -> http_error, anything else -> unknown_error.
transport_error <- function(e) {
  cls <- class(e)
  msg <- conditionMessage(e)
  if ("curl_error_operation_timedout" %in% cls) {
    return(error_result("Request timed out. The server took too long to respond.", "timeout_error"))
  }
  if (any(c("curl_error_couldnt_connect", "curl_error_couldnt_resolve_host",
            "curl_error_couldnt_resolve_proxy") %in% cls)) {
    return(error_result("Failed to connect to the server. Please check if the server is running.",
                        "connection_error"))
  }
  if ("curl_error" %in% cls) {
    return(error_result(paste0("HTTP error occurred: ", msg), "http_error"))
  }
  error_result(paste0("An unexpected error occurred: ", msg), "unknown_error")
}

# TRUE for conditions raised by the HTTP transport (curl).
is_transport_error <- function(e) {
  inherits(e, "curl_error")
}

# Decode a curl response body as UTF-8 text.
response_text <- function(resp) {
  if (length(resp$content) == 0) {
    return("")
  }
  text <- rawToChar(resp$content)
  Encoding(text) <- "UTF-8"
  text
}

user_agent_string <- function() {
  version <- tryCatch(as.character(utils::packageVersion("openalgo")), error = function(e) "dev")
  paste0("openalgo-r/", version)
}
