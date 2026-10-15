# Order management methods (Python: openalgo/orders.py, class OrderAPI).
#
# Every method is attached to the client returned by api(). Parameters that the
# Python SDK takes as keyword-only arguments come after `...` here, so they
# must be named exactly (R never partially matches arguments after `...`).
# Any other named argument is sent as an extra payload field, like **kwargs.

#' Place an order
#'
#' Place an order with the given parameters. All parameters must be named.
#'
#' @section Usage:
#' ```
#' client$placeorder(strategy = "Python", symbol, action, exchange,
#'                   price_type = "MARKET", product = "MIS", quantity = 1, ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `symbol`: Trading symbol. Required.
#' * `action`: `"BUY"` or `"SELL"`. Required.
#' * `exchange`: Exchange code. Required.
#' * `price_type`: Type of price. Defaults to `"MARKET"`.
#' * `product`: Product type. Defaults to `"MIS"`.
#' * `quantity`: Quantity to trade. Defaults to 1.
#' * `...`: Optional fields such as `price` (required for LIMIT orders),
#'   `trigger_price` (required for SL and SL-M orders), `disclosed_quantity`,
#'   `target`, `stoploss` and `trailing_sl`. Values are sent as strings.
#' @return A named list with the JSON response from the API, for example
#'   `list(orderid = "...", status = "success")`.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$placeorder(strategy = "Python", symbol = "SBIN", action = "BUY",
#'                   exchange = "NSE", price_type = "LIMIT", product = "MIS",
#'                   quantity = 1, price = 750)
#' }
#' @family order methods
#' @name placeorder
NULL

#' Place a smart order
#'
#' Place a smart order that considers the current position size.
#'
#' @section Usage:
#' ```
#' client$placesmartorder(strategy = "Python", symbol, action, exchange,
#'                        price_type = "MARKET", product = "MIS", quantity = 1,
#'                        position_size, ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `symbol`: Trading symbol. Required.
#' * `action`: `"BUY"` or `"SELL"`. Required.
#' * `exchange`: Exchange code. Required.
#' * `price_type`: Type of price. Defaults to `"MARKET"`.
#' * `product`: Product type. Defaults to `"MIS"`.
#' * `quantity`: Quantity to trade. Defaults to 1.
#' * `position_size`: Required position size. Required.
#' * `...`: Optional fields such as `price`, `trigger_price`,
#'   `disclosed_quantity`, `target`, `stoploss` and `trailing_sl`.
#' @return A named list with the JSON response from the API.
#' @examples
#' \dontrun{
#' client$placesmartorder(strategy = "Python", symbol = "TATAMOTORS",
#'                        action = "SELL", exchange = "NSE", price_type = "MARKET",
#'                        product = "MIS", quantity = 1, position_size = 5)
#' }
#' @family order methods
#' @name placesmartorder
NULL

#' Place a basket of orders
#'
#' Place multiple orders simultaneously.
#'
#' @section Usage:
#' ```
#' client$basketorder(strategy = "Python", orders, ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `orders`: A list of orders, each a named list with `symbol`, `exchange`,
#'   `action`, `quantity` and optionally `pricetype`, `product`, `price`,
#'   `trigger_price` and `disclosed_quantity`. Numeric values are sent as
#'   strings. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and a `results` list holding one entry
#'   (`orderid`, `status`, `symbol`) per order.
#' @examples
#' \dontrun{
#' client$basketorder(orders = list(
#'   list(symbol = "BHEL", exchange = "NSE", action = "BUY", quantity = 1,
#'        pricetype = "MARKET", product = "MIS"),
#'   list(symbol = "ZOMATO", exchange = "NSE", action = "SELL", quantity = 1,
#'        pricetype = "MARKET", product = "MIS")
#' ))
#' }
#' @family order methods
#' @name basketorder
NULL

#' Split a large order
#'
#' Split a large order into multiple smaller orders.
#'
#' @section Usage:
#' ```
#' client$splitorder(strategy = "Python", symbol, action, exchange, quantity,
#'                   splitsize, price_type = "MARKET", product = "MIS", ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `symbol`: Trading symbol. Required.
#' * `action`: `"BUY"` or `"SELL"`. Required.
#' * `exchange`: Exchange code. Required.
#' * `quantity`: Total quantity to trade. Required.
#' * `splitsize`: Size of each split order. Required.
#' * `price_type`: Type of price. Defaults to `"MARKET"`.
#' * `product`: Product type. Defaults to `"MIS"`.
#' * `...`: Optional fields such as `price`, `trigger_price` and
#'   `disclosed_quantity`.
#' @return A named list with `status`, `split_size`, `total_quantity` and a
#'   `results` list with one entry per split order.
#' @examples
#' \dontrun{
#' client$splitorder(symbol = "YESBANK", exchange = "NSE", action = "SELL",
#'                   quantity = 105, splitsize = 20, price_type = "MARKET",
#'                   product = "MIS")
#' }
#' @family order methods
#' @name splitorder
NULL

#' Get the status of an order
#'
#' @section Usage:
#' ```
#' client$orderstatus(order_id, strategy = "Python", ...)
#' ```
#' @section Arguments:
#' * `order_id`: The ID of the order to check. Required.
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status` and `data` (action, exchange,
#'   order_status, orderid, price, pricetype, product, quantity, symbol,
#'   timestamp, trigger_price).
#' @examples
#' \dontrun{
#' client$orderstatus(order_id = "24120900146469", strategy = "Test Strategy")
#' }
#' @family order methods
#' @name orderstatus
NULL

#' Get the open position for a symbol
#'
#' @section Usage:
#' ```
#' client$openposition(strategy = "Python", symbol, exchange, product, ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `product`: Product type. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `quantity` and `status`.
#' @examples
#' \dontrun{
#' client$openposition(strategy = "Test Strategy", symbol = "YESBANK",
#'                     exchange = "NSE", product = "CNC")
#' }
#' @family order methods
#' @name openposition
NULL

#' Modify an existing order
#'
#' @section Usage:
#' ```
#' client$modifyorder(order_id, strategy = "Python", symbol, action, exchange,
#'                    price_type = "LIMIT", product, quantity, price,
#'                    disclosed_quantity = "0", trigger_price = "0", ...)
#' ```
#' @section Arguments:
#' * `order_id`: The ID of the order to modify. Required.
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `symbol`: Trading symbol. Required.
#' * `action`: `"BUY"` or `"SELL"`. Required.
#' * `exchange`: Exchange code. Required.
#' * `price_type`: Type of price. Defaults to `"LIMIT"`.
#' * `product`: Product type. Required.
#' * `quantity`: Quantity to trade. Required.
#' * `price`: New price for the order. Required.
#' * `disclosed_quantity`: Disclosed quantity. Defaults to `"0"`.
#' * `trigger_price`: Trigger price. Defaults to `"0"`.
#' * `...`: Optional additional fields.
#' @return A named list with the JSON response from the API.
#' @examples
#' \dontrun{
#' client$modifyorder(order_id = "24120900146469", strategy = "Python",
#'                    symbol = "YESBANK", action = "BUY", exchange = "NSE",
#'                    price_type = "LIMIT", product = "CNC", quantity = 1,
#'                    price = 16.5)
#' }
#' @family order methods
#' @name modifyorder
NULL

#' Cancel an existing order
#'
#' @section Usage:
#' ```
#' client$cancelorder(order_id, strategy = "Python", ...)
#' ```
#' @section Arguments:
#' * `order_id`: The ID of the order to cancel. Required.
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API.
#' @examples
#' \dontrun{
#' client$cancelorder(order_id = "24120900146469", strategy = "Test Strategy")
#' }
#' @family order methods
#' @name cancelorder
NULL

#' Close all open positions of a strategy
#'
#' @section Usage:
#' ```
#' client$closeposition(strategy = "Python", ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API.
#' @examples
#' \dontrun{
#' client$closeposition(strategy = "Test Strategy")
#' }
#' @family order methods
#' @name closeposition
NULL

#' Cancel all orders of a strategy
#'
#' @section Usage:
#' ```
#' client$cancelallorder(strategy = "Python", ...)
#' ```
#' @section Arguments:
#' * `strategy`: The trading strategy name. Defaults to `"Python"`.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API.
#' @examples
#' \dontrun{
#' client$cancelallorder(strategy = "Test Strategy")
#' }
#' @family order methods
#' @name cancelallorder
NULL

orders_public <- list(
  placeorder = function(..., strategy = "Python", symbol, action, exchange,
                        price_type = "MARKET", product = "MIS", quantity = 1) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      symbol = symbol,
      action = action,
      exchange = exchange,
      pricetype = price_type,
      product = product,
      quantity = py_str(quantity)
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("placeorder", payload)
  },

  placesmartorder = function(..., strategy = "Python", symbol, action, exchange,
                             price_type = "MARKET", product = "MIS", quantity = 1,
                             position_size) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      symbol = symbol,
      action = action,
      exchange = exchange,
      pricetype = price_type,
      product = product,
      quantity = py_str(quantity),
      position_size = py_str(position_size)
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("placesmartorder", payload)
  },

  basketorder = function(..., strategy = "Python", orders) {
    kwargs <- dots_kwargs(...)
    processed_orders <- lapply(orders, function(order) {
      processed <- empty_named_list()
      for (key in names(order)) {
        value <- order[[key]]
        if ((is.numeric(value) || is.logical(value)) && length(value) == 1 && !is.na(value)) {
          value <- py_str(value)
        }
        processed[key] <- list(value)
      }
      processed
    })
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      orders = processed_orders
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("basketorder", payload)
  },

  splitorder = function(..., strategy = "Python", symbol, action, exchange, quantity,
                        splitsize, price_type = "MARKET", product = "MIS") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      symbol = symbol,
      action = action,
      exchange = exchange,
      quantity = py_str(quantity),
      splitsize = py_str(splitsize),
      pricetype = price_type,
      product = product
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("splitorder", payload)
  },

  orderstatus = function(..., order_id, strategy = "Python") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      orderid = order_id
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("orderstatus", payload)
  },

  openposition = function(..., strategy = "Python", symbol, exchange, product) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      symbol = symbol,
      exchange = exchange,
      product = product
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("openposition", payload)
  },

  modifyorder = function(..., order_id, strategy = "Python", symbol, action, exchange,
                         price_type = "LIMIT", product, quantity, price,
                         disclosed_quantity = "0", trigger_price = "0") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      orderid = order_id,
      strategy = strategy,
      symbol = symbol,
      action = action,
      exchange = exchange,
      pricetype = price_type,
      product = product,
      quantity = py_str(quantity),
      price = py_str(price),
      disclosed_quantity = py_str(disclosed_quantity),
      trigger_price = py_str(trigger_price)
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("modifyorder", payload)
  },

  cancelorder = function(..., order_id, strategy = "Python") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      orderid = order_id,
      strategy = strategy
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("cancelorder", payload)
  },

  closeposition = function(..., strategy = "Python") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("closeposition", payload)
  },

  cancelallorder = function(..., strategy = "Python") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy
    )
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("cancelallorder", payload)
  }
)
