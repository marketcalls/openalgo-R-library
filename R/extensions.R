# Additional REST endpoints: methods for documented OpenAlgo server endpoints
# that the Python SDK does not wrap. They follow the conventions of the rest of
# the package: keyword-only parameters after `...`, every other named argument
# is sent as an extra payload field (as is, NULL skipped), POST requests go
# through make_request (the OrderAPI response handling) and GET requests send
# the API key as the `apikey` query parameter.

#' Authenticated ping
#'
#' Check that the API key resolves to an active broker session. This is not an
#' anonymous health check: an invalid key, or a missing or revoked broker
#' session, is answered with HTTP 403.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/ping`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$ping(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list such as
#'   `list(status = "success", data = list(message = "pong", broker = "yourbroker"))`.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$ping()
#' }
#' @family additional endpoints
#' @name ping
NULL

#' Get the sandbox P&L by symbol
#'
#' Return today's realized and unrealized P&L of the open sandbox positions,
#' one entry per symbol. The endpoint only works while analyzer (sandbox) mode
#' is enabled; in live mode the server answers HTTP 400.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/pnl/symbols`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$pnlsymbols(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status`, `data` (one entry per symbol with
#'   `symbol`, `exchange`, `product`, `quantity`, `pnl`, `unrealized_pnl`,
#'   `today_realized_pnl` and `total_pnl_today`), `total_pnl`,
#'   `total_unrealized_pnl`, `total_today_realized_pnl`, `total_pnl_today` and
#'   `mode`.
#' @examples
#' \dontrun{
#' pnl <- client$pnlsymbols()
#' pnl$total_pnl_today
#' }
#' @family additional endpoints
#' @name pnlsymbols
NULL

#' Calculate option Greeks for several options
#'
#' Calculate implied volatility and the Greeks (delta, gamma, theta, vega,
#' rho) for 1 to 50 options in one request, with the Black-76 model. Single
#' items can fail while the batch succeeds, so inspect every item and the
#' summary.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/multioptiongreeks`) but the Python SDK has no counterpart.
#' Use [optiongreeks] for a single option.
#'
#' @section Usage:
#' ```
#' client$multioptiongreeks(symbols, interest_rate = NULL, expiry_time = NULL, ...)
#' ```
#' @section Arguments:
#' * `symbols`: The options, a list of named lists with `symbol` (option
#'   symbol) and `exchange` (NFO, BFO, CDS, MCX or CRYPTO), and optionally
#'   `underlying_symbol` and `underlying_exchange` to override the underlying.
#'   A single option may be given as one named list, and a data frame with
#'   those columns is accepted too (one option per row). It is always sent as
#'   a JSON array; `NULL` and `NA` fields of an item are left out. Required.
#' * `interest_rate`: Annualized risk-free rate in percent (0 to 100), used
#'   for every option. Optional.
#' * `expiry_time`: Expiry time as `"HH:MM"`, used for every option. Optional.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status`, `data` (one entry per option with
#'   `status`, `symbol`, `exchange`, `implied_volatility` and `greeks`) and
#'   `summary` (`total`, `success`, `failed`).
#'
#'   Like the server, the client checks `symbols` before sending: it must hold
#'   1 to 50 options, each with a `symbol` and an `exchange`. Otherwise an
#'   error list with `error_type = "validation_error"` is returned without
#'   calling the server.
#' @examples
#' \dontrun{
#' client$multioptiongreeks(symbols = list(
#'   list(symbol = "NIFTY25NOV2526000CE", exchange = "NFO"),
#'   list(symbol = "NIFTY25NOV2526000PE", exchange = "NFO")
#' ), interest_rate = 7.0)
#' }
#' @family additional endpoints
#' @name multioptiongreeks
NULL

#' Get historical candles in ticker format
#'
#' Fetch historical candles from the broker for one symbol, as JSON records or
#' as plain text rows. This is a GET request with the API key in the query
#' string. The server limits the date range by interval (10 years for D, W and
#' M; 30 days for intraday intervals) and always reads the broker API.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/ticker/<EXCHANGE>:<SYMBOL>`) but the Python SDK has no
#' counterpart. [history] returns the same candles as a data frame.
#'
#' @section Usage:
#' ```
#' client$ticker(symbol, exchange, interval = "D", start_date, end_date,
#'               format = "json", ...)
#' ```
#' @section Arguments:
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `interval`: Candle interval, for example `"1m"`, `"5m"`, `"1h"` or
#'   `"D"`. Defaults to `"D"`.
#' * `start_date`: Start date as `"YYYY-MM-DD"` (sent as `from`). Required.
#' * `end_date`: End date as `"YYYY-MM-DD"` (sent as `to`). Required.
#' * `format`: `"json"` (default) or `"txt"`.
#' * `...`: Optional additional query parameters.
#'
#' The path segment `EXCHANGE:SYMBOL` is URL-encoded.
#' @return For `format = "json"` the parsed response, a named list with
#'   `status` and `data` (records with `timestamp`, `open`, `high`, `low`,
#'   `close`, `volume`).
#'
#'   For `format = "txt"` the plain text body as one character string on
#'   HTTP 200: one comma separated row per candle, `Ticker,Date,Open,High,Low,
#'   Close,Volume` for daily data and with the time after the date for
#'   intraday data. Any other status is returned as an `http_error` list.
#' @examples
#' \dontrun{
#' client$ticker(symbol = "RELIANCE", exchange = "NSE", interval = "D",
#'               start_date = "2025-01-01", end_date = "2025-01-31")
#' rows <- client$ticker(symbol = "RELIANCE", exchange = "NSE", interval = "5m",
#'                       start_date = "2025-01-30", end_date = "2025-01-31",
#'                       format = "txt")
#' if (is.character(rows)) cat(rows)
#' }
#' @family additional endpoints
#' @name ticker
NULL

#' Read the chart preferences
#'
#' Read every chart workspace preference stored for the API key. This is a GET
#' request with the API key in the query string.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/chart`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$chart(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional query parameters.
#' @return A named list with `status` and `data`, the stored preferences.
#' @examples
#' \dontrun{
#' client$chart()$data
#' }
#' @family additional endpoints
#' @name chart
NULL

#' Update the chart preferences
#'
#' Store chart workspace preferences for the API key. Every named argument is
#' one preference, sent as is (a list becomes a JSON object).
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/chart`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$updatechart(...)
#' ```
#' @section Arguments:
#' * `...`: The preferences as named arguments, for example
#'   `tv_theme = "dark"`. `NULL` values are skipped. At least one and at most
#'   50 preferences, with names of at most 50 characters.
#' @return A named list with `status` and `message`. When no preference is
#'   given, more than 50 are given or a name is longer than 50 characters, an
#'   error list with `error_type = "validation_error"` is returned without
#'   calling the server (the server rejects the same requests).
#' @examples
#' \dontrun{
#' client$updatechart(tv_theme = "dark", tv_chart_layout = list(interval = "15m"))
#' }
#' @family additional endpoints
#' @name updatechart
NULL

#' Read the Telegram bot configuration
#'
#' Read the Telegram bot configuration. The bot token is masked by the
#' server. This is a GET request with the API key in the query string.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/telegram/config`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegramconfig(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional query parameters.
#' @return A named list with `status` and `data`, the configuration (for
#'   example `bot_token` (masked), `is_active`, `polling_mode`,
#'   `broadcast_enabled` and `rate_limit_per_minute`).
#' @examples
#' \dontrun{
#' client$telegramconfig()$data
#' }
#' @family additional endpoints
#' @name telegramconfig
NULL

#' Update the Telegram bot configuration
#'
#' Update the Telegram bot configuration. Only the fields given are changed.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/telegram/config`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$updatetelegramconfig(token = NULL, webhook_url = NULL,
#'                             polling_mode = NULL, broadcast_enabled = NULL,
#'                             rate_limit_per_minute = NULL, ...)
#' ```
#' @section Arguments:
#' * `token`: Telegram bot token. Optional.
#' * `webhook_url`: Webhook URL of the bot. Optional.
#' * `polling_mode`: `TRUE` for polling mode, `FALSE` for webhook mode.
#'   Optional.
#' * `broadcast_enabled`: Allow broadcast messages. Optional.
#' * `rate_limit_per_minute`: Messages per minute, 1 to 120. Optional.
#' * `...`: Optional additional fields for future API extensions.
#'
#' Arguments left `NULL` are not sent.
#' @return A named list with `status` and `message`.
#' @examples
#' \dontrun{
#' client$updatetelegramconfig(polling_mode = TRUE, rate_limit_per_minute = 30)
#' }
#' @family additional endpoints
#' @name updatetelegramconfig
NULL

#' Start the Telegram bot
#'
#' Start the Telegram bot with the stored configuration (polling mode, or
#' initialized for webhook mode). The bot token must be configured.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/telegram/start`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegramstart(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `message`.
#' @examples
#' \dontrun{
#' client$telegramstart()
#' }
#' @family additional endpoints
#' @name telegramstart
NULL

#' Stop the Telegram bot
#'
#' Stop the Telegram bot. A stopped bot also suppresses the automatic order
#' alerts and rejects [telegram] notifications.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/telegram/stop`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegramstop(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `message`.
#' @examples
#' \dontrun{
#' client$telegramstop()
#' }
#' @family additional endpoints
#' @name telegramstop
NULL

#' List the linked Telegram users
#'
#' List the Telegram users linked to OpenAlgo, optionally filtered. This is a
#' GET request with the API key and the filters in the query string.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/telegram/users`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegramusers(broker = NULL, notifications_enabled = NULL, ...)
#' ```
#' @section Arguments:
#' * `broker`: Only users of this broker. Optional.
#' * `notifications_enabled`: `TRUE` or `FALSE` to filter on the
#'   notification setting (sent as `"true"` or `"false"`). Optional.
#' * `...`: Optional additional query parameters.
#' @return A named list with `status`, `data` (the users) and `count`.
#' @examples
#' \dontrun{
#' client$telegramusers()
#' client$telegramusers(notifications_enabled = TRUE)
#' }
#' @family additional endpoints
#' @name telegramusers
NULL

#' Broadcast a Telegram message
#'
#' Ask the server to broadcast a message to the linked Telegram users. The
#' server allows 5 broadcasts per minute and refuses them (HTTP 403) when
#' broadcasting is disabled in the bot configuration. The current server
#' validates the request but does not deliver it yet: it reports zero
#' deliveries.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/telegram/broadcast`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegrambroadcast(message, filters = NULL, ...)
#' ```
#' @section Arguments:
#' * `message`: The message, at most 4096 characters. Required.
#' * `filters`: Optional user filters, a named list sent as a JSON object.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status`, `message`, `success_count` and
#'   `fail_count`.
#' @examples
#' \dontrun{
#' client$telegrambroadcast(message = "Markets open in 15 minutes")
#' }
#' @family additional endpoints
#' @name telegrambroadcast
NULL

#' Get Telegram bot statistics
#'
#' Get the bot command statistics of the last days. This is a GET request
#' with the API key in the query string.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/telegram/stats`) but the Python SDK has no counterpart.
#'
#' @section Usage:
#' ```
#' client$telegramstats(days = NULL, ...)
#' ```
#' @section Arguments:
#' * `days`: Number of days, 1 to 365. When `NULL` (default) it is not sent
#'   and the server uses 7.
#' * `...`: Optional additional query parameters.
#' @return A named list with `status` and `data`, the statistics.
#' @examples
#' \dontrun{
#' client$telegramstats(days = 30)
#' }
#' @family additional endpoints
#' @name telegramstats
NULL

#' Read the preferences of a Telegram user
#'
#' Read the notification preferences of one linked Telegram user. This is a
#' GET request with the API key and `telegram_id` in the query string.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`GET /api/v1/telegram/preferences`) but the Python SDK has no
#' counterpart.
#'
#' @section Usage:
#' ```
#' client$telegrampreferences(telegram_id, ...)
#' ```
#' @section Arguments:
#' * `telegram_id`: Numeric Telegram user id. Required.
#' * `...`: Optional additional query parameters.
#' @return A named list with `status` and `data`, the preferences.
#' @examples
#' \dontrun{
#' client$telegrampreferences(telegram_id = 123456789)
#' }
#' @family additional endpoints
#' @name telegrampreferences
NULL

#' Update the preferences of a Telegram user
#'
#' Update the notification preferences of one linked Telegram user. Only the
#' preferences given are changed.
#'
#' This method is an addition: the OpenAlgo REST API provides the endpoint
#' (`POST /api/v1/telegram/preferences`) but the Python SDK has no
#' counterpart.
#'
#' @section Usage:
#' ```
#' client$updatetelegrampreferences(telegram_id, order_notifications = NULL,
#'                                  trade_notifications = NULL,
#'                                  pnl_notifications = NULL,
#'                                  daily_summary = NULL, summary_time = NULL,
#'                                  language = NULL, timezone = NULL, ...)
#' ```
#' @section Arguments:
#' * `telegram_id`: Numeric Telegram user id. Required.
#' * `order_notifications`: Enable order notifications (`TRUE`/`FALSE`).
#' * `trade_notifications`: Enable trade notifications.
#' * `pnl_notifications`: Enable P&L notifications.
#' * `daily_summary`: Enable the daily summary.
#' * `summary_time`: Daily summary time as `"HH:MM"`.
#' * `language`: Preferred language.
#' * `timezone`: Time zone of the user.
#' * `...`: Optional additional fields for future API extensions.
#'
#' Arguments left `NULL` are not sent.
#' @return A named list with `status` and `message`.
#' @examples
#' \dontrun{
#' client$updatetelegrampreferences(telegram_id = 123456789,
#'                                  daily_summary = TRUE, summary_time = "16:00")
#' }
#' @family additional endpoints
#' @name updatetelegrampreferences
NULL

# The validation error list (same shape as margin() and the GTT methods).
ext_validation_error <- function(message) {
  list(status = "error", message = message, error_type = "validation_error")
}

# TRUE for a scalar NA, which a data frame row holds for a missing value.
ext_is_na_scalar <- function(x) {
  is.atomic(x) && length(x) == 1 && is.na(x)
}

# Normalize the `symbols` argument of multioptiongreeks() into a list of
# named lists: a list of options, a single option (one named list) or a data
# frame with one option per row. Returns NULL when the shape is not usable.
ext_option_items <- function(symbols) {
  if (is.data.frame(symbols)) {
    return(lapply(seq_len(nrow(symbols)), function(i) as.list(symbols[i, , drop = FALSE])))
  }
  if (!is.list(symbols)) return(NULL)
  nms <- names(symbols)
  if (!is.null(nms) && any(nms %in% c("symbol", "exchange"))) {
    return(list(symbols))
  }
  if (!is.null(nms) && any(nzchar(nms))) return(NULL)
  unname(symbols)
}

# One option of multioptiongreeks(): the known fields first, in the server's
# order, then any other field; NULL and NA values are left out.
ext_option_item <- function(item) {
  known <- c("symbol", "exchange", "underlying_symbol", "underlying_exchange")
  keys <- c(intersect(known, names(item)), setdiff(names(item), known))
  out <- empty_named_list()
  for (key in keys) {
    value <- item[[key]]
    if (is.factor(value)) value <- as.character(value)
    if (is.null(value) || ext_is_na_scalar(value)) next
    out[key] <- list(value)
  }
  out
}

# TRUE for a non-empty single string or number, as a required field needs.
ext_present <- function(x) {
  !is.null(x) && length(x) == 1 && !is.na(x) && nzchar(as.character(x))
}

extensions_public <- list(
  ping = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("ping", payload)
  },

  pnlsymbols = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("pnl/symbols", payload)
  },

  multioptiongreeks = function(..., symbols, interest_rate = NULL, expiry_time = NULL) {
    kwargs <- dots_kwargs(...)
    items <- ext_option_items(symbols)
    if (is.null(items)) {
      return(ext_validation_error("symbols must be a list of options"))
    }
    if (length(items) == 0) {
      return(ext_validation_error("symbols must contain at least one option"))
    }
    if (length(items) > 50) {
      return(ext_validation_error("Maximum 50 symbols allowed"))
    }
    processed <- vector("list", length(items))
    for (i in seq_along(items)) {
      item <- items[[i]]
      if (!is.list(item) || is.null(names(item))) {
        return(ext_validation_error(sprintf("symbols[%d] must be a named list", i)))
      }
      item <- ext_option_item(item)
      if (!ext_present(item[["symbol"]])) {
        return(ext_validation_error(sprintf("symbols[%d]: symbol is required", i)))
      }
      if (!ext_present(item[["exchange"]])) {
        return(ext_validation_error(sprintf("symbols[%d]: exchange is required", i)))
      }
      processed[[i]] <- item
    }
    payload <- list(
      apikey = self$api_key,
      symbols = processed
    )
    if (!is.null(interest_rate)) payload$interest_rate <- interest_rate
    if (!is.null(expiry_time)) payload$expiry_time <- expiry_time
    payload <- add_kwargs(payload, kwargs)
    private$make_request("multioptiongreeks", payload)
  },

  ticker = function(..., symbol, exchange, interval = "D", start_date, end_date,
                    format = "json") {
    kwargs <- dots_kwargs(...)
    endpoint <- paste0("ticker/", curl::curl_escape(paste0(py_str(exchange), ":", py_str(symbol))))
    params <- list(
      apikey = self$api_key,
      interval = interval,
      from = start_date,
      to = end_date,
      format = format
    )
    params <- add_kwargs(params, kwargs)
    if (!identical(tolower(py_str(format)), "txt")) {
      return(private$ext_get(endpoint, params))
    }
    # Plain text: the body itself on 200, the usual http_error otherwise.
    tryCatch({
      resp <- private$perform(paste0(self$base_url, endpoint), query = params)
      text <- response_text(resp)
      if (resp$status_code != 200) {
        error_result(sprintf("HTTP %d: %s", resp$status_code, text), "http_error",
                     code = resp$status_code)
      } else {
        text
      }
    }, error = function(e) transport_error(e))
  },

  chart = function(...) {
    kwargs <- dots_kwargs(...)
    params <- add_kwargs(list(apikey = self$api_key), kwargs)
    private$ext_get("chart", params)
  },

  updatechart = function(...) {
    kwargs <- dots_kwargs(...)
    preferences <- add_kwargs(empty_named_list(), kwargs)
    if (length(preferences) == 0) {
      return(ext_validation_error("No preferences provided to update"))
    }
    if (length(preferences) > 50) {
      return(ext_validation_error("Too many preference keys (max 50)"))
    }
    long <- names(preferences)[nchar(names(preferences)) > 50]
    if (length(long) > 0) {
      return(ext_validation_error(sprintf("Preference key too long: %s... (max 50 chars)",
                                          substr(long[1], 1, 20))))
    }
    payload <- c(list(apikey = self$api_key), preferences)
    private$make_request("chart", payload)
  },

  telegramconfig = function(...) {
    kwargs <- dots_kwargs(...)
    params <- add_kwargs(list(apikey = self$api_key), kwargs)
    private$ext_get("telegram/config", params)
  },

  updatetelegramconfig = function(..., token = NULL, webhook_url = NULL, polling_mode = NULL,
                                  broadcast_enabled = NULL, rate_limit_per_minute = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- add_kwargs(list(apikey = self$api_key), list(
      token = token,
      webhook_url = webhook_url,
      polling_mode = polling_mode,
      broadcast_enabled = broadcast_enabled,
      rate_limit_per_minute = rate_limit_per_minute
    ))
    payload <- add_kwargs(payload, kwargs)
    private$make_request("telegram/config", payload)
  },

  telegramstart = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- add_kwargs(list(apikey = self$api_key), kwargs)
    private$make_request("telegram/start", payload)
  },

  telegramstop = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- add_kwargs(list(apikey = self$api_key), kwargs)
    private$make_request("telegram/stop", payload)
  },

  telegramusers = function(..., broker = NULL, notifications_enabled = NULL) {
    kwargs <- dots_kwargs(...)
    if (is.logical(notifications_enabled) && length(notifications_enabled) == 1 &&
        !is.na(notifications_enabled)) {
      notifications_enabled <- if (notifications_enabled) "true" else "false"
    }
    params <- add_kwargs(list(apikey = self$api_key), list(
      broker = broker,
      notifications_enabled = notifications_enabled
    ))
    params <- add_kwargs(params, kwargs)
    private$ext_get("telegram/users", params)
  },

  telegrambroadcast = function(..., message, filters = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      message = message
    )
    if (!is.null(filters)) payload$filters <- filters
    payload <- add_kwargs(payload, kwargs)
    private$make_request("telegram/broadcast", payload)
  },

  telegramstats = function(..., days = NULL) {
    kwargs <- dots_kwargs(...)
    params <- add_kwargs(list(apikey = self$api_key), list(days = days))
    params <- add_kwargs(params, kwargs)
    private$ext_get("telegram/stats", params)
  },

  telegrampreferences = function(..., telegram_id) {
    kwargs <- dots_kwargs(...)
    params <- list(
      apikey = self$api_key,
      telegram_id = telegram_id
    )
    params <- add_kwargs(params, kwargs)
    private$ext_get("telegram/preferences", params)
  },

  updatetelegrampreferences = function(..., telegram_id, order_notifications = NULL,
                                       trade_notifications = NULL, pnl_notifications = NULL,
                                       daily_summary = NULL, summary_time = NULL,
                                       language = NULL, timezone = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      telegram_id = telegram_id
    )
    payload <- add_kwargs(payload, list(
      order_notifications = order_notifications,
      trade_notifications = trade_notifications,
      pnl_notifications = pnl_notifications,
      daily_summary = daily_summary,
      summary_time = summary_time,
      language = language,
      timezone = timezone
    ))
    payload <- add_kwargs(payload, kwargs)
    private$make_request("telegram/preferences", payload)
  }
)

extensions_private <- list(
  # GET with query parameters through handle_response; transport failures are
  # mapped to the usual error lists, as instruments() does.
  ext_get = function(endpoint, params) {
    tryCatch(private$get_request(endpoint, params), error = function(e) transport_error(e))
  }
)
