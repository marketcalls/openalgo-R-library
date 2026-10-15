# Live tests against a running OpenAlgo server. They run only when
# OPENALGO_API_KEY is set (never on CRAN); the host comes from OPENALGO_HOST
# (default http://127.0.0.1:5000). Order-placing tests run only when the
# server reports analyze (sandbox) mode, so no live order is ever placed.
# Orders are LIMIT orders priced far from the market, so nothing fills.
#
# Every endpoint is exercised. Each call is recorded as "passed",
# "tolerated" (a legitimate server error, with the server's message) or
# "failed", and the table is printed by the last test. Tolerated errors:
# * Closed market: errors about a missing LTP, quotes, ticks, a closed
#   session or the square-off time (orders, GTT, history, option analytics).
# * Notifications: telegram and whatsapp answer HTTP 409 when the bot is not
#   running or the device is not paired.
# * Strategy module: lifecycle calls go to strategy id 999999 so they never
#   touch a real strategy; the server answers 404 "Strategy not found".
#   Reads use the first listed strategy when there is one.
# * Strategy webhook: a token is shown only once in the browser, so the
#   webhook is called with an unknown token and answers 404 rejected_token.
# * closeposition answers an error when the strategy holds no position.
#   cancelallorder and closeposition act on the whole sandbox account, not
#   only on this file's strategy tag.
# * The WebSocket feed sends no ticks while the market is closed.

skip_on_cran()
skip_if(Sys.getenv("OPENALGO_API_KEY") == "", "OPENALGO_API_KEY is not set")

live_host <- Sys.getenv("OPENALGO_HOST", "")
if (!nzchar(live_host)) live_host <- "http://127.0.0.1:5000"
live <- api(api_key = Sys.getenv("OPENALGO_API_KEY"), host = live_host, timeout = 60)
live_strategy <- "RLiveTest"
missing_strategy_id <- 999999L

live_analyzer <- live$analyzerstatus()
live_sandbox <- identical(live_analyzer$status, "success") &&
  isTRUE(live_analyzer$data$analyze_mode)

skip_unless_sandbox <- function() {
  skip_if_not(live_sandbox, "server is not in analyze (sandbox) mode; never place live orders")
}

# Tolerance patterns, matched against the server's message.
closed_market <- paste0("market|closed|ltp|last price|quote|tick|session|holiday|square|",
                        "no data|not available|price")
not_configured <- "bot|pair|not connected|telegram|whatsapp|not linked|username|configured"
no_strategy <- "strategy not found"
no_position <- "no open position|no position|closed 0"
bad_token <- "unknown or expired webhook token"

live_outcomes <- new.env(parent = emptyenv())
live_outcomes$rows <- list()

live_record <- function(endpoint, outcome, detail = "") {
  live_outcomes$rows[[length(live_outcomes$rows) + 1L]] <-
    data.frame(endpoint = endpoint, outcome = outcome, detail = detail, stringsAsFactors = FALSE)
}

live_message <- function(x) {
  msg <- x$message
  if (is.null(msg)) msg <- x$error_type
  if (is.null(msg)) msg <- ""
  paste(unlist(msg), collapse = " ")
}

# Check one result. A success (or data frame) runs `check` and is recorded
# as passed when every expectation in it holds. An error whose message
# matches `tolerate` is recorded as tolerated with the server's message;
# any other error fails the test. Returns TRUE for a success.
live_expect <- function(endpoint, x, check = NULL, tolerate = closed_market,
                        why = "market closed") {
  if (is.data.frame(x) || identical(x$status, "success")) {
    failed <- FALSE
    if (!is.null(check)) {
      withCallingHandlers(check(x), expectation_failure = function(e) failed <<- TRUE)
    } else {
      succeed()
    }
    live_record(endpoint, if (failed) "failed" else "passed",
                if (failed) "success response with an unexpected shape" else "")
    return(!failed)
  }
  expect_true(is.list(x))
  expect_identical(x$status, "error")
  msg <- trimws(live_message(x))
  if (!is.null(x$code) && !startsWith(msg, "HTTP ")) msg <- sprintf("HTTP %s: %s", x$code, msg)
  if (!is.null(tolerate) && grepl(tolerate, msg, ignore.case = TRUE)) {
    live_record(endpoint, "tolerated", paste0(why, ": ", msg))
    return(FALSE)
  }
  live_record(endpoint, "failed", msg)
  fail(sprintf("%s returned an error: %s", endpoint, msg))
  FALSE
}

live_ltp <- function() {
  q <- live$quotes(symbol = "SBIN", exchange = "NSE")
  ltp <- suppressWarnings(as.numeric(q$data$ltp))
  if (length(ltp) != 1 || is.na(ltp) || ltp <= 0) ltp <- suppressWarnings(as.numeric(q$data$prev_close))
  if (length(ltp) != 1 || is.na(ltp) || ltp <= 0) ltp <- 500
  ltp
}

# A tick-aligned price far below the market, so a LIMIT BUY never fills.
far_price <- function(ltp, factor = 0.8) {
  round(floor(ltp * factor * 20) / 20, 2)
}

live_expiry <- function() {
  e <- live$expiry(symbol = "NIFTY", exchange = "NFO", instrumenttype = "options")
  if (!identical(e$status, "success") || length(e$data) == 0) return(NULL)
  gsub("-", "", e$data[[1]], fixed = TRUE)
}

test_that("analyzerstatus reports analyze (sandbox) mode", {
  live_expect("analyzerstatus", live_analyzer, function(x) {
    expect_true(isTRUE(x$data$analyze_mode))
    expect_identical(x$data$mode, "analyze")
  }, tolerate = NULL)
})

test_that("analyzertoggle keeps analyze mode", {
  # Only ever toggles to analyze mode, and only when already in it.
  skip_unless_sandbox()
  live_expect("analyzertoggle", live$analyzertoggle(TRUE), function(x) {
    expect_true(isTRUE(x$data$analyze_mode))
  }, tolerate = NULL)
  expect_true(isTRUE(live$analyzerstatus()$data$analyze_mode))
})

# The feed test runs early: late in a long live run the server's WebSocket
# handshake has been seen to time out, which a fresh process never showed.
test_that("live WebSocket feed", {
  skip_if_not_installed("websocket")
  ws_client <- api(api_key = Sys.getenv("OPENALGO_API_KEY"), host = live_host, verbose = 1)
  on.exit(capture.output(ws_client$disconnect()), add = TRUE)
  # Up to three attempts; the feed log explains a failure. The line that
  # shows the masked API key is never kept.
  ok <- FALSE
  log <- character(0)
  for (attempt in 1:3) {
    log <- capture.output(ok <- ws_client$connect())
    if (isTRUE(ok)) break
    capture.output(ws_client$wait(2))
  }
  ws_client$verbose <- 0L
  log <- log[!grepl("API key", log, fixed = TRUE)]
  live_expect("ws connect", if (isTRUE(ok)) list(status = "success") else
    list(status = "error", message = paste(c("connect() returned FALSE", log), collapse = " | ")),
    function(x) expect_true(ws_client$authenticated), tolerate = NULL)
  skip_if_not(isTRUE(ok), "WebSocket connection failed")

  sbin <- list(list(exchange = "NSE", symbol = "SBIN"))
  for (name in c("subscribe_ltp", "subscribe_quote", "subscribe_depth")) {
    live_expect(paste("ws", name), list(status = if (isTRUE(ws_client[[name]](sbin))) "success"
                                        else "error", message = "subscribe returned FALSE"),
                tolerate = NULL)
  }
  live_expect("ws subscribe_orders", list(status = if (isTRUE(ws_client$subscribe_orders()))
    "success" else "error", message = "subscribe returned FALSE"), tolerate = NULL)
  ws_client$wait(3)

  ltp <- ws_client$get_ltp()
  quotes <- ws_client$get_quotes()
  depth <- ws_client$get_depth()
  orders <- ws_client$get_orders()
  expect_identical(names(ltp), "ltp")
  expect_identical(names(quotes), "quote")
  expect_identical(names(depth), "depth")
  expect_identical(names(orders), "orders")
  getters <- list("ws get_ltp" = ltp$ltp, "ws get_quotes" = quotes$quote,
                  "ws get_depth" = depth$depth)
  for (name in names(getters)) {
    got <- getters[[name]]
    expect_true(is.list(got))
    if (!is.null(got$NSE$SBIN)) {
      live_record(name, "passed", "tick received")
    } else {
      live_record(name, "tolerated", "market closed: no tick received for NSE:SBIN")
    }
  }
  expect_true(is.list(orders$orders))
  live_record("ws get_orders", "passed", sprintf("%d order update(s)", length(orders$orders)))

  for (name in c("unsubscribe_ltp", "unsubscribe_quote", "unsubscribe_depth")) {
    live_expect(paste("ws", name), list(status = if (isTRUE(ws_client[[name]](sbin))) "success"
                                        else "error", message = "unsubscribe returned FALSE"),
                tolerate = NULL)
  }
  live_expect("ws unsubscribe_orders", list(status = if (isTRUE(ws_client$unsubscribe_orders()))
    "success" else "error", message = "unsubscribe returned FALSE"), tolerate = NULL)
  ws_client$disconnect()
  expect_false(ws_client$connected)
  expect_false(ws_client$authenticated)
  live_record("ws disconnect", "passed")
})

test_that("live WebSocket additions", {
  feed <- api(api_key = Sys.getenv("OPENALGO_API_KEY"), host = live_host)
  connected <- FALSE
  for (attempt in 1:3) {
    connected <- feed$connect()
    if (connected) break
  }
  skip_if_not(connected, "could not connect to the WebSocket feed")
  on.exit(feed$disconnect(), add = TRUE)

  brokers <- feed$get_supported_brokers()
  expect_identical(brokers$type, "supported_brokers")
  live_record("ws get_supported_brokers", "passed")
  info <- feed$get_broker_info()
  expect_identical(info$type, "broker_info")
  live_record("ws get_broker_info", "passed")
  pong <- feed$ws_ping()
  expect_identical(pong$type, "pong")
  expect_true(is.numeric(pong$latency_ms))
  live_record("ws ws_ping", "passed", sprintf("%.0f ms", pong$latency_ms))
  expect_true(feed$subscribe_depth(list(list(exchange = "NSE", symbol = "SBIN")), depth = 5))
  feed$wait(1)
  expect_true(feed$unsubscribe_all())
  live_record("ws subscribe_depth + unsubscribe_all", "passed")
})

test_that("account reads", {
  live_expect("funds", live$funds(), function(x) {
    expect_true(all(c("availablecash", "collateral", "m2mrealized", "m2munrealized") %in%
                      names(x$data)))
  }, tolerate = NULL)
  live_expect("orderbook", live$orderbook(), function(x) {
    expect_true(all(c("orders", "statistics") %in% names(x$data)))
  }, tolerate = NULL)
  live_expect("tradebook", live$tradebook(), function(x) expect_true(is.list(x$data)),
              tolerate = NULL)
  live_expect("positionbook", live$positionbook(), function(x) expect_true(is.list(x$data)),
              tolerate = NULL)
  live_expect("holdings", live$holdings(), function(x) {
    expect_true(all(c("holdings", "statistics") %in% names(x$data)))
  }, tolerate = NULL)
  live_expect("margin", live$margin(positions = list(
    list(symbol = "SBIN", exchange = "NSE", action = "BUY", product = "MIS", pricetype = "LIMIT",
         quantity = 1, price = far_price(live_ltp())))), function(x) {
    expect_true(is.numeric(x$data$total_margin_required))
  })
})

test_that("market data reads", {
  live_expect("quotes", live$quotes(symbol = "SBIN", exchange = "NSE"), function(x) {
    expect_true(all(c("ltp", "bid", "ask", "open", "high", "low") %in% names(x$data)))
    expect_true(is.numeric(x$data$ltp))
  })
  live_expect("multiquotes", live$multiquotes(symbols = list(
    list(symbol = "SBIN", exchange = "NSE"), list(symbol = "INFY", exchange = "NSE"))),
    function(x) {
      expect_length(x$results, 2L)
      expect_identical(vapply(x$results, function(r) r$symbol, ""), c("SBIN", "INFY"))
    })
  live_expect("depth", live$depth(symbol = "SBIN", exchange = "NSE"), function(x) {
    expect_true(all(c("bids", "asks", "ltp") %in% names(x$data)))
    expect_length(x$data$bids, 5L)
  })
  live_expect("symbol", live$symbol(symbol = "SBIN", exchange = "NSE"), function(x) {
    expect_identical(x$data$symbol, "SBIN")
    expect_identical(x$data$exchange, "NSE")
  }, tolerate = NULL)
  live_expect("search", live$search(query = "SBIN", exchange = "NSE"), function(x) {
    expect_true("SBIN" %in% vapply(x$data, function(r) r$symbol, ""))
  }, tolerate = NULL)
  iv <- live$intervals()
  live_expect("intervals", iv, function(x) {
    expect_true(all(c("minutes", "days") %in% names(x$data)))
    expect_true("1m" %in% unlist(x$data$minutes))
  }, tolerate = NULL)
  live_expect("interval", live$interval(), function(x) expect_identical(x, iv), tolerate = NULL)
})

test_that("history returns data frames for 1m and D", {
  live_expect("history 1m", live$history(symbol = "SBIN", exchange = "NSE", interval = "1m",
                                         start_date = format(Sys.Date() - 7),
                                         end_date = format(Sys.Date())), function(x) {
    expect_identical(names(x)[1], "timestamp")
    expect_identical(attr(x$timestamp, "tzone"), "Asia/Kolkata")
    expect_true(all(c("open", "high", "low", "close", "volume") %in% names(x)))
    expect_false(is.unsorted(x$timestamp, strictly = TRUE))
  })
  live_expect("history D", live$history(symbol = "SBIN", exchange = "NSE", interval = "D",
                                        start_date = format(Sys.Date() - 30),
                                        end_date = format(Sys.Date())), function(x) {
    expect_identical(names(x)[1], "timestamp")
    expect_identical(attr(x$timestamp, "tzone"), "UTC")
    expect_gt(nrow(x), 5L)
    expect_false(is.unsorted(x$timestamp, strictly = TRUE))
  })
})

test_that("instruments for one exchange and for all exchanges", {
  live_expect("instruments NSE", live$instruments(exchange = "NSE"), function(x) {
    expect_gt(nrow(x), 1000L)
    expect_true(all(c("symbol", "exchange", "lotsize", "tick_size") %in% names(x)))
    expect_true("SBIN" %in% x$symbol)
  }, tolerate = NULL)
  live_expect("instruments (all)", live$instruments(), function(x) {
    expect_true(all(c("NSE", "NFO") %in% x$exchange))
    expect_identical(rownames(x)[1], "1")
  }, tolerate = NULL)
})

test_that("expiry and the options analytics", {
  e <- live$expiry(symbol = "NIFTY", exchange = "NFO", instrumenttype = "options")
  live_expect("expiry", e, function(x) {
    expect_gt(length(x$data), 0L)
    expect_match(x$data[[1]], "^\\d{2}-[A-Z]{3}-\\d{2}$")
  }, tolerate = NULL)
  expiry <- live_expiry()
  skip_if(is.null(expiry), "no NIFTY option expiry available")

  os <- live$optionsymbol(underlying = "NIFTY", exchange = "NSE_INDEX", expiry_date = expiry,
                          offset = "ATM", option_type = "CE")
  live_expect("optionsymbol", os, function(x) {
    expect_match(x$symbol, paste0("^NIFTY", expiry, "\\d+CE$"))
    expect_identical(x$exchange, "NFO")
  })
  live_expect("optionchain", live$optionchain(underlying = "NIFTY", exchange = "NSE_INDEX",
                                              expiry_date = expiry, strike_count = 2),
              function(x) {
                expect_identical(x$underlying, "NIFTY")
                expect_identical(x$expiry_date, expiry)
              })
  sym <- if (is.character(os$symbol)) os$symbol else paste0("NIFTY", expiry, "25000CE")
  live_expect("optiongreeks", live$optiongreeks(symbol = sym, exchange = "NFO"), function(x) {
    expect_true(all(c("delta", "gamma", "theta", "vega") %in% names(x$greeks)))
  })
  live_expect("syntheticfuture", live$syntheticfuture(underlying = "NIFTY",
                                                      exchange = "NSE_INDEX",
                                                      expiry_date = expiry), function(x) {
    expect_identical(x$expiry, expiry)
    expect_true(is.numeric(x$synthetic_future_price))
  })
})

test_that("market calendar", {
  live_expect("holidays", live$holidays(), function(x) {
    expect_identical(as.integer(x$year), as.integer(format(Sys.Date(), "%Y")))
    expect_true(is.list(x$data))
  }, tolerate = NULL)
  live_expect("timings", live$timings(), function(x) expect_true(is.list(x$data)),
              tolerate = NULL)
  live_expect("timings (date)", live$timings(date = format(Sys.Date())),
              function(x) expect_true(is.list(x$data)), tolerate = NULL)
})

test_that("notifications", {
  live_expect("telegram", live$telegram(username = "openalgo_r_test", message = "R SDK live test"),
              function(x) succeed(), tolerate = not_configured, why = "not configured")
  live_expect("whatsapp", live$whatsapp("R SDK live test"), function(x) succeed(),
              tolerate = not_configured, why = "not configured")
})

test_that("sandbox order flow: place, status, modify, cancel", {
  skip_unless_sandbox()
  on.exit(live$cancelallorder(strategy = live_strategy), add = TRUE)
  ltp <- live_ltp()

  po <- live$placeorder(strategy = live_strategy, symbol = "SBIN", action = "BUY", exchange = "NSE",
                        price_type = "LIMIT", product = "CNC", quantity = 1, price = far_price(ltp))
  placed <- live_expect("placeorder", po, function(x) {
    expect_true(is.character(x$orderid) && nzchar(x$orderid))
  })
  order_id <- if (placed) po$orderid else "0"

  live_expect("orderstatus", live$orderstatus(order_id = order_id, strategy = live_strategy),
              function(x) {
                expect_identical(as.character(x$data$orderid), order_id)
                expect_identical(x$data$symbol, "SBIN")
                expect_identical(x$data$action, "BUY")
              }, tolerate = if (placed) NULL else closed_market)
  live_expect("modifyorder", live$modifyorder(
    order_id = order_id, strategy = live_strategy, symbol = "SBIN", action = "BUY",
    exchange = "NSE", price_type = "LIMIT", product = "CNC", quantity = 1,
    price = far_price(ltp, 0.79)), tolerate = if (placed) closed_market else ".")
  live_expect("cancelorder", live$cancelorder(order_id = order_id, strategy = live_strategy),
              function(x) expect_identical(as.character(x$orderid), order_id),
              tolerate = if (placed) closed_market else ".")
})

test_that("sandbox smart, basket, split and options orders, then cancel all", {
  skip_unless_sandbox()
  on.exit(live$cancelallorder(strategy = live_strategy), add = TRUE)
  price <- far_price(live_ltp())

  # The sandbox fills a smart order that has a quantity at market, whatever
  # the price type. quantity 0 with position_size 0 on a flat strategy is a
  # pure position match: the server answers success without placing an order.
  live_expect("placesmartorder", live$placesmartorder(
    strategy = live_strategy, symbol = "SBIN", action = "BUY", exchange = "NSE",
    price_type = "LIMIT", product = "CNC", quantity = 0, position_size = 0, price = price),
    function(x) expect_true(is.character(x$message) || is.character(x$orderid)))

  live_expect("basketorder", live$basketorder(strategy = live_strategy, orders = list(
    list(symbol = "SBIN", exchange = "NSE", action = "BUY", quantity = 1, pricetype = "LIMIT",
         product = "CNC", price = price),
    list(symbol = "SBIN", exchange = "NSE", action = "BUY", quantity = 1, pricetype = "LIMIT",
         product = "CNC", price = far_price(price, 0.98)))),
    function(x) expect_length(x$results, 2L))

  live_expect("splitorder", live$splitorder(
    strategy = live_strategy, symbol = "SBIN", action = "BUY", exchange = "NSE", quantity = 2,
    splitsize = 1, price_type = "LIMIT", product = "CNC", price = price),
    function(x) expect_length(x$results, 2L))

  expiry <- live_expiry()
  if (!is.null(expiry)) {
    # Deep out of the money option BUYs at the minimum tick never fill.
    live_expect("optionsorder", live$optionsorder(
      strategy = live_strategy, underlying = "NIFTY", exchange = "NSE_INDEX",
      expiry_date = expiry, offset = "OTM5", option_type = "CE", action = "BUY", quantity = 65,
      price_type = "LIMIT", product = "NRML", price = 0.05), function(x) {
        expect_true(is.character(x$orderid))
        expect_match(x$symbol, "^NIFTY.*CE$")
      })
    live_expect("optionsmultiorder", live$optionsmultiorder(
      strategy = live_strategy, underlying = "NIFTY", exchange = "NSE_INDEX",
      expiry_date = expiry, legs = list(
        list(offset = "OTM6", option_type = "CE", action = "BUY", quantity = 65,
             pricetype = "LIMIT", product = "NRML", price = 0.05),
        list(offset = "OTM6", option_type = "PE", action = "BUY", quantity = 65,
             pricetype = "LIMIT", product = "NRML", price = 0.05))),
      function(x) expect_length(x$results, 2L))
  }

  live_expect("openposition", live$openposition(strategy = live_strategy, symbol = "SBIN",
                                                exchange = "NSE", product = "CNC"),
              # Not asserted to be 0: positions are account-wide, so another
              # client of the same sandbox account may hold one.
              function(x) expect_false(is.na(suppressWarnings(as.numeric(x$quantity)))),
              tolerate = NULL)
  live_expect("cancelallorder", live$cancelallorder(strategy = live_strategy),
              function(x) expect_true(is.character(x$message)), tolerate = NULL)
  live_expect("closeposition", live$closeposition(strategy = live_strategy),
              function(x) expect_true(is.character(x$message)),
              tolerate = no_position, why = "no open position")
})

test_that("sandbox GTT place, modify and cancel", {
  skip_unless_sandbox()
  ltp <- live_ltp()
  price <- far_price(ltp)
  live_expect("gttorderbook", live$gttorderbook(), function(x) expect_true(is.list(x$data)),
              tolerate = NULL)
  gp <- live$placegttorder(strategy = live_strategy, symbol = "SBIN", action = "BUY",
                           exchange = "NSE", trigger_type = "SINGLE", product = "CNC",
                           quantity = 1, price = price, triggerprice_sl = price)
  placed <- live_expect("placegttorder", gp, function(x) {
    expect_true(is.character(x$trigger_id) && nzchar(x$trigger_id))
  })
  skip_if_not(placed, "GTT placement refused while the market is closed")
  trigger_id <- gp$trigger_id
  on.exit(live$cancelgttorder(trigger_id = trigger_id, strategy = live_strategy), add = TRUE)
  ids <- function(book) vapply(book$data, function(g) as.character(g$trigger_id), "")
  expect_true(trigger_id %in% ids(live$gttorderbook()))

  new_price <- far_price(ltp, 0.79)
  live_expect("modifygttorder", live$modifygttorder(
    trigger_id = trigger_id, strategy = live_strategy, symbol = "SBIN", action = "BUY",
    exchange = "NSE", trigger_type = "SINGLE", product = "CNC", quantity = 1, price = new_price,
    triggerprice_sl = new_price))
  live_expect("cancelgttorder", live$cancelgttorder(trigger_id = trigger_id,
                                                    strategy = live_strategy))
  expect_false(trigger_id %in% ids(live$gttorderbook()))
  live_expect("gttorderbook (all)", live$gttorderbook(status = "all"),
              function(x) expect_true(trigger_id %in% ids(x)), tolerate = NULL)
})

test_that("strategy module endpoints", {
  sl <- live$strategylist()
  live_expect("strategylist", sl, function(x) expect_true(is.list(x$data)), tolerate = NULL)
  live_expect("strategylist (filters)", live$strategylist(status = "stopped", q = "r"),
              function(x) expect_true(is.list(x$data)), tolerate = NULL)

  # Reads use a real strategy when the key owns one.
  read_id <- missing_strategy_id
  if (identical(sl$status, "success") && length(sl$data) > 0) read_id <- sl$data[[1]]$id
  reads <- list(
    strategystatus = function() live$strategystatus(strategy_id = read_id),
    strategyruns = function() live$strategyruns(strategy_id = read_id, limit = 5),
    strategyorders = function() live$strategyorders(strategy_id = read_id),
    strategyevents = function() live$strategyevents(strategy_id = read_id, limit = 5))
  for (name in names(reads)) {
    live_expect(name, reads[[name]](), function(x) succeed(), tolerate = no_strategy,
                why = "no strategy owned by this key")
  }

  # Lifecycle calls always target a strategy id that does not exist.
  skip_unless_sandbox()
  lifecycle <- list(
    strategystart = function() live$strategystart(strategy_id = missing_strategy_id,
                                                  mode = "sandbox"),
    strategystop = function() live$strategystop(strategy_id = missing_strategy_id),
    strategycloseall = function() live$strategycloseall(strategy_id = missing_strategy_id),
    strategycloseleg = function() live$strategycloseleg(strategy_id = missing_strategy_id,
                                                        leg_id = 1))
  for (name in names(lifecycle)) {
    res <- lifecycle[[name]]()
    expect_identical(res$code, 404L)
    live_expect(name, res, tolerate = no_strategy, why = "strategy id 999999 does not exist")
  }
})

test_that("strategy webhook round trip", {
  s <- Strategy(live_host, webhook_token = "oaws_unknown_token_for_r_live_tests")
  calls <- list(
    "webhook start" = function() s$start("sandbox"),
    "webhook stop" = function() s$stop(),
    "webhook long_entry" = function() s$long_entry(leg_id = 1),
    "webhook short_exit" = function() s$short_exit(symbol = "SBIN", exchange = "NSE"))
  for (name in names(calls)) {
    res <- calls[[name]]()
    expect_identical(res$code, 404L)
    expect_identical(res$result, "rejected_token")
    live_expect(name, res, tolerate = bad_token, why = "no webhook token available")
  }
  s$close()
})

test_that("additional endpoints beyond the Python SDK (read-only)", {
  live_expect("ping", live$ping(), function(x) {
    expect_identical(x$data$message, "pong")
  }, tolerate = NULL)
  live_expect("pnlsymbols", live$pnlsymbols(), function(x) {
    expect_true(is.list(x$data))
  }, tolerate = NULL)
  live_expect("chart", live$chart(), function(x) expect_true("data" %in% names(x)),
              tolerate = NULL)
  live_expect("ticker json", live$ticker(symbol = "SBIN", exchange = "NSE", interval = "D",
                                          start_date = format(Sys.Date() - 30),
                                          end_date = format(Sys.Date())),
              function(x) expect_true(is.list(x$data)))
  txt <- live$ticker(symbol = "SBIN", exchange = "NSE", interval = "D",
                     start_date = format(Sys.Date() - 30), end_date = format(Sys.Date()),
                     format = "txt")
  if (is.character(txt)) {
    expect_length(txt, 1L)
    live_record("ticker txt", "passed")
  } else {
    live_expect("ticker txt", txt)
  }
  expiry <- live_expiry()
  if (!is.null(expiry)) {
    chain <- live$optionchain(underlying = "NIFTY", exchange = "NSE_INDEX",
                              expiry_date = expiry, strike_count = 1)
    syms <- list()
    if (identical(chain$status, "success")) {
      for (row in chain$chain) {
        if (!is.null(row$ce$symbol)) syms[[length(syms) + 1L]] <- list(symbol = row$ce$symbol, exchange = "NFO")
        if (!is.null(row$pe$symbol)) syms[[length(syms) + 1L]] <- list(symbol = row$pe$symbol, exchange = "NFO")
      }
    }
    if (length(syms) > 0) {
      live_expect("multioptiongreeks", live$multioptiongreeks(symbols = syms[seq_len(min(2L, length(syms)))]),
                  function(x) expect_true(is.list(x$data)))
    }
  }
  live_expect("telegramconfig", live$telegramconfig(), tolerate = not_configured,
              why = "telegram not configured")
  live_expect("telegramusers", live$telegramusers(), tolerate = not_configured,
              why = "telegram not configured")
  live_expect("telegramstats", live$telegramstats(days = 7), tolerate = not_configured,
              why = "telegram not configured")
})

test_that("live endpoint outcomes", {
  rows <- do.call(rbind, live_outcomes$rows)
  expect_s3_class(rows, "data.frame")
  expect_false(any(rows$outcome == "failed"))
  cat("\nLive endpoint outcomes:\n")
  for (i in seq_len(nrow(rows))) {
    cat(sprintf("  %-24s %-9s %s\n", rows$endpoint[i], rows$outcome[i], rows$detail[i]))
  }
  cat(sprintf("  passed %d, tolerated %d, failed %d\n", sum(rows$outcome == "passed"),
              sum(rows$outcome == "tolerated"), sum(rows$outcome == "failed")))
})
