# Market data methods (Python: openalgo/data.py, class DataAPI).
#
# Every method is attached to the client returned by api(). Parameters that the
# Python SDK takes as keyword-only arguments come after `...` here, so they
# must be named exactly. Any other named argument is sent as an extra payload
# field, like **kwargs; unlike the order methods these extra values are sent
# as given, not converted to strings.
#
# In the Python SDK the unified client resolves every request through the
# order surface's request helpers, so these methods use private$make_request.

#' Get a real-time quote for a symbol
#'
#' @section Usage:
#' ```
#' client$quotes(symbol, exchange, ...)
#' ```
#' @section Arguments:
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `...`: Optional additional fields for future API extensions. `NULL`
#'   values are skipped, other values are sent as given.
#' @return A named list with the JSON response from the API, holding the quote
#'   data (bid, ask, ltp, volume and so on) under `data`.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$quotes(symbol = "RELIANCE", exchange = "NSE")
#' }
#' @family data methods
#' @name quotes
NULL

#' Get real-time quotes for several symbols
#'
#' Get quotes for multiple symbols in a single request.
#'
#' @section Usage:
#' ```
#' client$multiquotes(symbols, ...)
#' ```
#' @section Arguments:
#' * `symbols`: A list of symbol and exchange pairs, each a named list with
#'   `symbol` and `exchange`. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API. On success it has
#'   `status = "success"` and the quote data for each symbol; on error it has
#'   `status = "error"` and a message.
#' @examples
#' \dontrun{
#' result <- client$multiquotes(symbols = list(
#'   list(symbol = "RELIANCE", exchange = "NSE"),
#'   list(symbol = "NIFTY", exchange = "NSE_INDEX"),
#'   list(symbol = "GOLD", exchange = "MCX")
#' ))
#' if (identical(result$status, "success")) {
#'   for (quote in result$data) cat(quote$symbol, "\n")
#' }
#' }
#' @family data methods
#' @name multiquotes
NULL

#' Get market depth for a symbol
#'
#' Get the order book (market depth) for a symbol.
#'
#' @section Usage:
#' ```
#' client$depth(symbol, exchange, ...)
#' ```
#' @section Arguments:
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API, including the top
#'   five bids and asks.
#' @examples
#' \dontrun{
#' client$depth(symbol = "SBIN", exchange = "NSE")
#' }
#' @family data methods
#' @name depth
NULL

#' Get symbol details
#'
#' @section Usage:
#' ```
#' client$symbol(symbol, exchange, ...)
#' ```
#' @section Arguments:
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API: token, lot size,
#'   tick size and the other symbol details.
#' @examples
#' \dontrun{
#' client$symbol(symbol = "NIFTY30DEC25FUT", exchange = "NFO")
#' }
#' @family data methods
#' @name symbol
NULL

#' Search for symbols
#'
#' Search for symbols across exchanges.
#'
#' @section Usage:
#' ```
#' client$search(query, exchange = NULL, ...)
#' ```
#' @section Arguments:
#' * `query`: Search query. Required.
#' * `exchange`: Exchange filter. Optional; it is only sent when it is a
#'   non-empty value. Supported exchanges: NSE, NFO, BSE, BFO, MCX, CDS, BCD,
#'   NCDEX, NSE_INDEX, BSE_INDEX, MCX_INDEX.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API. Each match carries
#'   `symbol`, `name`, `exchange`, `token`, `instrumenttype`, `lotsize`,
#'   `strike` (options) and `expiry` (derivatives).
#' @examples
#' \dontrun{
#' client$search(query = "NIFTY 26000 DEC CE", exchange = "NFO")
#' }
#' @family data methods
#' @name search
NULL

#' Get historical candles as a data frame
#'
#' Fetch historical data for a symbol and return it as a `data.frame`.
#'
#' @section Usage:
#' ```
#' client$history(symbol, exchange, interval, start_date, end_date,
#'                source = "api", ...)
#' ```
#' @section Arguments:
#' * `symbol`: Trading symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `interval`: Candle interval. Required. Use [intervals] to list the
#'   supported values.
#' * `start_date`: Start date as `"YYYY-MM-DD"`. Required.
#' * `end_date`: End date as `"YYYY-MM-DD"`. Required.
#' * `source`: Data source. `"api"` (default) fetches from the broker
#'   connection; `"db"` reads the OpenAlgo historical database, which stores
#'   1m and D candles and computes every other interval on the fly. Custom
#'   intraday intervals (2m, 3m, 4m, 6m, 7m, 2h, 3h, 4h and so on) and the
#'   daily based intervals (W, M, Q, Y and multiples such as 2W or 3M) are
#'   only available with `source = "db"`.
#' * `...`: Optional additional fields for future API extensions.
#' @return On success a `data.frame` with one row per candle. R data frames
#'   have no index, so where the Python SDK sets the timestamp as the pandas
#'   index, here `timestamp` is the first column. It is a `POSIXct` converted
#'   from the Unix seconds sent by the server: in the `"Asia/Kolkata"` time
#'   zone for intraday intervals, and in `"UTC"` (the server's wall clock
#'   date) for `"D"`, `"W"` and `"M"`. Rows are sorted by timestamp, rows with
#'   a duplicated timestamp are dropped (the first is kept) and row names run
#'   from 1.
#'
#'   If the server returns no candles the result is
#'   `list(status = "error", message = "No data available for the specified period", error_type = "no_data")`.
#'   If the candles cannot be converted the result is an error list with
#'   `error_type = "processing_error"` and the server's records in `raw_data`.
#'   Any other response (an API or transport error) is returned unchanged.
#' @examples
#' \dontrun{
#' df <- client$history(symbol = "SBIN", exchange = "NSE", interval = "5m",
#'                      start_date = "2025-01-01", end_date = "2025-01-31")
#' if (is.data.frame(df)) head(df)
#' }
#' @family data methods
#' @name history
NULL

#' List the supported history intervals
#'
#' @section Usage:
#' ```
#' client$intervals(...)
#' ```
#' @section Arguments:
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API, the supported
#'   intervals grouped by type (seconds, minutes, hours, days, weeks, months).
#' @examples
#' \dontrun{
#' client$intervals()
#' }
#' @family data methods
#' @name intervals
NULL

#' List the supported history intervals (legacy)
#'
#' Legacy method kept for compatibility. Use [intervals] instead. It takes no
#' arguments.
#'
#' @section Usage:
#' ```
#' client$interval()
#' ```
#' @return The same as [intervals].
#' @examples
#' \dontrun{
#' client$interval()
#' }
#' @family data methods
#' @name interval
NULL

#' Get the expiry dates of a symbol
#'
#' @section Usage:
#' ```
#' client$expiry(symbol, exchange, instrumenttype, ...)
#' ```
#' @section Arguments:
#' * `symbol`: Underlying symbol. Required.
#' * `exchange`: Exchange code. Required.
#' * `instrumenttype`: Instrument type, `"futures"` or `"options"`. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with the JSON response from the API, the expiry dates
#'   under `data`.
#' @examples
#' \dontrun{
#' client$expiry(symbol = "NIFTY", exchange = "NFO", instrumenttype = "options")
#' }
#' @family data methods
#' @name expiry
NULL

#' Download the instrument master
#'
#' Download all trading symbols and instruments, optionally for one exchange
#' only. This is a GET request with the API key in the query string.
#'
#' @section Usage:
#' ```
#' client$instruments(exchange = NULL)
#' ```
#' @section Arguments:
#' * `exchange`: Exchange to download. Optional. When `NULL` (default) every
#'   exchange is downloaded in turn (NSE, BSE, NFO, BFO, MCX, CDS, BCD,
#'   NSE_INDEX, BSE_INDEX) and the results are combined; exchanges that fail
#'   are skipped silently.
#'
#' No other arguments are accepted.
#' @return On success a `data.frame` with the columns `symbol`, `brsymbol`,
#'   `name`, `exchange`, `token`, `expiry` (derivatives), `strike` (options),
#'   `lotsize`, `instrumenttype` and `tick_size`. When all exchanges are
#'   combined, the columns are the union of every exchange's columns (missing
#'   values are `NA`) and row names run from 1.
#'
#'   On failure an error list: `error_type = "no_data"` when nothing was
#'   returned, `"processing_error"` (with `raw_data`) when the records could
#'   not be converted, or the API and transport error lists of the other
#'   methods.
#' @examples
#' \dontrun{
#' all_df <- client$instruments()
#' nse_df <- client$instruments(exchange = "NSE")
#' if (is.data.frame(nse_df)) {
#'   equities <- nse_df[nse_df$instrumenttype == "EQ", ]
#'   utils::write.csv(nse_df, "nse_instruments.csv", row.names = FALSE)
#' }
#' }
#' @family data methods
#' @name instruments
NULL

#' Get the synthetic future price
#'
#' Calculate the synthetic futures price from the ATM call and put options:
#' strike price plus call premium minus put premium. The server finds the ATM
#' strike itself. This only calculates; it never places an order.
#'
#' @section Usage:
#' ```
#' client$syntheticfuture(underlying, exchange, expiry_date, ...)
#' ```
#' @section Arguments:
#' * `underlying`: Underlying symbol, for example `"NIFTY"` or `"RELIANCE"`.
#'   Required.
#' * `exchange`: Exchange code: NSE_INDEX, BSE_INDEX, NSE or BSE. Index
#'   exchanges are mapped to their options exchanges by the server. Required.
#' * `expiry_date`: Expiry date as DDMMMYY, for example `"28NOV25"`. Required.
#' * `...`: Optional additional fields for future API extensions.
#' @return A named list with `status`, `underlying`, `underlying_ltp`,
#'   `expiry`, `atm_strike` and `synthetic_future_price`.
#' @examples
#' \dontrun{
#' result <- client$syntheticfuture(underlying = "NIFTY", exchange = "NSE_INDEX",
#'                                  expiry_date = "28NOV25")
#' if (identical(result$status, "success")) {
#'   basis <- result$synthetic_future_price - result$underlying_ltp
#' }
#' }
#' @family data methods
#' @name syntheticfuture
NULL

# Build a data.frame from a parsed JSON value the way pandas.DataFrame() does
# for the shapes the server sends: a list of records, or an object of columns.
json_to_df <- function(data) {
  if (is.null(data)) {
    return(data.frame())
  }
  if (is.data.frame(data)) {
    return(data)
  }
  if (!is.list(data)) {
    stop("DataFrame constructor not properly called!", call. = FALSE)
  }
  if (!is_json_object(data)) {
    return(records_to_df(data))
  }
  # An object of columns.
  if (length(data) == 0) {
    return(data.frame())
  }
  is_col <- vapply(data, is.list, logical(1))
  if (!any(is_col)) {
    stop("If using all scalar values, you must pass an index", call. = FALSE)
  }
  lens <- unique(lengths(data[is_col]))
  if (length(lens) > 1) {
    stop("All arrays must be of the same length", call. = FALSE)
  }
  out <- lapply(data, function(col) {
    if (!is.list(col)) {
      return(rep(if (is.null(col)) NA else col, lens))
    }
    values <- lapply(col, function(v) if (is.null(v) || length(v) == 0) NA else v)
    if (any(vapply(values, is.list, logical(1)))) {
      return(I(values))
    }
    unlist(values, use.names = FALSE)
  })
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE, optional = TRUE)
}

# Turn the raw candle frame into the history() result: POSIXct timestamp as
# the first column, sorted, duplicate timestamps dropped (first kept).
format_history_df <- function(df, interval) {
  if (!("timestamp" %in% names(df))) {
    stop("'timestamp'", call. = FALSE)
  }
  ts <- df[["timestamp"]]
  if (is.factor(ts)) {
    ts <- as.character(ts)
  }
  if (is.character(ts)) {
    secs <- suppressWarnings(as.numeric(ts))
    bad <- !is.na(ts) & is.na(secs)
    if (any(bad)) {
      stop(sprintf("non convertible value %s with the unit 's'", ts[bad][1]), call. = FALSE)
    }
  } else if (is.numeric(ts) || is.logical(ts)) {
    secs <- as.numeric(ts)
  } else {
    stop("timestamp values must be Unix seconds", call. = FALSE)
  }
  tz <- if (interval %in% c("D", "W", "M")) "UTC" else "Asia/Kolkata"
  df[["timestamp"]] <- .POSIXct(secs, tz = tz)
  df <- df[c("timestamp", setdiff(names(df), "timestamp"))]
  df <- df[order(df[["timestamp"]], method = "radix"), , drop = FALSE]
  df <- df[!duplicated(df[["timestamp"]]), , drop = FALSE]
  rownames(df) <- NULL
  df
}

# pandas.concat(frames, ignore_index = TRUE): union of columns in order of
# first appearance, missing values filled with NA, fresh row numbers.
concat_frames <- function(frames) {
  cols <- character(0)
  for (df in frames) {
    cols <- c(cols, setdiff(names(df), cols))
  }
  frames <- lapply(frames, function(df) {
    for (col in setdiff(cols, names(df))) {
      df[[col]] <- rep(NA, nrow(df))
    }
    df[cols]
  })
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  out
}

data_public <- list(
  quotes = function(..., symbol, exchange) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("quotes", payload)
  },

  multiquotes = function(..., symbols) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbols = symbols
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("multiquotes", payload)
  },

  depth = function(..., symbol, exchange) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("depth", payload)
  },

  symbol = function(..., symbol, exchange) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("symbol", payload)
  },

  search = function(..., query, exchange = NULL) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      query = query
    )
    if (py_truthy(exchange)) {
      payload["exchange"] <- list(exchange)
    }
    payload <- add_kwargs(payload, kwargs)
    private$make_request("search", payload)
  },

  history = function(..., symbol, exchange, interval, start_date, end_date, source = "api") {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange,
      interval = interval,
      start_date = start_date,
      end_date = end_date,
      source = source
    )
    payload <- add_kwargs(payload, kwargs)

    result <- private$make_request("history", payload)

    if (identical(result[["status"]], "success") && "data" %in% names(result)) {
      return(tryCatch({
        df <- json_to_df(result[["data"]])
        if (nrow(df) == 0 || ncol(df) == 0) {
          error_result("No data available for the specified period", "no_data")
        } else {
          format_history_df(df, interval)
        }
      }, error = function(e) {
        c(error_result(paste0("Failed to process historical data: ", conditionMessage(e)),
                       "processing_error"),
          list(raw_data = result[["data"]]))
      }))
    }
    result
  },

  intervals = function(...) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("intervals", payload)
  },

  interval = function(...) {
    no_extra_args("interval", ...)
    self$intervals()
  },

  expiry = function(..., symbol, exchange, instrumenttype) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      symbol = symbol,
      exchange = exchange,
      instrumenttype = instrumenttype
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("expiry", payload)
  },

  instruments = function(..., exchange = NULL) {
    no_extra_args("instruments", ...)

    # No exchange: fetch every exchange and combine.
    if (is.null(exchange)) {
      all_exchanges <- c("NSE", "BSE", "NFO", "BFO", "MCX", "CDS", "BCD", "NSE_INDEX", "BSE_INDEX")
      all_dfs <- list()
      for (exch in all_exchanges) {
        params <- list(apikey = self$api_key, exchange = exch)
        df <- tryCatch({
          result <- private$get_request("instruments", params)
          if (identical(result[["status"]], "success") && "data" %in% names(result)) {
            json_to_df(result[["data"]])
          } else {
            NULL
          }
        }, error = function(e) NULL)
        if (!is.null(df) && nrow(df) > 0 && ncol(df) > 0) {
          all_dfs[[length(all_dfs) + 1]] <- df
        }
      }
      if (length(all_dfs) > 0) {
        return(concat_frames(all_dfs))
      }
      return(error_result("Failed to fetch instruments from any exchange", "no_data"))
    }

    # Single exchange.
    params <- list(apikey = self$api_key, exchange = exchange)
    fetched <- tryCatch(list(ok = TRUE, value = private$get_request("instruments", params)),
                        error = function(e) list(ok = FALSE, value = transport_error(e)))
    if (!fetched$ok) {
      return(fetched$value)
    }
    result <- fetched$value
    if (identical(result[["status"]], "success") && "data" %in% names(result)) {
      return(tryCatch({
        df <- json_to_df(result[["data"]])
        if (nrow(df) == 0 || ncol(df) == 0) {
          error_result("No instruments available for the specified exchange", "no_data")
        } else {
          df
        }
      }, error = function(e) {
        c(error_result(paste0("Failed to process instruments data: ", conditionMessage(e)),
                       "processing_error"),
          list(raw_data = result[["data"]]))
      }))
    }
    result
  },

  syntheticfuture = function(..., underlying, exchange, expiry_date) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      underlying = underlying,
      exchange = exchange,
      expiry_date = expiry_date
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("syntheticfuture", payload)
  }
)
