# Telegram and WhatsApp notifications (Python: openalgo/telegram.py and
# openalgo/whatsapp.py). In the unified Python client both resolve
# _make_request and _handle_response from OrderAPI (first in the MRO), so a
# non-200 answer is "HTTP <code>: <body>" for WhatsApp too.

skip_if_not_installed("webfakes")
skip_if_not_installed("httpuv")

test_that("telegram body and defaults", {
  cl <- mock_client()
  r <- call_mock("telegram/notify", function() cl$telegram(username = "trader", message = "hi"))
  expect_request(r$request, "telegram/notify", list(apikey = mock_api_key, username = "trader",
                                                    message = "hi", priority = 5))
  expect_true(is.numeric(r$request$json$priority))
  r <- call_mock("telegram/notify", function() {
    cl$telegram(username = "trader", message = "hi", priority = 10, silent = TRUE, x = NULL)
  })
  expect_request(r$request, "telegram/notify", list(apikey = mock_api_key, username = "trader",
                                                    message = "hi", priority = 10, silent = TRUE))
  mock_reset()
  expect_error(cl$telegram(message = "hi"), "username")
  expect_error(cl$telegram("trader", username = "u", message = "m"), "must be named")
  expect_length(mock_requests(), 0L)
})

test_that("whatsapp defaults to self", {
  cl <- mock_client()
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("hello"))
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key, self = TRUE,
                                                    message = "hello", wait_for_delivery = TRUE))
  r <- call_mock("whatsapp/notify", function() cl$whatsapp())
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key, self = TRUE,
                                                    wait_for_delivery = TRUE))
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("x", to = "   "))
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key, self = TRUE,
                                                    message = "x", wait_for_delivery = TRUE))
})

test_that("whatsapp recipient selection", {
  cl <- mock_client()
  # username wins over to.
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", to = "919000000000",
                                                            username = "ops"))
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key, username = "ops",
                                                    message = "m", wait_for_delivery = TRUE))
  # An empty username falls through to `to`.
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", to = "919000000000",
                                                            username = ""))
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key,
                                                    phone = "919000000000", message = "m",
                                                    wait_for_delivery = TRUE))
  # A list or several numbers are phones, one element stays an array.
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", to = list("919000000001")))
  expect_request(r$request, "whatsapp/notify", list(apikey = mock_api_key,
                                                    phones = list("919000000001"), message = "m",
                                                    wait_for_delivery = TRUE))
  expect_match(r$request$body, "\"phones\":[\"919000000001\"]", fixed = TRUE)
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", to = c("9101", "9102")))
  expect_identical(r$request$json$phones, list("9101", "9102"))
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", to = list()))
  expect_match(r$request$body, "\"phones\":[]", fixed = TRUE)
})

test_that("whatsapp attachments, wait_for_delivery and keyword arguments", {
  cl <- mock_client()
  r <- call_mock("whatsapp/notify", function() {
    cl$whatsapp("report", image = "/tmp/a.png", document = "/tmp/b.pdf", caption = "c",
                filename = "b.pdf", wait_for_delivery = 0, apikey = "ignored",
                image_path = "ignored", priority = 2, none = NULL)
  })
  expect_request(r$request, "whatsapp/notify", list(
    apikey = mock_api_key, self = TRUE, message = "report", image_path = "/tmp/a.png",
    document_path = "/tmp/b.pdf", caption = "c", filename = "b.pdf",
    wait_for_delivery = FALSE, priority = 2))
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m", image_path = "/tmp/x.png"))
  expect_identical(r$request$json$image_path, "/tmp/x.png")
  expect_error(cl$whatsapp("a", "b"), "must be named")
})

test_that("a WhatsApp HTTP error is reported as HTTP <code>: <body>", {
  cl <- mock_client()
  r <- call_mock("whatsapp/notify", function() cl$whatsapp("m"),
                 json = list(status = "error", message = "WhatsApp is not paired"), status = 400L)
  expect_identical(r$result, list(
    status = "error",
    message = "HTTP 400: {\"status\":\"error\",\"message\":\"WhatsApp is not paired\"}",
    code = 400L, error_type = "http_error"))
})

test_that("notification methods follow the make_request response paths", {
  check_make_request_paths("telegram/notify", function(cl) cl$telegram(username = "u",
                                                                       message = "m"))
  check_make_request_paths("whatsapp/notify", function(cl) cl$whatsapp("m"))
})
