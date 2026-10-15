# Market data methods. Extra keyword arguments
# are sent as given (not stringified); history() and instruments() return
# data frames.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("quotes, depth and symbol bodies", {
  cl <- mock_client()
  for (ep in c("quotes", "depth", "symbol")) {
    r <- call_mock(ep, function() {
      cl[[ep]](symbol = "SBIN", exchange = "NSE", extra = 5, skipped = NULL)
    }, json = list(status = "success", data = list(ltp = 812.35)))
    expect_identical(r$result, list(status = "success", data = list(ltp = 812.35)))
    expect_request(r$request, ep, list(apikey = mock_api_key, symbol = "SBIN", exchange = "NSE",
                                       extra = 5))
    expect_true(is.numeric(r$request$json$extra))
  }
  expect_error(cl$quotes(symbol = "SBIN"), "exchange")
  expect_error(cl$quotes("SBIN", symbol = "SBIN", exchange = "NSE"), "must be named")
})

test_that("multiquotes keeps a single symbol inside an array", {
  cl <- mock_client()
  r <- call_mock("multiquotes", function() {
    cl$multiquotes(symbols = list(list(symbol = "RELIANCE", exchange = "NSE")))
  })
  expect_request(r$request, "multiquotes", list(
    apikey = mock_api_key, symbols = list(list(symbol = "RELIANCE", exchange = "NSE"))))
  expect_match(r$request$body, "\"symbols\":[{\"symbol\":\"RELIANCE\"", fixed = TRUE)
})

test_that("search sends exchange only when it is truthy", {
  cl <- mock_client()
  r <- call_mock("search", function() cl$search(query = "NIFTY"))
  expect_request(r$request, "search", list(apikey = mock_api_key, query = "NIFTY"))
  r <- call_mock("search", function() cl$search(query = "NIFTY", exchange = ""))
  expect_request(r$request, "search", list(apikey = mock_api_key, query = "NIFTY"))
  r <- call_mock("search", function() cl$search(query = "NIFTY", exchange = "NFO", limit = 10))
  expect_request(r$request, "search", list(apikey = mock_api_key, query = "NIFTY",
                                           exchange = "NFO", limit = 10))
})

test_that("intervals, interval, expiry and syntheticfuture bodies", {
  cl <- mock_client()
  r <- call_mock("intervals", function() cl$intervals())
  expect_request(r$request, "intervals", list(apikey = mock_api_key))
  # interval() is the legacy alias of intervals().
  r <- call_mock("intervals", function() cl$interval())
  expect_request(r$request, "intervals", list(apikey = mock_api_key))
  expect_error(cl$interval(x = 1), "unexpected argument")

  r <- call_mock("expiry", function() {
    cl$expiry(symbol = "NIFTY", exchange = "NFO", instrumenttype = "options")
  })
  expect_request(r$request, "expiry", list(apikey = mock_api_key, symbol = "NIFTY",
                                           exchange = "NFO", instrumenttype = "options"))

  r <- call_mock("syntheticfuture", function() {
    cl$syntheticfuture(underlying = "NIFTY", exchange = "NSE_INDEX", expiry_date = "28NOV25")
  })
  expect_request(r$request, "syntheticfuture", list(
    apikey = mock_api_key, underlying = "NIFTY", exchange = "NSE_INDEX",
    expiry_date = "28NOV25"))
})

candles <- list(
  list(timestamp = 1700000120, open = 3, high = 3, low = 3, close = 3, volume = 30),
  list(timestamp = 1700000000, open = 1, high = 1, low = 1, close = 1, volume = 10),
  list(timestamp = 1700000120, open = 9, high = 9, low = 9, close = 9, volume = 90),
  list(timestamp = 1700000060, open = 2, high = 2, low = 2, close = 2, volume = 20)
)

test_that("history sends the payload with source defaulting to api", {
  cl <- mock_client()
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "5m", start_date = "2025-01-01",
               end_date = "2025-01-02", oi = TRUE)
  }, json = list(status = "success", data = candles))
  expect_request(r$request, "history", list(
    apikey = mock_api_key, symbol = "SBIN", exchange = "NSE", interval = "5m",
    start_date = "2025-01-01", end_date = "2025-01-02", source = "api", oi = TRUE))
})

test_that("intraday history is an Asia/Kolkata data frame, sorted, duplicates dropped", {
  cl <- mock_client()
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "1m", start_date = "a",
               end_date = "b")
  }, json = list(status = "success", data = candles))
  df <- r$result
  expect_s3_class(df, "data.frame")
  expect_identical(names(df), c("timestamp", "open", "high", "low", "close", "volume"))
  expect_s3_class(df$timestamp, "POSIXct")
  expect_identical(attr(df$timestamp, "tzone"), "Asia/Kolkata")
  expect_equal(as.numeric(df$timestamp), c(1700000000, 1700000060, 1700000120))
  # The first row of a duplicated timestamp is kept (pandas keep="first").
  expect_equal(df$close, c(1, 2, 3))
  expect_identical(format(df$timestamp[1], "%Y-%m-%d %H:%M:%S"), "2023-11-15 03:43:20")
})

test_that("daily history keeps UTC timestamps", {
  cl <- mock_client()
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "D", start_date = "a",
               end_date = "b")
  }, json = list(status = "success", data = list(
    list(timestamp = 1735689600, close = 1), list(timestamp = 1735603200, close = 0))))
  expect_identical(attr(r$result$timestamp, "tzone"), "UTC")
  expect_equal(as.numeric(r$result$timestamp), c(1735603200, 1735689600))
  expect_identical(format(r$result$timestamp[2], "%Y-%m-%d %H:%M:%S"), "2025-01-01 00:00:00")
})

test_that("history error results", {
  cl <- mock_client()
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "1m", start_date = "a",
               end_date = "b")
  }, json = list(status = "success", data = list()))
  expect_identical(r$result, list(status = "error",
                                  message = "No data available for the specified period",
                                  error_type = "no_data"))

  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "1m", start_date = "a",
               end_date = "b")
  }, json = list(status = "success", data = list(list(close = 1))))
  expect_identical(r$result, list(status = "error",
                                  message = "Failed to process historical data: 'timestamp'",
                                  error_type = "processing_error",
                                  raw_data = list(list(close = 1L))))

  # A success without data, and an API error, are returned unchanged.
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "1m", start_date = "a",
               end_date = "b")
  }, json = list(status = "success"))
  expect_identical(r$result, list(status = "success"))
  r <- call_mock("history", function() {
    cl$history(symbol = "SBIN", exchange = "NSE", interval = "1m", start_date = "a",
               end_date = "b")
  }, json = list(status = "error", message = "Invalid interval"))
  expect_identical(r$result, list(status = "error", message = "Invalid interval", code = 200L,
                                  error_type = "api_error"))
})

test_that("instruments for one exchange is a GET returning a data frame", {
  cl <- mock_client()
  r <- call_mock("instruments", function() cl$instruments(exchange = "NSE"),
                 json = list(status = "success", data = list(
                   list(symbol = "SBIN", exchange = "NSE", lotsize = 1),
                   list(symbol = "TCS", exchange = "NSE", lotsize = 1))))
  expect_identical(r$request$method, "GET")
  expect_identical(r$request$path, api_path("instruments"))
  expect_identical(r$request$query, list(apikey = mock_api_key, exchange = "NSE"))
  expect_identical(r$request$body, "")
  expect_s3_class(r$result, "data.frame")
  expect_identical(r$result$symbol, c("SBIN", "TCS"))
  expect_identical(names(r$result), c("symbol", "exchange", "lotsize"))

  r <- call_mock("instruments", function() cl$instruments(exchange = "NSE"),
                 json = list(status = "success", data = list()))
  expect_identical(r$result, list(status = "error",
                                  message = "No instruments available for the specified exchange",
                                  error_type = "no_data"))

  r <- call_mock("instruments", function() cl$instruments(exchange = "NSE"),
                 json = list(status = "error", message = "bad"), status = 403L)
  expect_identical(r$result$message, "HTTP 403: {\"status\":\"error\",\"message\":\"bad\"}")
  expect_identical(r$result$error_type, "http_error")

  expect_error(cl$instruments("NSE"), "unexpected argument")
})

test_that("instruments for all exchanges combines the ones that succeed", {
  cl <- mock_client()
  mock_reset()
  path <- api_path("instruments")
  mock_respond(path, json = list(status = "error", message = "no master contract"))
  mock_respond(path, query = list(exchange = "NSE"), json = list(status = "success", data = list(
    list(symbol = "SBIN", exchange = "NSE", lotsize = 1))))
  mock_respond(path, query = list(exchange = "NFO"), status = 500L, body = "boom",
               content_type = "text/plain")
  mock_respond(path, query = list(exchange = "MCX"), json = list(status = "success", data = list(
    list(symbol = "GOLD", exchange = "MCX", tick_size = 1, expiry = "05FEB26"))))
  mock_respond(path, query = list(exchange = "BSE"), json = list(status = "success",
                                                                 data = list()))
  df <- cl$instruments()
  reqs <- mock_requests()
  expect_identical(vapply(reqs, function(q) q$query$exchange, ""),
                   c("NSE", "BSE", "NFO", "BFO", "MCX", "CDS", "BCD", "NSE_INDEX", "BSE_INDEX"))
  expect_true(all(vapply(reqs, function(q) q$method, "") == "GET"))
  expect_s3_class(df, "data.frame")
  expect_identical(names(df), c("symbol", "exchange", "lotsize", "tick_size", "expiry"))
  expect_identical(df$symbol, c("SBIN", "GOLD"))
  expect_equal(df$lotsize, c(1, NA))
  expect_equal(df$tick_size, c(NA, 1))
  expect_identical(df$expiry, c(NA, "05FEB26"))
  expect_identical(rownames(df), c("1", "2"))

  mock_reset()
  mock_respond(path, json = list(status = "error", message = "down"))
  expect_identical(cl$instruments(), list(status = "error",
                                          message = "Failed to fetch instruments from any exchange",
                                          error_type = "no_data"))
  expect_length(mock_requests(), 9L)
})

test_that("data methods follow the make_request response paths", {
  check_make_request_paths("quotes", function(cl) cl$quotes(symbol = "SBIN", exchange = "NSE"))
})
