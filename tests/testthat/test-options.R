# Options methods. optionsorder and
# optionsymbol stringify extra keyword arguments, the others send them as
# given; strike_int (and optionsymbol's strategy) is deprecated.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("optiongreeks sends optional parameters only when given", {
  cl <- mock_client()
  r <- call_mock("optiongreeks", function() {
    cl$optiongreeks(symbol = "NIFTY25NOV2526000CE", exchange = "NFO")
  })
  expect_request(r$request, "optiongreeks", list(apikey = mock_api_key,
                                                 symbol = "NIFTY25NOV2526000CE", exchange = "NFO"))
  r <- call_mock("optiongreeks", function() {
    cl$optiongreeks(symbol = "NIFTY25NOV2526000CE", exchange = "NFO", interest_rate = 6.5,
                    forward_price = 26050.25, underlying_symbol = "NIFTY",
                    underlying_exchange = "NSE_INDEX", expiry_time = "15:30", extra = 1)
  })
  expect_request(r$request, "optiongreeks", list(
    apikey = mock_api_key, symbol = "NIFTY25NOV2526000CE", exchange = "NFO",
    interest_rate = 6.5, forward_price = 26050.25, underlying_symbol = "NIFTY",
    underlying_exchange = "NSE_INDEX", expiry_time = "15:30", extra = 1))
})

test_that("optionsorder stringifies quantity and keyword arguments", {
  cl <- mock_client()
  r <- call_mock("optionsorder", function() {
    cl$optionsorder(underlying = "NIFTY", exchange = "NSE_INDEX", offset = "ATM",
                    option_type = "CE", action = "BUY", quantity = 75, expiry_date = "28NOV25",
                    price = 100.5, splitsize = 0)
  })
  expect_request(r$request, "optionsorder", list(
    apikey = mock_api_key, strategy = "Python", underlying = "NIFTY", exchange = "NSE_INDEX",
    offset = "ATM", option_type = "CE", action = "BUY", quantity = "75", pricetype = "MARKET",
    product = "MIS", expiry_date = "28NOV25", price = "100.5", splitsize = "0"))
})

test_that("optionsorder strike_int is deprecated and sent as a string", {
  cl <- mock_client()
  mock_reset()
  expect_warning(
    cl$optionsorder(underlying = "NIFTY", exchange = "NSE_INDEX", strike_int = 50,
                    offset = "ITM2", option_type = "PE", action = "SELL", quantity = 75),
    "The 'strike_int' parameter is deprecated and will be removed in future versions.",
    fixed = TRUE)
  expect_request(last_request(), "optionsorder", list(
    apikey = mock_api_key, strategy = "Python", underlying = "NIFTY", exchange = "NSE_INDEX",
    offset = "ITM2", option_type = "PE", action = "SELL", quantity = "75", pricetype = "MARKET",
    product = "MIS", strike_int = "50"))
  expect_error(cl$optionsorder(underlying = "NIFTY", exchange = "NSE_INDEX", offset = "ATM",
                               option_type = "CE", action = "BUY"), "quantity")
})

test_that("optionsymbol warns for strategy and strike_int", {
  cl <- mock_client()
  r <- call_mock("optionsymbol", function() {
    cl$optionsymbol(underlying = "NIFTY", exchange = "NSE_INDEX", offset = "ATM",
                    option_type = "CE", expiry_date = "28NOV25")
  })
  expect_request(r$request, "optionsymbol", list(
    apikey = mock_api_key, underlying = "NIFTY", exchange = "NSE_INDEX", offset = "ATM",
    option_type = "CE", expiry_date = "28NOV25"))

  mock_reset()
  w <- character(0)
  withCallingHandlers(
    cl$optionsymbol(strategy = "S", underlying = "NIFTY", exchange = "NSE_INDEX",
                    strike_int = 100, offset = "OTM1", option_type = "PE", lots = 2),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    })
  expect_identical(w, c(
    "The 'strategy' parameter is deprecated and will be removed in future versions.",
    "The 'strike_int' parameter is deprecated and will be removed in future versions."))
  expect_request(last_request(), "optionsymbol", list(
    apikey = mock_api_key, underlying = "NIFTY", exchange = "NSE_INDEX", offset = "OTM1",
    option_type = "PE", strategy = "S", strike_int = "100", lots = "2"))
})

test_that("optionsmultiorder converts leg fields to int and float", {
  cl <- mock_client()
  r <- call_mock("optionsmultiorder", function() {
    cl$optionsmultiorder(strategy = "Iron", underlying = "NIFTY", exchange = "NSE_INDEX",
                         expiry_date = "28NOV25", legs = list(
                           list(offset = "OTM2", option_type = "CE", action = "BUY",
                                quantity = "75", expiry_date = "25NOV25", pricetype = "LIMIT",
                                product = "NRML", price = "10.5", trigger_price = 10,
                                disclosed_quantity = 7.9, ignored = "x")),
                         tag = 5)
  })
  expect_request(r$request, "optionsmultiorder", list(
    apikey = mock_api_key, strategy = "Iron", underlying = "NIFTY", exchange = "NSE_INDEX",
    legs = list(list(offset = "OTM2", option_type = "CE", action = "BUY", quantity = 75,
                     expiry_date = "25NOV25", pricetype = "LIMIT", product = "NRML",
                     price = 10.5, trigger_price = 10, disclosed_quantity = 7)),
    expiry_date = "28NOV25", tag = 5))
  expect_match(r$request$body, "\"legs\":[{", fixed = TRUE)
  expect_identical(r$request$json$legs[[1]]$quantity, 75L)
})

test_that("optionsmultiorder strike_int is deprecated and sent as an integer", {
  cl <- mock_client()
  mock_reset()
  expect_warning(
    cl$optionsmultiorder(strategy = "S", underlying = "NIFTY", exchange = "NSE_INDEX",
                         strike_int = "50", legs = list(
                           list(offset = "ATM", option_type = "CE", action = "SELL", quantity = 75),
                           list(offset = "ATM", option_type = "PE", action = "SELL", quantity = 75))),
    "strike_int", fixed = TRUE)
  req <- last_request()
  expect_identical(req$json$strike_int, 50L)
  expect_length(req$json$legs, 2L)
  expect_identical(names(req$json), c("apikey", "strategy", "underlying", "exchange", "legs",
                                      "strike_int"))
  # A leg without a required key fails before sending.
  mock_reset()
  expect_error(cl$optionsmultiorder(strategy = "S", underlying = "NIFTY", exchange = "NSE_INDEX",
                                    legs = list(list(offset = "ATM", option_type = "CE",
                                                     quantity = 75))), "action")
  expect_length(mock_requests(), 0L)
})

test_that("optionchain sends strike_count as an integer", {
  cl <- mock_client()
  r <- call_mock("optionchain", function() cl$optionchain(underlying = "NIFTY",
                                                         exchange = "NSE_INDEX"))
  expect_request(r$request, "optionchain", list(apikey = mock_api_key, underlying = "NIFTY",
                                                exchange = "NSE_INDEX"))
  r <- call_mock("optionchain", function() {
    cl$optionchain(underlying = "NIFTY", exchange = "NSE_INDEX", expiry_date = "28NOV25",
                   strike_count = "10")
  })
  expect_request(r$request, "optionchain", list(apikey = mock_api_key, underlying = "NIFTY",
                                                exchange = "NSE_INDEX", expiry_date = "28NOV25",
                                                strike_count = 10))
  expect_identical(r$request$json$strike_count, 10L)
})

test_that("options methods follow the make_request response paths", {
  check_make_request_paths("optionchain", function(cl) {
    cl$optionchain(underlying = "NIFTY", exchange = "NSE_INDEX")
  })
})
