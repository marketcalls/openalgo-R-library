# Account methods. Extra keyword arguments are
# sent as given; margin() validates and stringifies its positions.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("funds, orderbook, tradebook, positionbook and holdings send the API key", {
  cl <- mock_client()
  for (ep in c("funds", "orderbook", "tradebook", "positionbook", "holdings")) {
    r <- call_mock(ep, function() cl[[ep]](), json = list(status = "success",
                                                          data = list(availablecash = "100.00")))
    expect_identical(r$result, list(status = "success", data = list(availablecash = "100.00")))
    expect_request(r$request, ep, list(apikey = mock_api_key))
    r <- call_mock(ep, function() cl[[ep]](flag = 1, none = NULL))
    expect_request(r$request, ep, list(apikey = mock_api_key, flag = 1))
    expect_error(cl[[ep]]("x"), "must be named")
  }
})

test_that("analyzerstatus and analyzertoggle use the analyzer routes", {
  cl <- mock_client()
  r <- call_mock("analyzer", function() cl$analyzerstatus(),
                 json = list(status = "success", data = list(analyze_mode = TRUE, mode = "analyze",
                                                             total_logs = 2L)))
  expect_request(r$request, "analyzer", list(apikey = mock_api_key))
  expect_identical(r$result$data$analyze_mode, TRUE)

  r <- call_mock("analyzer/toggle", function() cl$analyzertoggle(TRUE))
  expect_request(r$request, "analyzer/toggle", list(apikey = mock_api_key, mode = TRUE))
  expect_match(r$request$body, "\"mode\":true", fixed = TRUE)
  r <- call_mock("analyzer/toggle", function() cl$analyzertoggle(mode = FALSE))
  expect_request(r$request, "analyzer/toggle", list(apikey = mock_api_key, mode = FALSE))
  expect_error(cl$analyzertoggle(), "mode")
})

test_that("margin stringifies quantity, price and trigger_price and fills defaults", {
  cl <- mock_client()
  r <- call_mock("margin", function() {
    cl$margin(positions = list(
      list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS",
           pricetype = "LIMIT", quantity = 10, price = 750.5),
      list(symbol = "NIFTY30DEC2526000CE", exchange = "NFO", action = "SELL", product = "NRML",
           pricetype = "SL", quantity = "75", price = 150, trigger_price = 149.5, lots = 1)
    ))
  }, json = list(status = "success", data = list(total_margin_required = 328482.5)))
  expect_identical(r$result$data$total_margin_required, 328482.5)
  expect_request(r$request, "margin", list(apikey = mock_api_key, positions = list(
    list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS",
         pricetype = "LIMIT", quantity = "10", price = "750.5", trigger_price = "0"),
    list(symbol = "NIFTY30DEC2526000CE", exchange = "NFO", action = "SELL", product = "NRML",
         pricetype = "SL", quantity = "75", price = "150", trigger_price = "149.5", lots = 1))))
})

test_that("margin keeps a single position in an array and an explicit null price", {
  cl <- mock_client()
  r <- call_mock("margin", function() {
    cl$margin(positions = list(list(symbol = "SBIN", exchange = "NSE", action = "BUY",
                                    product = "MIS", pricetype = "MARKET", quantity = 1,
                                    price = NULL)), note = "x")
  })
  expect_match(r$request$body, "\"positions\":[{", fixed = TRUE)
  expect_request(r$request, "margin", list(apikey = mock_api_key, positions = list(
    list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS",
         pricetype = "MARKET", quantity = "1", price = NULL, trigger_price = "0")),
    note = "x"))
})

test_that("margin validation errors are returned before any request", {
  cl <- mock_client()
  mock_reset()
  v <- function(message) list(status = "error", message = message, error_type = "validation_error")
  expect_identical(cl$margin(positions = list(symbol = "SBIN")), v("Positions must be an array"))
  expect_identical(cl$margin(positions = "SBIN"), v("Positions must be an array"))
  expect_identical(cl$margin(positions = list()), v("Positions array cannot be empty"))
  many <- rep(list(list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS",
                        pricetype = "MARKET", quantity = 1)), 51)
  expect_identical(cl$margin(positions = many), v("Maximum 50 positions allowed"))
  expect_length(mock_requests(), 0L)
  expect_error(cl$margin(), "positions")
})

test_that("account methods follow the make_request response paths", {
  check_make_request_paths("funds", function(cl) cl$funds())
})
