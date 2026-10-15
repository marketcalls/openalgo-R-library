#' OpenAlgo API client
#'
#' @description
#' The OpenAlgo client: one object carrying every REST method (orders, GTT
#' orders, market data, account, options, strategy module, notifications and
#' market calendar utilities) and the WebSocket market data feed. Create it
#' with [api()]; this R6 class generator is exported for `inherits()` checks
#' and for advanced use.
#'
#' Methods are called with `$`, for example `client$placeorder(...)`, and take
#' the same parameter names as the Python SDK. See [api()] for the method list.
#'
#' @export
OpenAlgoAPI <- R6::R6Class(
  "OpenAlgoAPI",
  inherit = BaseAPI,
  cloneable = FALSE,
  public = c(
    list(
      # @field verbose Feed logging level: 0 silent, 1 basic, 2 full debug.
      verbose = 0L,
      # @field ws_port WebSocket server port.
      ws_port = NULL,
      # @field ws_host WebSocket host derived from `host`.
      ws_host = NULL,
      # @field ws_url WebSocket URL.
      ws_url = NULL,
      # @field ws The underlying WebSocket connection, or `NULL`.
      ws = NULL,
      # @field connected `TRUE` while the WebSocket is open.
      connected = FALSE,
      # @field authenticated `TRUE` once the WebSocket is authenticated.
      authenticated = FALSE,
      # @field ltp_data Latest LTP per `"EXCHANGE:SYMBOL"`.
      ltp_data = NULL,
      # @field quotes_data Latest quote per `"EXCHANGE:SYMBOL"`.
      quotes_data = NULL,
      # @field depth_data Latest depth per `"EXCHANGE:SYMBOL"`.
      depth_data = NULL,
      # @field order_data Order updates received, most recent first (max 500).
      order_data = NULL,
      # @field ltp_callback Callback for LTP updates.
      ltp_callback = NULL,
      # @field quote_callback Callback for quote updates.
      quote_callback = NULL,
      # @field quotes_callback Reserved (kept for parity with the Python SDK).
      quotes_callback = NULL,
      # @field depth_callback Callback for depth updates.
      depth_callback = NULL,
      # @field order_callback Callback for order updates.
      order_callback = NULL,
      # @field auto_reconnect Reconnect and replay subscriptions after a drop.
      auto_reconnect = TRUE,

      # @description Create a client. Prefer [api()].
      # @param api_key User's API key.
      # @param host Base URL for the API endpoints.
      # @param version API version.
      # @param timeout Request timeout in seconds.
      # @param ws_port WebSocket server port.
      # @param ws_url Custom WebSocket URL, overrides `host` and `ws_port`.
      # @param verbose Feed logging level (`FALSE`/0, `TRUE`/1 or 2).
      # @param auto_reconnect Reconnect automatically after a drop.
      initialize = function(api_key, host = "http://127.0.0.1:5000", version = "v1",
                            timeout = 120.0, ws_port = 8765, ws_url = NULL,
                            verbose = FALSE, auto_reconnect = TRUE) {
        super$initialize(api_key, host, version, timeout)

        self$verbose <- if (isFALSE(verbose)) 0L else as.integer(verbose)
        self$ws_port <- ws_port

        if (py_truthy(ws_url)) {
          self$ws_url <- ws_url
        } else if (startsWith(host, "https://")) {
          # An addition to the Python derivation: production deployments
          # serve the WebSocket behind the same TLS domain at /ws, so an
          # https host maps to wss://<host[:port]>/ws and ws_port is unused.
          host_port <- strsplit(substring(host, 9), "/", fixed = TRUE)[[1]][1]
          self$ws_host <- strsplit(host_port, ":", fixed = TRUE)[[1]][1]
          self$ws_url <- paste0("wss://", host_port, "/ws")
        } else {
          ws_host <- host
          if (startsWith(ws_host, "http://")) {
            ws_host <- substring(ws_host, 8)
          } else if (startsWith(ws_host, "https://")) {
            ws_host <- substring(ws_host, 9)
          }
          ws_host <- strsplit(ws_host, "/", fixed = TRUE)[[1]][1]
          ws_host <- strsplit(ws_host, ":", fixed = TRUE)[[1]][1]
          self$ws_host <- ws_host
          self$ws_url <- paste0("ws://", ws_host, ":", py_str(ws_port))
        }

        self$ws <- NULL
        self$connected <- FALSE
        self$authenticated <- FALSE

        self$ltp_data <- empty_named_list()
        self$quotes_data <- empty_named_list()
        self$depth_data <- empty_named_list()
        self$order_data <- list()

        self$auto_reconnect <- isTRUE(as.logical(auto_reconnect))
        private$shutting_down <- FALSE
        private$orders_subscribed <- FALSE
        private$active_subs <- list(empty_named_list(), empty_named_list(), empty_named_list())
        invisible(self)
      },

      # @description Print a summary without revealing the API key.
      # @param ... Unused.
      print = function(...) {
        cat("<OpenAlgoAPI>\n")
        cat("  base_url: ", self$base_url, "\n", sep = "")
        cat("  ws_url:   ", self$ws_url, "\n", sep = "")
        cat("  feed:     ", if (isTRUE(self$authenticated)) "connected" else "not connected", "\n", sep = "")
        invisible(self)
      }
    ),
    orders_public,
    gtt_public,
    data_public,
    account_public,
    options_public,
    strategy_api_public,
    telegram_public,
    whatsapp_public,
    utilities_public,
    extensions_public,
    feed_public
  ),
  private = c(
    list(
      shutting_down = FALSE,
      orders_subscribed = FALSE,
      active_subs = NULL
    ),
    gtt_private,
    strategy_api_private,
    extensions_private,
    feed_private
  )
)

#' Create an OpenAlgo API client
#'
#' Initialize the OpenAlgo API client. This mirrors `openalgo.api(...)` in the
#' Python SDK: the returned object carries every REST method and the WebSocket
#' feed.
#'
#' @param api_key User's API key.
#' @param host Base URL for the API endpoints. Defaults to localhost.
#' @param version API version. Defaults to `"v1"`.
#' @param timeout Request timeout in seconds. Defaults to 120.
#' @param ws_port WebSocket server port. Defaults to 8765.
#' @param ws_url Custom WebSocket URL. Overrides `host` and `ws_port`. When
#'   not given it is derived from `host`: an `http://` host gives
#'   `ws://<hostname>:<ws_port>` (as in the Python SDK), and an `https://`
#'   host gives `wss://<host[:port]>/ws`, the path production deployments
#'   serve the WebSocket on (an addition; `ws_port` is not used then).
#' @param verbose Feed logging level. `FALSE` or 0: silent (errors only);
#'   `TRUE` or 1: connection, authentication and subscription status; 2: full
#'   debug including every market data update.
#' @param auto_reconnect If `TRUE` (default), the feed reconnects,
#'   re-authenticates and replays every active subscription after a drop,
#'   with exponential backoff.
#'
#' @return An [OpenAlgoAPI] object.
#'
#' @section Methods:
#' * Orders: [placeorder], [placesmartorder], [basketorder], [splitorder],
#'   [orderstatus], [openposition], [modifyorder], [cancelorder],
#'   [closeposition], [cancelallorder]
#' * GTT orders: [placegttorder], [modifygttorder], [cancelgttorder],
#'   [gttorderbook]
#' * Market data: [quotes], [multiquotes], [depth], [symbol], [search],
#'   [history], [intervals], [interval], [expiry], [instruments],
#'   [syntheticfuture]
#' * Account: [funds], [orderbook], [tradebook], [positionbook], [holdings],
#'   [analyzerstatus], [analyzertoggle], [margin]
#' * Options: [optiongreeks], [optionsorder], [optionsymbol],
#'   [optionsmultiorder], [optionchain]
#' * Strategy module: [strategylist], [strategystatus], [strategystart],
#'   [strategystop], [strategycloseall], [strategycloseleg], [strategyruns],
#'   [strategyorders], [strategyevents]
#' * Notifications: [telegram], [whatsapp]
#' * Utilities: [holidays], [timings]
#' * Additional endpoints (in the OpenAlgo REST API but not in the Python
#'   SDK): [ping], [pnlsymbols], [multioptiongreeks], [ticker], [chart],
#'   [updatechart], [telegramconfig], [updatetelegramconfig],
#'   [telegramstart], [telegramstop], [telegramusers], [telegrambroadcast],
#'   [telegramstats], [telegrampreferences], [updatetelegrampreferences]
#' * WebSocket feed: [connect], [disconnect], [subscribe_ltp],
#'   [unsubscribe_ltp], [subscribe_quote], [unsubscribe_quote],
#'   [subscribe_depth], [unsubscribe_depth], [subscribe_orders],
#'   [unsubscribe_orders], [get_ltp], [get_quotes], [get_depth],
#'   [get_orders], [wait], and the server actions not in the Python SDK:
#'   [unsubscribe_all], [get_broker_info], [get_supported_brokers],
#'   [ws_ping] (plus the `depth` argument of [subscribe_depth])
#'
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$funds()
#' client$placeorder(strategy = "Python", symbol = "SBIN", action = "BUY",
#'                   exchange = "NSE", price_type = "MARKET", product = "MIS",
#'                   quantity = 1)
#' }
#' @export
api <- function(api_key, host = "http://127.0.0.1:5000", version = "v1", timeout = 120.0,
                ws_port = 8765, ws_url = NULL, verbose = FALSE, auto_reconnect = TRUE) {
  OpenAlgoAPI$new(api_key = api_key, host = host, version = version, timeout = timeout,
                  ws_port = ws_port, ws_url = ws_url, verbose = verbose,
                  auto_reconnect = auto_reconnect)
}
