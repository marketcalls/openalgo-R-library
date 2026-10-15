# openalgo 1.0.0

First release of the R client for OpenAlgo, the self-hosted algorithmic trading platform.
It lets you place and manage orders, read positions and funds, pull historical candles
into a `data.frame`, work with option chains and Greeks, run the strategy module and
stream live prices and order updates from R, RStudio or a scheduled `Rscript` job. It
needs R 4.1 or newer.

## Orders

* Place, smart, basket and split orders, modify, cancel, cancel all, close position,
  order status and open position.
* Options orders by offset (ATM, ITMn, OTMn), multi-leg options orders with the same or
  different expiries, and option symbol lookup.
* GTT orders (SINGLE and OCO): place, modify, cancel and the GTT order book, with an
  impossible trigger refused locally before anything is sent.

## Market data

* Quotes, multi-quotes, market depth, symbol details, search, expiry dates, intervals,
  instruments (as a `data.frame`) and synthetic futures.
* `history()` returns a `data.frame` with a `POSIXct` `timestamp` first column, from the
  broker or from the server's stored data.
* `ticker()` returns candles as JSON records or as plain text rows.
* Option chain, option Greeks for one option and `multioptiongreeks()` for up to 50
  options in one request.

## Account and utilities

* Funds, margin, order book, trade book, position book and holdings.
* `ping()` checks that the API key works and the broker session is logged in.
* Analyzer (sandbox) mode status and toggle, and `pnlsymbols()` for today's P&L per
  symbol in sandbox mode.
* Market holidays and timings.
* Chart preferences: `chart()` and `updatechart()`.

## Notifications

* Telegram alerts with `telegram()`, and Telegram bot management: configuration, start
  and stop, linked users, broadcast, statistics and per-user preferences.
* WhatsApp messages with `whatsapp()`: to yourself, one number or up to 5 numbers, with
  text, images or documents.

## Strategy module

* Strategy list, status, start, stop, close all, close leg, runs, orders and events, with
  `mode` required on start.
* `Strategy()` webhook client for batch (`start`, `stop`) and signal (`long_entry`,
  `long_exit`, `short_entry`, `short_exit`) strategies. Every documented outcome is
  returned with its `result` label, and the webhook token is never printed.

## WebSocket feed

* LTP, quotes, market depth (5, 20, 30 or 50 levels, broker dependent) and account
  order updates, with callbacks or polling snapshots.
* `unsubscribe_all()`, `get_broker_info()`, `get_supported_brokers()` and `ws_ping()`.
* Callbacks run on the R event loop; scripts keep the feed running with
  `client$wait(seconds)`.
* An `https://` host connects the feed to `wss://<domain>/ws` automatically; `ws_url`
  overrides it.
* Three verbose levels and auto-reconnect that re-authenticates and replays every
  subscription.

## Errors

* Failures are returned as lists with `status = "error"`, a `message` and an
  `error_type`, never raised, so a trading loop handles them like any other response.

## Testing

* Mock tests run against local mock servers, need no OpenAlgo server or API key, and are
  CRAN-safe.
* Live tests run only when `OPENALGO_API_KEY` is set (server address from
  `OPENALGO_HOST`, default `http://127.0.0.1:5000`) and place orders only when the server
  is in analyzer (sandbox) mode.
* The live tests and the slow mock tests are skipped on CRAN; set `NOT_CRAN=true` to run
  them.
