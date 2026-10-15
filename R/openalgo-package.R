#' openalgo: R Client for the OpenAlgo Trading Platform
#'
#' The R client for OpenAlgo. It wraps the REST API, the strategy webhook and
#' the WebSocket market data feed, with the same method names, parameters and
#' payloads as the official Python SDK.
#'
#' * [api()] creates the client. Every REST method and the feed are methods of
#'   that object: `client$placeorder(...)`, `client$history(...)`,
#'   `client$connect()`, and so on. See [api()] for the full list.
#' * [Strategy()] creates the webhook sender for a strategy.
#'
#' Responses are returned as named lists (the parsed JSON). Failures are
#' returned, not raised, as a list with `status = "error"`, a `message` and an
#' `error_type` (`timeout_error`, `connection_error`, `http_error`,
#' `api_error`, `json_error`, `validation_error`, `no_data`,
#' `processing_error` or `unknown_error`), exactly like the Python SDK.
#'
#' @keywords internal
#' @importFrom R6 R6Class
#' @importFrom curl new_handle
#' @importFrom later run_now
#' @importFrom websocket WebSocket
"_PACKAGE"
