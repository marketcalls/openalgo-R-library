# WebSocket feed utilities:
# the depth level of subscribe_depth(), unsubscribe_all(), get_broker_info(),
# get_supported_brokers(), ws_ping(), acknowledgement and error logging, and
# the wss URL derivation for https hosts. Runs against an in-process server
# that emulates the OpenAlgo WebSocket proxy, on the 'later' event loop.

skip_if_not_installed("httpuv")
skip_if_not_installed("websocket")
skip_if_not_installed("later")

ext_key <- "abcdefghijklmnopqrstuvwxyz123456"

ext_pump_until <- function(cond, timeout = 5) {
  start <- Sys.time()
  while (!isTRUE(cond()) && as.numeric(Sys.time() - start, units = "secs") < timeout) {
    later::run_now(0.05)
  }
  isTRUE(cond())
}

ext_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
}

# A fake proxy answering like websocket_proxy/server.py: subscribe acks echo
# the mode label and depth (or a per-symbol error for symbols listed in
# `fail`), unsubscribe acks list successful and failed items, and the
# request/response actions answer with their reply types. With
# `silent = TRUE` the request/response actions get no answer. `before_reply`
# frames are sent ahead of every request/response reply.
ext_proxy <- function() {
  srv <- new.env()
  srv$port <- httpuv::randomPort()
  srv$frames <- list()
  srv$conns <- list()
  srv$opened <- 0L
  srv$silent <- FALSE
  srv$fail <- character(0)
  srv$broker_reply <- list(type = "broker_info", status = "success", broker = "yourbroker",
                           adapter_status = "connected", user_id = "u1")
  srv$before_reply <- list()
  labels <- c("LTP", "Quote", "Depth")

  app <- list(
    call = function(req) {
      list(status = 404L, headers = list("Content-Type" = "text/plain"), body = "not found")
    },
    onWSOpen = function(ws) {
      srv$opened <- srv$opened + 1L
      conn <- srv$opened
      key <- as.character(conn)
      srv$conns[[key]] <- ws
      reply <- function(x) {
        for (f in srv$before_reply) ws$send(ext_json(f))
        ws$send(ext_json(x))
      }
      ws$onMessage(function(binary, message) {
        srv$frames[[length(srv$frames) + 1L]] <- list(conn = conn, text = message)
        msg <- jsonlite::parse_json(message, simplifyVector = FALSE)
        action <- msg$action
        if (identical(action, "authenticate")) {
          ws$send('{"type":"auth","status":"success","broker":"yourbroker","user_id":"u1"}')
        } else if (identical(action, "subscribe")) {
          subs <- lapply(msg$symbols, function(s) {
            if (s$symbol %in% srv$fail) {
              list(symbol = s$symbol, exchange = s$exchange, status = "error",
                   message = sprintf("Depth level %d is not supported by this broker",
                                     as.integer(msg$depth)), broker = "yourbroker")
            } else {
              list(symbol = s$symbol, exchange = s$exchange, status = "success",
                   mode = labels[msg$mode], depth = msg$depth, broker = "yourbroker")
            }
          })
          ws$send(ext_json(list(type = "subscribe", status = "success", subscriptions = subs,
                                message = "Subscription processing complete")))
        } else if (identical(action, "unsubscribe_all")) {
          ws$send(ext_json(list(type = "unsubscribe", status = "success",
                                message = "Unsubscription processing complete",
                                successful = list(list(symbol = "SBIN", exchange = "NSE",
                                                       mode = "Depth", status = "success")),
                                failed = list())))
        } else if (srv$silent) {
          NULL
        } else if (identical(action, "get_broker_info")) {
          reply(srv$broker_reply)
        } else if (identical(action, "get_supported_brokers")) {
          reply(list(type = "supported_brokers", status = "success",
                     brokers = list("yourbroker", "anotherbroker"), count = 2L))
        } else if (identical(action, "ping")) {
          reply(list(type = "pong", status = "success", server_timestamp = 1L,
                     client_timestamp = msg$timestamp))
        }
      })
      ws$onClose(function() {
        srv$conns[[key]] <- NULL
      })
    }
  )

  srv$server <- httpuv::startServer("127.0.0.1", srv$port, app)
  srv$stop <- function() {
    if (!is.null(srv$server)) httpuv::stopServer(srv$server)
    srv$server <- NULL
  }
  srv$push <- function(x) {
    text <- if (is.character(x)) x else ext_json(x)
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
  srv
}

ext_client <- function(srv, verbose = 0, auto_reconnect = TRUE) {
  api(api_key = ext_key, host = "http://127.0.0.1:5000", ws_url = srv$url,
      verbose = verbose, auto_reconnect = auto_reconnect)
}

ext_private <- function(client) {
  client$.__enclos_env__$private
}

test_that("an https host derives the production wss URL", {
  expect_identical(api("k", host = "https://algo.example.com")$ws_url,
                   "wss://algo.example.com/ws")
  expect_identical(api("k", host = "https://algo.example.com/")$ws_url,
                   "wss://algo.example.com/ws")
  expect_identical(api("k", host = "https://algo.example.com:8443/openalgo/")$ws_url,
                   "wss://algo.example.com:8443/ws")
  expect_identical(api("k", host = "https://algo.example.com:8443")$ws_host, "algo.example.com")
  # ws_port is not used for https hosts; an explicit ws_url still wins.
  expect_identical(api("k", host = "https://algo.example.com", ws_port = 9999)$ws_url,
                   "wss://algo.example.com/ws")
  expect_identical(api("k", host = "https://algo.example.com", ws_url = "wss://other/feed")$ws_url,
                   "wss://other/feed")
  # http hosts derive ws://<hostname>:<ws_port>.
  expect_identical(api("k")$ws_url, "ws://127.0.0.1:8765")
  expect_identical(api("k", host = "http://localhost:5000/", ws_port = 9000)$ws_url,
                   "ws://localhost:9000")
})

test_that("subscribe_depth sends the depth level and validates it", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(expect_true(client$connect()))

  capture.output({
    expect_true(client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN"))))
    expect_true(client$subscribe_depth(list(list(exchange = "NSE", symbol = "INFY")), depth = 20))
    expect_true(client$subscribe_depth(list(exchange = "NFO", symbol = "NIFTYFUT"), depth = 50L))
  })
  out <- capture.output({
    expect_false(client$subscribe_depth(list(list(exchange = "NSE", symbol = "TCS")), depth = 0))
    expect_false(client$subscribe_depth(list(list(exchange = "NSE", symbol = "TCS")), depth = 2.5))
    expect_false(client$subscribe_depth(list(list(exchange = "NSE", symbol = "TCS")), depth = "20"))
    expect_false(client$subscribe_depth(list(list(exchange = "NSE", symbol = "TCS")), depth = NA))
  })
  expect_true("[ERROR]  Invalid depth level: 0 (must be a positive whole number)" %in% out)
  expect_true("[ERROR]  Invalid depth level: 2.5 (must be a positive whole number)" %in% out)
  expect_true("[ERROR]  Invalid depth level: '20' (must be a positive whole number)" %in% out)
  client$verbose <- 0L

  expect_true(ext_pump_until(function() length(srv$frames) >= 4))
  client$wait(0.2)
  expect_identical(srv$texts()[-1], c(
    '{"action":"subscribe","symbols":[{"symbol":"SBIN","exchange":"NSE"}],"mode":3,"depth":5}',
    '{"action":"subscribe","symbols":[{"symbol":"INFY","exchange":"NSE"}],"mode":3,"depth":20}',
    '{"action":"subscribe","symbols":[{"symbol":"NIFTYFUT","exchange":"NFO"}],"mode":3,"depth":50}'
  ))
  levels <- ext_private(client)$feed_depth_levels
  expect_identical(unname(unlist(levels)), c(5L, 20L, 50L))
  expect_length(ext_private(client)$active_subs[[3]], 3)

  # Unsubscribing forgets the level; LTP and quote keep depth 5 on the wire.
  expect_true(client$unsubscribe_depth(list(list(exchange = "NSE", symbol = "INFY"))))
  expect_identical(unname(unlist(ext_private(client)$feed_depth_levels)), c(5L, 50L))
  capture.output(expect_true(client$subscribe_ltp(list(list(exchange = "NSE", symbol = "SBIN")))))
  expect_true(ext_pump_until(function() length(srv$frames) >= 6))
  expect_identical(srv$texts()[6],
                   '{"action":"subscribe","symbols":[{"symbol":"SBIN","exchange":"NSE"}],"mode":1,"depth":5}')
})

test_that("a reconnect replays each depth subscription with its level", {
  skip_on_cran()
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())

  client$subscribe_depth(list(list(exchange = "NSE", symbol = "A")), depth = 20)
  client$subscribe_depth(list(list(exchange = "NSE", symbol = "B")))
  client$subscribe_depth(list(list(exchange = "NSE", symbol = "C")), depth = 20)
  client$subscribe_quote(list(list(exchange = "NSE", symbol = "Q")))
  client$wait(0.3)

  srv$drop()
  expect_true(ext_pump_until(function() isTRUE(client$authenticated) && srv$opened >= 2 &&
                               length(srv$texts(2)) >= 4, timeout = 10))
  expect_identical(srv$texts(2), c(
    sprintf('{"action":"authenticate","api_key":"%s"}', ext_key),
    '{"action":"subscribe","symbols":[{"symbol":"Q","exchange":"NSE"}],"mode":2,"depth":5}',
    paste0('{"action":"subscribe","symbols":[{"symbol":"A","exchange":"NSE"},',
           '{"symbol":"C","exchange":"NSE"}],"mode":3,"depth":20}'),
    '{"action":"subscribe","symbols":[{"symbol":"B","exchange":"NSE"}],"mode":3,"depth":5}'
  ))
})

test_that("get_depth pads both books to max(5, levels received)", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())
  client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")), depth = 20)
  client$subscribe_depth(list(list(exchange = "NSE", symbol = "INFY")))
  client$wait(0.2)

  lvl <- function(i) list(price = 100 + i, quantity = i, orders = 1L)
  srv$push(list(type = "market_data", symbol = "SBIN", exchange = "NSE", mode = 3L,
                data = list(ltp = 100.5, timestamp = 1L,
                            depth = list(buy = lapply(1:20, lvl), sell = lapply(1:18, lvl)))))
  srv$push(list(type = "market_data", symbol = "INFY", exchange = "NSE", mode = 3L,
                data = list(ltp = 1500, timestamp = 2L,
                            depth = list(buy = lapply(1:3, lvl), sell = list()))))
  expect_true(ext_pump_until(function() length(client$depth_data) == 2))

  d <- client$get_depth()$depth$NSE
  expect_identical(names(d$SBIN$buyBook), as.character(1:20))
  expect_identical(names(d$SBIN$sellBook), as.character(1:20))
  expect_identical(d$SBIN$buyBook[["20"]], list(price = 120, qty = 20L, orders = 1L))
  expect_identical(d$SBIN$sellBook[["18"]], list(price = 118, qty = 18L, orders = 1L))
  expect_identical(d$SBIN$sellBook[["19"]], list(price = 0, qty = 0L, orders = 0L))
  expect_identical(names(d$INFY$buyBook), as.character(1:5))
  expect_identical(names(d$INFY$sellBook), as.character(1:5))
  expect_identical(d$INFY$buyBook[["4"]], list(price = 0, qty = 0L, orders = 0L))
})

test_that("acks log mode labels, per-symbol failures, unsubscribe results and errors", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  srv$fail <- "BAD"
  client <- ext_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())

  out <- capture.output({
    client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN"),
                                list(exchange = "NSE", symbol = "BAD")), depth = 50)
    client$subscribe_ltp(list(list(exchange = "NSE", symbol = "INFY")))
    client$wait(0.3)
    # Labels in any case and numeric modes are both understood.
    srv$push(list(type = "subscribe", subscriptions = list(
      list(symbol = "X", exchange = "BSE", status = "success", mode = "quote"),
      list(symbol = "Y", exchange = "BSE", status = "success", mode = 1L),
      list(symbol = "Z", exchange = "BSE", status = "success", mode = "bogus"))))
    srv$push(list(type = "unsubscribe", status = "partial", successful = list(
      list(symbol = "INFY", exchange = "NSE", mode = "LTP", status = "success")),
      failed = list(list(symbol = "TCS", exchange = "NSE", mode = NULL, status = "error",
                         message = "Invalid mode"))))
    srv$push('{"status":"error","code":"INVALID_ACTION","message":"Invalid action: foo"}')
    srv$push('{"type":"error","message":"boom"}')
    client$wait(0.3)
  })
  expect_true("[SUB]    NSE:SBIN | Mode: Depth | Status: success | Depth: 50" %in% out)
  expect_true(paste0("[SUB]    NSE:BAD | Mode: Unknown | Status: error | Message: ",
                     "Depth level 50 is not supported by this broker") %in% out)
  expect_true("[SUB]    NSE:INFY | Mode: LTP | Status: success" %in% out)
  expect_true("[SUB]    BSE:X | Mode: Quote | Status: success" %in% out)
  expect_true("[SUB]    BSE:Y | Mode: LTP | Status: success" %in% out)
  expect_true("[SUB]    BSE:Z | Mode: Unknown | Status: success" %in% out)
  expect_true("[UNSUB]  NSE:INFY | Mode: LTP | Status: success" %in% out)
  expect_true("[UNSUB]  NSE:TCS | Mode: Unknown | Status: error | Message: Invalid mode" %in% out)
  expect_true("[UNSUB]  Unsubscribe | Status: partial" %in% out)
  expect_true("[ERROR]  Server error INVALID_ACTION: Invalid action: foo" %in% out)
  expect_true("[ERROR]  Server error: boom" %in% out)
  expect_false(any(grepl("Error handling message", out, fixed = TRUE)))

  # Silent at verbose 0.
  client$verbose <- 0L
  out <- capture.output({
    srv$push('{"status":"error","code":"X","message":"quiet"}')
    client$wait(0.2)
  })
  expect_identical(out, character(0))
})

test_that("unsubscribe_all sends the action and forgets every subscription", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv, verbose = 1)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  capture.output(client$connect())

  capture.output({
    client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")))
    client$subscribe_quote(list(list(exchange = "NSE", symbol = "INFY")))
    client$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")), depth = 20)
    client$subscribe_orders()
    srv$push(list(type = "market_data", symbol = "RELIANCE", exchange = "NSE", mode = 1L,
                  data = list(ltp = 1424, timestamp = 1L)))
    srv$push(list(type = "market_data", symbol = "INFY", exchange = "NSE", mode = 2L,
                  data = list(ltp = 1500, timestamp = 1L)))
    srv$push(list(type = "market_data", symbol = "SBIN", exchange = "NSE", mode = 3L,
                  data = list(ltp = 800, timestamp = 1L, depth = list(buy = list(), sell = list()))))
    ext_pump_until(function() length(client$depth_data) == 1 && length(client$quotes_data) == 1 &&
                     length(client$ltp_data) == 1)
  })
  expect_length(client$ltp_data, 1)

  out <- capture.output({
    expect_true(client$unsubscribe_all())
    client$wait(0.3)
  })
  expect_identical(srv$texts()[length(srv$texts())], '{"action":"unsubscribe_all"}')
  expect_true("[UNSUB]  Unsubscribing from all market data" %in% out)
  expect_true("[UNSUB]  NSE:SBIN | Mode: Depth | Status: success" %in% out)
  expect_true("[UNSUB]  Unsubscribe | Status: success" %in% out)
  subs <- ext_private(client)$active_subs
  expect_identical(lengths(subs), c(0L, 0L, 0L))
  expect_length(ext_private(client)$feed_depth_levels, 0)
  expect_length(client$ltp_data, 0)
  expect_length(client$quotes_data, 0)
  expect_length(client$depth_data, 0)
  expect_identical(client$get_ltp(), list(ltp = stats::setNames(list(), character(0))))
  # Order updates are a separate stream and stay subscribed.
  expect_true(ext_private(client)$orders_subscribed)

  # Not connected: nothing is sent, but the local state is still cleared.
  idle <- ext_client(srv)
  idle_private <- ext_private(idle)
  idle_private$active_subs[[1]][["k"]] <- list(symbol = "A", exchange = "NSE")
  expect_length(ext_private(idle)$active_subs[[1]], 1)
  expect_false(idle$unsubscribe_all())
  expect_length(ext_private(idle)$active_subs[[1]], 0)
})

test_that("get_broker_info, get_supported_brokers and ws_ping return the replies", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())

  info <- client$get_broker_info()
  expect_identical(info, list(type = "broker_info", status = "success", broker = "yourbroker",
                              adapter_status = "connected", user_id = "u1"))
  brokers <- client$get_supported_brokers()
  expect_identical(brokers, list(type = "supported_brokers", status = "success",
                                 brokers = list("yourbroker", "anotherbroker"), count = 2L))
  before <- floor(as.numeric(Sys.time()) * 1000)
  pong <- client$ws_ping()
  expect_identical(names(pong), c("type", "status", "server_timestamp", "client_timestamp",
                                  "latency_ms"))
  expect_identical(pong$type, "pong")
  expect_true(is.numeric(pong$latency_ms) && pong$latency_ms >= 0 && pong$latency_ms < 5000)
  expect_true(pong$client_timestamp >= before)

  texts <- srv$texts()
  expect_identical(texts[2:3], c('{"action":"get_broker_info"}',
                                 '{"action":"get_supported_brokers"}'))
  expect_match(texts[4], '^\\{"action":"ping","timestamp":[0-9]{13}\\}$')
  expect_identical(jsonlite::parse_json(texts[4])$timestamp, pong$client_timestamp)
})

test_that("a server error reply is returned and market data keeps flowing while waiting", {
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())

  got <- new.env()
  got$ltp <- list()
  client$subscribe_ltp(list(list(exchange = "NSE", symbol = "RELIANCE")),
                       on_data_received = function(d) got$ltp[[length(got$ltp) + 1L]] <- d)
  client$wait(0.2)

  # Market data that arrives ahead of the reply is stored and passed on.
  srv$before_reply <- list(list(type = "market_data", symbol = "RELIANCE", exchange = "NSE",
                                mode = 1L, data = list(ltp = 1424.5, timestamp = 7L)))
  srv$broker_reply <- list(status = "error", code = "NOT_AUTHENTICATED",
                           message = "You must authenticate first")
  res <- client$get_broker_info()
  expect_identical(res, list(status = "error", code = "NOT_AUTHENTICATED",
                             message = "You must authenticate first"))
  expect_length(got$ltp, 1)
  expect_identical(got$ltp[[1]]$data, list(ltp = 1424.5, timestamp = 7L))
  expect_identical(client$ltp_data[["NSE:RELIANCE"]], list(price = 1424.5, timestamp = 7L))
})

test_that("waiting requests fail cleanly without a connection or a reply", {
  client <- api(api_key = ext_key, host = "http://127.0.0.1:5000")
  not_connected <- list(status = "error", message = "Not connected to WebSocket server",
                        error_type = "connection_error")
  expect_identical(client$get_broker_info(), not_connected)
  expect_identical(client$get_supported_brokers(), not_connected)
  expect_identical(client$ws_ping(), not_connected)

  skip_on_cran()
  srv <- ext_proxy()
  on.exit(srv$stop(), add = TRUE)
  client <- ext_client(srv)
  on.exit(capture.output(client$disconnect()), add = TRUE, after = FALSE)
  expect_true(client$connect())
  srv$silent <- TRUE

  # A pong that arrived before the request is not taken as its answer.
  srv$push(list(type = "pong", status = "success", server_timestamp = 1L))
  client$wait(0.2)
  start <- Sys.time()
  expect_identical(client$ws_ping(timeout = 0.5),
                   list(status = "error", message = "Timed out waiting for pong reply",
                        error_type = "timeout_error"))
  expect_gte(as.numeric(Sys.time() - start, units = "secs"), 0.45)
  expect_identical(client$get_broker_info(timeout = 0.3)$error_type, "timeout_error")
  expect_identical(client$get_supported_brokers(timeout = 0.3)$message,
                   "Timed out waiting for supported_brokers reply")
})
