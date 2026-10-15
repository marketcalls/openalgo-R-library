# Client construction and the shared request helpers.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("api() sets the REST and WebSocket configuration", {
  cl <- api(api_key = "k")
  expect_true(inherits(cl, "OpenAlgoAPI"))
  expect_identical(cl$api_key, "k")
  expect_identical(cl$base_url, "http://127.0.0.1:5000/api/v1/")
  expect_identical(cl$headers, list("Content-Type" = "application/json"))
  expect_identical(cl$timeout, 120)
  expect_identical(cl$ws_url, "ws://127.0.0.1:8765")
  expect_identical(cl$ws_host, "127.0.0.1")
  expect_identical(cl$verbose, 0L)
  expect_true(cl$auto_reconnect)

  cl <- api(api_key = "k", host = "https://algo.example.com:5000/x", version = "v2",
            timeout = 5, ws_port = 9000, verbose = TRUE, auto_reconnect = FALSE)
  expect_identical(cl$base_url, "https://algo.example.com:5000/x/api/v2/")
  expect_identical(cl$timeout, 5)
  expect_identical(cl$verbose, 1L)
  expect_false(cl$auto_reconnect)
  # An https host maps to
  # wss://<host[:port]>/ws and ws_port is unused.
  expect_identical(cl$ws_url, "wss://algo.example.com:5000/ws")
  expect_identical(cl$ws_host, "algo.example.com")

  # Any other host: ws://<hostname>:<ws_port>.
  cl <- api(api_key = "k", host = "http://algo.example.com:5000/x", ws_port = 9000)
  expect_identical(cl$ws_url, "ws://algo.example.com:9000")
  expect_identical(cl$ws_host, "algo.example.com")

  # A custom ws_url wins; a trailing slash on host is kept.
  cl <- api(api_key = "k", host = "http://h:5000/", ws_url = "wss://feed.example.com/ws")
  expect_identical(cl$ws_url, "wss://feed.example.com/ws")
  expect_identical(cl$base_url, "http://h:5000//api/v1/")
})

test_that("printing the client does not reveal the API key", {
  cl <- api(api_key = "super_secret_key_value")
  out <- capture.output(print(cl))
  expect_false(any(grepl("super_secret_key_value", out, fixed = TRUE)))
  expect_true(any(grepl("http://127.0.0.1:5000/api/v1/", out, fixed = TRUE)))
})

test_that("the API version is part of the request path", {
  mock_reset()
  cl <- api(api_key = mock_api_key, host = mock_url(), version = "v2")
  cl$funds()
  req <- last_request()
  expect_identical(req$path, "/api/v2/funds")
  expect_identical(req$json, list(apikey = mock_api_key))
})

test_that("make_request response handling covers every path", {
  check_make_request_paths("funds", function(cl) cl$funds())

  cl <- mock_client()
  # An empty JSON object is a dict with no status, so it is returned as is.
  r <- call_mock("funds", function() cl$funds(), json = structure(list(), names = character(0)))
  expect_identical(r$result, structure(list(), names = character(0)))

  # A status "error" keeps a JSON null message (dict.get returns None).
  mock_reset()
  mock_respond(api_path("funds"), body = "{\"status\":\"error\",\"message\":null}")
  expect_identical(cl$funds(), list(status = "error", message = NULL, code = 200L,
                                    error_type = "api_error"))

  # Other non-object JSON values report their JSON type name.
  for (case in list(c("\"text\"", "str"), c("5", "int"), c("true", "bool"),
                    c("null", "NoneType"))) {
    mock_reset()
    mock_respond(api_path("funds"), body = case[1])
    expect_identical(cl$funds()$message, sprintf("'%s' object has no attribute 'get'", case[2]))
  }

  # An empty 200 body is invalid JSON.
  mock_reset()
  mock_respond(api_path("funds"), body = "")
  expect_identical(cl$funds(), list(status = "error", message = "Invalid JSON response from server",
                                    raw_response = "", error_type = "json_error"))
})

test_that("BaseAPI._post response handling covers every path", {
  check_post_paths("gttorderbook", function(cl) cl$gttorderbook())
})

test_that("transport failures map to timeout_error and connection_error", {
  # A timeout and a refused connection take a few seconds.
  skip_on_cran()
  # make_request (orders, data, account, options, notifications, utilities).
  check_client_transport_errors("funds", function(cl) cl$funds())
  check_client_transport_errors("placeorder", function(cl) {
    cl$placeorder(symbol = "SBIN", action = "BUY", exchange = "NSE")
  })
  # BaseAPI._post (GTT and strategy module).
  check_client_transport_errors("gttorderbook", function(cl) cl$gttorderbook())
  check_client_transport_errors("strategy/list", function(cl) cl$strategylist())
  # The GET used by instruments().
  check_client_transport_errors("instruments", function(cl) cl$instruments(exchange = "NSE"))
})

test_that("the client reuses its connection and survives close()", {
  cl <- mock_client()
  mock_reset()
  for (i in 1:3) expect_identical(cl$funds(), list(status = "success"))
  cl$close()
  expect_identical(cl$funds(), list(status = "success"))
  cl$close()
  expect_identical(cl$gttorderbook(), list(status = "success"))
  reqs <- mock_requests()
  expect_length(reqs, 5L)
  expect_true(all(vapply(reqs, function(r) r$content_type, "") == "application/json"))
})

test_that("payload values serialize like json.dumps and str()", {
  cl <- mock_client()
  r <- call_mock("funds", function() {
    cl$funds(a = 0.1 + 0.2, b = 1 / 3, c = 100000, d = 1e-05, e = 750.5, f = -2.25, g = NULL,
             h = c("x", "y"), i = list(1), j = NA)
  })
  expect_identical(r$request$body, paste0(
    "{\"apikey\":\"", mock_api_key, "\",\"a\":0.30000000000000004,",
    "\"b\":0.3333333333333333,\"c\":100000,\"d\":1e-05,\"e\":750.5,\"f\":-2.25,",
    "\"h\":[\"x\",\"y\"],\"i\":[1],\"j\":null}"))

  # The order surface uses str(): the shortest repr that reads back exactly.
  r <- call_mock("placeorder", function() {
    cl$placeorder(symbol = "S", action = "BUY", exchange = "NSE", quantity = 123456789,
                  a = 0.1 + 0.2, b = 1 / 3, c = 1e-05, d = 1e16 + 0.5, e = 1234.5678,
                  f = -0.5, g = 2.5e-07, h = 812.35 * 0.99, i = 1e15 + 0.5)
  })
  j <- r$request$json
  expect_identical(j$quantity, "123456789")
  expect_identical(unlist(j[c("a", "b", "c", "d", "e", "f", "g", "h", "i")], use.names = FALSE),
                   c("0.30000000000000004", "0.3333333333333333", "1e-05", "1e+16", "1234.5678",
                     "-0.5", "2.5e-07", "804.2265", "1000000000000000.5"))
})
