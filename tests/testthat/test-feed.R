# WebSocket feed tests against an in-process server that emulates the
# OpenAlgo WebSocket proxy. The httpuv server and the websocket client both
# run on the 'later' event loop, so the tests pump it with later::run_now().

skip_if_not_installed("httpuv")
skip_if_not_installed("websocket")
skip_if_not_installed("later")

test_key <- "abcdefghijklmnopqrstuvwxyz123456"

pump_until <- function(cond, timeout = 5) {
  start <- Sys.time()
  while (!isTRUE(cond()) && as.numeric(Sys.time() - start, units = "secs") < timeout) {
    later::run_now(0.05)
  }
  isTRUE(cond())
}

json_text <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
}

# A fake OpenAlgo WebSocket proxy. Records every text frame it receives with
# the number of the connection it came on, answers authenticate, subscribe and
# order subscription requests, and can push frames or drop connections.
fake_proxy <- function(auth_ok = TRUE) {
  srv <- new.env()
  srv$auth_ok <- auth_ok
  srv$port <- httpuv::randomPort()
  srv$frames <- list()
  srv$conns <- list()
  srv$opened <- 0L

  app <- list(
    call = function(req) {
      list(status = 404L, headers = list("Content-Type" = "text/plain"), body = "not found")
    },
    onWSOpen = function(ws) {
      srv$opened <- srv$opened + 1L
      conn <- srv$opened
      key <- as.character(conn)
      srv$conns[[key]] <- ws
      ws$onMessage(function(binary, message) {
        srv$frames[[length(srv$frames) + 1L]] <- list(conn = conn, text = message)
        msg <- jsonlite::parse_json(message, simplifyVector = FALSE)
        action <- msg$action
        if (identical(action, "authenticate")) {
          if (isTRUE(srv$auth_ok)) {
            ws$send('{"type":"auth","status":"success","broker":"x","user_id":"u"}')
          } else {
            ws$send('{"type":"auth","status":"error","message":"Invalid API key"}')
          }
        } else if (identical(action, "subscribe")) {
          subs <- lapply(msg$symbols, function(s) {
            list(symbol = s$symbol, exchange = s$exchange, status = "success", mode = msg$mode)
          })
          ws$send(json_text(list(type = "subscribe", subscriptions = subs)))
        } else if (action %in% c("subscribe_orders", "unsubscribe_orders")) {
          ws$send(json_text(list(type = action, status = "success")))
        }
      })
      ws$onClose(function() {
        srv$conns[[key]] <- NULL
      })
    }
  )

  srv$start <- function() {
    srv$server <- httpuv::startServer("127.0.0.1", srv$port, app)
  }
  srv$stop <- function() {
    if (!is.null(srv$server)) httpuv::stopServer(srv$server)
    srv$server <- NULL
  }
  srv$push <- function(x) {
    text <- if (is.character(x)) x else json_text(x)
    for (ws in srv$conns) ws$send(text)
  }
  srv$drop <- function() {
    for (ws in srv$conns) ws$close()
  }
  srv$texts <- function(conn = NULL) {
    keep <- Filter(function(f) is.null(conn) || f$conn == conn, srv$frames)
    vapply(keep, function(f) f$text, character(1))
  }
  srv$url <- sprintf("ws://127.0.0.1:%d", srv$port)
  srv$start()
  srv
}

new_feed_client <- function(srv, verbose = 0, auto_reconnect = TRUE) {
  api(api_key = test_key, host = "http://127.0.0.1:5000", ws_url = srv$url,
      verbose = verbose, auto_reconnect = auto_reconnect)
}

private_of <- function(client) {
  client$.__enclos_env__$private
}

empty_named <- function() stats::setNames(list(), character(0))

test_that("connect authenticates with the exact auth frame and logs a masked key", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)

  out <- capture.output(ok <- client$connect())
  expect_true(ok)
  expect_true(client$connected)
  expect_true(client$authenticated)
  expect_identical(srv$texts(), sprintf('{"action":"authenticate","api_key":"%s"}', test_key))
  expect_true(paste0("[WS]     Connected to ", srv$url) %in% out)
  expect_true("[AUTH]   Authenticating with API key: abcdefgh...yz123456" %in% out)
  expect_true("[AUTH]   Success | Broker: x | User: u" %in% out)

  out <- capture.output(client$disconnect())
  expect_false(client$connected)
  expect_false(client$authenticated)
  expect_null(client$ws)
  expect_true(paste0("[WS]     Disconnected from ", srv$url) %in% out)
})

test_that("subscribe and unsubscribe send the protocol message shapes", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())

  expect_true(client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE"))))
  expect_true(client$subscribe_quote(list(list(exchange = "NSE", symbol = "INFY"),
                                          list(exchange = "BSE", exchange_token = "500325"))))
  # A single instrument given as one named list is still sent as an array.
  expect_true(client$subscribe_depth(list(exchange = "NSE", symbol = "SBIN")))
  expect_true(client$unsubscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE"))))
  expect_true(client$unsubscribe_quote(list(list(exchange = "NSE", symbol = "INFY"),
                                            list(exchange = "BSE", symbol = "500325"))))
  expect_true(client$subscribe_orders())
  expect_true(client$unsubscribe_orders())

  expect_true(pump_until(function() length(srv$frames) >= 8))
  expect_identical(srv$texts()[-1], c(
    '{"action":"subscribe","symbols":[{"symbol":"RELIANCE","exchange":"NSE"}],"mode":1,"depth":5}',
    paste0('{"action":"subscribe","symbols":[{"symbol":"INFY","exchange":"NSE"},',
           '{"symbol":"500325","exchange":"BSE"}],"mode":2,"depth":5}'),
    '{"action":"subscribe","symbols":[{"symbol":"SBIN","exchange":"NSE"}],"mode":3,"depth":5}',
    '{"action":"unsubscribe","symbols":[{"symbol":"RELIANCE","exchange":"NSE","mode":1}]}',
    paste0('{"action":"unsubscribe","symbols":[{"symbol":"INFY","exchange":"NSE","mode":2},',
           '{"symbol":"500325","exchange":"BSE","mode":2}]}'),
    '{"action":"subscribe_orders"}',
    '{"action":"unsubscribe_orders"}'
  ))

  subs <- private_of(client)$active_subs
  expect_length(subs[[1]], 0)
  expect_length(subs[[2]], 0)
  expect_identical(unname(subs[[3]]), list(list(symbol = "SBIN", exchange = "NSE")))
  expect_false(private_of(client)$orders_subscribed)
})

test_that("subscription acks are logged per symbol", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())

  out <- capture.output({
    client$subscribe_quote(list(list(exchange = "NSE", symbol = "INFY")))
    client$subscribe_orders()
    client$wait(0.5)
  })
  expect_true("[SUB]    Subscribing NSE:INFY Quote..." %in% out)
  expect_true("[SUB]    NSE:INFY | Mode: Quote | Status: success" %in% out)
  expect_true("[SUB]    Subscribing to order updates..." %in% out)
  expect_true("[SUB]    Order updates | subscribe_orders | Status: success" %in% out)
})

test_that("market data is stored, returned by get_* and passed to callbacks", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())

  got <- new.env()
  got$ltp <- list()
  got$quote <- list()
  got$depth <- list()
  got$orders <- list()
  client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")),
                       on_data_received = function(d) got$ltp[[length(got$ltp) + 1L]] <- d)
  client$subscribe_quote(list(list(exchange = "NSE", symbol = "INFY")),
                         on_data_received = function(d) got$quote[[length(got$quote) + 1L]] <- d)
  client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")),
                         on_data_received = function(d) got$depth[[length(got$depth) + 1L]] <- d)
  client$subscribe_orders(on_order_update = function(d) got$orders[[length(got$orders) + 1L]] <- d)
  client$wait(0.3)

  # LTP with ltt at the top level of data.
  srv$push('{"type":"market_data","symbol":"RELIANCE","exchange":"NSE","mode":1,"data":{"ltp":1424.5,"timestamp":1700000000000,"ltt":1699999999000,"volume":5}}')
  expect_true(pump_until(function() length(got$ltp) == 1))
  expect_identical(got$ltp[[1]], list(
    type = "market_data", symbol = "RELIANCE", exchange = "NSE", mode = 1L,
    data = list(ltp = 1424.5, timestamp = 1700000000000, ltt = 1699999999000)
  ))
  expect_identical(client$ltp_data[["NSE:RELIANCE"]], list(price = 1424.5, timestamp = 1700000000000))

  # ltt nested one level deeper, and a missing timestamp defaults to now.
  before <- floor(as.numeric(Sys.time()) * 1000)
  srv$push('{"type":"market_data","symbol":"RELIANCE","exchange":"NSE","mode":1,"data":{"ltp":1425,"data":{"ltt":123}}}')
  expect_true(pump_until(function() length(got$ltp) == 2))
  second <- got$ltp[[2]]
  expect_identical(names(second$data), c("ltp", "timestamp", "ltt"))
  expect_identical(second$data$ltt, 123L)
  expect_gte(second$data$timestamp, before)

  # No ltt at all.
  srv$push('{"type":"market_data","symbol":"RELIANCE","exchange":"NSE","mode":1,"data":{"ltp":1426.25,"timestamp":1700000000001}}')
  expect_true(pump_until(function() length(got$ltp) == 3))
  expect_identical(got$ltp[[3]]$data, list(ltp = 1426.25, timestamp = 1700000000001))

  expect_identical(client$get_ltp(), list(ltp = list(NSE = list(
    RELIANCE = list(timestamp = 1700000000001, ltp = 1426.25)))))
  expect_identical(client$get_ltp(exchange = "NSE", symbol = "RELIANCE")$ltp$NSE$RELIANCE$ltp, 1426.25)
  expect_identical(client$get_ltp(exchange = "BSE"), list(ltp = empty_named()))
  expect_identical(client$get_ltp(symbol = "INFY"), list(ltp = empty_named()))

  # Quote: missing fields default to 0.
  srv$push('{"type":"market_data","symbol":"INFY","exchange":"NSE","mode":2,"data":{"open":1500.0,"high":1510.5,"low":1495,"close":1498,"ltp":1505.5,"volume":1000,"timestamp":1700000000002}}')
  expect_true(pump_until(function() length(got$quote) == 1))
  quote_data <- list(open = 1500, high = 1510.5, low = 1495L, close = 1498L, ltp = 1505.5,
                     volume = 1000L, last_trade_quantity = 0L, avg_trade_price = 0L,
                     change = 0L, change_percent = 0L, timestamp = 1700000000002)
  expect_identical(got$quote[[1]], list(type = "market_data", symbol = "INFY", exchange = "NSE",
                                        mode = 2L, data = quote_data))
  expect_identical(client$quotes_data[["NSE:INFY"]], quote_data)
  expect_identical(client$get_quotes(), list(quote = list(NSE = list(INFY = list(
    timestamp = 1700000000002, open = 1500, high = 1510.5, low = 1495L, close = 1498L,
    ltp = 1505.5, volume = 1000L, last_trade_quantity = 0L, avg_trade_price = 0L,
    change = 0L, change_percent = 0L)))))
  expect_identical(client$get_quotes(exchange = "BSE"), list(quote = empty_named()))

  # Depth: two buy levels, one sell level with a null quantity.
  srv$push(paste0('{"type":"market_data","symbol":"SBIN","exchange":"NSE","mode":3,"data":{"ltp":800.5,',
                  '"timestamp":1700000000003,"depth":{"buy":[{"price":800.4,"quantity":100,"orders":3},',
                  '{"price":800,"quantity":50,"orders":1}],"sell":[{"price":800.6,"quantity":null,"orders":2}]}}}'))
  expect_true(pump_until(function() length(got$depth) == 1))
  depth_cb <- got$depth[[1]]
  expect_identical(names(depth_cb), c("type", "symbol", "exchange", "mode", "data"))
  expect_identical(depth_cb$mode, 3L)
  expect_identical(names(depth_cb$data), c("ltp", "timestamp", "depth"))
  expect_identical(depth_cb$data$depth$buy[[1]]$price, 800.4)
  expect_identical(client$depth_data[["NSE:SBIN"]], depth_cb$data)

  zero <- list(price = 0, qty = 0L, orders = 0L)
  expect_identical(client$get_depth(), list(depth = list(NSE = list(SBIN = list(
    timestamp = 1700000000003,
    ltp = 800.5,
    buyBook = list("1" = list(price = 800.4, qty = 100L, orders = 3L),
                   "2" = list(price = 800, qty = 50L, orders = 1L),
                   "3" = zero, "4" = zero, "5" = zero),
    sellBook = list("1" = list(price = 800.6, qty = 0L, orders = 2L),
                    "2" = zero, "3" = zero, "4" = zero, "5" = zero)
  )))))
  expect_identical(client$get_depth(exchange = "NSE", symbol = "XYZ"), list(depth = empty_named()))

  # Order updates: stored most recent first, callback receives the message.
  srv$push('{"type":"order_update","orderid":"1","symbol":"SBIN","order_status":"open","quantity":1}')
  srv$push('{"type":"order_update","orderid":"2","symbol":"SBIN","order_status":"complete","quantity":1}')
  expect_true(pump_until(function() length(got$orders) == 2))
  expect_identical(got$orders[[1]]$orderid, "1")
  orders <- client$get_orders()
  expect_identical(names(orders), "orders")
  expect_identical(vapply(orders$orders, function(o) o$orderid, character(1)), c("2", "1"))

  # Unsubscribe removes cached data.
  expect_true(client$unsubscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE"))))
  expect_true(client$unsubscribe_quote(list(list(exchange = "NSE", symbol = "INFY"))))
  expect_true(client$unsubscribe_depth(list(list(exchange = "NSE", symbol = "SBIN"))))
  expect_identical(client$get_ltp(), list(ltp = empty_named()))
  expect_identical(client$get_quotes(), list(quote = empty_named()))
  expect_identical(client$get_depth(), list(depth = empty_named()))
  expect_length(client$ltp_data, 0)
})

test_that("callback errors and invalid JSON are logged, not raised", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())
  capture.output(client$subscribe_ltp(list(list(exchange = "NSE", symbol = "A")),
                                      on_data_received = function(d) stop("boom")))
  out <- capture.output({
    srv$push('{"type":"market_data","symbol":"A","exchange":"NSE","mode":1,"data":{"ltp":1}}')
    srv$push("this is not json")
    client$wait(0.5)
  })
  expect_true("[ERROR]  LTP callback error: boom" %in% out)
  expect_true("[ERROR]  Invalid JSON message: this is not json..." %in% out)
  expect_identical(client$ltp_data[["NSE:A"]]$price, 1L)
})

test_that("invalid instruments are rejected and logged", {
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())

  out <- capture.output(ok <- client$subscribe_ltp(list(list(exchange = "NSE"), list(symbol = "X"))))
  expect_false(ok)
  expect_true("[ERROR]  Invalid instrument: {'exchange': 'NSE'}" %in% out)
  expect_true("[ERROR]  Invalid instrument: {'symbol': 'X'}" %in% out)
  out <- capture.output(ok <- client$unsubscribe_depth(list(list(exchange = "", symbol = "X"))))
  expect_false(ok)
  expect_identical(out, "[ERROR]  Invalid instrument: {'exchange': '', 'symbol': 'X'}")

  capture.output({
    ok <- client$subscribe_ltp(list(list(exchange = "NSE"), list(exchange = "NSE", symbol = "TCS")))
    client$wait(0.3)
  })
  expect_true(ok)
  expect_identical(srv$texts()[-1],
                   '{"action":"subscribe","symbols":[{"symbol":"TCS","exchange":"NSE"}],"mode":1,"depth":5}')
})

test_that("methods guard against a missing connection", {
  client <- api(api_key = test_key, ws_url = "ws://127.0.0.1:9", verbose = 1)
  out <- capture.output({
    expect_false(client$subscribe_ltp(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$subscribe_quote(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$subscribe_depth(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$subscribe_orders())
  })
  expect_identical(out, rep("[ERROR]  Not connected to WebSocket server", 4))
  out <- capture.output({
    expect_false(client$unsubscribe_ltp(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$unsubscribe_quote(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$unsubscribe_depth(list(list(exchange = "NSE", symbol = "A"))))
    expect_false(client$unsubscribe_orders())
  })
  expect_length(out, 0)

  # Connected but not authenticated.
  client$connected <- TRUE
  out <- capture.output(expect_false(client$subscribe_ltp(list(list(exchange = "NSE", symbol = "A")))))
  expect_identical(out, "[ERROR]  Not authenticated with WebSocket server")
  client$connected <- FALSE

  expect_identical(client$get_ltp(), list(ltp = empty_named()))
  expect_identical(client$get_quotes(), list(quote = empty_named()))
  expect_identical(client$get_depth(), list(depth = empty_named()))
  expect_identical(client$get_orders(), list(orders = list()))
  expect_null(client$disconnect())
})

test_that("a rejected API key makes connect() return FALSE", {
  # connect() waits out its 5 s authentication window.
  skip_on_cran()
  srv <- fake_proxy(auth_ok = FALSE)
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)

  out <- capture.output(ok <- client$connect())
  expect_false(ok)
  expect_true(client$connected)
  expect_false(client$authenticated)
  expect_true("[ERROR]  Authentication failed: Invalid API key" %in% out)
})

test_that("order history is capped at 500, most recent first", {
  client <- api(api_key = test_key, ws_url = "ws://127.0.0.1:9")
  priv <- private_of(client)
  for (i in 1:505) {
    priv$feed_process_message(sprintf('{"type":"order_update","orderid":"%d"}', i))
  }
  orders <- client$get_orders()$orders
  expect_length(orders, 500)
  expect_identical(orders[[1]]$orderid, "505")
  expect_identical(orders[[500]]$orderid, "6")
})

test_that("verbose 2 prints the debug lines", {
  client <- api(api_key = test_key, ws_url = "ws://127.0.0.1:9", verbose = 2)
  priv <- private_of(client)
  out <- capture.output({
    priv$feed_process_message('{"type":"market_data","symbol":"A","exchange":"NSE","mode":1,"data":{"ltp":10.0}}')
    priv$feed_process_message('{"type":"market_data","symbol":"B","exchange":"NSE","mode":2,"data":{"open":1.5,"high":2,"low":1,"close":1.25,"ltp":1.75}}')
    priv$feed_process_message('{"type":"market_data","symbol":"C","exchange":"NSE","mode":3,"data":{"ltp":5,"depth":{"buy":[{"price":4.5,"quantity":10,"orders":1}],"sell":[]}}}')
  })
  expect_identical(out, c(
    "[LTP]    NSE:A                | LTP: 10.0",
    "[QUOTE]  NSE:B                | O: 1.5        H: 2          L: 1          C: 1.25       LTP: 1.75",
    "[DEPTH]  NSE:C                | LTP: 5",
    sprintf("         %-30s | %-30s", "BUY", "SELL"),
    sprintf("         %-10s %-10s %-8s | %-10s %-10s %-8s", "Price", "Qty", "Orders", "Price", "Qty", "Orders"),
    paste0("         ", strrep("-", 62)),
    sprintf("         %-10s %-10s %-8s | %-10s %-10s %-8s", "4.5", "10", "1", "-", "-", "-")
  ))
})

test_that("auto-reconnect replays subscriptions and disconnect() suppresses it", {
  # Reconnect timing (1 s backoff plus waits).
  skip_on_cran()
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())

  got <- new.env()
  got$ltp <- list()
  capture.output({
    client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE"),
                              list(exchange = "NSE", symbol = "INFY")),
                         on_data_received = function(d) got$ltp[[length(got$ltp) + 1L]] <- d)
    client$subscribe_quote(list(list(exchange = "NSE", symbol = "TCS")))
    client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")))
    client$unsubscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")))
    client$subscribe_orders()
    client$wait(0.3)
  })

  # The server drops the connection: the client reconnects after 1 s.
  out <- capture.output({
    srv$drop()
    expect_true(pump_until(function() length(srv$texts(conn = 2)) >= 4, timeout = 10))
    client$wait(0.3)
  })
  expect_true(client$authenticated)
  expect_true(paste0("[WS]     Disconnected from ", srv$url) %in% out)
  expect_true("[WS]     Reconnect attempt 1 in 1s..." %in% out)
  expect_true("[WS]     Reconnected and re-authenticated." %in% out)
  expect_true("[SUB]    Replaying 2 LTP subscription(s) after reconnect" %in% out)
  expect_true("[SUB]    Replaying 1 Quote subscription(s) after reconnect" %in% out)
  expect_true("[SUB]    Replaying order-update subscription after reconnect" %in% out)
  expect_identical(srv$texts(conn = 2), c(
    sprintf('{"action":"authenticate","api_key":"%s"}', test_key),
    paste0('{"action":"subscribe","symbols":[{"symbol":"RELIANCE","exchange":"NSE"},',
           '{"symbol":"INFY","exchange":"NSE"}],"mode":1,"depth":5}'),
    '{"action":"subscribe","symbols":[{"symbol":"TCS","exchange":"NSE"}],"mode":2,"depth":5}',
    '{"action":"subscribe_orders"}'
  ))

  # The callback survives the reconnect.
  srv$push('{"type":"market_data","symbol":"INFY","exchange":"NSE","mode":1,"data":{"ltp":1500}}')
  expect_true(pump_until(function() length(got$ltp) == 1))
  expect_identical(got$ltp[[1]]$symbol, "INFY")

  # disconnect() is a graceful shutdown: no reconnect follows.
  capture.output({
    client$disconnect()
    client$wait(2)
  })
  expect_identical(srv$opened, 2L)
  expect_false(client$connected)
  expect_false(client$authenticated)
})

test_that("auto-reconnect backs off while the server is down", {
  # Backoff timing against a stopped server.
  skip_on_cran()
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output({
    client$connect()
    client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")))
    client$wait(0.3)
  })

  out <- capture.output({
    srv$drop()
    expect_true(pump_until(function() !client$connected, timeout = 3))
    srv$stop()
    # Attempt 1 fires after 1 s against the stopped server and fails (a
    # refused connection can take a couple of seconds to be reported).
    expect_true(pump_until(function() private_of(client)$feed_reconnect_attempt >= 1, timeout = 10))
    srv$start()
    # Attempt 2 fires 2 s after the failure.
    expect_true(pump_until(function() isTRUE(client$authenticated), timeout = 8))
    client$wait(0.3)
  })
  expect_true("[WS]     Reconnect attempt 1 in 1s..." %in% out)
  expect_true("[ERROR]  Failed to connect to WebSocket server" %in% out)
  expect_true("[WS]     Reconnect attempt 2 in 2s..." %in% out)
  expect_true("[WS]     Reconnected and re-authenticated." %in% out)
  expect_identical(srv$texts(conn = 2)[2],
                   '{"action":"subscribe","symbols":[{"symbol":"RELIANCE","exchange":"NSE"}],"mode":1,"depth":5}')
})

test_that("auto_reconnect = FALSE keeps the connection down", {
  # Waits to prove no reconnect happens.
  skip_on_cran()
  srv <- fake_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- new_feed_client(srv, auto_reconnect = FALSE)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())
  srv$drop()
  expect_true(pump_until(function() !client$connected, timeout = 3))
  client$wait(1.5)
  expect_identical(srv$opened, 1L)
  expect_false(client$authenticated)
})
