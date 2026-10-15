# Market calendar utilities (Python: openalgo/utilities.py, class UtilitiesAPI).
#
# These methods take no extra fields: unknown arguments are an error, as they
# are in Python.

#' Get market holidays
#'
#' Get market holidays for a specific year.
#'
#' @section Usage:
#' ```
#' client$holidays(year = NULL)
#' ```
#' @section Arguments:
#' * `year`: Year for the holiday data (2020 to 2050). When `NULL` (default)
#'   it is not sent and the server uses the current year.
#' @return A named list such as
#'   ```
#'   list(status = "success", year = 2025, timezone = "Asia/Kolkata",
#'        data = list(
#'          list(date = "2025-02-26", description = "Maha Shivaratri",
#'               holiday_type = "TRADING_HOLIDAY",
#'               closed_exchanges = list("NSE", "BSE", "NFO", "BFO", "CDS", "BCD"),
#'               open_exchanges = list(
#'                 list(exchange = "MCX", start_time = 1740549000000,
#'                      end_time = 1740602700000)))))
#'   ```
#'   Times are epoch milliseconds.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#' client$holidays()
#' client$holidays(year = 2025)
#' }
#' @family utility methods
#' @name holidays
NULL

#' Get market timings
#'
#' Get market timings for a specific date.
#'
#' @section Usage:
#' ```
#' client$timings(date = NULL)
#' ```
#' @section Arguments:
#' * `date`: Date as a `"YYYY-MM-DD"` string. When `NULL` (default) today's
#'   local date is sent.
#' @return A named list such as
#'   ```
#'   list(status = "success",
#'        data = list(
#'          list(exchange = "NSE", start_time = 1745984700000,
#'               end_time = 1746007200000),
#'          list(exchange = "BSE", start_time = 1745984700000,
#'               end_time = 1746007200000),
#'          list(exchange = "MCX", start_time = 1745983800000,
#'               end_time = 1746037500000)))
#'   ```
#'   Times are epoch milliseconds. An empty `data` list means the market is
#'   closed (holiday).
#' @examples
#' \dontrun{
#' client$timings()
#' client$timings(date = "2025-01-31")
#' }
#' @family utility methods
#' @name timings
NULL

utilities_public <- list(
  holidays = function(year = NULL, ...) {
    no_extra_args("holidays", ...)
    payload <- list(apikey = self$api_key)
    if (!is.null(year)) {
      payload$year <- year
    }
    private$make_request("market/holidays", payload)
  },

  timings = function(date = NULL, ...) {
    no_extra_args("timings", ...)
    if (is.null(date)) {
      date <- format(Sys.Date(), "%Y-%m-%d")
    }
    payload <- list(
      apikey = self$api_key,
      date = date
    )
    private$make_request("market/timings", payload)
  }
)
