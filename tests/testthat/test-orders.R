# Order methods (Python: openalgo/orders.py). Every numeric field and every
# extra keyword argument is sent as a string (str(value)), None is skipped.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("placeorder sends the defaults", {
  cl <- mock_client()
  r <- call_mock("placeorder", function() {
    cl$placeorder(symbol = "SBIN", action = "BUY", exchange = "NSE")
  }, json = list(status = "success", orderid = "250408000989443"))
  expect_identical(r$result, list(status = "success", orderid = "250408000989443"))
  expect_request(r$request, "placeorder", list(
    apikey = mock_api_key, strategy = "Python", symbol = "SBIN", action = "BUY",
    exchange = "NSE", pricetype = "MARKET", product = "MIS", quantity = "1"))
  expect_identical(r$request$content_type, "application/json")
})

test_that("placeorder stringifies quantity and every keyword argument", {
  cl <- mock_client()
  r <- call_mock("placeorder", function() {
    cl$placeorder(strategy = "Test Strategy", symbol = "RELIANCE", action = "SELL",
                  exchange = "NSE", price_type = "LIMIT", product = "CNC", quantity = 100000,
                  price = 750.5, trigger_price = 0, disclosed_quantity = 10L,
                  target = 0.1 + 0.2, stoploss = 1e-05, trailing_sl = TRUE, flag_off = FALSE,
                  tag = "abc", skipped = NULL)
  })
  expect_request(r$request, "placeorder", list(
    apikey = mock_api_key, strategy = "Test Strategy", symbol = "RELIANCE", action = "SELL",
    exchange = "NSE", pricetype = "LIMIT", product = "CNC", quantity = "100000",
    price = "750.5", trigger_price = "0", disclosed_quantity = "10",
    target = "0.30000000000000004", stoploss = "1e-05", trailing_sl = "True",
    flag_off = "False", tag = "abc"))
  # Never scientific notation for whole numbers.
  expect_match(r$request$body, "\"quantity\":\"100000\"", fixed = TRUE)
})

test_that("a keyword argument overrides a built-in field in place", {
  cl <- mock_client()
  r <- call_mock("placeorder", function() {
    cl$placeorder(symbol = "SBIN", action = "BUY", exchange = "NSE", pricetype = "LIMIT")
  })
  expect_identical(names(r$request$json), c("apikey", "strategy", "symbol", "action",
                                            "exchange", "pricetype", "product", "quantity"))
  expect_identical(r$request$json$pricetype, "LIMIT")
})

test_that("order methods reject unnamed extra arguments and missing required ones", {
  cl <- mock_client()
  mock_reset()
  expect_error(cl$placeorder("SBIN", symbol = "SBIN", action = "BUY", exchange = "NSE"),
               "must be named")
  expect_error(cl$placeorder(action = "BUY", exchange = "NSE"), "symbol")
  expect_error(cl$placesmartorder(symbol = "SBIN", action = "BUY", exchange = "NSE"),
               "position_size")
  expect_error(cl$cancelorder(), "order_id")
  expect_error(cl$closeposition("x"), "must be named")
  expect_length(mock_requests(), 0L)
})

test_that("placesmartorder sends position_size as a string", {
  cl <- mock_client()
  r <- call_mock("placesmartorder", function() {
    cl$placesmartorder(symbol = "TATAMOTORS", action = "SELL", exchange = "NSE",
                       quantity = 1, position_size = 5, price = 512.35)
  })
  expect_request(r$request, "placesmartorder", list(
    apikey = mock_api_key, strategy = "Python", symbol = "TATAMOTORS", action = "SELL",
    exchange = "NSE", pricetype = "MARKET", product = "MIS", quantity = "1",
    position_size = "5", price = "512.35"))
})

test_that("basketorder stringifies numbers and booleans inside each order", {
  cl <- mock_client()
  r <- call_mock("basketorder", function() {
    cl$basketorder(strategy = "Basket", orders = list(
      list(symbol = "BHEL", exchange = "NSE", action = "BUY", quantity = 1,
           pricetype = "LIMIT", product = "MIS", price = 210.75, amo = TRUE),
      list(symbol = "ZOMATO", exchange = "NSE", action = "SELL", quantity = "2",
           pricetype = "MARKET", product = "MIS")
    ), tag = 7)
  }, json = list(status = "success", results = list(list(orderid = "1", status = "success",
                                                         symbol = "BHEL"))))
  expect_identical(r$result$results[[1]]$symbol, "BHEL")
  expect_request(r$request, "basketorder", list(
    apikey = mock_api_key, strategy = "Basket", orders = list(
      list(symbol = "BHEL", exchange = "NSE", action = "BUY", quantity = "1",
           pricetype = "LIMIT", product = "MIS", price = "210.75", amo = "True"),
      list(symbol = "ZOMATO", exchange = "NSE", action = "SELL", quantity = "2",
           pricetype = "MARKET", product = "MIS")),
    tag = "7"))
})

test_that("a basket with one order stays a JSON array", {
  cl <- mock_client()
  r <- call_mock("basketorder", function() {
    cl$basketorder(orders = list(list(symbol = "BHEL", exchange = "NSE", action = "BUY",
                                      quantity = 1)))
  })
  expect_match(r$request$body, "\"orders\":[{", fixed = TRUE)
  expect_identical(r$request$json$strategy, "Python")
  expect_length(r$request$json$orders, 1L)
})

test_that("splitorder keeps the Python key order", {
  cl <- mock_client()
  r <- call_mock("splitorder", function() {
    cl$splitorder(symbol = "YESBANK", exchange = "NSE", action = "SELL", quantity = 105,
                  splitsize = 20, price = 16.5)
  })
  expect_request(r$request, "splitorder", list(
    apikey = mock_api_key, strategy = "Python", symbol = "YESBANK", action = "SELL",
    exchange = "NSE", quantity = "105", splitsize = "20", pricetype = "MARKET",
    product = "MIS", price = "16.5"))
})

test_that("orderstatus, openposition and cancelorder bodies", {
  cl <- mock_client()
  r <- call_mock("orderstatus", function() {
    cl$orderstatus(order_id = "24120900146469", strategy = "Test Strategy")
  })
  expect_request(r$request, "orderstatus", list(
    apikey = mock_api_key, strategy = "Test Strategy", orderid = "24120900146469"))

  r <- call_mock("openposition", function() {
    cl$openposition(symbol = "YESBANK", exchange = "NSE", product = "CNC")
  })
  expect_request(r$request, "openposition", list(
    apikey = mock_api_key, strategy = "Python", symbol = "YESBANK", exchange = "NSE",
    product = "CNC"))

  r <- call_mock("cancelorder", function() cl$cancelorder(order_id = "123", extra = 1))
  expect_request(r$request, "cancelorder", list(
    apikey = mock_api_key, orderid = "123", strategy = "Python", extra = "1"))
})

test_that("modifyorder sends its defaults as strings", {
  cl <- mock_client()
  r <- call_mock("modifyorder", function() {
    cl$modifyorder(order_id = "24120900146469", symbol = "YESBANK", action = "BUY",
                   exchange = "NSE", product = "CNC", quantity = 1, price = 16.5)
  })
  expect_request(r$request, "modifyorder", list(
    apikey = mock_api_key, orderid = "24120900146469", strategy = "Python",
    symbol = "YESBANK", action = "BUY", exchange = "NSE", pricetype = "LIMIT",
    product = "CNC", quantity = "1", price = "16.5", disclosed_quantity = "0",
    trigger_price = "0"))
  expect_error(cl$modifyorder(order_id = "1", symbol = "A", action = "BUY", exchange = "NSE",
                              product = "CNC", quantity = 1), "price")
})

test_that("closeposition and cancelallorder bodies", {
  cl <- mock_client()
  r <- call_mock("closeposition", function() cl$closeposition())
  expect_request(r$request, "closeposition", list(apikey = mock_api_key, strategy = "Python"))
  r <- call_mock("cancelallorder", function() cl$cancelallorder(strategy = "S1", note = NULL))
  expect_request(r$request, "cancelallorder", list(apikey = mock_api_key, strategy = "S1"))
})

test_that("order methods follow the make_request response paths", {
  check_make_request_paths("placeorder", function(cl) {
    cl$placeorder(symbol = "SBIN", action = "BUY", exchange = "NSE")
  })
})
