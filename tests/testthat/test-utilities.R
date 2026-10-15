# Market calendar utilities (Python: openalgo/utilities.py). No extra
# keyword arguments are accepted.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("holidays sends the year only when given", {
  cl <- mock_client()
  r <- call_mock("market/holidays", function() cl$holidays(),
                 json = list(status = "success", year = 2025L, data = list()))
  expect_identical(r$result, list(status = "success", year = 2025L, data = list()))
  expect_request(r$request, "market/holidays", list(apikey = mock_api_key))
  r <- call_mock("market/holidays", function() cl$holidays(2025))
  expect_request(r$request, "market/holidays", list(apikey = mock_api_key, year = 2025))
  expect_match(r$request$body, "\"year\":2025}", fixed = TRUE)
  expect_error(cl$holidays(2025, 1), "unexpected argument")
  expect_error(cl$holidays(year = 2025, exchange = "NSE"), "unexpected argument")
})

test_that("timings defaults to today's date", {
  cl <- mock_client()
  before <- format(Sys.Date(), "%Y-%m-%d")
  r <- call_mock("market/timings", function() cl$timings())
  after <- format(Sys.Date(), "%Y-%m-%d")
  expect_identical(r$request$method, "POST")
  expect_identical(r$request$path, api_path("market/timings"))
  expect_identical(names(r$request$json), c("apikey", "date"))
  expect_true(r$request$json$date %in% c(before, after))
  r <- call_mock("market/timings", function() cl$timings(date = "2025-01-01"))
  expect_request(r$request, "market/timings", list(apikey = mock_api_key, date = "2025-01-01"))
  expect_error(cl$timings("2025-01-01", "x"), "unexpected argument")
})

test_that("utilities follow the make_request response paths", {
  check_make_request_paths("market/holidays", function(cl) cl$holidays())
})
