# Strategy webhook sender (Python: openalgo/strategy.py, class Strategy).
#
# Posts to the public webhook at /strategy/webhook/<token>, the surface any
# external alert sender reaches. It is not under /api/v1 and takes no API key:
# the token in the URL is the whole credential, so treat it like a password.
#
# The token is shown exactly once, in the browser, when the strategy is
# created or its token rotated. No endpoint returns it (only its SHA-256
# digest is stored), so if it is lost, rotate it on the strategy page.
#
# Two vocabularies, and each strategy kind refuses the other's:
# * batch: start (which requires a mode, "live" or "sandbox") and stop. A
#   multi-leg spread entered and exited as a unit.
# * signal: long_entry, long_exit, short_entry and short_exit. One alert moves
#   one leg. There is no start and no mode: the first signal after the session
#   boundary opens the run, and the mode comes from the strategy's own live
#   opt-in.

#' Strategy webhook sender class
#'
#' @description
#' R6 class behind [Strategy()]: sends signals to an OpenAlgo strategy through
#' its public webhook. Create it with [Strategy()]; the generator is exported
#' for `inherits()` checks.
#'
#' @keywords internal
#' @export
OpenAlgoStrategy <- R6::R6Class(
  "OpenAlgoStrategy",
  cloneable = FALSE,
  public = list(
    # @field timeout Request timeout in seconds given at construction. As in
    #   the Python SDK, the connection keeps the timeout it was created with.
    timeout = NULL,

    # @description Initialize the webhook sender. Prefer [Strategy()].
    # @param host_url OpenAlgo server URL, for example
    #   `"http://127.0.0.1:5000"`.
    # @param webhook_id The strategy's webhook token (legacy name).
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param webhook_token The webhook token under its accurate name. Wins
    #   over `webhook_id`.
    # @param timeout Request timeout in seconds.
    initialize = function(host_url, webhook_id = NULL, ..., webhook_token = NULL, timeout = 30.0) {
      no_extra_args("Strategy", ...)
      token <- if (!is.null(webhook_token)) webhook_token else webhook_id
      if (!py_truthy(token)) {
        base::stop(paste0(
          "A webhook token is required. Pass webhook_token='oaws_...' - the ",
          "value shown once in the browser when the strategy was created or ",
          "its token rotated."
        ), call. = FALSE)
      }
      private$host_url <- sub("/+$", "", host_url)
      private$webhook_id <- token
      private$webhook_url_cache <- NULL
      self$timeout <- timeout
      private$client_timeout <- timeout
      private$handle <- NULL
      invisible(self)
    },

    # @description Release the pooled HTTP connection. A later call opens a
    #   new one.
    close = function() {
      private$handle <- NULL
      invisible(NULL)
    },

    # @description Print the sender without revealing the token.
    # @param ... Unused.
    print = function(...) {
      cat(sprintf("Strategy(host_url='%s', webhook_token=<redacted>)\n", private$host_url))
      invisible(self)
    },

    # @description Post a raw payload to the webhook and return the parsed
    #   response. Every documented outcome is returned rather than raised,
    #   including rejections, because the `result` label is the contract: a
    #   409 `rejected_cooling_off` and a 200 `rejected_dedupe` both need
    #   reading. Only a transport failure or a non-JSON answer produces a
    #   locally built error list.
    # @param payload A named list, the JSON body to send.
    # @return The server's response as a named list, with `code` attached
    #   when the HTTP status was not 200 (and `status` defaulted to
    #   `"error"`). It carries `status`, `result`, `message` and, where
    #   applicable, `strategy_id`, `run_id`, `stop_pending` and `exits`.
    send = function(payload) {
      body <- to_json(payload)
      resp <- tryCatch(private$perform(body), curl_error = function(e) e)
      if (is_transport_error(resp)) {
        return(transport_error(resp))
      }
      parse_post_response(resp, non_json_as_http = TRUE)
    },

    # @description Start a batch strategy: enter every leg. Live is opt-in
    #   per strategy: `mode = "live"` on a strategy without live trading
    #   enabled answers 403 `rejected_live_disabled`. Two identical starts
    #   within 60 seconds are one signal (`rejected_dedupe`, reported as a
    #   success). A strategy stopped within the last 30 seconds refuses a
    #   start with 409 `rejected_cooling_off`. A start against a signal
    #   strategy is `rejected_invalid_action`.
    # @param mode `"live"` or `"sandbox"`. Required, exact and
    #   case-sensitive on the server. There is no default.
    # @return A named list with `status`, `result`, `message`,
    #   `strategy_id` and `run_id`.
    start = function(mode) {
      self$send(list(action = "start", mode = mode))
    },

    # @description Stop a batch strategy: exit every owned position at
    #   market. "Strategy stop accepted" means the durable request reached
    #   the engine, not that the broker is flat: `stop_pending = TRUE` keeps
    #   the run current and managed until exit fills confirm it is flat. A
    #   stop is never blocked by the cooling-off window.
    # @return A named list with `status`, `result`, `message`,
    #   `strategy_id`, `run_id`, `stop_pending` and `exits`.
    stop = function() {
      self$send(list(action = "stop"))
    },

    # @description Send a signal strategy action, naming the leg by id or by
    #   symbol. A signal that does nothing is a success with a note, not a
    #   failure, for example `Signal accepted (already_long)`; the notes are
    #   `already_long`, `already_short`, `no_matching_position`,
    #   `outside_entry_window` and `outside_trading_window`. A signal blocked
    #   by the strategy's direction, or naming a leg that does not exist,
    #   answers 400 `rejected_invalid_action`. An opposite entry squares the
    #   existing side first, then opens. Signal actions skip the dedupe and
    #   cooling-off windows. A leg on a derivatives exchange must name an
    #   exact listed contract.
    # @param action `"long_entry"`, `"long_exit"`, `"short_entry"` or
    #   `"short_exit"`.
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param leg_id Which leg the signal targets (sent as an integer). Wins
    #   over `symbol` and `exchange` on the server when both are given.
    # @param symbol Leg symbol, used when `leg_id` is absent.
    # @param exchange Exchange for `symbol`.
    # @return A named list with `status`, `result`, `message`,
    #   `strategy_id` and `run_id`.
    signal = function(action, ..., leg_id = NULL, symbol = NULL, exchange = NULL) {
      no_extra_args("signal", ...)
      payload <- list(action = action)
      if (!is.null(leg_id)) {
        payload["leg_id"] <- list(as_py_int(leg_id))
      }
      if (!is.null(symbol)) {
        payload["symbol"] <- list(symbol)
      }
      if (!is.null(exchange)) {
        payload["exchange"] <- list(exchange)
      }
      self$send(payload)
    },

    # @description Open or reverse into a long on one leg. See `signal()`.
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param leg_id Which leg the signal targets.
    # @param symbol Leg symbol, used when `leg_id` is absent.
    # @param exchange Exchange for `symbol`.
    # @return As `signal()`.
    long_entry = function(..., leg_id = NULL, symbol = NULL, exchange = NULL) {
      no_extra_args("long_entry", ...)
      self$signal("long_entry", leg_id = leg_id, symbol = symbol, exchange = exchange)
    },

    # @description Close a long on one leg. See `signal()`.
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param leg_id Which leg the signal targets.
    # @param symbol Leg symbol, used when `leg_id` is absent.
    # @param exchange Exchange for `symbol`.
    # @return As `signal()`.
    long_exit = function(..., leg_id = NULL, symbol = NULL, exchange = NULL) {
      no_extra_args("long_exit", ...)
      self$signal("long_exit", leg_id = leg_id, symbol = symbol, exchange = exchange)
    },

    # @description Open or reverse into a short on one leg. See `signal()`.
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param leg_id Which leg the signal targets.
    # @param symbol Leg symbol, used when `leg_id` is absent.
    # @param exchange Exchange for `symbol`.
    # @return As `signal()`.
    short_entry = function(..., leg_id = NULL, symbol = NULL, exchange = NULL) {
      no_extra_args("short_entry", ...)
      self$signal("short_entry", leg_id = leg_id, symbol = symbol, exchange = exchange)
    },

    # @description Close a short on one leg. See `signal()`.
    # @param ... Not accepted; present so the following arguments must be
    #   named.
    # @param leg_id Which leg the signal targets.
    # @param symbol Leg symbol, used when `leg_id` is absent.
    # @param exchange Exchange for `symbol`.
    # @return As `signal()`.
    short_exit = function(..., leg_id = NULL, symbol = NULL, exchange = NULL) {
      no_extra_args("short_exit", ...)
      self$signal("short_exit", leg_id = leg_id, symbol = symbol, exchange = exchange)
    },

    # @description Removed: the webhook it posted to no longer exists. The
    #   old surface took a symbol, a BUY or SELL action and a position size,
    #   and read the long only, short only or both mode from the strategy's
    #   configuration. There is no mapping this method could make on its own
    #   (BUY is `long_entry()` on a flat leg and `short_exit()` on a short
    #   one), so it always raises an error. Use `start()` and `stop()` for a
    #   batch strategy, or the four signal methods for a signal strategy.
    # @param symbol Unused.
    # @param action Unused.
    # @param position_size Unused.
    strategyorder = function(symbol, action, position_size = NULL) {
      base::stop(paste0(
        "Strategy.strategyorder() was removed: the webhook it posted to no longer ",
        "exists. Use start(mode)/stop() for a batch strategy, or long_entry()/",
        "long_exit()/short_entry()/short_exit() for a signal strategy."
      ), call. = FALSE)
    }
  ),
  active = list(
    # @field webhook_url The webhook URL, `"<host_url>/strategy/webhook/<token>"`
    #   (read-only, built once and cached). It embeds the token, so it is a
    #   credential in its own right: do not log it.
    webhook_url = function(value) {
      if (!missing(value)) {
        base::stop("webhook_url is read-only", call. = FALSE)
      }
      if (is.null(private$webhook_url_cache)) {
        private$webhook_url_cache <- paste0(private$host_url, "/strategy/webhook/",
                                            private$webhook_id)
      }
      private$webhook_url_cache
    }
  ),
  private = list(
    host_url = NULL,
    webhook_id = NULL,
    webhook_url_cache = NULL,
    client_timeout = NULL,
    # One reusable curl handle, so repeated signals reuse the keep-alive
    # connection instead of opening a socket each time.
    handle = NULL,

    perform = function(body) {
      if (is.null(private$handle)) {
        private$handle <- curl::new_handle()
      }
      h <- private$handle
      timeout_ms <- as.integer(round(as.numeric(private$client_timeout) * 1000))
      curl::handle_setopt(h, copypostfields = body, timeout_ms = timeout_ms,
                          connecttimeout_ms = timeout_ms, followlocation = FALSE,
                          useragent = user_agent_string())
      curl::handle_setheaders(h, "Content-Type" = "application/json")
      curl::curl_fetch_memory(self$webhook_url, handle = h)
    }
  )
)

#' Create a strategy webhook sender
#'
#' Send signals to an OpenAlgo strategy through its public webhook at
#' `<host_url>/strategy/webhook/<token>`. This mirrors `openalgo.Strategy(...)`
#' in the Python SDK. The webhook takes no API key: the token is the whole
#' credential, so treat it like a password. It is shown once in the browser
#' when the strategy is created or its token rotated; no endpoint returns it.
#'
#' Batch strategies use `start(mode)` and `stop()`. Signal strategies use
#' `long_entry()`, `long_exit()`, `short_entry()` and `short_exit()` (or
#' `signal(action, ...)`), naming the leg with `leg_id` or with `symbol` and
#' `exchange`. Each strategy kind refuses the other's actions. `send(payload)`
#' posts a raw payload. Every documented outcome is returned as a named list
#' rather than raised; read its `result` label. `strategyorder()` was removed
#' and always raises an error. Printing the object never shows the token.
#'
#' @param host_url OpenAlgo server URL, for example `"http://127.0.0.1:5000"`.
#'   Trailing slashes are removed.
#' @param webhook_id The strategy's webhook token (the `oaws_...` value),
#'   under its legacy name, kept for compatibility with earlier releases.
#' @param ... Not accepted. Any argument after `webhook_id` must be named.
#' @param webhook_token The same token under its accurate name. Wins over
#'   `webhook_id` when both are given.
#' @param timeout Request timeout in seconds. Defaults to 30.
#'
#' @return An [OpenAlgoStrategy] object. Creating it fails with an error when
#'   no token is given under either name.
#'
#' @examples
#' \dontrun{
#' s <- Strategy("http://127.0.0.1:5000", webhook_token = "oaws_your_token")
#'
#' # Batch strategy
#' s$start(mode = "sandbox")
#' s$stop()
#'
#' # Signal strategy
#' s$long_entry(leg_id = 1)
#' s$long_exit(symbol = "NIFTY30DEC25FUT", exchange = "NFO")
#'
#' s$close()
#' }
#' @export
Strategy <- function(host_url, webhook_id = NULL, ..., webhook_token = NULL, timeout = 30.0) {
  no_extra_args("Strategy", ...)
  OpenAlgoStrategy$new(host_url = host_url, webhook_id = webhook_id,
                       webhook_token = webhook_token, timeout = timeout)
}
