# WebSocket market data feed (Python: openalgo/feed.py, class FeedAPI).
#
# The Python SDK runs the socket in a background thread. R is single threaded,
# so here the socket (package 'websocket') and every timer run on the 'later'
# event loop instead. That loop runs by itself whenever the R console is idle;
# a script that is busy (or simply finishes) must pump it, which is what
# client$wait() does. connect() and disconnect() pump it while they block.
#
# later::run_now() does not run anything when it is called from inside a later
# callback, so the auto-reconnect logic cannot be a blocking loop like the
# Python reconnect thread. It is a small state machine driven by later::later()
# timers and the socket callbacks.

#' Connect to the WebSocket feed
#'
#' Connect to the OpenAlgo WebSocket server and authenticate with the API key.
#'
#' The WebSocket runs on the event loop of the 'later' package rather than in a
#' background thread (R is single threaded). `connect()` pumps that loop while
#' it waits: up to 5 seconds for the connection, then up to 5 seconds for the
#' authentication reply. Afterwards the loop runs automatically whenever the R
#' console is idle. In a script, call [wait] (`client$wait(seconds)`) to let
#' market data arrive and callbacks fire.
#'
#' If `auto_reconnect` is `TRUE` (the default, see [api()]), a dropped
#' connection is reopened with backoff (1, 2, 5, 10, 30 then 60 seconds),
#' re-authenticated, and every active subscription is replayed. The reconnect
#' timers also run on the 'later' loop, so a script must keep pumping it.
#'
#' The Python SDK sends a WebSocket ping every 20 seconds (with a 10 second
#' pong timeout) to detect silent dead connections. The R 'websocket' package
#' does not expose ping settings, so this cannot be configured here.
#'
#' Do not call `connect()` from inside a feed callback: the event loop cannot
#' be pumped from there, so it would time out and return `FALSE`.
#'
#' @section Usage:
#' ```
#' client$connect()
#' ```
#' @return `TRUE` if the connection and authentication succeed, `FALSE`
#'   otherwise.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000",
#'               ws_url = "ws://127.0.0.1:8765", verbose = 1)
#' client$connect()
#' }
#' @family websocket feed methods
#' @name connect
NULL

#' Disconnect from the WebSocket feed
#'
#' Close the WebSocket connection. This is a graceful shutdown: automatic
#' reconnection is suppressed until [connect] is called again. Waits up to 2
#' seconds for the close to complete.
#'
#' @section Usage:
#' ```
#' client$disconnect()
#' ```
#' @return `NULL`, invisibly.
#' @examples
#' \dontrun{
#' client$disconnect()
#' }
#' @family websocket feed methods
#' @name disconnect
NULL

#' Subscribe to LTP updates
#'
#' Subscribe to last traded price updates for one or more instruments. All
#' instruments are sent in a single bulk subscribe message.
#'
#' @section Usage:
#' ```
#' client$subscribe_ltp(instruments, on_data_received = NULL)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with
#'   `exchange` (exchange code such as `"NSE"`, `"BSE"`, `"NFO"`), `symbol`
#'   (trading symbol) and optionally `exchange_token` (used as the symbol when
#'   `symbol` is missing). A single instrument may also be given as one named
#'   list, and a data frame with those columns is accepted too. Invalid
#'   instruments are logged and skipped.
#' * `on_data_received`: Optional callback function, called with one argument
#'   for every update: `list(type = "market_data", symbol, exchange, mode = 1,
#'   data = list(ltp, timestamp))`, with `data$ltt` added when the server sends
#'   it.
#' @return `TRUE` if the subscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' instruments <- list(list(exchange = "NSE", symbol = "RELIANCE"),
#'                     list(exchange = "NSE", symbol = "INFY"))
#' client$subscribe_ltp(instruments, on_data_received = function(data) {
#'   cat(data$exchange, data$symbol, data$data$ltp, "\n")
#' })
#' client$wait(10)
#' }
#' @family websocket feed methods
#' @name subscribe_ltp
NULL

#' Unsubscribe from LTP updates
#'
#' Unsubscribe from LTP updates for instruments and delete their cached LTP
#' data.
#'
#' @section Usage:
#' ```
#' client$unsubscribe_ltp(instruments)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with `exchange`,
#'   `symbol` and optionally `exchange_token`.
#' @return `TRUE` if the unsubscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$unsubscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")))
#' }
#' @family websocket feed methods
#' @name unsubscribe_ltp
NULL

#' Subscribe to quote updates
#'
#' Subscribe to quote updates (open, high, low, close, LTP, volume and more)
#' for one or more instruments.
#'
#' @section Usage:
#' ```
#' client$subscribe_quote(instruments, on_data_received = NULL)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with `exchange`,
#'   `symbol` and optionally `exchange_token`.
#' * `on_data_received`: Optional callback function, called for every update
#'   with `list(type = "market_data", symbol, exchange, mode = 2, data)`,
#'   where `data` holds `open`, `high`, `low`, `close`, `ltp`, `volume`,
#'   `last_trade_quantity`, `avg_trade_price`, `change`, `change_percent` and
#'   `timestamp`.
#' @return `TRUE` if the subscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$subscribe_quote(list(list(exchange = "NSE", symbol = "SBIN")))
#' client$wait(5)
#' client$get_quotes()
#' }
#' @family websocket feed methods
#' @name subscribe_quote
NULL

#' Unsubscribe from quote updates
#'
#' Unsubscribe from quote updates for instruments and delete their cached
#' quote data.
#'
#' @section Usage:
#' ```
#' client$unsubscribe_quote(instruments)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with `exchange`,
#'   `symbol` and optionally `exchange_token`.
#' @return `TRUE` if the unsubscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$unsubscribe_quote(list(list(exchange = "NSE", symbol = "SBIN")))
#' }
#' @family websocket feed methods
#' @name unsubscribe_quote
NULL

#' Subscribe to market depth updates
#'
#' Subscribe to market depth (order book) updates for one or more
#' instruments. The subscribe message requests `depth` levels (5 by default,
#' as in the Python SDK).
#'
#' The `depth` argument is an addition: the Python SDK always requests 5
#' levels. The server accepts other levels (for example 20, 30 or 50); which
#' ones work depends on the broker, and a refused level is reported per
#' symbol in the subscribe acknowledgement (logged at `verbose = 1`). The
#' level is remembered per instrument, so an automatic reconnect replays each
#' depth subscription with the level it was made with.
#'
#' @section Usage:
#' ```
#' client$subscribe_depth(instruments, on_data_received = NULL, depth = 5)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with `exchange`,
#'   `symbol` and optionally `exchange_token`.
#' * `on_data_received`: Optional callback function, called for every update
#'   with `list(type = "market_data", symbol, exchange, mode = 3,
#'   data = list(ltp, timestamp, depth = list(buy, sell)))`.
#' * `depth`: Number of depth levels to request, a positive whole number such
#'   as 5, 20, 30 or 50 (broker dependent). Sent as the `depth` field of the
#'   subscribe message. Defaults to 5.
#' @return `TRUE` if the subscription request was sent, `FALSE` otherwise
#'   (also when `depth` is not a positive whole number, which is logged).
#' @examples
#' \dontrun{
#' client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")))
#' client$wait(5)
#' client$get_depth()
#'
#' # 20 levels, where the broker supports it
#' client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")), depth = 20)
#' }
#' @family websocket feed methods
#' @name subscribe_depth
NULL

#' Unsubscribe from market depth updates
#'
#' Unsubscribe from market depth updates for instruments and delete their
#' cached depth data.
#'
#' @section Usage:
#' ```
#' client$unsubscribe_depth(instruments)
#' ```
#' @section Arguments:
#' * `instruments`: A list of instruments, each a named list with `exchange`,
#'   `symbol` and optionally `exchange_token`.
#' @return `TRUE` if the unsubscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$unsubscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")))
#' }
#' @family websocket feed methods
#' @name unsubscribe_depth
NULL

#' Subscribe to order updates
#'
#' Subscribe to real-time order updates for the authenticated account. Order
#' updates cover asynchronous status changes pushed by the broker (or the
#' sandbox engine in analyze mode) after an order is placed: fills, partial
#' fills, rejections and cancellations. No symbols are involved; this is an
#' account-level stream.
#'
#' @section Usage:
#' ```
#' client$subscribe_orders(on_order_update = NULL)
#' ```
#' @section Arguments:
#' * `on_order_update`: Optional callback function, called with each
#'   `order_update` message as a named list with `type`, `orderid`, `symbol`,
#'   `exchange`, `action`, `quantity`, `pricetype`, `product`,
#'   `order_status`, `filled_quantity`, `pending_quantity`, `average_price`,
#'   `rejection_reason` and `broker`.
#' @return `TRUE` if the subscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$subscribe_orders(on_order_update = function(update) {
#'   cat(update$orderid, update$order_status, "\n")
#' })
#' }
#' @family websocket feed methods
#' @name subscribe_orders
NULL

#' Unsubscribe from order updates
#'
#' Stop receiving real-time order updates.
#'
#' @section Usage:
#' ```
#' client$unsubscribe_orders()
#' ```
#' @return `TRUE` if the unsubscription request was sent, `FALSE` otherwise.
#' @examples
#' \dontrun{
#' client$unsubscribe_orders()
#' }
#' @family websocket feed methods
#' @name unsubscribe_orders
NULL

#' Get the order updates received so far
#'
#' Return the order updates received since connecting, most recent first,
#' capped at 500. Pending event loop work is run first (without blocking), so
#' a polling script sees fresh data.
#'
#' @section Usage:
#' ```
#' client$get_orders()
#' ```
#' @return `list(orders = list(...))`, each element an `order_update` message.
#' @examples
#' \dontrun{
#' client$get_orders()$orders
#' }
#' @family websocket feed methods
#' @name get_orders
NULL

#' Get the latest LTP data
#'
#' Return the latest LTP data in nested form. Pending event loop work is run
#' first (without blocking), so a polling script sees fresh data.
#'
#' @section Usage:
#' ```
#' client$get_ltp(exchange = NULL, symbol = NULL)
#' ```
#' @section Arguments:
#' * `exchange`: Optional exchange filter.
#' * `symbol`: Optional symbol filter.
#' @return A nested named list
#'   `list(ltp = list(EXCHANGE = list(SYMBOL = list(timestamp, ltp))))`. With no
#'   data, `ltp` is an empty named list.
#' @examples
#' \dontrun{
#' client$get_ltp()
#' client$get_ltp(exchange = "NSE", symbol = "RELIANCE")$ltp$NSE$RELIANCE$ltp
#' }
#' @family websocket feed methods
#' @name get_ltp
NULL

#' Get the latest quote data
#'
#' Return the latest quote data in nested form. Pending event loop work is run
#' first (without blocking).
#'
#' @section Usage:
#' ```
#' client$get_quotes(exchange = NULL, symbol = NULL)
#' ```
#' @section Arguments:
#' * `exchange`: Optional exchange filter.
#' * `symbol`: Optional symbol filter.
#' @return A nested named list `list(quote = list(EXCHANGE = list(SYMBOL =
#'   list(timestamp, open, high, low, close, ltp, volume, last_trade_quantity,
#'   avg_trade_price, change, change_percent))))`. With no data, `quote` is an
#'   empty named list.
#' @examples
#' \dontrun{
#' client$get_quotes(exchange = "NSE")
#' }
#' @family websocket feed methods
#' @name get_quotes
NULL

#' Get the latest market depth data
#'
#' Return the latest market depth data in nested form. Each book is a named
#' list keyed `"1"`, `"2"`, and so on, padded with empty levels up to 5, or
#' up to the number of levels received when the server sent more (for
#' example 20 after `subscribe_depth(..., depth = 20)`), so both books of a
#' symbol have the same length. Pending event loop work is run first (without
#' blocking).
#'
#' @section Usage:
#' ```
#' client$get_depth(exchange = NULL, symbol = NULL)
#' ```
#' @section Arguments:
#' * `exchange`: Optional exchange filter.
#' * `symbol`: Optional symbol filter.
#' @return A nested named list `list(depth = list(EXCHANGE = list(SYMBOL =
#'   list(timestamp, ltp, buyBook, sellBook))))`, where each book level is
#'   `list(price, qty, orders)`. With no data, `depth` is an empty named list.
#' @examples
#' \dontrun{
#' book <- client$get_depth(exchange = "NSE", symbol = "SBIN")
#' book$depth$NSE$SBIN$buyBook[["1"]]$price
#' }
#' @family websocket feed methods
#' @name get_depth
NULL

#' Unsubscribe from all market data
#'
#' Unsubscribe from every LTP, quote and depth subscription of this
#' connection in one request (`{"action": "unsubscribe_all"}`). The active
#' subscriptions of all modes are forgotten, so an automatic reconnect does
#' not replay them, and the cached LTP, quote and depth data is cleared. The
#' order-update subscription is not affected (see [unsubscribe_orders]).
#'
#' This method is an addition: the OpenAlgo WebSocket server supports the
#' action but the Python SDK has no counterpart. The server answers with an
#' `unsubscribe` acknowledgement, logged per symbol at `verbose = 1`.
#'
#' @section Usage:
#' ```
#' client$unsubscribe_all()
#' ```
#' @return `TRUE` if the request was sent, `FALSE` otherwise (not connected
#'   or not authenticated). The local subscriptions and cached data are
#'   cleared in both cases.
#' @examples
#' \dontrun{
#' client$unsubscribe_all()
#' }
#' @family websocket feed methods
#' @name unsubscribe_all
NULL

#' Get the broker of the WebSocket session
#'
#' Ask the WebSocket server which broker serves this authenticated session
#' (`{"action": "get_broker_info"}`) and wait for the reply. While waiting the
#' event loop is pumped, so market data keeps being stored and callbacks keep
#' firing.
#'
#' This method is an addition: the OpenAlgo WebSocket server supports the
#' action but the Python SDK has no counterpart. Do not call it from inside a
#' feed callback: the event loop cannot be pumped from there, so it would time
#' out.
#'
#' @section Usage:
#' ```
#' client$get_broker_info(timeout = 5)
#' ```
#' @section Arguments:
#' * `timeout`: Seconds to wait for the reply. Defaults to 5.
#' @return The reply as a named list, for example `list(type = "broker_info",
#'   status = "success", broker = "yourbroker", adapter_status = "connected",
#'   user_id = "...")`. A server error reply (for example
#'   `list(status = "error", code = "NOT_AUTHENTICATED", message = "...")`)
#'   that arrives while waiting is returned as is. Without a connection the
#'   result is an error list with `error_type = "connection_error"`, and
#'   without a reply in time one with `error_type = "timeout_error"`.
#' @examples
#' \dontrun{
#' client$connect()
#' client$get_broker_info()$broker
#' }
#' @family websocket feed methods
#' @name get_broker_info
NULL

#' Get the brokers the server supports
#'
#' Ask the WebSocket server for the list of brokers it is configured for
#' (`{"action": "get_supported_brokers"}`) and wait for the reply. While
#' waiting the event loop is pumped, so market data keeps flowing.
#'
#' This method is an addition: the OpenAlgo WebSocket server supports the
#' action but the Python SDK has no counterpart. Do not call it from inside a
#' feed callback.
#'
#' @section Usage:
#' ```
#' client$get_supported_brokers(timeout = 5)
#' ```
#' @section Arguments:
#' * `timeout`: Seconds to wait for the reply. Defaults to 5.
#' @return The reply as a named list, for example
#'   `list(type = "supported_brokers", status = "success",
#'   brokers = list("yourbroker", "anotherbroker"), count = 2)`, or a server error reply,
#'   or an error list (`connection_error` or `timeout_error`) as for
#'   [get_broker_info].
#' @examples
#' \dontrun{
#' unlist(client$get_supported_brokers()$brokers)
#' }
#' @family websocket feed methods
#' @name get_supported_brokers
NULL

#' Measure the WebSocket round trip
#'
#' Send an application level ping (`{"action": "ping", "timestamp": <epoch
#' ms>}`) and wait for the server's `pong`. This is an optional latency
#' probe; WebSocket control frame pings are answered by the 'websocket'
#' package itself. While waiting the event loop is pumped, so market data
#' keeps flowing.
#'
#' This method is an addition: the OpenAlgo WebSocket server supports the
#' action but the Python SDK has no counterpart. It is named `ws_ping()`
#' because [ping] is the REST endpoint. Do not call it from inside a feed
#' callback.
#'
#' @section Usage:
#' ```
#' client$ws_ping(timeout = 5)
#' ```
#' @section Arguments:
#' * `timeout`: Seconds to wait for the reply. Defaults to 5.
#' @return The `pong` reply as a named list, for example
#'   `list(type = "pong", status = "success", server_timestamp = ...,
#'   client_timestamp = ..., latency_ms = 3)`, where `latency_ms` is the
#'   measured round trip in milliseconds, added by the client. A server error
#'   reply, or an error list (`connection_error` or `timeout_error`) as for
#'   [get_broker_info], otherwise.
#' @examples
#' \dontrun{
#' client$ws_ping()$latency_ms
#' }
#' @family websocket feed methods
#' @name ws_ping
NULL

#' Run the feed event loop for a while
#'
#' An R-specific addition with no Python counterpart. The Python SDK receives
#' data on a background thread. R is single threaded, so the WebSocket, the
#' feed callbacks and the auto-reconnect timers run on the event loop of the
#' 'later' package instead. That loop runs automatically whenever the R
#' console is idle, but while a script is running it only advances when it is
#' pumped. `wait()` pumps it for `seconds` seconds so that market data is
#' stored and callbacks fire, in the places where a Python script would call
#' `time.sleep()`.
#'
#' Do not call `wait()` from inside a feed callback: the loop cannot be pumped
#' from there, so it just blocks.
#'
#' @section Usage:
#' ```
#' client$wait(seconds = 1)
#' ```
#' @section Arguments:
#' * `seconds`: How long to run the event loop, in seconds.
#' @return `NULL`, invisibly.
#' @examples
#' \dontrun{
#' client$connect()
#' client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")),
#'                      on_data_received = function(data) print(data$data$ltp))
#' client$wait(30)
#' client$disconnect()
#' }
#' @family websocket feed methods
#' @name wait
NULL

# Reconnect backoff schedule in seconds, capped at the last value.
feed_backoffs <- c(1, 2, 5, 10, 30, 60)

feed_mode_names <- c("LTP", "Quote", "Depth")

# Current time in epoch milliseconds (Python: int(time.time() * 1000)).
feed_now_ms <- function() {
  floor(as.numeric(Sys.time()) * 1000)
}

# TRUE for a parsed JSON object (Python dict), including an empty one.
feed_is_dict <- function(x) {
  is.list(x) && !is.null(names(x))
}

# Python dict.get(key, default) on a parsed JSON value. A key present with a
# JSON null returns NULL (None), as in Python. A non-dict raises the same
# AttributeError text as Python.
feed_get <- function(x, key, default = NULL) {
  if (!feed_is_dict(x)) {
    stop(sprintf("'%s' object has no attribute 'get'", py_type_name(x)), call. = FALSE)
  }
  if (key %in% names(x)) x[[key]] else default
}

# Python `key in x` for a parsed JSON value.
feed_in <- function(key, x) {
  if (is.null(x)) {
    stop("argument of type 'NoneType' is not iterable", call. = FALSE)
  }
  if (is.list(x)) {
    if (feed_is_dict(x)) return(key %in% names(x))
    return(any(vapply(x, function(v) identical(v, key), logical(1))))
  }
  if (is.character(x) && length(x) == 1) {
    return(grepl(key, x, fixed = TRUE))
  }
  stop(sprintf("argument of type '%s' is not iterable", py_type_name(x)), call. = FALSE)
}

# Look up a field of a user supplied instrument (named list or named vector).
feed_field <- function(x, key) {
  nms <- names(x)
  if (is.null(nms) || !(key %in% nms)) return(NULL)
  x[[key]]
}

# TRUE when a parsed JSON number is a whole number that the server most likely
# sent as a float (for example 1234.0). jsonlite returns integers for JSON
# integers in the 32-bit range and doubles otherwise.
feed_json_float <- function(x) {
  is.double(x) && length(x) == 1 && !is.na(x) && is.finite(x) &&
    x == trunc(x) && abs(x) < 2^31
}

# Python repr() of a value, used for the dict printouts in the log.
feed_repr <- function(x, float_dot = TRUE) {
  if (is.null(x)) return("None")
  if (is.list(x)) {
    if (feed_is_dict(x)) {
      if (length(x) == 0) return("{}")
      items <- vapply(seq_along(x), function(i) {
        paste0(feed_repr(names(x)[i]), ": ", feed_repr(x[[i]], float_dot))
      }, character(1))
      return(paste0("{", paste(items, collapse = ", "), "}"))
    }
    items <- vapply(x, function(v) feed_repr(v, float_dot), character(1))
    return(paste0("[", paste(items, collapse = ", "), "]"))
  }
  if (length(x) != 1) {
    return(feed_repr(as.list(x), float_dot))
  }
  if (is.character(x)) {
    if (is.na(x)) return("None")
    s <- gsub("\\", "\\\\", x, fixed = TRUE)
    s <- gsub("\n", "\\n", s, fixed = TRUE)
    s <- gsub("\r", "\\r", s, fixed = TRUE)
    s <- gsub("\t", "\\t", s, fixed = TRUE)
    if (grepl("'", s, fixed = TRUE) && !grepl("\"", s, fixed = TRUE)) {
      return(paste0("\"", s, "\""))
    }
    return(paste0("'", gsub("'", "\\'", s, fixed = TRUE), "'"))
  }
  if (float_dot && feed_json_float(x)) {
    return(paste0(py_str(x), ".0"))
  }
  py_str(x)
}

# Python str() of a parsed JSON value, as an f-string without a format spec
# renders it.
feed_str <- function(x) {
  if (is.null(x) || is.list(x) || length(x) != 1) return(feed_repr(x))
  if (feed_json_float(x)) return(paste0(py_str(x), ".0"))
  py_str(x)
}

feed_pad <- function(s, width) {
  paste0(s, strrep(" ", max(0, width - nchar(s))))
}

# Python f"{x:<width}". Like Python, None or a container cannot take a format
# spec and raises.
feed_ljust <- function(x, width) {
  if (is.null(x) || is.list(x)) {
    stop(sprintf("unsupported format string passed to %s.__format__", py_type_name(x)),
         call. = FALSE)
  }
  feed_pad(feed_str(x), width)
}

# Python key.split(":"): keeps leading and trailing empty fields.
feed_split_key <- function(key) {
  parts <- strsplit(key, ":", fixed = TRUE)[[1]]
  if (endsWith(key, ":")) parts <- c(parts, "")
  parts
}

# Python `ex != exchange` filter test, for an optional filter argument.
feed_filter_out <- function(filter, value) {
  py_truthy(filter) && !(is.character(filter) && length(filter) == 1 && value == filter)
}

# Python `x or 0` on a depth level field.
feed_or0 <- function(x) {
  if (py_truthy(x)) x else 0
}

# Python int(): truncates; values outside the 32-bit range stay doubles.
feed_int <- function(x) {
  v <- trunc(as.numeric(x))
  if (!is.na(v) && abs(v) < 2^31) as.integer(v) else v
}

# Name of a mode as an acknowledgement reports it: the number 1, 2 or 3, or
# the label "LTP", "Quote" or "Depth" in any case (the server echoes the
# label). Anything else is "Unknown".
feed_mode_label <- function(mode) {
  if (is.numeric(mode) && length(mode) == 1 && !is.na(mode) && mode %in% 1:3) {
    return(feed_mode_names[mode])
  }
  if (is.character(mode) && length(mode) == 1 && !is.na(mode)) {
    hit <- match(tolower(mode), tolower(feed_mode_names))
    if (!is.na(hit)) return(feed_mode_names[hit])
  }
  "Unknown"
}

# A server error frame: {"type": "error", ...}, or the proxy's
# {"status": "error", "code": ..., "message": ...} that carries no type.
feed_is_error_frame <- function(message, type) {
  identical(type, "error") ||
    (is.null(type) && identical(feed_get(message, "status"), "error"))
}

# Build one book of get_depth(): levels keyed "1", "2", ... padded to
# `size` levels (5, or more when the server sent more levels).
feed_book <- function(levels, size = 5L) {
  book <- empty_named_list()
  n <- length(levels)
  for (i in seq_len(n)) {
    level <- levels[[i]]
    book[[as.character(i)]] <- list(
      price = as.numeric(feed_or0(feed_get(level, "price"))),
      qty = feed_int(feed_or0(feed_get(level, "quantity"))),
      orders = feed_int(feed_or0(feed_get(level, "orders")))
    )
  }
  if (n < size) {
    for (i in (n + 1):size) {
      book[[as.character(i)]] <- list(price = 0, qty = 0L, orders = 0L)
    }
  }
  book
}

# Normalize the `instruments` argument into a list of instruments. Accepts a
# list of named lists (the Python shape), a single named list, or a data
# frame with one instrument per row.
feed_instrument_list <- function(instruments) {
  if (is.null(instruments)) return(list())
  if (is.data.frame(instruments)) {
    return(lapply(seq_len(nrow(instruments)), function(i) as.list(instruments[i, , drop = FALSE])))
  }
  nms <- names(instruments)
  if (!is.null(nms) && any(nms %in% c("exchange", "symbol", "exchange_token"))) {
    return(list(instruments))
  }
  as.list(instruments)
}

# Key of an active subscription, unambiguous for any exchange and symbol.
feed_sub_key <- function(exchange, symbol) {
  to_json(list(exchange, symbol))
}

feed_public <- list(
  connect = function() {
    # A user-initiated connect re-arms auto-reconnect (disconnect() disarms
    # it) and replaces any reconnect cycle that is still running.
    private$shutting_down <- FALSE
    private$feed_stop_reconnect()
    private$feed_do_connect()
  },

  disconnect = function() {
    # Mark a graceful shutdown so the close does not trigger auto-reconnect.
    private$shutting_down <- TRUE
    private$feed_stop_reconnect()
    if (!is.null(self$ws)) {
      tryCatch(self$ws$close(), error = function(e) NULL)
      start <- Sys.time()
      while (isTRUE(self$connected) && as.numeric(Sys.time() - start, units = "secs") < 2) {
        later::run_now(0.1)
      }
      # Events of the closed socket that arrive later are ignored.
      private$feed_sock_id <- private$feed_sock_id + 1L
      self$ws <- NULL
      self$connected <- FALSE
      self$authenticated <- FALSE
    }
    invisible(NULL)
  },

  subscribe_ltp = function(instruments, on_data_received = NULL) {
    private$feed_subscribe(1L, instruments, on_data_received)
  },

  unsubscribe_ltp = function(instruments) {
    private$feed_unsubscribe(1L, instruments)
  },

  subscribe_quote = function(instruments, on_data_received = NULL) {
    private$feed_subscribe(2L, instruments, on_data_received)
  },

  unsubscribe_quote = function(instruments) {
    private$feed_unsubscribe(2L, instruments)
  },

  subscribe_depth = function(instruments, on_data_received = NULL, depth = 5) {
    if (!is.numeric(depth) || length(depth) != 1 || is.na(depth) || depth < 1 ||
        depth != trunc(depth)) {
      private$feed_log(1, "ERROR", paste0("Invalid depth level: ", feed_repr(depth, float_dot = FALSE),
                                          " (must be a positive whole number)"))
      return(FALSE)
    }
    private$feed_subscribe(3L, instruments, on_data_received, depth = as.integer(depth))
  },

  unsubscribe_depth = function(instruments) {
    private$feed_unsubscribe(3L, instruments)
  },

  subscribe_orders = function(on_order_update = NULL) {
    if (!isTRUE(self$connected)) {
      private$feed_log(1, "ERROR", "Not connected to WebSocket server")
      return(FALSE)
    }
    if (!isTRUE(self$authenticated)) {
      private$feed_log(1, "ERROR", "Not authenticated with WebSocket server")
      return(FALSE)
    }
    if (!is.null(on_order_update)) {
      self$order_callback <- on_order_update
    }
    private$feed_log(1, "SUB", "Subscribing to order updates...")
    tryCatch({
      self$ws$send(to_json(list(action = "subscribe_orders")))
      private$orders_subscribed <- TRUE
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error sending order subscription: ", conditionMessage(e)))
      FALSE
    })
  },

  unsubscribe_orders = function() {
    if (!isTRUE(self$connected) || !isTRUE(self$authenticated)) {
      return(FALSE)
    }
    private$feed_log(1, "UNSUB", "Unsubscribing from order updates")
    private$orders_subscribed <- FALSE
    tryCatch({
      self$ws$send(to_json(list(action = "unsubscribe_orders")))
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error sending order unsubscription: ", conditionMessage(e)))
      FALSE
    })
  },

  unsubscribe_all = function() {
    # Forget every market data subscription and its cached data first, so a
    # reconnect does not replay them even when the request cannot be sent.
    private$active_subs <- list(empty_named_list(), empty_named_list(), empty_named_list())
    private$feed_depth_levels <- list()
    self$ltp_data <- empty_named_list()
    self$quotes_data <- empty_named_list()
    self$depth_data <- empty_named_list()
    if (!isTRUE(self$connected) || !isTRUE(self$authenticated) || is.null(self$ws)) {
      return(FALSE)
    }
    private$feed_log(1, "UNSUB", "Unsubscribing from all market data")
    tryCatch({
      self$ws$send(to_json(list(action = "unsubscribe_all")))
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error sending unsubscribe_all: ", conditionMessage(e)))
      FALSE
    })
  },

  get_broker_info = function(timeout = 5) {
    private$feed_request(list(action = "get_broker_info"), "broker_info", timeout)
  },

  get_supported_brokers = function(timeout = 5) {
    private$feed_request(list(action = "get_supported_brokers"), "supported_brokers", timeout)
  },

  ws_ping = function(timeout = 5) {
    sent_ms <- feed_now_ms()
    reply <- private$feed_request(list(action = "ping", timestamp = sent_ms), "pong", timeout)
    if (feed_is_dict(reply) && identical(reply[["type"]], "pong")) {
      # Measured from the moment the reply was read off the socket.
      reply$latency_ms <- private$feed_reply_ms - sent_ms
    }
    reply
  },

  get_orders = function() {
    private$feed_poll()
    list(orders = self$order_data)
  },

  get_ltp = function(exchange = NULL, symbol = NULL) {
    private$feed_poll()
    out <- empty_named_list()
    for (symbol_key in names(self$ltp_data)) {
      if (!grepl(":", symbol_key, fixed = TRUE)) next
      data <- self$ltp_data[[symbol_key]]
      parts <- feed_split_key(symbol_key)
      ex <- parts[1]
      sym <- parts[2]
      if (feed_filter_out(exchange, ex)) next
      if (feed_filter_out(symbol, sym)) next
      if (is.null(out[[ex]])) out[[ex]] <- empty_named_list()
      out[[ex]][[sym]] <- list(timestamp = data[["timestamp"]], ltp = data[["price"]])
    }
    list(ltp = out)
  },

  get_quotes = function(exchange = NULL, symbol = NULL) {
    private$feed_poll()
    out <- empty_named_list()
    for (symbol_key in names(self$quotes_data)) {
      if (!grepl(":", symbol_key, fixed = TRUE)) next
      data <- self$quotes_data[[symbol_key]]
      parts <- feed_split_key(symbol_key)
      ex <- parts[1]
      sym <- parts[2]
      if (feed_filter_out(exchange, ex)) next
      if (feed_filter_out(symbol, sym)) next
      if (is.null(out[[ex]])) out[[ex]] <- empty_named_list()
      out[[ex]][[sym]] <- list(
        timestamp = data[["timestamp"]],
        open = data[["open"]],
        high = data[["high"]],
        low = data[["low"]],
        close = data[["close"]],
        ltp = data[["ltp"]],
        volume = feed_get(data, "volume", 0L),
        last_trade_quantity = feed_get(data, "last_trade_quantity", 0L),
        avg_trade_price = feed_get(data, "avg_trade_price", 0L),
        change = feed_get(data, "change", 0L),
        change_percent = feed_get(data, "change_percent", 0L)
      )
    }
    list(quote = out)
  },

  get_depth = function(exchange = NULL, symbol = NULL) {
    private$feed_poll()
    out <- empty_named_list()
    for (symbol_key in names(self$depth_data)) {
      if (!grepl(":", symbol_key, fixed = TRUE)) next
      data <- self$depth_data[[symbol_key]]
      parts <- feed_split_key(symbol_key)
      ex <- parts[1]
      sym <- parts[2]
      if (feed_filter_out(exchange, ex)) next
      if (feed_filter_out(symbol, sym)) next
      if (is.null(out[[ex]])) out[[ex]] <- empty_named_list()
      book <- feed_get(data, "depth", empty_named_list())
      buy <- feed_get(book, "buy", list())
      sell <- feed_get(book, "sell", list())
      # Both books are padded to 5 levels, or to the deeper book's length
      # when more levels were received.
      size <- max(5L, length(buy), length(sell))
      out[[ex]][[sym]] <- list(
        timestamp = feed_get(data, "timestamp", feed_now_ms()),
        ltp = feed_get(data, "ltp", 0L),
        buyBook = feed_book(buy, size),
        sellBook = feed_book(sell, size)
      )
    }
    list(depth = out)
  },

  wait = function(seconds = 1) {
    start <- Sys.time()
    repeat {
      remaining <- seconds - as.numeric(Sys.time() - start, units = "secs")
      if (remaining <= 0) break
      later::run_now(min(remaining, 0.1))
    }
    invisible(NULL)
  }
)

feed_private <- list(
  # Id of the current socket. Every socket's callbacks carry the id it was
  # opened with; events of a replaced or retired socket are ignored.
  feed_sock_id = 0L,
  feed_sock_opened = FALSE,
  feed_sock_closed = FALSE,
  # Auto-reconnect state machine (Python: the reconnect thread).
  feed_reconnect_active = FALSE,
  feed_reconnect_attempt = 0L,
  feed_reconnect_sock = NULL,
  feed_reconnect_timer = NULL,
  feed_reconnect_check = NULL,
  # Depth level of each active depth subscription, keyed like active_subs.
  feed_depth_levels = list(),
  # Replies to request/response actions (broker_info, supported_brokers,
  # pong) and server error frames, numbered so a waiting request only takes
  # a reply that arrived after it was sent. Only the last few are kept.
  feed_replies = list(),
  feed_reply_seq = 0L,
  feed_reply_ms = NULL,

  feed_log = function(level, category, message) {
    if (self$verbose >= level) {
      cat(sprintf("%-8s %s", paste0("[", category, "]"), message), "\n", sep = "")
    }
    invisible(NULL)
  },

  # Run whatever is ready on the event loop without blocking.
  feed_poll = function() {
    later::run_now(0)
    invisible(NULL)
  },

  # Send one request/response action and pump the event loop until a reply of
  # type `reply_type` (or a server error frame) arrives, at most `timeout`
  # seconds. Market data that arrives meanwhile is processed as usual.
  feed_request = function(msg, reply_type, timeout = 5) {
    if (!isTRUE(self$connected) || is.null(self$ws)) {
      return(error_result("Not connected to WebSocket server", "connection_error"))
    }
    start_seq <- private$feed_reply_seq
    sent <- tryCatch({
      self$ws$send(to_json(msg))
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", sprintf("Error sending %s: %s", msg$action, conditionMessage(e)))
      FALSE
    })
    if (!sent) {
      return(error_result(sprintf("Failed to send %s request", msg$action), "connection_error"))
    }
    find_reply <- function() {
      for (entry in private$feed_replies) {
        if (entry$seq > start_seq && (identical(entry$type, reply_type) || entry$error)) {
          return(entry)
        }
      }
      NULL
    }
    start <- Sys.time()
    repeat {
      entry <- find_reply()
      if (!is.null(entry)) {
        private$feed_reply_ms <- entry$ms
        return(entry$message)
      }
      remaining <- timeout - as.numeric(Sys.time() - start, units = "secs")
      if (remaining <= 0 || !isTRUE(self$connected)) break
      later::run_now(min(remaining, 0.05))
    }
    if (!isTRUE(self$connected)) {
      return(error_result(sprintf("Connection closed while waiting for %s reply", reply_type),
                          "connection_error"))
    }
    error_result(sprintf("Timed out waiting for %s reply", reply_type), "timeout_error")
  },

  # Keep a reply for feed_request().
  feed_store_reply = function(type, message, error = FALSE) {
    private$feed_reply_seq <- private$feed_reply_seq + 1L
    entry <- list(seq = private$feed_reply_seq, type = type, error = error, message = message,
                  ms = feed_now_ms())
    replies <- c(private$feed_replies, list(entry))
    if (length(replies) > 20) replies <- replies[(length(replies) - 19):length(replies)]
    private$feed_replies <- replies
    invisible(NULL)
  },

  # Open one WebSocket connection with its callbacks and start connecting.
  feed_open_socket = function() {
    private$feed_sock_id <- private$feed_sock_id + 1L
    id <- private$feed_sock_id
    ws <- websocket::WebSocket$new(self$ws_url, autoConnect = FALSE, errorLogChannels = "none")
    ws$onOpen(function(event) private$feed_on_open(id))
    ws$onMessage(function(event) {
      if (id == private$feed_sock_id) private$feed_process_message(event$data)
    })
    ws$onClose(function(event) {
      if (id == private$feed_sock_id) private$feed_handle_closed(id)
    })
    ws$onError(function(event) private$feed_on_error(id, event$message))
    private$feed_sock_opened <- FALSE
    private$feed_sock_closed <- FALSE
    self$ws <- ws
    ws$connect()
    invisible(id)
  },

  # Stop using the current socket: its later events are ignored.
  feed_retire_socket = function() {
    ws <- self$ws
    private$feed_sock_id <- private$feed_sock_id + 1L
    self$ws <- NULL
    self$connected <- FALSE
    self$authenticated <- FALSE
    if (!is.null(ws)) {
      state <- tryCatch(as.integer(ws$readyState()), error = function(e) 3L)
      if (state %in% c(0L, 1L)) tryCatch(ws$close(), error = function(e) NULL)
    }
    invisible(NULL)
  },

  # Open a connection and block (pumping the event loop) until it is
  # authenticated. Used by connect() (Python: _do_connect).
  feed_do_connect = function() {
    tryCatch({
      if (!is.null(self$ws)) private$feed_retire_socket()
      self$connected <- FALSE
      self$authenticated <- FALSE
      private$feed_open_socket()

      start <- Sys.time()
      while (!isTRUE(self$connected) && as.numeric(Sys.time() - start, units = "secs") < 5) {
        later::run_now(0.1)
      }
      if (!isTRUE(self$connected)) {
        private$feed_log(1, "ERROR", "Failed to connect to WebSocket server")
        return(FALSE)
      }

      start <- Sys.time()
      while (!isTRUE(self$authenticated) && as.numeric(Sys.time() - start, units = "secs") < 5 &&
             isTRUE(self$connected)) {
        later::run_now(0.1)
      }
      isTRUE(self$authenticated)
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error connecting to WebSocket: ", conditionMessage(e)))
      FALSE
    })
  },

  feed_on_open = function(id) {
    if (id != private$feed_sock_id) return(invisible(NULL))
    private$feed_sock_opened <- TRUE
    private$feed_log(1, "WS", paste0("Connected to ", self$ws_url))
    self$connected <- TRUE
    tryCatch(private$feed_authenticate(), error = function(e) {
      private$feed_log(1, "ERROR", paste0("WebSocket error: ", conditionMessage(e)))
    })
    invisible(NULL)
  },

  feed_on_error = function(id, message) {
    if (id != private$feed_sock_id) return(invisible(NULL))
    private$feed_log(1, "ERROR", paste0("WebSocket error: ", message))
    # A connection that fails (or dies with an error) does not always get an
    # onClose event here; Python's client always calls on_close after it.
    state <- tryCatch(as.integer(self$ws$readyState()), error = function(e) 3L)
    if (!private$feed_sock_opened || identical(state, 3L)) {
      private$feed_handle_closed(id)
    }
    invisible(NULL)
  },

  # Python: the on_close handler.
  feed_handle_closed = function(id) {
    if (private$feed_sock_closed) return(invisible(NULL))
    private$feed_sock_closed <- TRUE
    opened <- private$feed_sock_opened
    private$feed_log(1, "WS", paste0("Disconnected from ", self$ws_url))
    self$connected <- FALSE
    self$authenticated <- FALSE
    # Schedule auto-reconnect unless the user called disconnect() or
    # auto_reconnect is off. Active subscriptions are replayed once the new
    # connection authenticates.
    if (isTRUE(self$auto_reconnect) && !isTRUE(private$shutting_down)) {
      if (private$feed_reconnect_active) {
        if (identical(private$feed_reconnect_sock, id)) {
          private$feed_reconnect_failed(id, connect_failed = !opened)
        }
      } else {
        private$feed_schedule_reconnect()
      }
    }
    invisible(NULL)
  },

  # Start a reconnect cycle unless one is already running.
  feed_schedule_reconnect = function() {
    if (isTRUE(private$shutting_down) || !isTRUE(self$auto_reconnect)) return(invisible(NULL))
    if (private$feed_reconnect_active) return(invisible(NULL))
    private$feed_reconnect_active <- TRUE
    private$feed_reconnect_attempt <- 0L
    private$feed_reconnect_next()
  },

  # Wait out the backoff delay of the next attempt.
  feed_reconnect_next = function() {
    if (isTRUE(private$shutting_down) || isTRUE(self$authenticated)) {
      private$feed_stop_reconnect()
      return(invisible(NULL))
    }
    attempt <- private$feed_reconnect_attempt
    delay <- feed_backoffs[min(attempt, length(feed_backoffs) - 1) + 1]
    private$feed_log(1, "WS", sprintf("Reconnect attempt %d in %ds...", attempt + 1L, delay))
    private$feed_reconnect_timer <- later::later(function() {
      private$feed_reconnect_timer <- NULL
      private$feed_reconnect_try()
    }, delay)
    invisible(NULL)
  },

  # Open the socket of one attempt. It then has 5 seconds to connect and 5
  # more to authenticate before the attempt counts as failed.
  feed_reconnect_try = function() {
    if (!private$feed_reconnect_active) return(invisible(NULL))
    if (isTRUE(private$shutting_down) || isTRUE(self$authenticated)) {
      private$feed_stop_reconnect()
      return(invisible(NULL))
    }
    if (!is.null(self$ws)) private$feed_retire_socket()
    id <- tryCatch(private$feed_open_socket(), error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error connecting to WebSocket: ", conditionMessage(e)))
      NULL
    })
    if (is.null(id)) {
      private$feed_reconnect_attempt <- private$feed_reconnect_attempt + 1L
      private$feed_reconnect_next()
      return(invisible(NULL))
    }
    private$feed_reconnect_sock <- id
    private$feed_reconnect_check <- later::later(function() {
      private$feed_reconnect_check <- NULL
      private$feed_reconnect_deadline(id, 1L)
    }, 5)
    invisible(NULL)
  },

  feed_reconnect_deadline = function(id, phase) {
    if (!private$feed_reconnect_active || !identical(private$feed_reconnect_sock, id)) {
      return(invisible(NULL))
    }
    if (isTRUE(self$authenticated)) return(invisible(NULL))
    if (phase == 1L && isTRUE(self$connected)) {
      private$feed_reconnect_check <- later::later(function() {
        private$feed_reconnect_check <- NULL
        private$feed_reconnect_deadline(id, 2L)
      }, 5)
      return(invisible(NULL))
    }
    private$feed_reconnect_failed(id, connect_failed = !isTRUE(self$connected) && phase == 1L)
  },

  feed_reconnect_failed = function(id, connect_failed = FALSE) {
    if (!identical(private$feed_reconnect_sock, id)) return(invisible(NULL))
    private$feed_reconnect_sock <- NULL
    if (!is.null(private$feed_reconnect_check)) {
      private$feed_reconnect_check()
      private$feed_reconnect_check <- NULL
    }
    if (connect_failed) {
      private$feed_log(1, "ERROR", "Failed to connect to WebSocket server")
    }
    if (id == private$feed_sock_id) private$feed_retire_socket()
    private$feed_reconnect_attempt <- private$feed_reconnect_attempt + 1L
    private$feed_reconnect_next()
  },

  # Called when a connection authenticates while a reconnect cycle runs.
  feed_reconnect_succeeded = function() {
    private$feed_stop_reconnect()
    private$feed_log(1, "WS", "Reconnected and re-authenticated.")
    private$feed_replay_subscriptions()
  },

  # Cancel the reconnect cycle and its timers.
  feed_stop_reconnect = function() {
    if (!is.null(private$feed_reconnect_timer)) {
      private$feed_reconnect_timer()
      private$feed_reconnect_timer <- NULL
    }
    if (!is.null(private$feed_reconnect_check)) {
      private$feed_reconnect_check()
      private$feed_reconnect_check <- NULL
    }
    private$feed_reconnect_active <- FALSE
    private$feed_reconnect_sock <- NULL
    private$feed_reconnect_attempt <- 0L
    invisible(NULL)
  },

  # Re-issue every active subscription as one bulk message per mode, then the
  # order-update subscription. Callbacks are kept across reconnects.
  feed_replay_subscriptions = function() {
    for (mode in 1:3) {
      store <- private$active_subs[[mode]]
      if (length(store) == 0) next
      if (mode < 3L) {
        instruments <- unname(store)
        private$feed_log(1, "SUB", sprintf("Replaying %d %s subscription(s) after reconnect",
                                           length(instruments), feed_mode_names[mode]))
        private$feed_send_subscribe(mode, instruments)
        next
      }
      # Depth: one bulk message per depth level, in order of first use.
      levels <- vapply(names(store), function(k) {
        level <- private$feed_depth_levels[[k]]
        if (is.null(level)) 5L else as.integer(level)
      }, integer(1))
      for (level in unique(levels)) {
        instruments <- unname(store[levels == level])
        private$feed_log(1, "SUB", sprintf("Replaying %d %s subscription(s) after reconnect",
                                           length(instruments), feed_mode_names[mode]))
        private$feed_send_subscribe(mode, instruments, depth = level)
      }
    }
    if (isTRUE(private$orders_subscribed) && !is.null(self$ws)) {
      private$feed_log(1, "SUB", "Replaying order-update subscription after reconnect")
      tryCatch(self$ws$send(to_json(list(action = "subscribe_orders"))), error = function(e) {
        private$feed_log(1, "ERROR", paste0("Error replaying order subscription: ", conditionMessage(e)))
      })
    }
    invisible(NULL)
  },

  # One bulk subscribe message; `symbols` is always a JSON array.
  feed_send_subscribe = function(mode, instruments, depth = 5L) {
    if (is.null(self$ws)) return(FALSE)
    msg <- list(
      action = "subscribe",
      symbols = unname(instruments),
      mode = as.integer(mode),
      depth = as.integer(depth)
    )
    tryCatch({
      self$ws$send(to_json(msg))
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error sending bulk subscribe: ", conditionMessage(e)))
      FALSE
    })
  },

  # One bulk unsubscribe message; each entry carries its own mode.
  feed_send_unsubscribe = function(mode, instruments) {
    if (is.null(self$ws)) return(FALSE)
    symbols <- lapply(unname(instruments), function(i) {
      list(symbol = i[["symbol"]], exchange = i[["exchange"]], mode = as.integer(mode))
    })
    msg <- list(action = "unsubscribe", symbols = symbols)
    tryCatch({
      self$ws$send(to_json(msg))
      TRUE
    }, error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error sending bulk unsubscribe: ", conditionMessage(e)))
      FALSE
    })
  },

  # Validate one instrument. Returns list(exchange, symbol) or NULL (logged).
  feed_validate_instrument = function(instrument) {
    exchange <- feed_field(instrument, "exchange")
    symbol <- feed_field(instrument, "symbol")
    exchange_token <- feed_field(instrument, "exchange_token")
    # If only exchange_token is provided, it is used as the symbol.
    if (!py_truthy(symbol) && py_truthy(exchange_token)) {
      symbol <- exchange_token
    }
    if (!py_truthy(exchange) || !py_truthy(symbol)) {
      private$feed_log(1, "ERROR", paste0("Invalid instrument: ", feed_repr(instrument, float_dot = FALSE)))
      return(NULL)
    }
    list(exchange = exchange, symbol = symbol)
  },

  feed_subscribe = function(mode, instruments, callback, depth = 5L) {
    if (!isTRUE(self$connected)) {
      private$feed_log(1, "ERROR", "Not connected to WebSocket server")
      return(FALSE)
    }
    if (!isTRUE(self$authenticated)) {
      private$feed_log(1, "ERROR", "Not authenticated with WebSocket server")
      return(FALSE)
    }
    if (!is.null(callback)) {
      if (mode == 1L) self$ltp_callback <- callback
      else if (mode == 2L) self$quote_callback <- callback
      else self$depth_callback <- callback
    }
    valid <- list()
    for (instrument in feed_instrument_list(instruments)) {
      inst <- private$feed_validate_instrument(instrument)
      if (is.null(inst)) next
      entry <- list(symbol = inst$symbol, exchange = inst$exchange)
      valid[[length(valid) + 1L]] <- entry
      sub_key <- feed_sub_key(inst$exchange, inst$symbol)
      private$active_subs[[mode]][[sub_key]] <- entry
      if (mode == 3L) {
        # Remembered so a reconnect replays the same depth level.
        private$feed_depth_levels[[sub_key]] <- as.integer(depth)
      }
      private$feed_log(1, "SUB", sprintf("Subscribing %s:%s %s...", py_str(inst$exchange),
                                         py_str(inst$symbol), feed_mode_names[mode]))
    }
    if (length(valid) == 0) return(FALSE)
    # A single bulk message for every instrument.
    private$feed_send_subscribe(mode, valid, depth = depth)
  },

  feed_unsubscribe = function(mode, instruments) {
    if (!isTRUE(self$connected) || !isTRUE(self$authenticated)) {
      return(FALSE)
    }
    cache <- c("ltp_data", "quotes_data", "depth_data")[mode]
    valid <- list()
    for (instrument in feed_instrument_list(instruments)) {
      inst <- private$feed_validate_instrument(instrument)
      if (is.null(inst)) next
      private$feed_log(1, "UNSUB", sprintf("Unsubscribing %s:%s %s", py_str(inst$exchange),
                                           py_str(inst$symbol), feed_mode_names[mode]))
      valid[[length(valid) + 1L]] <- list(symbol = inst$symbol, exchange = inst$exchange)
      # Drop from the active subscriptions so a reconnect does not replay it.
      sub_key <- feed_sub_key(inst$exchange, inst$symbol)
      private$active_subs[[mode]][[sub_key]] <- NULL
      if (mode == 3L) private$feed_depth_levels[[sub_key]] <- NULL
      # Delete the cached data of this symbol.
      symbol_key <- paste0(py_str(inst$exchange), ":", py_str(inst$symbol))
      if (symbol_key %in% names(self[[cache]])) {
        self[[cache]][[symbol_key]] <- NULL
      }
    }
    if (length(valid) == 0) return(FALSE)
    private$feed_send_unsubscribe(mode, valid)
  },

  feed_authenticate = function() {
    if (!isTRUE(self$connected)) {
      private$feed_log(1, "ERROR", "Cannot authenticate: not connected")
      return(invisible(NULL))
    }
    key <- py_str(self$api_key)
    n <- nchar(key)
    private$feed_log(1, "AUTH", sprintf("Authenticating with API key: %s...%s",
                                        substr(key, 1, 8), substr(key, max(1, n - 7), n)))
    self$ws$send(to_json(list(action = "authenticate", api_key = self$api_key)))
    invisible(NULL)
  },

  # Python: _process_message.
  feed_process_message = function(message_str) {
    if (is.raw(message_str)) {
      message_str <- rawToChar(message_str)
      Encoding(message_str) <- "UTF-8"
    }
    parsed <- parse_json_text(message_str)
    if (!parsed$ok) {
      private$feed_log(1, "ERROR", sprintf("Invalid JSON message: %s...", substr(message_str, 1, 100)))
      return(invisible(NULL))
    }
    tryCatch(private$feed_dispatch(parsed$value), error = function(e) {
      private$feed_log(1, "ERROR", paste0("Error handling message: ", conditionMessage(e)))
    })
    invisible(NULL)
  },

  feed_dispatch = function(message) {
    type <- feed_get(message, "type")

    # Authentication response.
    if (identical(type, "auth")) {
      if (identical(feed_get(message, "status"), "success")) {
        self$authenticated <- TRUE
        broker <- feed_get(message, "broker", "unknown")
        user_id <- feed_get(message, "user_id", "unknown")
        private$feed_log(1, "AUTH", sprintf("Success | Broker: %s | User: %s",
                                            feed_str(broker), feed_str(user_id)))
        private$feed_log(2, "AUTH", paste0("Full response: ", feed_repr(message)))
        if (private$feed_reconnect_active) {
          private$feed_reconnect_succeeded()
        }
      } else {
        private$feed_log(1, "ERROR", paste0("Authentication failed: ",
                                            feed_str(feed_get(message, "message", "Unknown error"))))
      }
      return(invisible(NULL))
    }

    # Order-update subscription responses.
    if (identical(type, "subscribe_orders") || identical(type, "unsubscribe_orders")) {
      private$feed_log(1, "SUB", sprintf("Order updates | %s | Status: %s", type,
                                         feed_str(feed_get(message, "status", "?"))))
      private$feed_log(2, "SUB", paste0("Full response: ", feed_repr(message)))
      return(invisible(NULL))
    }

    # Real-time order updates (account level, no symbol subscription).
    if (identical(type, "order_update")) {
      orders <- c(list(message), self$order_data)
      if (length(orders) > 500) orders <- orders[1:500]
      self$order_data <- orders

      line <- sprintf("%s | %s | Qty: %s/%s | Avg: %s | ID: %s",
                      feed_ljust(feed_get(message, "symbol", "?"), 20),
                      feed_ljust(feed_get(message, "order_status", "?"), 10),
                      feed_str(feed_get(message, "filled_quantity", 0L)),
                      feed_str(feed_get(message, "quantity", 0L)),
                      feed_str(feed_get(message, "average_price", 0L)),
                      feed_str(feed_get(message, "orderid", "?")))
      private$feed_log(2, "ORDER", line)

      if (!is.null(self$order_callback)) {
        tryCatch(self$order_callback(message), error = function(e) {
          private$feed_log(1, "ERROR", paste0("Order callback error: ", conditionMessage(e)))
        })
      }
      return(invisible(NULL))
    }

    # Subscription response.
    if (identical(type, "subscribe")) {
      subs <- feed_get(message, "subscriptions", list())
      if (is.null(subs)) stop("'NoneType' object is not iterable", call. = FALSE)
      for (sub in subs) {
        sym <- feed_get(sub, "symbol", "?")
        exch <- feed_get(sub, "exchange", "?")
        status <- feed_get(sub, "status", "?")
        # The server echoes the mode as a label ("LTP", "Quote", "Depth");
        # a number is accepted too.
        mode_name <- feed_mode_label(feed_get(sub, "mode", 0L))
        line <- sprintf("%s:%s | Mode: %s | Status: %s", feed_str(exch), feed_str(sym),
                        mode_name, feed_str(status))
        if (identical(mode_name, "Depth") && !is.null(feed_get(sub, "depth"))) {
          line <- paste0(line, " | Depth: ", feed_str(feed_get(sub, "depth")))
        }
        # A failed symbol carries the reason, for example a refused depth level.
        if (!identical(status, "success") && !is.null(feed_get(sub, "message"))) {
          line <- paste0(line, " | Message: ", feed_str(feed_get(sub, "message")))
        }
        private$feed_log(1, "SUB", line)
      }
      private$feed_log(2, "SUB", paste0("Full response: ", feed_repr(message)))
      return(invisible(NULL))
    }

    # Unsubscription response (also the answer to unsubscribe_all).
    if (identical(type, "unsubscribe")) {
      for (group in c("successful", "failed")) {
        items <- feed_get(message, group, list())
        if (!is.list(items)) next
        for (item in items) {
          if (!feed_is_dict(item)) next
          line <- sprintf("%s:%s | Mode: %s | Status: %s",
                          feed_str(feed_get(item, "exchange", "?")),
                          feed_str(feed_get(item, "symbol", "?")),
                          feed_mode_label(feed_get(item, "mode", 0L)),
                          feed_str(feed_get(item, "status", if (group == "failed") "error" else "success")))
          if (group == "failed" && !is.null(feed_get(item, "message"))) {
            line <- paste0(line, " | Message: ", feed_str(feed_get(item, "message")))
          }
          private$feed_log(1, "UNSUB", line)
        }
      }
      private$feed_log(1, "UNSUB", sprintf("Unsubscribe | Status: %s",
                                           feed_str(feed_get(message, "status", "?"))))
      private$feed_log(2, "UNSUB", paste0("Full response: ", feed_repr(message)))
      return(invisible(NULL))
    }

    # Replies to get_broker_info(), get_supported_brokers() and ws_ping().
    if (identical(type, "broker_info") || identical(type, "supported_brokers") ||
        identical(type, "pong")) {
      private$feed_store_reply(type, message)
      private$feed_log(2, "WS", paste0("Reply ", type, ": ", feed_repr(message)))
      return(invisible(NULL))
    }

    # Server error frames: {"status": "error", "code", "message"} (the proxy
    # sends no type) or {"type": "error", ...}.
    if (feed_is_error_frame(message, type)) {
      private$feed_store_reply(type, message, error = TRUE)
      code <- feed_get(message, "code")
      private$feed_log(1, "ERROR", sprintf("Server error%s: %s",
                                           if (is.null(code)) "" else paste0(" ", feed_str(code)),
                                           feed_str(feed_get(message, "message", "Unknown error"))))
      return(invisible(NULL))
    }

    # Market data.
    if (identical(type, "market_data")) {
      exchange <- feed_get(message, "exchange")
      symbol <- feed_get(message, "symbol")
      if (py_truthy(exchange) && py_truthy(symbol)) {
        mode <- feed_get(message, "mode")
        market_data <- feed_get(message, "data", empty_named_list())
        symbol_key <- paste0(feed_str(exchange), ":", feed_str(symbol))
        is_mode <- function(m) {
          is.numeric(mode) && length(mode) == 1 && !is.na(mode) && mode == m
        }

        if (is_mode(1) && feed_in("ltp", market_data)) {
          # LTP data (mode 1).
          ltp <- feed_get(market_data, "ltp")
          timestamp <- feed_get(market_data, "timestamp", feed_now_ms())
          self$ltp_data[[symbol_key]] <- list(price = ltp, timestamp = timestamp)
          private$feed_log(2, "LTP", sprintf("%s | LTP: %s", feed_ljust(symbol_key, 20), feed_str(ltp)))

          if (!is.null(self$ltp_callback)) {
            tryCatch({
              # A clean market data update without redundant fields.
              clean_data <- list(
                type = "market_data",
                symbol = symbol,
                exchange = exchange,
                mode = mode,
                data = list(ltp = ltp, timestamp = timestamp)
              )
              # Include LTT if the server sent it, at the top level of the
              # data or nested one level deeper.
              if (feed_in("ltt", market_data)) {
                clean_data$data["ltt"] <- list(market_data[["ltt"]])
              } else if (feed_in("ltt", feed_get(market_data, "data", empty_named_list()))) {
                clean_data$data["ltt"] <- list(market_data[["data"]][["ltt"]])
              }
              self$ltp_callback(clean_data)
            }, error = function(e) {
              private$feed_log(1, "ERROR", paste0("LTP callback error: ", conditionMessage(e)))
            })
          }
        } else if (is_mode(2)) {
          # Quote data (mode 2).
          quote_data <- list(
            open = feed_get(market_data, "open", 0L),
            high = feed_get(market_data, "high", 0L),
            low = feed_get(market_data, "low", 0L),
            close = feed_get(market_data, "close", 0L),
            ltp = feed_get(market_data, "ltp", 0L),
            volume = feed_get(market_data, "volume", 0L),
            last_trade_quantity = feed_get(market_data, "last_trade_quantity", 0L),
            avg_trade_price = feed_get(market_data, "avg_trade_price", 0L),
            change = feed_get(market_data, "change", 0L),
            change_percent = feed_get(market_data, "change_percent", 0L),
            timestamp = feed_get(market_data, "timestamp", feed_now_ms())
          )
          self$quotes_data[[symbol_key]] <- quote_data
          private$feed_log(2, "QUOTE", sprintf(
            "%s | O: %s H: %s L: %s C: %s LTP: %s",
            feed_ljust(symbol_key, 20),
            feed_ljust(quote_data[["open"]], 10),
            feed_ljust(quote_data[["high"]], 10),
            feed_ljust(quote_data[["low"]], 10),
            feed_ljust(quote_data[["close"]], 10),
            feed_str(quote_data[["ltp"]])
          ))

          if (!is.null(self$quote_callback)) {
            tryCatch({
              clean_data <- list(
                type = "market_data",
                symbol = symbol,
                exchange = exchange,
                mode = mode,
                data = quote_data
              )
              self$quote_callback(clean_data)
            }, error = function(e) {
              private$feed_log(1, "ERROR", paste0("Quote callback error: ", conditionMessage(e)))
            })
          }
        } else if (is_mode(3) && feed_in("depth", market_data)) {
          # Market depth data (mode 3).
          depth_data <- list(
            ltp = feed_get(market_data, "ltp", 0L),
            timestamp = feed_get(market_data, "timestamp", feed_now_ms()),
            depth = feed_get(market_data, "depth", list(buy = list(), sell = list()))
          )
          self$depth_data[[symbol_key]] <- depth_data

          book <- feed_get(depth_data, "depth", empty_named_list())
          buy_depth <- feed_get(book, "buy", list())
          sell_depth <- feed_get(book, "sell", list())

          private$feed_log(2, "DEPTH", sprintf("%s | LTP: %s", feed_ljust(symbol_key, 20),
                                               feed_str(depth_data[["ltp"]])))

          if (self$verbose >= 2) {
            pad <- "         "
            cat(pad, feed_pad("BUY", 30), " | ", feed_pad("SELL", 30), "\n", sep = "")
            cat(pad, feed_pad("Price", 10), " ", feed_pad("Qty", 10), " ", feed_pad("Orders", 8),
                " | ", feed_pad("Price", 10), " ", feed_pad("Qty", 10), " ", feed_pad("Orders", 8),
                "\n", sep = "")
            cat(pad, strrep("-", 62), "\n", sep = "")
            max_levels <- max(length(buy_depth), length(sell_depth), 1)
            for (i in seq_len(max_levels)) {
              buy_lvl <- if (i <= length(buy_depth)) buy_depth[[i]] else empty_named_list()
              sell_lvl <- if (i <= length(sell_depth)) sell_depth[[i]] else empty_named_list()
              cells <- c(
                feed_pad(feed_str(feed_get(buy_lvl, "price", "-")), 10),
                feed_pad(feed_str(feed_get(buy_lvl, "quantity", "-")), 10),
                feed_pad(feed_str(feed_get(buy_lvl, "orders", "-")), 8),
                feed_pad(feed_str(feed_get(sell_lvl, "price", "-")), 10),
                feed_pad(feed_str(feed_get(sell_lvl, "quantity", "-")), 10),
                feed_pad(feed_str(feed_get(sell_lvl, "orders", "-")), 8)
              )
              cat(pad, cells[1], " ", cells[2], " ", cells[3], " | ", cells[4], " ", cells[5],
                  " ", cells[6], "\n", sep = "")
            }
          }

          if (!is.null(self$depth_callback)) {
            tryCatch({
              clean_data <- list(
                type = "market_data",
                symbol = symbol,
                exchange = exchange,
                mode = mode,
                data = depth_data
              )
              self$depth_callback(clean_data)
            }, error = function(e) {
              private$feed_log(1, "ERROR", paste0("Depth callback error: ", conditionMessage(e)))
            })
          }
        }
      }
    }
    invisible(NULL)
  }
)
