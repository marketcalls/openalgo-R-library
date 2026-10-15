# Strategy module methods (Python: openalgo/strategy_api.py). Every route
# is a POST to /api/v1/strategy/<route>, ids are sent as integers, NULL
# filters are omitted and responses go through BaseAPI._post.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("strategylist sends only the filters that are set", {
  cl <- mock_client()
  r <- call_mock("strategy/list", function() cl$strategylist(),
                 json = list(status = "success", data = list()))
  expect_identical(r$result, list(status = "success", data = list()))
  expect_request(r$request, "strategy/list", list(apikey = mock_api_key))
  r <- call_mock("strategy/list", function() cl$strategylist(status = "running", q = "iron",
                                                            page = 2))
  expect_request(r$request, "strategy/list", list(apikey = mock_api_key, status = "running",
                                                  q = "iron", page = 2))
  expect_error(cl$strategylist("running"), "must be named")
})

test_that("strategystatus, stop and close_all send strategy_id as an integer", {
  cl <- mock_client()
  routes <- list(strategystatus = "status", strategystop = "stop", strategycloseall = "close_all")
  for (fn in names(routes)) {
    ep <- paste0("strategy/", routes[[fn]])
    r <- call_mock(ep, function() cl[[fn]](strategy_id = "42"))
    expect_request(r$request, ep, list(apikey = mock_api_key, strategy_id = 42))
    expect_identical(r$request$json$strategy_id, 42L)
    expect_match(r$request$body, "\"strategy_id\":42", fixed = TRUE)
  }
  mock_reset()
  expect_error(cl$strategystatus(strategy_id = "abc"), "invalid literal")
  expect_error(cl$strategystop(), "strategy_id")
  expect_length(mock_requests(), 0L)
})

test_that("strategystart passes mode through unchanged and requires it", {
  cl <- mock_client()
  r <- call_mock("strategy/start", function() cl$strategystart(strategy_id = 7, mode = "sandbox"),
                 json = list(status = "success", run_id = 3L, mode = "sandbox", legs = list()))
  expect_identical(r$result$run_id, 3L)
  expect_request(r$request, "strategy/start", list(apikey = mock_api_key, strategy_id = 7,
                                                   mode = "sandbox"))
  r <- call_mock("strategy/start", function() cl$strategystart(strategy_id = 7, mode = "LIVE"))
  expect_identical(r$request$json$mode, "LIVE")
  mock_reset()
  expect_error(cl$strategystart(strategy_id = 7), "mode")
  expect_length(mock_requests(), 0L)
})

test_that("strategycloseleg sends both ids as integers", {
  cl <- mock_client()
  r <- call_mock("strategy/close_leg", function() cl$strategycloseleg(strategy_id = 7, leg_id = 2.9))
  expect_request(r$request, "strategy/close_leg", list(apikey = mock_api_key, strategy_id = 7,
                                                       leg_id = 2))
  expect_identical(r$request$json$leg_id, 2L)
})

test_that("strategyruns, strategyorders and strategyevents filters", {
  cl <- mock_client()
  r <- call_mock("strategy/runs", function() cl$strategyruns(strategy_id = 7))
  expect_request(r$request, "strategy/runs", list(apikey = mock_api_key, strategy_id = 7))
  r <- call_mock("strategy/runs", function() cl$strategyruns(strategy_id = 7, limit = 5))
  expect_request(r$request, "strategy/runs", list(apikey = mock_api_key, strategy_id = 7,
                                                  limit = 5))
  r <- call_mock("strategy/orders", function() cl$strategyorders(strategy_id = 7, run_id = 9))
  expect_request(r$request, "strategy/orders", list(apikey = mock_api_key, strategy_id = 7,
                                                    run_id = 9))
  r <- call_mock("strategy/events", function() cl$strategyevents(strategy_id = 7))
  expect_request(r$request, "strategy/events", list(apikey = mock_api_key, strategy_id = 7))
  r <- call_mock("strategy/events", function() {
    cl$strategyevents(strategy_id = 7, run_id = 9, kind = "run_stop_failed",
                      severity = "critical", limit = 10, extra = TRUE)
  })
  expect_request(r$request, "strategy/events", list(
    apikey = mock_api_key, strategy_id = 7, run_id = 9, kind = "run_stop_failed",
    severity = "critical", limit = 10, extra = TRUE))
})

test_that("a 409 stop keeps the server body and adds the code", {
  cl <- mock_client()
  body <- list(status = "error", message = "Stop pending", stop_pending = TRUE,
               exits = list(list(leg_id = 1L, ok = FALSE)))
  r <- call_mock("strategy/stop", function() cl$strategystop(strategy_id = 7), json = body,
                 status = 409L)
  expect_identical(r$result, c(body, list(code = 409L)))
})

test_that("strategy methods follow the BaseAPI._post response paths", {
  check_post_paths("strategy/list", function(cl) cl$strategylist())
})
