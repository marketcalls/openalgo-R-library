# openalgo 1.0.0

First release of the R client for OpenAlgo, the self-hosted algorithmic trading platform.
It lets you place and manage orders, read positions and funds, pull historical candles
into a `data.frame`, work with option chains and Greeks, run the strategy module and
stream live prices and order updates from R, RStudio or a scheduled `Rscript` job. It is
installed from GitHub (`remotes::install_github("marketcalls/openalgo-R-library")`), not
from CRAN, and needs R 4.1 or newer.

## What it covers

* Mirrors the OpenAlgo Python SDK 2.0.5: the same method names, parameter names and
  defaults (including the default strategy name `"Python"`), the same request payloads,
  the same response shapes and the same error lists with their `error_type` values. Code
  and documentation written for the Python SDK carry over method by method.
* REST: orders (place, smart, basket, split, modify, cancel, cancel all, close position,
  order status, open position), GTT orders with the Python SDK's local trigger
  validation, market data (quotes, multi-quotes, depth, symbol, search, history,
  intervals, expiry, instruments, synthetic future), account (funds, order book, trade
  book, position book, holdings, margin, analyzer status and toggle), options (option
  Greeks, options order, option symbol, options multi-order, option chain), the strategy
  module, Telegram and WhatsApp notifications, and market holidays and timings.
* The strategy webhook client (`Strategy()`), with the token never printed.
* The WebSocket feed: LTP, quotes, depth and account order updates, with polling
  snapshots, three verbose levels and auto-reconnect that replays every subscription.
* Decimal values are sent exactly as the Python SDK sends them (the shortest round-trip
  representation, as Python's `json.dumps` writes it), so the same order reaches the
  server with the same digits from either SDK.

## Additions not in the Python SDK

* REST methods for documented server endpoints the Python SDK does not wrap: `ping()`,
  `pnlsymbols()`, `multioptiongreeks(symbols, interest_rate, expiry_time)`,
  `ticker(symbol, exchange, interval = "D", start_date, end_date, format = "json")` (also
  `format = "txt"`), `chart()`, `updatechart(...)`, `telegramconfig()`,
  `updatetelegramconfig(...)`, `telegramstart()`, `telegramstop()`,
  `telegramusers(...)`, `telegrambroadcast(message, ...)`, `telegramstats(days)`,
  `telegrampreferences(telegram_id)` and `updatetelegrampreferences(telegram_id, ...)`.
* Hosted servers: an `https://yourdomain.com` host gives the feed URL
  `wss://yourdomain.com/ws` automatically. The Python SDK always builds
  `ws://<host>:8765`. An explicit `ws_url` still overrides both.
* `subscribe_depth(..., depth = 5)` requests 20, 30 or 50 levels where the broker
  supports them; the level is replayed on reconnect.
* Feed methods for server actions the Python SDK does not send: `unsubscribe_all()`,
  `get_broker_info(timeout)`, `get_supported_brokers(timeout)` and `ws_ping(timeout)`
  (round trip in `latency_ms`).
* At `verbose = 1` the feed also prints server error frames and the server's unsubscribe
  acknowledgements.

## Known differences from the Python SDK

* Methods are called with `$` and named arguments; an unnamed extra argument is an error.
  Python `dict`, `True`/`False`/`None` and pandas DataFrames map to named lists,
  `TRUE`/`FALSE`/`NULL` and `data.frame`.
* `history()` returns a `data.frame` with `timestamp` as its first column (`POSIXct`,
  `Asia/Kolkata` for intraday, `UTC` for daily, weekly and monthly) instead of a
  timestamp index.
* R is single threaded, so the feed runs on the `later` event loop rather than a
  background thread. Scripts call `client$wait(seconds)` where a Python script would
  call `time.sleep()`, and `wait()`, `connect()` and the feed query methods must not be
  called from inside a feed callback.
* The WebSocket `ping_interval` and `ping_timeout` settings are not configurable.
* `client$close()` replaces the Python context manager.
* With an `https://` host the R client connects to `wss://<domain>/ws`, while a Python
  script given the same host tries `ws://<domain>:8765`.

## Not included

* Technical indicators (`openalgo.ta`).
* The server's portfolio backtester (`/api/v1/portfolio/*`) and SIP backtester
  (`/api/v1/sip/*`) endpoints. The server has them, but they are not in the public API
  documentation, so the client does not wrap them.

## Testing

* Mock tests run against local mock servers, need no OpenAlgo server or API key, and are
  CRAN-safe.
* Live tests run only when `OPENALGO_API_KEY` is set (server address from
  `OPENALGO_HOST`, default `http://127.0.0.1:5000`) and place orders only when the server
  is in analyzer (sandbox) mode.
* The live tests and the slow mock tests are skipped on CRAN; set `NOT_CRAN=true` to run
  them.
