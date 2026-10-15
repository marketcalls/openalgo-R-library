# Account methods (Python: openalgo/account.py, class AccountAPI).
#
# Extra named arguments are sent as payload fields exactly as given (they are
# not converted to strings), and NULL values are skipped.

#' Get funds
#'
#' Get funds and margin details of the connected trading account.
#'
#' @section Usage:
#' ```
#' client$funds(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list such as
#'   `list(status = "success", data = list(availablecash = "...",
#'   collateral = "...", m2mrealized = "...", m2munrealized = "...",
#'   utiliseddebits = "..."))`.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$funds()
#' }
#' @family account methods
#' @name funds
NULL

#' Get the order book
#'
#' Get the order book with basic order statistics.
#'
#' @section Usage:
#' ```
#' client$orderbook(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `data`, where `data$orders` is a
#'   list of orders (`action`, `exchange`, `order_status`, `orderid`, `price`,
#'   `pricetype`, `product`, `quantity`, `symbol`, `timestamp`,
#'   `trigger_price`) and `data$statistics` holds `total_buy_orders`,
#'   `total_completed_orders`, `total_open_orders`, `total_rejected_orders`
#'   and `total_sell_orders`.
#' @examples
#' \dontrun{
#' client$orderbook()
#' }
#' @family account methods
#' @name orderbook
NULL

#' Get the trade book
#'
#' @section Usage:
#' ```
#' client$tradebook(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `data`, a list of trades (`action`,
#'   `average_price`, `exchange`, `orderid`, `product`, `quantity`, `symbol`,
#'   `timestamp`, `trade_value`).
#' @examples
#' \dontrun{
#' client$tradebook()
#' }
#' @family account methods
#' @name tradebook
NULL

#' Get the position book
#'
#' @section Usage:
#' ```
#' client$positionbook(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `data`, a list of positions
#'   (`average_price`, `exchange`, `product`, `quantity`, `symbol`).
#' @examples
#' \dontrun{
#' client$positionbook()
#' }
#' @family account methods
#' @name positionbook
NULL

#' Get holdings
#'
#' Get stock holdings details.
#'
#' @section Usage:
#' ```
#' client$holdings(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `data`, where `data$holdings` is a
#'   list of holdings (`exchange`, `pnl`, `pnlpercent`, `product`, `quantity`,
#'   `symbol`) and `data$statistics` holds `totalholdingvalue`,
#'   `totalinvvalue`, `totalpnlpercentage` and `totalprofitandloss`.
#' @examples
#' \dontrun{
#' client$holdings()
#' }
#' @family account methods
#' @name holdings
NULL

#' Get the analyzer status
#'
#' Get analyzer (sandbox) mode status information.
#'
#' @section Usage:
#' ```
#' client$analyzerstatus(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list such as `list(status = "success",
#'   data = list(analyze_mode = FALSE, mode = "live", total_logs = 2))`.
#' @examples
#' \dontrun{
#' client$analyzerstatus()
#' }
#' @family account methods
#' @name analyzerstatus
NULL

#' Toggle the analyzer mode
#'
#' Switch between analyze (simulated) and live modes.
#'
#' @section Usage:
#' ```
#' client$analyzertoggle(mode, ...)
#' ```
#' @section Arguments:
#' * `mode`: `TRUE` for analyze mode (simulated), `FALSE` for live mode.
#'   Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list such as `list(status = "success",
#'   data = list(mode = "analyze", analyze_mode = TRUE, total_logs = 2,
#'   message = "Analyzer mode switched to analyze"))`.
#' @examples
#' \dontrun{
#' client$analyzertoggle(TRUE)
#' client$analyzertoggle(mode = FALSE)
#' }
#' @family account methods
#' @name analyzertoggle
NULL

#' Calculate margin requirements
#'
#' Calculate the total margin required for one or more positions, taking into
#' account margin benefits for hedged positions where the broker supports
#' basket margin.
#'
#' @section Usage:
#' ```
#' client$margin(positions, ...)
#' ```
#' @section Arguments:
#' * `positions`: An unnamed list of positions (at most 50), each a named list
#'   with:
#'   * `symbol`: Trading symbol (e.g. `"SBIN"`, `"NIFTY30DEC2526000CE"`).
#'     Required.
#'   * `exchange`: Exchange code (NSE, BSE, NFO, BFO, CDS, MCX). Required.
#'   * `action`: `"BUY"` or `"SELL"`. Required.
#'   * `product`: Product type (CNC, MIS, NRML). Required.
#'   * `pricetype`: Price type (MARKET, LIMIT, SL, SL-M). Required.
#'   * `quantity`: Quantity to trade. Required.
#'   * `price`: Price for LIMIT orders. Defaults to `"0"`.
#'   * `trigger_price`: Trigger price for SL and SL-M orders. Defaults to
#'     `"0"`.
#'
#'   `quantity`, `price` and `trigger_price` are sent as strings. Must be
#'   named (`positions = ...`).
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list such as `list(status = "success",
#'   data = list(total_margin_required = 328482, span_margin = 258482,
#'   exposure_margin = 70000))`. `span_margin` and `exposure_margin` are
#'   reported where the broker provides them. If `positions` is not an
#'   unnamed list, is empty or holds more than 50 entries, an error list with
#'   `error_type = "validation_error"` is returned without calling the server.
#'
#' For MARKET orders `price` can be `"0"`; for LIMIT orders `price` is
#' required; for SL and SL-M orders `trigger_price` is required.
#' @examples
#' \dontrun{
#' # Single position margin
#' client$margin(positions = list(
#'   list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS",
#'        pricetype = "LIMIT", quantity = "10", price = "750.50")
#' ))
#'
#' # Multiple positions (basket margin)
#' client$margin(positions = list(
#'   list(symbol = "NIFTY30DEC2526000CE", exchange = "NFO", action = "SELL",
#'        product = "NRML", pricetype = "LIMIT", quantity = "75",
#'        price = "150.75"),
#'   list(symbol = "NIFTY30DEC2526000PE", exchange = "NFO", action = "SELL",
#'        product = "NRML", pricetype = "LIMIT", quantity = "75",
#'        price = "125.50")
#' ))
#' }
#' @family account methods
#' @name margin
NULL

account_public <- list(
  funds = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("funds", payload)
  },

  orderbook = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("orderbook", payload)
  },

  tradebook = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("tradebook", payload)
  },

  positionbook = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("positionbook", payload)
  },

  holdings = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("holdings", payload)
  },

  analyzerstatus = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$make_request("analyzer", payload)
  },

  analyzertoggle = function(mode, ...) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      mode = mode
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("analyzer/toggle", payload)
  },

  margin = function(..., positions) {
    kwargs <- dots_kwargs(...)

    # A Python list is an unnamed R list; a named list is a dict.
    if (!is.list(positions) || !is.null(names(positions))) {
      return(list(status = "error", message = "Positions must be an array",
                  error_type = "validation_error"))
    }
    if (length(positions) == 0) {
      return(list(status = "error", message = "Positions array cannot be empty",
                  error_type = "validation_error"))
    }
    if (length(positions) > 50) {
      return(list(status = "error", message = "Maximum 50 positions allowed",
                  error_type = "validation_error"))
    }

    # Convert quantity, price and trigger_price to strings.
    processed_positions <- lapply(positions, function(position) {
      if (!is.list(position) || (length(position) > 0 && is.null(names(position)))) {
        stop(sprintf("'%s' object has no attribute 'items'", py_type_name(position)),
             call. = FALSE)
      }
      processed <- empty_named_list()
      for (key in names(position)) {
        value <- position[[key]]
        if (key %in% c("quantity", "price", "trigger_price") && !is.null(value)) {
          processed[key] <- list(py_str(value))
        } else {
          processed[key] <- list(value)
        }
      }
      # Defaults for the optional fields when the key is absent.
      if (!("price" %in% names(processed))) {
        processed$price <- "0"
      }
      if (!("trigger_price" %in% names(processed))) {
        processed$trigger_price <- "0"
      }
      processed
    })

    payload <- list(
      apikey = self$api_key,
      positions = processed_positions
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("margin", payload)
  }
)
