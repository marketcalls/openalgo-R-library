# GTT methods. Numeric fields go out as JSON
# numbers, SINGLE sends stoploss and target as JSON null, validation errors
# are returned (not raised) before any request, and responses go through
# BaseAPI._post.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

single_body <- function(...) {
  body <- list(
    apikey = mock_api_key, strategy = "Python", trigger_type = "SINGLE", exchange = "NSE",
    symbol = "SBIN", action = "BUY", product = "CNC", quantity = 1, pricetype = "LIMIT",
    price = 0, triggerprice_sl = 0, triggerprice_tg = 800, stoploss = NULL, target = NULL)
  extra <- list(...)
  for (k in names(extra)) body[k] <- list(extra[[k]])
  body
}

test_that("placegttorder SINGLE sends numbers and JSON null legs", {
  cl <- mock_client()
  r <- call_mock("placegttorder", function() {
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", triggerprice_tg = 800)
  }, json = list(status = "success", trigger_id = "GTT-1"))
  expect_identical(r$result, list(status = "success", trigger_id = "GTT-1"))
  expect_request(r$request, "placegttorder", single_body())
  expect_match(r$request$body, "\"stoploss\":null,\"target\":null", fixed = TRUE)
  expect_true(is.numeric(r$request$json$quantity))
  expect_true(is.numeric(r$request$json$price))
})

test_that("placegttorder upper-cases action and trigger type and coerces numbers", {
  cl <- mock_client()
  r <- call_mock("placegttorder", function() {
    cl$placegttorder(strategy = "G", symbol = "SBIN", action = "sell", exchange = "NSE",
                     trigger_type = "single", product = "NRML", quantity = 100000,
                     price = "750.5", triggerprice_sl = "745.25", triggerprice_tg = 0)
  })
  expect_request(r$request, "placegttorder", list(
    apikey = mock_api_key, strategy = "G", trigger_type = "SINGLE", exchange = "NSE",
    symbol = "SBIN", action = "SELL", product = "NRML", quantity = 100000, pricetype = "LIMIT",
    price = 750.5, triggerprice_sl = 745.25, triggerprice_tg = 0, stoploss = NULL,
    target = NULL))
  expect_match(r$request$body, "\"quantity\":100000,", fixed = TRUE)
  expect_match(r$request$body, "\"price\":750.5,", fixed = TRUE)
})

test_that("GTT quantity is an integer unless fractional", {
  cl <- mock_client()
  r <- call_mock("placegttorder", function() {
    cl$placegttorder(symbol = "BTC", action = "BUY", exchange = "CRYPTO", quantity = 1.5,
                     triggerprice_sl = 10)
  })
  expect_identical(r$request$json$quantity, 1.5)
  r <- call_mock("placegttorder", function() {
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", quantity = "10",
                     triggerprice_sl = 10)
  })
  expect_identical(r$request$json$quantity, 10L)
  expect_match(r$request$body, "\"quantity\":10,", fixed = TRUE)
})

test_that("placegttorder OCO sends both legs", {
  cl <- mock_client()
  r <- call_mock("placegttorder", function() {
    cl$placegttorder(symbol = "SBIN", action = "SELL", exchange = "NSE", trigger_type = "OCO",
                     quantity = 5, triggerprice_sl = 700, stoploss = 699.5,
                     triggerprice_tg = 900, target = "900.5", tag = 3, note = NULL)
  })
  expect_request(r$request, "placegttorder", list(
    apikey = mock_api_key, strategy = "Python", trigger_type = "OCO", exchange = "NSE",
    symbol = "SBIN", action = "SELL", product = "CNC", quantity = 5, pricetype = "LIMIT",
    price = 0, triggerprice_sl = 700, triggerprice_tg = 900, stoploss = 699.5,
    target = 900.5, tag = 3))
  # Keyword arguments pass through unchanged, not as strings.
  expect_true(is.numeric(r$request$json$tag))
})

test_that("GTT validation errors are returned before any request", {
  cl <- mock_client()
  mock_reset()
  v <- function(message) list(status = "error", message = message, error_type = "validation_error")
  expect_identical(
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", trigger_type = "GTC",
                     triggerprice_tg = 800),
    v("trigger_type must be 'SINGLE' or 'OCO'."))
  expect_identical(
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", trigger_type = "OCO"),
    v("Required for OCO: triggerprice_sl, stoploss, triggerprice_tg, target."))
  expect_identical(
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", trigger_type = "OCO",
                     triggerprice_sl = 700, triggerprice_tg = 900, stoploss = ""),
    v("Required for OCO: stoploss, target."))
  expect_identical(
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", trigger_type = "OCO",
                     triggerprice_sl = 900, triggerprice_tg = 900, stoploss = 1, target = 2),
    v("Stoploss trigger must be less than target trigger (triggerprice_sl < triggerprice_tg)."))
  expect_identical(
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE"),
    v("SINGLE GTT requires a positive triggerprice_sl or triggerprice_tg."))
  expect_identical(
    cl$modifygttorder(trigger_id = "1", symbol = "SBIN", action = "BUY", exchange = "NSE",
                      triggerprice_sl = 700, triggerprice_tg = 900),
    v("SINGLE GTT takes exactly one of triggerprice_sl or triggerprice_tg; set the other to 0."))
  expect_length(mock_requests(), 0L)
})

test_that("GTT methods reject unnamed arguments and missing required ones", {
  cl <- mock_client()
  mock_reset()
  expect_error(cl$placegttorder("SBIN", symbol = "SBIN", action = "BUY", exchange = "NSE",
                                triggerprice_tg = 1), "must be named")
  expect_error(cl$placegttorder(action = "BUY", exchange = "NSE", triggerprice_tg = 1), "symbol")
  expect_error(cl$modifygttorder(symbol = "SBIN", action = "BUY", exchange = "NSE",
                                 triggerprice_tg = 1), "trigger_id")
  expect_error(cl$gttorderbook("all"), "must be named")
  expect_length(mock_requests(), 0L)
})

test_that("modifygttorder appends trigger_id as a string", {
  cl <- mock_client()
  r <- call_mock("modifygttorder", function() {
    cl$modifygttorder(trigger_id = 12345, symbol = "SBIN", action = "BUY", exchange = "NSE",
                      triggerprice_tg = 800)
  })
  expect_request(r$request, "modifygttorder", single_body(trigger_id = "12345"))
  expect_identical(utils::tail(names(r$request$json), 1), "trigger_id")
})

test_that("cancelgttorder and gttorderbook bodies", {
  cl <- mock_client()
  r <- call_mock("cancelgttorder", function() cl$cancelgttorder(trigger_id = 987))
  expect_request(r$request, "cancelgttorder", list(apikey = mock_api_key, strategy = "Python",
                                                   trigger_id = "987"))
  r <- call_mock("gttorderbook", function() cl$gttorderbook())
  expect_request(r$request, "gttorderbook", list(apikey = mock_api_key))
  r <- call_mock("gttorderbook", function() cl$gttorderbook(status = "all", other = NULL))
  expect_request(r$request, "gttorderbook", list(apikey = mock_api_key, status = "all"))
})

test_that("GTT methods follow the BaseAPI._post response paths", {
  check_post_paths("placegttorder", function(cl) {
    cl$placegttorder(symbol = "SBIN", action = "BUY", exchange = "NSE", triggerprice_tg = 800)
  })
  check_post_paths("gttorderbook", function(cl) cl$gttorderbook())
})
