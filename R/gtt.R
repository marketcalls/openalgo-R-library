# GTT (Good Till Triggered) order methods (Python: openalgo/gtt.py, class GTTAPI).
#
# A GTT is a price trigger that sits with the broker until LTP crosses the
# level, at which point the underlying order is placed automatically.
#
# Two trigger types, and picking the wrong one is the usual mistake:
#
# * SINGLE: one trigger, one order. Exactly one of triggerprice_sl and
#   triggerprice_tg carries the level and the other stays 0. The suffix is
#   only a directional hint (_sl for a level below LTP, _tg for one above),
#   because a SINGLE GTT has no stoploss leg to name.
# * OCO: two triggers, one of which fires and cancels the other. Here the
#   suffix is a real role: triggerprice_sl is the stoploss leg's trigger with
#   stoploss as its limit, triggerprice_tg is the target leg's trigger with
#   target as its limit, and all four are required.
#
# GTT numeric fields go out as JSON numbers rather than the strings the rest
# of the order surface sends, because the server validates them as floats.
# GTT requests use private$post (Python: BaseAPI._post), not make_request.

# Trigger types the API accepts.
GTT_TRIGGER_TYPES <- c("SINGLE", "OCO")

# Products a GTT accepts. MIS is refused server-side: a GTT can sit for days
# and MIS is squared off the same session.
GTT_PRODUCTS <- c("CNC", "NRML")

# Python's float(value). Strings follow Python's float grammar (surrounding
# whitespace, underscores between digits, inf, infinity and nan); anything
# else raises the same error Python raises.
gtt_float <- function(value) {
  if (is.null(value)) {
    stop("float() argument must be a string or a real number, not 'NoneType'", call. = FALSE)
  }
  if (is.factor(value)) {
    value <- as.character(value)
  }
  if (is.list(value) || length(value) != 1) {
    stop(sprintf("float() argument must be a string or a real number, not '%s'",
                 if (is.list(value)) py_type_name(value) else class(value)[1]),
         call. = FALSE)
  }
  if (is.character(value)) {
    if (is.na(value)) {
      stop("float() argument must be a string or a real number, not 'NoneType'", call. = FALSE)
    }
    s <- trimws(value, whitespace = "[\\h\\v]")
    pattern <- paste0("^[+-]?(?:(?:(?:\\d(?:_?\\d)*(?:\\.(?:\\d(?:_?\\d)*)?)?|\\.\\d(?:_?\\d)*)",
                      "(?:[eE][+-]?\\d(?:_?\\d)*)?)|inf|infinity|nan)$")
    if (!grepl(pattern, s, ignore.case = TRUE, perl = TRUE)) {
      stop(sprintf("could not convert string to float: '%s'", value), call. = FALSE)
    }
    return(as.numeric(gsub("_", "", s, fixed = TRUE)))
  }
  if (is.logical(value) || is.numeric(value)) {
    return(as.numeric(value))
  }
  stop(sprintf("float() argument must be a string or a real number, not '%s'", class(value)[1]),
       call. = FALSE)
}

# Python's int(value) for an integer-valued quantity. A string must be an
# integer literal ("10.0" raises, as it does in Python).
gtt_int <- function(value) {
  if (is.factor(value)) {
    value <- as.character(value)
  }
  if (is.character(value)) {
    s <- trimws(value, whitespace = "[\\h\\v]")
    if (!grepl("^[+-]?\\d(?:_?\\d)*$", s, perl = TRUE)) {
      stop(sprintf("invalid literal for int() with base 10: '%s'", value), call. = FALSE)
    }
    value <- as.numeric(gsub("_", "", s, fixed = TRUE))
  }
  value <- trunc(as.numeric(value))
  if (abs(value) <= .Machine$integer.max) as.integer(value) else value
}

# Python: _num. Coerce a trigger or price field to a float, treating NULL and
# "" as unset.
gtt_num <- function(value, default = 0.0) {
  if (is.null(value) || (is.character(value) && length(value) == 1 && !is.na(value) && value == "")) {
    return(default)
  }
  gtt_float(value)
}

# Python: float(quantity) if float(quantity) % 1 else int(quantity).
gtt_quantity <- function(quantity) {
  q <- gtt_float(quantity)
  if (!is.finite(q) || q %% 1 != 0) {
    return(q)
  }
  gtt_int(quantity)
}

gtt_validation_error <- function(message) {
  list(status = "error", message = message, error_type = "validation_error")
}

#' Place a GTT order
#'
#' Place a GTT (Good Till Triggered) order: a price trigger that sits with the
#' broker until LTP crosses the level, at which point the underlying order is
#' placed automatically. All parameters must be named.
#'
#' Two trigger types are supported:
#' * `"SINGLE"`: one trigger, one order. Exactly one of `triggerprice_sl` and
#'   `triggerprice_tg` carries the level and the other stays 0. The suffix is
#'   only a directional hint (`_sl` for a level below LTP, `_tg` for one
#'   above).
#' * `"OCO"`: two triggers, one of which fires and cancels the other.
#'   `triggerprice_sl` is the stoploss leg's trigger with `stoploss` as its
#'   limit, `triggerprice_tg` is the target leg's trigger with `target` as its
#'   limit, and all four are required.
#'
#' Numeric fields are sent as JSON numbers, not strings, because the server
#' validates them as floats. Invalid combinations are reported before the
#' request is sent, as an error list with `error_type = "validation_error"`.
#'
#' @section Usage:
#' ```
#' client$placegttorder(strategy = "Python", symbol, action, exchange,
#'                      trigger_type = "SINGLE", product = "CNC", quantity = 1,
#'                      price_type = "LIMIT", price = 0,
#'                      triggerprice_sl = 0, triggerprice_tg = 0,
#'                      stoploss = NULL, target = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy`: Strategy identifier, used as the broker correlation id where
#'   supported. Defaults to `"Python"`.
#' * `symbol`: Trading symbol in OpenAlgo format. Required.
#' * `action`: `"BUY"` or `"SELL"` (upper-cased before sending). For OCO it
#'   applies to both legs. Required.
#' * `exchange`: Exchange code. Required.
#' * `trigger_type`: `"SINGLE"` or `"OCO"` (upper-cased before sending).
#'   Defaults to `"SINGLE"`.
#' * `product`: `"CNC"` or `"NRML"`. MIS is refused. Defaults to `"CNC"`.
#' * `quantity`: Order quantity. Integer for equity and F&O; a fractional
#'   value is only accepted on crypto exchanges. Defaults to 1.
#' * `price_type`: `"LIMIT"` or `"MARKET"`. Defaults to `"LIMIT"`.
#' * `price`: SINGLE only: the child order's limit price. Send 0 with
#'   `price_type = "MARKET"`. Ignored for OCO.
#' * `triggerprice_sl`: Trigger below LTP. For SINGLE use this or
#'   `triggerprice_tg`; for OCO it is the stoploss leg's trigger.
#' * `triggerprice_tg`: Trigger above LTP. For SINGLE use this or
#'   `triggerprice_sl`; for OCO it is the target leg's trigger.
#' * `stoploss`: OCO only: the stoploss leg's limit price.
#' * `target`: OCO only: the target leg's limit price.
#' * `...`: Extra fields, passed through unchanged for future API extensions.
#'
#' `NULL` and `""` for a price or trigger field mean unset (0, or missing for
#' the OCO limits). A string that is not a number raises an error.
#' @return A named list, `list(status = "success", trigger_id = "...")` on
#'   success. Save the `trigger_id`: modify and cancel both need it.
#'
#' `last_price` is fetched server-side; do not send it. In analyzer (sandbox)
#' mode the trigger is placed in the sandbox: the response carries
#' `mode = "analyze"` and a `GTT-...` trigger id, and it fires against live LTP
#' exactly as it would at the broker.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#'
#' # SINGLE: buy when the price drops to 700
#' client$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE",
#'                      trigger_type = "SINGLE", product = "CNC", quantity = 1,
#'                      price_type = "LIMIT", price = 701, triggerprice_sl = 700)
#'
#' # OCO: protect a holding with a stoploss and a target
#' client$placegttorder(symbol = "SBIN", action = "SELL", exchange = "NSE",
#'                      trigger_type = "OCO", product = "CNC", quantity = 1,
#'                      triggerprice_sl = 700, stoploss = 699,
#'                      triggerprice_tg = 850, target = 851)
#' }
#' @family gtt methods
#' @name placegttorder
NULL

#' Modify a GTT order
#'
#' Modify an active GTT trigger. Modify is a full replacement, not a patch:
#' every field on the trigger is replaced by what this call sends, so pass
#' everything you want to keep rather than only the values that changed.
#'
#' @section Usage:
#' ```
#' client$modifygttorder(trigger_id, strategy = "Python", symbol, action,
#'                       exchange, trigger_type = "SINGLE", product = "CNC",
#'                       quantity = 1, price_type = "LIMIT", price = 0,
#'                       triggerprice_sl = 0, triggerprice_tg = 0,
#'                       stoploss = NULL, target = NULL, ...)
#' ```
#' @section Arguments:
#' * `trigger_id`: The trigger to modify, as returned by [placegttorder].
#'   Sent as a string. Required.
#' * Everything else is identical to [placegttorder].
#' @return A named list, `list(status = "success", trigger_id = "...")` on
#'   success.
#'
#' What cannot be modified: `trigger_type` (SINGLE to OCO or back), `symbol`,
#' `exchange` and `action` are fixed; cancel and re-place instead. Only active
#' GTTs are modifiable; triggered, cancelled and expired ones are immutable.
#' @examples
#' \dontrun{
#' client$modifygttorder(trigger_id = "123456", symbol = "SBIN", action = "BUY",
#'                       exchange = "NSE", trigger_type = "SINGLE",
#'                       product = "CNC", quantity = 2, price_type = "LIMIT",
#'                       price = 691, triggerprice_sl = 690)
#' }
#' @family gtt methods
#' @name modifygttorder
NULL

#' Cancel a GTT order
#'
#' Cancel an active GTT trigger.
#'
#' @section Usage:
#' ```
#' client$cancelgttorder(trigger_id, strategy = "Python", ...)
#' ```
#' @section Arguments:
#' * `trigger_id`: The trigger to cancel. Sent as a string. Required.
#' * `strategy`: Strategy identifier, recorded in event logs. Defaults to
#'   `"Python"`.
#' * `...`: Extra fields, passed through unchanged for future API extensions.
#' @return A named list, `list(status = "success", trigger_id = "...")` on
#'   success.
#'
#' Cancelling an OCO removes both legs atomically; there is no per-leg
#' cancel. Only active triggers can be cancelled. Cancelling one that already
#' fired returns whatever the broker says, which may be a success or a
#' "trigger not found" error.
#' @examples
#' \dontrun{
#' client$cancelgttorder(trigger_id = "123456")
#' }
#' @family gtt methods
#' @name cancelgttorder
NULL

#' List GTT orders
#'
#' List the authenticated user's GTT triggers. By default only active
#' triggers are returned, the ones that can still fire. Pass `status = "all"`
#' for the history as well (triggered, cancelled, expired, rejected), ordered
#' active first. This needs an OpenAlgo server that accepts the `status`
#' field; older servers refuse it as an unknown field.
#'
#' @section Usage:
#' ```
#' client$gttorderbook(...)
#' ```
#' @section Arguments:
#' * `...`: Optional fields, such as `status` (`"active"`, the default, or
#'   `"all"`), passed through unchanged.
#' @return A named list, `list(status = "success", data = list(...))`, where
#'   each entry carries `trigger_id`, `trigger_type` (`"single"` or
#'   `"two-leg"`), `status`, `symbol`, `exchange`, `trigger_prices`
#'   (ascending), `last_price`, `legs`, `created_at`, `updated_at` and
#'   `expires_at`. A SINGLE has one trigger price and one leg; an OCO has two
#'   of each, stoploss first.
#' @examples
#' \dontrun{
#' client$gttorderbook()
#' client$gttorderbook(status = "all")
#' }
#' @family gtt methods
#' @name gttorderbook
NULL

gtt_private <- list(
  # Python: _gtt_payload. Build and validate the flat GTT body shared by place
  # and modify. Validation mirrors the server's own rules, and a failure is
  # returned as an error list (not raised) so a trading loop handles it like
  # every other failure. Returns list(payload = , error = ).
  gtt_payload = function(strategy, trigger_type, symbol, action, exchange,
                         product, quantity, price_type, price,
                         triggerprice_sl, triggerprice_tg, stoploss, target, kwargs) {
    trigger_type <- toupper(py_str(trigger_type))
    if (!(trigger_type %in% GTT_TRIGGER_TYPES)) {
      return(list(payload = NULL,
                  error = gtt_validation_error("trigger_type must be 'SINGLE' or 'OCO'.")))
    }

    sl_trigger <- gtt_num(triggerprice_sl)
    tg_trigger <- gtt_num(triggerprice_tg)

    if (trigger_type == "OCO") {
      sl_limit <- gtt_num(stoploss, NULL)
      tg_limit <- gtt_num(target, NULL)
      checks <- list(
        triggerprice_sl = sl_trigger,
        stoploss = sl_limit,
        triggerprice_tg = tg_trigger,
        target = tg_limit
      )
      missing_fields <- character(0)
      for (name in c("triggerprice_sl", "stoploss", "triggerprice_tg", "target")) {
        if (!py_truthy(checks[[name]])) {
          missing_fields <- c(missing_fields, name)
        }
      }
      if (length(missing_fields) > 0) {
        return(list(payload = NULL,
                    error = gtt_validation_error(
                      paste0("Required for OCO: ", paste(missing_fields, collapse = ", "), "."))))
      }
      if (isTRUE(sl_trigger >= tg_trigger)) {
        return(list(payload = NULL,
                    error = gtt_validation_error(paste0(
                      "Stoploss trigger must be less than target trigger ",
                      "(triggerprice_sl < triggerprice_tg)."))))
      }
    } else {
      if (isTRUE(sl_trigger <= 0) && isTRUE(tg_trigger <= 0)) {
        return(list(payload = NULL,
                    error = gtt_validation_error(paste0(
                      "SINGLE GTT requires a positive triggerprice_sl or ",
                      "triggerprice_tg."))))
      }
      if (isTRUE(sl_trigger > 0) && isTRUE(tg_trigger > 0)) {
        return(list(payload = NULL,
                    error = gtt_validation_error(paste0(
                      "SINGLE GTT takes exactly one of triggerprice_sl or ",
                      "triggerprice_tg; set the other to 0."))))
      }
      # SINGLE has no legs, so the per-leg limits are sent as JSON null.
      sl_limit <- NULL
      tg_limit <- NULL
    }

    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      trigger_type = trigger_type,
      exchange = exchange,
      symbol = symbol,
      action = toupper(py_str(action)),
      product = product,
      quantity = gtt_quantity(quantity),
      pricetype = price_type,
      price = gtt_num(price),
      triggerprice_sl = sl_trigger,
      triggerprice_tg = tg_trigger,
      stoploss = sl_limit,
      target = tg_limit
    )
    payload <- add_kwargs(payload, kwargs)
    list(payload = payload, error = NULL)
  }
)

gtt_public <- list(
  placegttorder = function(..., strategy = "Python", symbol, action, exchange,
                           trigger_type = "SINGLE", product = "CNC", quantity = 1,
                           price_type = "LIMIT", price = 0,
                           triggerprice_sl = 0, triggerprice_tg = 0,
                           stoploss = NULL, target = NULL) {
    kwargs <- dots_kwargs(...)
    # Python raises on a missing required argument before any validation.
    force(symbol)
    force(action)
    force(exchange)
    built <- private$gtt_payload(
      strategy = strategy, trigger_type = trigger_type, symbol = symbol,
      action = action, exchange = exchange, product = product, quantity = quantity,
      price_type = price_type, price = price,
      triggerprice_sl = triggerprice_sl, triggerprice_tg = triggerprice_tg,
      stoploss = stoploss, target = target, kwargs = kwargs
    )
    if (!is.null(built$error)) {
      return(built$error)
    }
    private$post("placegttorder", built$payload)
  },

  modifygttorder = function(..., trigger_id, strategy = "Python", symbol, action,
                            exchange, trigger_type = "SINGLE", product = "CNC", quantity = 1,
                            price_type = "LIMIT", price = 0,
                            triggerprice_sl = 0, triggerprice_tg = 0,
                            stoploss = NULL, target = NULL) {
    kwargs <- dots_kwargs(...)
    # Python raises on a missing required argument before any validation.
    force(trigger_id)
    force(symbol)
    force(action)
    force(exchange)
    built <- private$gtt_payload(
      strategy = strategy, trigger_type = trigger_type, symbol = symbol,
      action = action, exchange = exchange, product = product, quantity = quantity,
      price_type = price_type, price = price,
      triggerprice_sl = triggerprice_sl, triggerprice_tg = triggerprice_tg,
      stoploss = stoploss, target = target, kwargs = kwargs
    )
    if (!is.null(built$error)) {
      return(built$error)
    }
    payload <- built$payload
    payload$trigger_id <- py_str(trigger_id)
    private$post("modifygttorder", payload)
  },

  cancelgttorder = function(..., trigger_id, strategy = "Python") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      strategy = strategy,
      trigger_id = py_str(trigger_id)
    )
    payload <- add_kwargs(payload, kwargs)
    private$post("cancelgttorder", payload)
  },

  gttorderbook = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(apikey = self$api_key)
    payload <- add_kwargs(payload, kwargs)
    private$post("gttorderbook", payload)
  }
)
