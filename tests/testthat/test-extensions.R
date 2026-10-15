# Additional REST endpoints (R/extensions.R): documented OpenAlgo server
# endpoints the Python SDK does not wrap. POSTs use the make_request response
# handling; GETs send the API key and parameters in the query string.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("ping and pnlsymbols post the API key and extra fields as is", {
  cl <- mock_client()
  r <- call_mock("ping", function() cl$ping(),
                 json = list(status = "success", data = list(message = "pong", broker = "x")))
  expect_identical(r$result, list(status = "success", data = list(message = "pong", broker = "x")))
  expect_request(r$request, "ping", list(apikey = mock_api_key))
  expect_identical(r$request$content_type, "application/json")

  r <- call_mock("ping", function() cl$ping(extra = 5, skipped = NULL))
  expect_request(r$request, "ping", list(apikey = mock_api_key, extra = 5))
  expect_true(is.numeric(r$request$json$extra))
  expect_error(cl$ping(5), "must be named")

  r <- call_mock("pnl/symbols", function() cl$pnlsymbols(),
                 json = list(status = "success", data = list(), mode = "analyze"))
  expect_request(r$request, "pnl/symbols", list(apikey = mock_api_key))
  expect_identical(r$result$mode, "analyze")
})

test_that("multioptiongreeks always sends symbols as an array", {
  cl <- mock_client()
  opts <- list(list(symbol = "NIFTY25NOV2526000CE", exchange = "NFO"),
               list(symbol = "NIFTY25NOV2526000PE", exchange = "NFO",
                    underlying_symbol = "NIFTY", underlying_exchange = "NSE_INDEX"))
  r <- call_mock("multioptiongreeks", function() {
    cl$multioptiongreeks(symbols = opts, interest_rate = 7, expiry_time = "15:30")
  }, json = list(status = "success", data = list(), summary = list(total = 2L)))
  expect_request(r$request, "multioptiongreeks", list(
    apikey = mock_api_key, symbols = opts, interest_rate = 7, expiry_time = "15:30"))

  # Optional fields are left out when NULL; a single option is still an array.
  r <- call_mock("multioptiongreeks", function() {
    cl$multioptiongreeks(symbols = list(symbol = "X", exchange = "NFO"))
  })
  expect_request(r$request, "multioptiongreeks", list(
    apikey = mock_api_key, symbols = list(list(symbol = "X", exchange = "NFO"))))
  expect_match(r$request$body, "\"symbols\":[{", fixed = TRUE)

  # A data frame gives one option per row; NA cells are not sent. Known
  # fields come first in the server's order, other fields after them.
  df <- data.frame(exchange = c("NFO", "BFO"), symbol = c("A", "B"),
                   underlying_symbol = c(NA, "SENSEX"), stringsAsFactors = FALSE)
  r <- call_mock("multioptiongreeks", function() cl$multioptiongreeks(symbols = df, foo = TRUE))
  expect_request(r$request, "multioptiongreeks", list(
    apikey = mock_api_key,
    symbols = list(list(symbol = "A", exchange = "NFO"),
                   list(symbol = "B", exchange = "BFO", underlying_symbol = "SENSEX")),
    foo = TRUE))
})

test_that("multioptiongreeks validates symbols like the server, without a request", {
  cl <- mock_client()
  mock_reset()
  verr <- function(msg) list(status = "error", message = msg, error_type = "validation_error")
  expect_identical(cl$multioptiongreeks(symbols = list()),
                   verr("symbols must contain at least one option"))
  many <- rep(list(list(symbol = "X", exchange = "NFO")), 51)
  expect_identical(cl$multioptiongreeks(symbols = many), verr("Maximum 50 symbols allowed"))
  expect_identical(cl$multioptiongreeks(symbols = list(list(symbol = "X"))),
                   verr("symbols[1]: exchange is required"))
  expect_identical(cl$multioptiongreeks(symbols = list(list(symbol = "X", exchange = "NFO"),
                                                       list(exchange = "NFO"))),
                   verr("symbols[2]: symbol is required"))
  expect_identical(cl$multioptiongreeks(symbols = list(list(symbol = "", exchange = "NFO"))),
                   verr("symbols[1]: symbol is required"))
  expect_identical(cl$multioptiongreeks(symbols = list("X")),
                   verr("symbols[1] must be a named list"))
  expect_identical(cl$multioptiongreeks(symbols = "X"), verr("symbols must be a list of options"))
  expect_identical(cl$multioptiongreeks(symbols = list(a = 1)),
                   verr("symbols must be a list of options"))
  expect_length(mock_requests(), 0)

  # Exactly 50 is allowed.
  r <- call_mock("multioptiongreeks", function() {
    cl$multioptiongreeks(symbols = rep(list(list(symbol = "X", exchange = "NFO")), 50))
  })
  expect_length(r$request$json$symbols, 50)
})

test_that("ticker is a GET on the encoded EXCHANGE:SYMBOL path", {
  cl <- mock_client()
  data <- list(status = "success", data = list(list(timestamp = 1L, open = 1.5)))
  mock_reset()
  mock_respond(api_path("ticker/NSE:RELIANCE"), json = data)
  res <- cl$ticker(symbol = "RELIANCE", exchange = "NSE", start_date = "2025-01-01",
                   end_date = "2025-01-31")
  req <- last_request()
  expect_identical(res, data)
  expect_identical(req$method, "GET")
  expect_identical(req$path, api_path("ticker/NSE:RELIANCE"))
  expect_identical(req$query, list(apikey = mock_api_key, interval = "D", from = "2025-01-01",
                                   to = "2025-01-31", format = "json"))
  expect_identical(req$body, "")

  # Extra arguments become query parameters; reserved characters are encoded.
  mock_reset()
  mock_respond(api_path("ticker/NSE:M&M"), json = data)
  res <- cl$ticker(symbol = "M&M", exchange = "NSE", interval = "5m", start_date = "2025-01-30",
                   end_date = "2025-01-31", sort = "asc", skipped = NULL)
  req <- last_request()
  expect_identical(res, data)
  expect_identical(req$path, api_path("ticker/NSE:M&M"))
  expect_identical(req$query, list(apikey = mock_api_key, interval = "5m", from = "2025-01-30",
                                   to = "2025-01-31", format = "json", sort = "asc"))

  expect_error(cl$ticker(symbol = "SBIN", exchange = "NSE", end_date = "2025-01-31"),
               "start_date")
})

test_that("ticker format txt returns the plain text body", {
  cl <- mock_client()
  path <- api_path("ticker/NSE:SBIN")
  text <- "NSE:SBIN,2025-01-30,750.5,760,749,755.25,123456\nNSE:SBIN,2025-01-31,755,758,751,752,99000"
  mock_reset()
  mock_respond(path, body = text, content_type = "text/plain")
  res <- cl$ticker(symbol = "SBIN", exchange = "NSE", start_date = "2025-01-30",
                   end_date = "2025-01-31", format = "txt")
  expect_identical(res, text)
  expect_identical(last_request()$query$format, "txt")

  # An empty 200 body is an empty string.
  mock_reset()
  mock_respond(path, body = "", content_type = "text/plain")
  expect_identical(cl$ticker(symbol = "SBIN", exchange = "NSE", start_date = "2025-01-30",
                             end_date = "2025-01-31", format = "txt"), "")

  # Non-200 is the usual http_error list.
  mock_reset()
  mock_respond(path, body = "Invalid openalgo apikey\n", status = 403L, content_type = "text/plain")
  expect_identical(cl$ticker(symbol = "SBIN", exchange = "NSE", start_date = "2025-01-30",
                             end_date = "2025-01-31", format = "txt"),
                   list(status = "error", message = "HTTP 403: Invalid openalgo apikey\n",
                        code = 403L, error_type = "http_error"))
})

test_that("ticker json follows the make_request response paths", {
  check_make_request_paths("ticker/NSE:SBIN", function(cl) {
    cl$ticker(symbol = "SBIN", exchange = "NSE", start_date = "2025-01-01", end_date = "2025-01-02")
  })
})

test_that("chart reads with a GET and updatechart posts the preferences", {
  cl <- mock_client()
  r <- call_mock("chart", function() cl$chart(),
                 json = list(status = "success", data = list(tv_theme = "dark")))
  expect_identical(r$result, list(status = "success", data = list(tv_theme = "dark")))
  expect_identical(r$request$method, "GET")
  expect_identical(r$request$path, api_path("chart"))
  expect_identical(r$request$query, list(apikey = mock_api_key))

  r <- call_mock("chart", function() {
    cl$updatechart(tv_theme = "dark", tv_chart_layout = list(interval = "15m"), skipped = NULL,
                   flags = list(1L, 2L), on = TRUE)
  })
  expect_request(r$request, "chart", list(apikey = mock_api_key, tv_theme = "dark",
                                          tv_chart_layout = list(interval = "15m"),
                                          flags = list(1L, 2L), on = TRUE))
  expect_match(r$request$body, "\"tv_chart_layout\":{\"interval\":\"15m\"}", fixed = TRUE)
})

test_that("updatechart validates the preference count and names, without a request", {
  cl <- mock_client()
  mock_reset()
  verr <- function(msg) list(status = "error", message = msg, error_type = "validation_error")
  expect_identical(cl$updatechart(), verr("No preferences provided to update"))
  expect_identical(cl$updatechart(a = NULL), verr("No preferences provided to update"))
  prefs <- stats::setNames(as.list(1:51), paste0("k", 1:51))
  expect_identical(do.call(cl$updatechart, prefs), verr("Too many preference keys (max 50)"))
  long <- strrep("x", 51)
  expect_identical(do.call(cl$updatechart, stats::setNames(list(1), long)),
                   verr(sprintf("Preference key too long: %s... (max 50 chars)", strrep("x", 20))))
  expect_length(mock_requests(), 0)

  r <- call_mock("chart", function() do.call(cl$updatechart, prefs[1:50]))
  expect_length(r$request$json, 51)
})

test_that("telegram configuration and lifecycle requests", {
  cl <- mock_client()
  r <- call_mock("telegram/config", function() cl$telegramconfig(),
                 json = list(status = "success", data = list(bot_token = "123456789:...")))
  expect_identical(r$request$method, "GET")
  expect_identical(r$request$path, api_path("telegram/config"))
  expect_identical(r$request$query, list(apikey = mock_api_key))
  expect_identical(r$result$data$bot_token, "123456789:...")

  r <- call_mock("telegram/config", function() cl$updatetelegramconfig())
  expect_request(r$request, "telegram/config", list(apikey = mock_api_key))

  r <- call_mock("telegram/config", function() {
    cl$updatetelegramconfig(token = "t", webhook_url = "https://example.com/hook",
                            polling_mode = FALSE, broadcast_enabled = TRUE,
                            rate_limit_per_minute = 30, extra = "x")
  })
  expect_request(r$request, "telegram/config", list(
    apikey = mock_api_key, token = "t", webhook_url = "https://example.com/hook",
    polling_mode = FALSE, broadcast_enabled = TRUE, rate_limit_per_minute = 30, extra = "x"))

  r <- call_mock("telegram/config", function() cl$updatetelegramconfig(polling_mode = TRUE))
  expect_request(r$request, "telegram/config", list(apikey = mock_api_key, polling_mode = TRUE))

  for (ep in c("start", "stop")) {
    r <- call_mock(paste0("telegram/", ep), function() cl[[paste0("telegram", ep)]](),
                   json = list(status = "success", message = "ok"))
    expect_request(r$request, paste0("telegram/", ep), list(apikey = mock_api_key))
    expect_identical(r$result, list(status = "success", message = "ok"))
  }
})

test_that("telegram users, stats and preferences put their filters in the query", {
  cl <- mock_client()
  r <- call_mock("telegram/users", function() cl$telegramusers(),
                 json = list(status = "success", data = list(), count = 0L))
  expect_identical(r$request$method, "GET")
  expect_identical(r$request$query, list(apikey = mock_api_key))
  expect_identical(r$result$count, 0L)

  r <- call_mock("telegram/users", function() {
    cl$telegramusers(broker = "yourbroker", notifications_enabled = TRUE)
  })
  expect_identical(r$request$query, list(apikey = mock_api_key, broker = "yourbroker",
                                         notifications_enabled = "true"))
  r <- call_mock("telegram/users", function() cl$telegramusers(notifications_enabled = FALSE))
  expect_identical(r$request$query, list(apikey = mock_api_key, notifications_enabled = "false"))

  r <- call_mock("telegram/stats", function() cl$telegramstats())
  expect_identical(r$request$path, api_path("telegram/stats"))
  expect_identical(r$request$query, list(apikey = mock_api_key))
  r <- call_mock("telegram/stats", function() cl$telegramstats(days = 30))
  expect_identical(r$request$query, list(apikey = mock_api_key, days = "30"))

  r <- call_mock("telegram/preferences", function() cl$telegrampreferences(telegram_id = 123456789))
  expect_identical(r$request$method, "GET")
  expect_identical(r$request$query, list(apikey = mock_api_key, telegram_id = "123456789"))
  expect_error(cl$telegrampreferences(), "telegram_id")
})

test_that("telegram broadcast and preference updates post their fields", {
  cl <- mock_client()
  r <- call_mock("telegram/broadcast", function() cl$telegrambroadcast(message = "hello"),
                 json = list(status = "success", success_count = 0L, fail_count = 0L))
  expect_request(r$request, "telegram/broadcast", list(apikey = mock_api_key, message = "hello"))
  expect_identical(r$result$success_count, 0L)

  r <- call_mock("telegram/broadcast", function() {
    cl$telegrambroadcast(message = "hi", filters = list(broker = "yourbroker"))
  })
  expect_request(r$request, "telegram/broadcast", list(apikey = mock_api_key, message = "hi",
                                                       filters = list(broker = "yourbroker")))
  expect_error(cl$telegrambroadcast(), "message")

  r <- call_mock("telegram/preferences", function() cl$updatetelegrampreferences(telegram_id = 42))
  expect_request(r$request, "telegram/preferences", list(apikey = mock_api_key, telegram_id = 42))

  r <- call_mock("telegram/preferences", function() {
    cl$updatetelegrampreferences(telegram_id = 42, order_notifications = TRUE,
                                 trade_notifications = FALSE, pnl_notifications = TRUE,
                                 daily_summary = TRUE, summary_time = "16:00",
                                 language = "en", timezone = "Asia/Kolkata")
  })
  expect_request(r$request, "telegram/preferences", list(
    apikey = mock_api_key, telegram_id = 42, order_notifications = TRUE,
    trade_notifications = FALSE, pnl_notifications = TRUE, daily_summary = TRUE,
    summary_time = "16:00", language = "en", timezone = "Asia/Kolkata"))
  expect_match(r$request$body, "\"telegram_id\":42,", fixed = TRUE)
})

test_that("POST and GET additions follow the make_request response paths", {
  check_make_request_paths("ping", function(cl) cl$ping())
  check_make_request_paths("telegram/broadcast", function(cl) cl$telegrambroadcast(message = "m"))
  check_make_request_paths("chart", function(cl) cl$chart())
  check_make_request_paths("telegram/users", function(cl) cl$telegramusers())
})

test_that("transport failures are returned as error lists", {
  skip_on_cran()
  check_client_transport_errors("ping", function(cl) cl$ping())
  check_client_transport_errors("telegram/stats", function(cl) cl$telegramstats())
  check_client_transport_errors("ticker/NSE:SBIN", function(cl) {
    cl$ticker(symbol = "SBIN", exchange = "NSE", start_date = "2025-01-01", end_date = "2025-01-02",
              format = "txt")
  })
})

test_that("telegram start and stop post only the api key", {
  cl <- mock_client()
  r <- call_mock("telegram/start", function() cl$telegramstart(),
                 json = list(status = "success", message = "Bot started"))
  expect_request(r$request, "telegram/start", list(apikey = mock_api_key))
  expect_identical(r$result$message, "Bot started")

  r <- call_mock("telegram/stop", function() cl$telegramstop(),
                 json = list(status = "success", message = "Bot stopped"))
  expect_request(r$request, "telegram/stop", list(apikey = mock_api_key))
  expect_identical(r$result$message, "Bot stopped")
})
