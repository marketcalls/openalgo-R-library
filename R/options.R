# Options methods (Python: openalgo/options.py, class OptionsAPI).
#
# Every method is attached to the client returned by api(). Parameters that the
# Python SDK takes as keyword-only arguments come after `...` here, so they
# must be named exactly. Any other named argument is sent as an extra payload
# field, like **kwargs: optionsorder() and optionsymbol() send those extra
# values as strings, the other methods send them as given.

#' Calculate option Greeks
#'
#' Calculate the option Greeks (delta, gamma, theta, vega, rho) and the
#' implied volatility with the Black-76 model. The server needs a live price
#' for the option and its underlying, unless `forward_price` is given.
#'
#' @section Usage:
#' ```
#' client$optiongreeks(symbol, exchange, interest_rate = NULL,
#'                     forward_price = NULL, underlying_symbol = NULL,
#'                     underlying_exchange = NULL, expiry_time = NULL, ...)
#' ```
#' @section Arguments:
#' * `symbol`: Option symbol, for example `"NIFTY02DEC2526000CE"`. Required.
#' * `exchange`: Exchange code (NFO, BFO, CDS, MCX). Required.
#' * `interest_rate`: Annualized risk-free rate in percent. Optional; the
#'   server uses 0 when it is not sent. Pass the current policy rate (for
#'   example 6.5) for meaningful rho values.
#' * `forward_price`: Custom forward or synthetic futures price. Optional.
#'   When given, the underlying price is not fetched. Useful for synthetic
#'   futures pricing, illiquid underlyings and scenario analysis.
#' * `underlying_symbol`: Custom underlying symbol, for example `"NIFTY"` or
#'   `"NIFTY30DEC25FUT"`. Optional; detected automatically otherwise.
#' * `underlying_exchange`: Custom underlying exchange, for example
#'   `"NSE_INDEX"` or `"NFO"`. Optional; detected automatically otherwise.
#' * `expiry_time`: Custom expiry time as `"HH:MM"`, for contracts with a
#'   non-standard expiry time. Optional. Exchange defaults: NFO and BFO 15:30,
#'   CDS 12:30, MCX 23:30.
#' * `...`: Optional additional fields for future API extensions.
#'
#' Optional values are only sent when they are not `NULL`, and are sent as
#' given (not converted to strings).
#' @return A named list with `status`, `symbol`, `exchange`, `underlying`,
#'   `strike`, `option_type`, `expiry_date`, `days_to_expiry`, `spot_price`,
#'   `option_price`, `interest_rate`, `implied_volatility` and `greeks`
#'   (delta, gamma, theta, vega, rho).
#' @examples
#' \dontrun{
#' client$optiongreeks(symbol = "NIFTY02DEC2526000CE", exchange = "NFO")
#' client$optiongreeks(symbol = "NIFTY30DEC2526000CE", exchange = "NFO",
#'                     underlying_symbol = "NIFTY30DEC25FUT",
#'                     underlying_exchange = "NFO")
#' client$optiongreeks(symbol = "NIFTY02DEC2526000CE", exchange = "NFO",
#'                     forward_price = 26350, interest_rate = 6.5)
#' client$optiongreeks(symbol = "CRUDEOIL17DEC255400CE", exchange = "MCX",
#'                     expiry_time = "19:00")
#' }
#' @family options methods
#' @name optiongreeks
NULL

#' Place an option order by offset
#'
#' Place an option order, letting the server resolve the option symbol from
#' the underlying, the expiry and the strike offset.
#'
#' @section Usage:
#' ```
#' client$optionsorder(strategy = "Python", underlying, exchange,
#'                     strike_int = NULL, offset, option_type, action, quantity,
#'                     expiry_date = NULL, price_type = "MARKET",
#'                     product = "MIS", ...)
#' ```
#' @section Arguments:
#' * `strategy`: Strategy name. Defaults to `"Python"`.
#' * `underlying`: Underlying symbol, for example `"NIFTY"` or
#'   `"NIFTY28OCT25FUT"`. Required.
#' * `exchange`: Exchange code (NSE_INDEX, NSE, NFO, BSE_INDEX, BSE, BFO).
#'   Required.
#' * `strike_int`: Deprecated and scheduled for removal; passing it raises a
#'   deprecation warning. Strike interval, sent as a string when given.
#' * `offset`: Strike offset: `"ATM"`, `"ITM1"` to `"ITM50"` or `"OTM1"` to
#'   `"OTM50"`. Required.
#' * `option_type`: `"CE"` or `"PE"`. Required.
#' * `action`: `"BUY"` or `"SELL"`. Required.
#' * `quantity`: Quantity, a multiple of the lot size. Sent as a string.
#'   Required.
#' * `expiry_date`: Expiry date as DDMMMYY, for example `"28OCT25"`. Optional
#'   when the underlying already names an expiry.
#' * `price_type`: `"MARKET"`, `"LIMIT"`, `"SL"` or `"SL-M"`. Defaults to
#'   `"MARKET"`.
#' * `product`: `"MIS"` or `"NRML"`. Defaults to `"MIS"`.
#' * `...`: Optional fields such as `price` (LIMIT orders), `trigger_price`
#'   (SL and SL-M orders) and `disclosed_quantity`. Values are sent as
#'   strings.
#' @return A named list with `status`, `orderid`, `symbol`, `exchange`,
#'   `underlying`, `underlying_ltp`, `offset`, `option_type` and, in analyze
#'   mode only, `mode`.
#' @examples
#' \dontrun{
#' client$optionsorder(strategy = "test_strategy", underlying = "NIFTY",
#'                     exchange = "NSE_INDEX", expiry_date = "28NOV24",
#'                     offset = "ATM", option_type = "CE", action = "BUY",
#'                     quantity = 75)
#' client$optionsorder(strategy = "nifty_scalping", underlying = "NIFTY",
#'                     exchange = "NSE_INDEX", expiry_date = "28NOV24",
#'                     offset = "OTM1", option_type = "CE", action = "BUY",
#'                     quantity = 75, price_type = "LIMIT", price = "50.0")
#' }
#' @family options methods
#' @name optionsorder
NULL

#' Resolve an option symbol by offset
#'
#' Get the exact option symbol, lot size and tick size for an underlying and
#' strike offset, without placing an order. Useful to check that a symbol
#' exists, to size quantities, to build multi-leg structures and to find the
#' current ATM strike.
#'
#' @section Usage:
#' ```
#' client$optionsymbol(strategy = NULL, underlying, exchange,
#'                     strike_int = NULL, offset, option_type,
#'                     expiry_date = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy`: Deprecated and scheduled for removal; passing it raises a
#'   deprecation warning. Sent as given when not `NULL`.
#' * `underlying`: Underlying symbol. Required.
#' * `exchange`: Exchange code (NSE_INDEX, NSE, NFO, BSE_INDEX, BSE, BFO).
#'   Required.
#' * `strike_int`: Deprecated and scheduled for removal; passing it raises a
#'   deprecation warning. Sent as a string when given.
#' * `offset`: Strike offset (`"ATM"`, `"ITM1"` to `"ITM50"`, `"OTM1"` to
#'   `"OTM50"`). Required.
#' * `option_type`: `"CE"` or `"PE"`. Required.
#' * `expiry_date`: Expiry date as DDMMMYY. Optional when the underlying
#'   already names an expiry.
#' * `...`: Optional additional fields. Values are sent as strings.
#' @return A named list with `status`, `symbol`, `exchange`, `lotsize`,
#'   `tick_size` and `underlying_ltp`.
#' @examples
#' \dontrun{
#' info <- client$optionsymbol(underlying = "NIFTY", exchange = "NSE_INDEX",
#'                             expiry_date = "28OCT25", offset = "ATM",
#'                             option_type = "CE")
#' info$symbol
#' info$lotsize
#' client$optionsymbol(underlying = "NIFTY28OCT25FUT", exchange = "NFO",
#'                     offset = "ITM2", option_type = "CE")
#' }
#' @family options methods
#' @name optionsymbol
NULL

#' Place a multi-leg option order
#'
#' Place several option legs on one underlying, each resolved from its strike
#' offset. The server executes BUY legs first for margin efficiency, then the
#' SELL legs.
#'
#' @section Usage:
#' ```
#' client$optionsmultiorder(strategy, underlying, exchange, legs,
#'                          expiry_date = NULL, strike_int = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy`: Strategy name. Required.
#' * `underlying`: Underlying symbol. Required.
#' * `exchange`: Exchange code (NSE_INDEX, NSE, NFO, BSE_INDEX, BSE, BFO).
#'   Required.
#' * `legs`: A list of 1 to 20 legs, each a named list. Required keys:
#'   `offset`, `option_type`, `action` and `quantity` (sent as an integer); a
#'   missing one is an error. Optional keys, sent only when present:
#'   `expiry_date` (per-leg expiry for calendar and diagonal spreads,
#'   overriding the request level one), `pricetype`, `product`, `price` and
#'   `trigger_price` (sent as numbers) and `disclosed_quantity` (sent as an
#'   integer). Any other key in a leg is dropped.
#' * `expiry_date`: Expiry date as DDMMMYY. Optional when the underlying
#'   already names an expiry.
#' * `strike_int`: Deprecated; passing it raises a deprecation warning. Sent
#'   as an integer when given.
#' * `...`: Optional additional fields, sent as given.
#' @return A named list with `status`, `underlying`, `underlying_ltp`, `mode`
#'   (analyze mode only) and `results`, one entry per leg with `leg`,
#'   `symbol`, `offset`, `option_type`, `action`, `status`, `orderid` and,
#'   on error, `message`.
#' @examples
#' \dontrun{
#' # Iron condor
#' client$optionsmultiorder(
#'   strategy = "Iron Condor", underlying = "NIFTY", exchange = "NSE_INDEX",
#'   expiry_date = "25NOV25",
#'   legs = list(
#'     list(offset = "OTM10", option_type = "CE", action = "BUY", quantity = 75),
#'     list(offset = "OTM10", option_type = "PE", action = "BUY", quantity = 75),
#'     list(offset = "OTM5", option_type = "CE", action = "SELL", quantity = 75),
#'     list(offset = "OTM5", option_type = "PE", action = "SELL", quantity = 75)
#'   )
#' )
#'
#' # Calendar spread: same strike, different expiries
#' client$optionsmultiorder(
#'   strategy = "Calendar Spread", underlying = "NIFTY", exchange = "NSE_INDEX",
#'   legs = list(
#'     list(offset = "ATM", option_type = "CE", action = "BUY", quantity = 75,
#'          expiry_date = "30DEC25"),
#'     list(offset = "ATM", option_type = "CE", action = "SELL", quantity = 75,
#'          expiry_date = "25NOV25")
#'   )
#' )
#' }
#' @family options methods
#' @name optionsmultiorder
NULL

#' Get an option chain
#'
#' Fetch the option chain with live quotes for every strike: LTP, bid and
#' ask, OHLC, volume, open interest, lot size and a moneyness label for both
#' the call and the put.
#'
#' @section Usage:
#' ```
#' client$optionchain(underlying, exchange, expiry_date = NULL,
#'                    strike_count = NULL, ...)
#' ```
#' @section Arguments:
#' * `underlying`: Underlying symbol, for example `"NIFTY"`, `"RELIANCE"` or
#'   `"NIFTY30DEC25FUT"`. Required.
#' * `exchange`: Exchange code (NSE_INDEX, NSE, NFO, BSE_INDEX, BSE, BFO).
#'   Required.
#' * `expiry_date`: Expiry date as DDMMMYY. Required unless the underlying
#'   already names an expiry.
#' * `strike_count`: Number of strikes above and below ATM (1 to 100), sent
#'   as an integer. Optional; every strike is returned when it is `NULL`.
#' * `...`: Optional additional fields, sent as given.
#'
#' Labels: below ATM the call is ITM and the put OTM, above ATM the call is
#' OTM and the put ITM, and at the ATM strike both are labelled ATM.
#' @return A named list with `status`, `underlying`, `underlying_ltp`,
#'   `expiry_date`, `atm_strike` and `chain`, one entry per strike with
#'   `strike`, `ce` and `pe` (each `NULL` or a list with `symbol`, `label`,
#'   `ltp`, `bid`, `ask`, `open`, `high`, `low`, `prev_close`, `volume`,
#'   `oi`, `lotsize` and `tick_size`).
#' @examples
#' \dontrun{
#' chain <- client$optionchain(underlying = "NIFTY", exchange = "NSE_INDEX",
#'                             expiry_date = "30DEC25", strike_count = 10)
#' if (identical(chain$status, "success")) {
#'   for (item in chain$chain) {
#'     ce_ltp <- if (is.null(item$ce)) "-" else item$ce$ltp
#'     pe_ltp <- if (is.null(item$pe)) "-" else item$pe$ltp
#'     cat("Strike:", item$strike, "| CE:", ce_ltp, "| PE:", pe_ltp, "\n")
#'   }
#' }
#' }
#' @family options methods
#' @name optionchain
NULL

# Python int() for the values the SDK converts: integer strings, numbers
# (truncated toward zero) and logicals. Anything else raises the error
# Python would raise. Values beyond the 32-bit range stay doubles so they
# still serialize as whole numbers.
as_py_int <- function(x) {
  none_msg <- "int() argument must be a string, a bytes-like object or a real number, not '%s'"
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.null(x) || (length(x) == 1 && (is.logical(x) || is.character(x)) && is.na(x))) {
    stop(sprintf(none_msg, "NoneType"), call. = FALSE)
  }
  if (length(x) != 1 || !(is.character(x) || is.numeric(x) || is.logical(x))) {
    stop(sprintf(none_msg, if (is.list(x) && !is.null(names(x))) "dict" else "list"), call. = FALSE)
  }
  if (is.character(x)) {
    s <- trimws(x)
    if (!grepl("^[+-]?[0-9]+(_[0-9]+)*$", s)) {
      stop(sprintf("invalid literal for int() with base 10: '%s'", x), call. = FALSE)
    }
    v <- as.numeric(gsub("_", "", s, fixed = TRUE))
  } else {
    if (is.nan(x) || is.na(x)) {
      stop("cannot convert float NaN to integer", call. = FALSE)
    }
    if (is.infinite(x)) {
      stop("cannot convert float infinity to integer", call. = FALSE)
    }
    v <- trunc(as.numeric(x))
  }
  if (abs(v) <= .Machine$integer.max) as.integer(v) else v
}

# Python float() for the values the SDK converts: numeric strings, numbers
# and logicals.
as_py_float <- function(x) {
  none_msg <- "float() argument must be a string or a real number, not '%s'"
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.null(x) || (length(x) == 1 && (is.logical(x) || is.character(x)) && is.na(x))) {
    stop(sprintf(none_msg, "NoneType"), call. = FALSE)
  }
  if (length(x) != 1 || !(is.character(x) || is.numeric(x) || is.logical(x))) {
    stop(sprintf(none_msg, if (is.list(x) && !is.null(names(x))) "dict" else "list"), call. = FALSE)
  }
  if (is.character(x)) {
    v <- suppressWarnings(as.numeric(gsub("_", "", trimws(x), fixed = TRUE)))
    if (is.na(v)) {
      stop(sprintf("could not convert string to float: '%s'", x), call. = FALSE)
    }
    return(v)
  }
  as.numeric(x)
}

# leg["key"] in Python: a missing key raises KeyError.
leg_value <- function(leg, key) {
  if (!(key %in% names(leg))) {
    stop(sprintf("KeyError: '%s'", key), call. = FALSE)
  }
  leg[[key]]
}

deprecated_param <- function(name) {
  warning(sprintf("The '%s' parameter is deprecated and will be removed in future versions.", name),
          call. = FALSE)
}

options_public <- list(
  optiongreeks = function(..., symbol, exchange, interest_rate = NULL, forward_price = NULL,
                          underlying_symbol = NULL, underlying_exchange = NULL,
                          expiry_time = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange
    )
    if (!is.null(interest_rate)) {
      payload["interest_rate"] <- list(interest_rate)
    }
    if (!is.null(forward_price)) {
      payload["forward_price"] <- list(forward_price)
    }
    if (!is.null(underlying_symbol)) {
      payload["underlying_symbol"] <- list(underlying_symbol)
    }
    if (!is.null(underlying_exchange)) {
      payload["underlying_exchange"] <- list(underlying_exchange)
    }
    if (!is.null(expiry_time)) {
      payload["expiry_time"] <- list(expiry_time)
    }
    payload <- add_kwargs(payload, kwargs)
    private$make_request("optiongreeks", payload)
  },

  optionsorder = function(..., strategy = "Python", underlying, exchange, strike_int = NULL,
                          offset, option_type, action, quantity, expiry_date = NULL,
                          price_type = "MARKET", product = "MIS") {
    kwargs <- dots_kwargs(...)
    if (!is.null(strike_int)) {
      deprecated_param("strike_int")
    }
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      underlying = underlying,
      exchange = exchange,
      offset = offset,
      option_type = option_type,
      action = action,
      quantity = py_str(quantity),
      pricetype = price_type,
      product = product
    )
    if (!is.null(strike_int)) {
      payload["strike_int"] <- list(py_str(strike_int))
    }
    if (!is.null(expiry_date)) {
      payload["expiry_date"] <- list(expiry_date)
    }
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("optionsorder", payload)
  },

  optionsymbol = function(..., strategy = NULL, underlying, exchange, strike_int = NULL,
                          offset, option_type, expiry_date = NULL) {
    kwargs <- dots_kwargs(...)
    if (!is.null(strategy)) {
      deprecated_param("strategy")
    }
    if (!is.null(strike_int)) {
      deprecated_param("strike_int")
    }
    payload <- list(
      apikey = self$api_key,
      underlying = underlying,
      exchange = exchange,
      offset = offset,
      option_type = option_type
    )
    if (!is.null(strategy)) {
      payload["strategy"] <- list(strategy)
    }
    if (!is.null(strike_int)) {
      payload["strike_int"] <- list(py_str(strike_int))
    }
    if (!is.null(expiry_date)) {
      payload["expiry_date"] <- list(expiry_date)
    }
    payload <- add_kwargs(payload, kwargs, stringify = TRUE)
    private$make_request("optionsymbol", payload)
  },

  optionsmultiorder = function(..., strategy, underlying, exchange, legs, expiry_date = NULL,
                               strike_int = NULL) {
    kwargs <- dots_kwargs(...)
    if (!is.null(strike_int)) {
      deprecated_param("strike_int")
    }
    processed_legs <- lapply(unname(legs), function(leg) {
      processed <- list()
      processed["offset"] <- list(leg_value(leg, "offset"))
      processed["option_type"] <- list(leg_value(leg, "option_type"))
      processed["action"] <- list(leg_value(leg, "action"))
      processed["quantity"] <- list(as_py_int(leg_value(leg, "quantity")))
      if ("expiry_date" %in% names(leg)) {
        processed["expiry_date"] <- list(leg[["expiry_date"]])
      }
      if ("pricetype" %in% names(leg)) {
        processed["pricetype"] <- list(leg[["pricetype"]])
      }
      if ("product" %in% names(leg)) {
        processed["product"] <- list(leg[["product"]])
      }
      if ("price" %in% names(leg)) {
        processed["price"] <- list(as_py_float(leg[["price"]]))
      }
      if ("trigger_price" %in% names(leg)) {
        processed["trigger_price"] <- list(as_py_float(leg[["trigger_price"]]))
      }
      if ("disclosed_quantity" %in% names(leg)) {
        processed["disclosed_quantity"] <- list(as_py_int(leg[["disclosed_quantity"]]))
      }
      processed
    })
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      underlying = underlying,
      exchange = exchange,
      legs = processed_legs
    )
    if (!is.null(strike_int)) {
      payload["strike_int"] <- list(as_py_int(strike_int))
    }
    if (!is.null(expiry_date)) {
      payload["expiry_date"] <- list(expiry_date)
    }
    payload <- add_kwargs(payload, kwargs)
    private$make_request("optionsmultiorder", payload)
  },

  optionchain = function(..., underlying, exchange, expiry_date = NULL, strike_count = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      underlying = underlying,
      exchange = exchange
    )
    if (!is.null(expiry_date)) {
      payload["expiry_date"] <- list(expiry_date)
    }
    if (!is.null(strike_count)) {
      payload["strike_count"] <- list(as_py_int(strike_count))
    }
    payload <- add_kwargs(payload, kwargs)
    private$make_request("optionchain", payload)
  }
)
