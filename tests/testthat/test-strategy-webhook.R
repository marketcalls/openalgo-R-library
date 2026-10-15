# Strategy webhook sender (Strategy()).
# Posts to <host>/strategy/webhook/<token> with no API key.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

token <- "oaws_test_token_123"
hook_path <- paste0("/strategy/webhook/", token)

hook_call <- function(fn, json = list(status = "success", result = "accepted"), status = 200L,
                      body = NULL, content_type = "application/json") {
  mock_reset()
  mock_respond(hook_path, json = json, status = status, body = body, content_type = content_type)
  result <- fn()
  list(result = result, request = last_request())
}

test_that("the token is required and webhook_token wins over webhook_id", {
  msg <- "A webhook token is required"
  expect_error(Strategy("http://127.0.0.1:5000"), msg, fixed = TRUE)
  expect_error(Strategy("http://127.0.0.1:5000", ""), msg, fixed = TRUE)
  expect_error(Strategy("http://127.0.0.1:5000", "legacy", webhook_token = ""), msg, fixed = TRUE)
  expect_error(Strategy("http://127.0.0.1:5000", "legacy", "positional"), "unexpected argument")

  s <- Strategy("http://127.0.0.1:5000/", "legacy")
  expect_identical(s$webhook_url, "http://127.0.0.1:5000/strategy/webhook/legacy")
  s <- Strategy("http://127.0.0.1:5000//", webhook_id = "legacy", webhook_token = "accurate")
  expect_identical(s$webhook_url, "http://127.0.0.1:5000/strategy/webhook/accurate")
  expect_error(s$webhook_url <- "x", "read-only")
  expect_identical(s$timeout, 30)
  expect_true(inherits(s, "OpenAlgoStrategy"))
})

test_that("printing never reveals the token", {
  s <- Strategy("http://127.0.0.1:5000/", webhook_token = "oaws_secret_value")
  out <- capture.output(print(s))
  expect_identical(out, "Strategy(host_url='http://127.0.0.1:5000', webhook_token=<redacted>)")
  expect_false(any(grepl("oaws_secret_value", out, fixed = TRUE)))
})

test_that("start and stop payloads", {
  s <- Strategy(mock_url(), webhook_token = token)
  r <- hook_call(function() s$start("sandbox"),
                 json = list(status = "success", result = "accepted", strategy_id = 4L,
                             run_id = 11L))
  expect_identical(r$result, list(status = "success", result = "accepted", strategy_id = 4L,
                                  run_id = 11L))
  expect_identical(r$request$method, "POST")
  expect_identical(r$request$path, hook_path)
  expect_identical(r$request$content_type, "application/json")
  expect_identical(r$request$json, list(action = "start", mode = "sandbox"))
  expect_false(grepl("apikey", r$request$body, fixed = TRUE))

  r <- hook_call(function() s$stop())
  expect_identical(r$request$json, list(action = "stop"))
  expect_error(s$start(), "mode")
})

test_that("signal payloads name the leg by integer id or by symbol", {
  s <- Strategy(mock_url(), webhook_token = token)
  r <- hook_call(function() s$signal("long_entry", leg_id = "3"))
  expect_identical(r$request$json, list(action = "long_entry", leg_id = 3L))
  expect_match(r$request$body, "\"leg_id\":3}", fixed = TRUE)

  r <- hook_call(function() s$long_exit(symbol = "NIFTY30DEC25FUT", exchange = "NFO"))
  expect_identical(r$request$json, list(action = "long_exit", symbol = "NIFTY30DEC25FUT",
                                        exchange = "NFO"))
  r <- hook_call(function() s$short_entry(leg_id = 1, symbol = "X", exchange = "NFO"))
  expect_identical(r$request$json, list(action = "short_entry", leg_id = 1L, symbol = "X",
                                        exchange = "NFO"))
  r <- hook_call(function() s$short_exit())
  expect_identical(r$request$json, list(action = "short_exit"))
  r <- hook_call(function() s$long_entry(leg_id = 2))
  expect_identical(r$request$json, list(action = "long_entry", leg_id = 2L))

  expect_error(s$long_entry(2), "unexpected argument")
  expect_error(s$signal("long_entry", 2), "unexpected argument")
})

test_that("send posts a raw payload", {
  s <- Strategy(mock_url(), webhook_token = token)
  r <- hook_call(function() s$send(list(action = "custom", n = 1.5, flags = list("a"))))
  expect_identical(r$request$json, list(action = "custom", n = 1.5, flags = list("a")))
})

test_that("strategyorder was removed and always raises", {
  s <- Strategy(mock_url(), webhook_token = token)
  mock_reset()
  expect_error(s$strategyorder("SBIN", "BUY", 1),
               "Strategy.strategyorder() was removed", fixed = TRUE)
  expect_length(mock_requests(), 0L)
})

test_that("webhook response handling", {
  s <- Strategy(mock_url(), webhook_token = token)

  # A 200 rejection is returned as is: the result label is the contract.
  r <- hook_call(function() s$start("sandbox"),
                 json = list(status = "success", result = "rejected_dedupe"))
  expect_identical(r$result, list(status = "success", result = "rejected_dedupe"))

  # 409 body passthrough with the code attached.
  r <- hook_call(function() s$start("sandbox"), status = 409L,
                 json = list(status = "error", result = "rejected_cooling_off",
                             message = "Cooling off"))
  expect_identical(r$result, list(status = "error", result = "rejected_cooling_off",
                                  message = "Cooling off", code = 409L))

  # A non-200 body without status gets status "error" after the existing keys.
  r <- hook_call(function() s$stop(), status = 403L, json = list(result = "rejected_live_disabled"))
  expect_identical(r$result, list(result = "rejected_live_disabled", status = "error",
                                  code = 403L))

  # A non-JSON answer is an http_error even on 200.
  r <- hook_call(function() s$stop(), body = "<html>ok</html>", content_type = "text/html")
  expect_identical(r$result, list(status = "error", message = "HTTP 200: <html>ok</html>",
                                  raw_response = "<html>ok</html>", code = 200L,
                                  error_type = "http_error"))
  r <- hook_call(function() s$stop(), status = 404L, body = "Not Found",
                 content_type = "text/plain")
  expect_identical(r$result, list(status = "error", message = "HTTP 404: Not Found",
                                  raw_response = "Not Found", code = 404L,
                                  error_type = "http_error"))

  # JSON that is not an object.
  r <- hook_call(function() s$stop(), body = "[\"a\"]")
  expect_identical(r$result, list(status = "error", message = "Unexpected JSON response from server",
                                  raw_response = list("a"), code = 200L, error_type = "json_error"))
})

test_that("webhook transport errors", {
  # A timeout and a refused connection take a few seconds.
  skip_on_cran()
  check_transport_errors(hook_path, function(host, timeout) {
    Strategy(host, webhook_token = token, timeout = timeout)
  }, function(s) s$stop())
})

test_that("close() releases the webhook connection", {
  # close() releases the connection; a later call opens a new one.
  s <- Strategy(mock_url(), webhook_token = token)
  s$close()
  r <- hook_call(function() s$stop())
  expect_identical(r$result, list(status = "success", result = "accepted"))
})
