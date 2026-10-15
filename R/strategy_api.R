# Strategy module methods (Python: openalgo/strategy_api.py, class StrategyAPI).
#
# The API key surface of the OpenAlgo strategy module: multi-leg options
# strategies with end to end risk management, plus the signal driven mode that
# reacts to individual alerts. It covers the lifecycle and the reads only.
# Building a strategy stays in the browser wizard; nothing here can create a
# strategy, edit its configuration, enable live trading, rotate a webhook
# token or delete anything.
#
# Every route is a POST to /api/v1/strategy/<route> with the identifier in the
# body, sent through private$post (Python: BaseAPI._post), so a non-200 answer
# with a JSON body is returned with `code` attached rather than replaced.
#
# Vocabularies (exact and case-sensitive on the server, not exported here):
# run modes "live" and "sandbox"; strategy statuses "stopped", "running",
# "paused" and "errored"; event severities "info", "warn" and "critical".

#' List strategies
#'
#' List the strategies this API key owns, newest first.
#'
#' @section Usage:
#' ```
#' client$strategylist(status = NULL, q = NULL, ...)
#' ```
#' @section Arguments:
#' * `status`: Filter by strategy status: `"stopped"`, `"running"`,
#'   `"paused"` or `"errored"`. Optional. A value outside this vocabulary is a
#'   400, not an empty list.
#' * `q`: Case-insensitive substring match on the strategy name, 100
#'   characters at most. Optional.
#' * `...`: Passed through unchanged for future API extensions.
#'
#' `NULL` filters are not sent at all.
#' @return A named list `list(status = "success", data = list(...))` with one
#'   entry per strategy carrying `id`, `name`, `strategy_kind`, `direction`,
#'   `product`, the risk settings, `live_enabled`, `status`,
#'   `current_run_id` and `last_finalized_run`.
#'
#'   The list form omits `legs`; call [strategystatus] for one strategy's
#'   legs. For a stopped strategy, `last_finalized_run$pnl_realized` is the
#'   durable final P&L.
#' @examples
#' \dontrun{
#' client$strategylist(status = "running")
#' }
#' @family strategy module methods
#' @name strategylist
NULL

#' Get one strategy and its current run
#'
#' Get one strategy's full configuration including its legs, and its current
#' run.
#'
#' @section Usage:
#' ```
#' client$strategystatus(strategy_id, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer (sent as an integer).
#'   Required.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list with `status`, `data` and `run`. `run` is `NULL`
#'   whenever the strategy has no current run, the normal state of a stopped
#'   strategy.
#'
#'   A populated `run$stop_requested_reason` means a stop is durable but not
#'   yet confirmed flat: the run is still current and still managed.
#'   `run$resolved_expiries` is the snapshot taken at run start, so a
#'   positional strategy does not roll to a new contract mid-run. Prefer `run`
#'   over the strategy's own `status` to know whether anything is open. A
#'   strategy that is not yours answers 404, the same as one that does not
#'   exist.
#' @examples
#' \dontrun{
#' client$strategystatus(strategy_id = 12)
#' }
#' @family strategy module methods
#' @name strategystatus
NULL

#' Start a strategy run
#'
#' Start a run of a batch strategy. Every leg's entry order is placed.
#'
#' @section Usage:
#' ```
#' client$strategystart(strategy_id, mode, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `mode`: `"live"` or `"sandbox"`. Required, exact and case-sensitive, and
#'   never defaulted, here or on the server: omitting it is an error rather
#'   than a live order. It is passed through exactly as given, so a typo is
#'   refused by the server rather than read as sandbox. Live is opt-in per
#'   strategy: `mode = "live"` is refused with a 409 until live trading is
#'   enabled on the strategy page.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list with `status`, `run_id`, `mode` and `legs`, one entry
#'   per leg carrying `leg_id`, `ok`, `acknowledged`, `symbol`,
#'   `broker_order_id` and `error`.
#'
#'   Partial success is a 200: check `legs[[i]]$ok` rather than assuming every
#'   leg reached the market. `ok = TRUE` with `acknowledged = FALSE` is a real
#'   order whose id could not be written back, not a rejection; it reconciles
#'   itself. A run whose entries were all rejected is closed immediately and
#'   the call answers 400. A second start against a running strategy answers
#'   409. This is for batch strategies only: a signal strategy has no start,
#'   its first inbound signal after the session boundary opens the run.
#' @examples
#' \dontrun{
#' res <- client$strategystart(strategy_id = 12, mode = "sandbox")
#' vapply(res$legs, function(leg) isTRUE(leg$ok), logical(1))
#' }
#' @family strategy module methods
#' @name strategystart
NULL

#' Stop a strategy run
#'
#' Stop the strategy's current run: exit every owned position at market.
#'
#' @section Usage:
#' ```
#' client$strategystop(strategy_id, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required. The run is
#'   resolved from the strategy; a caller never supplies a run id.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list with `status`, `run_id`, `stop_pending` and `exits`,
#'   one entry per leg carrying `leg_id`, `ok`, `position_ref`, `exit_owner`
#'   and `error`.
#'
#'   An accepted stop is not necessarily flat: `stop_pending = TRUE` means the
#'   request is durable and its exits were accepted, but the run stays open
#'   and managed until fills prove every position is flat. Never infer
#'   flatness from the HTTP status. The answer is 409 when nothing is running,
#'   and a 409 can also carry `stop_pending = TRUE` when an unfilled entry or
#'   a refused exit still needs management: retry the stop in that case.
#' @examples
#' \dontrun{
#' res <- client$strategystop(strategy_id = 12)
#' isTRUE(res$stop_pending)
#' }
#' @family strategy module methods
#' @name strategystop
NULL

#' Close every leg of a strategy run
#'
#' Close every leg of the current run, recording an operator's intent. Same
#' stop mechanics as [strategystop] with a different audit trail: a
#' `close_all_manual` event is written before the stop persists. It proves an
#' operator asked for a flatten, not that the broker became flat
#' (`run_stopped` is that terminal evidence).
#'
#' @section Usage:
#' ```
#' client$strategycloseall(strategy_id, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list with `status`, `run_id`, `stop_pending` and `exits`,
#'   the same shape as [strategystop].
#' @examples
#' \dontrun{
#' client$strategycloseall(strategy_id = 12)
#' }
#' @family strategy module methods
#' @name strategycloseall
NULL

#' Close one leg of a strategy run
#'
#' Exit one leg of the current run at market. The run continues with the
#' other legs.
#'
#' @section Usage:
#' ```
#' client$strategycloseleg(strategy_id, leg_id, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `leg_id`: The leg's id within the strategy, the value in `legs[[i]]$id`
#'   of [strategystatus] (not an order id and not a run id). Sent as an
#'   integer. Required.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list with `status`, `run_id`, `leg_id`, `run_stopped` and
#'   `exits`.
#'
#'   `run_stopped` reports only what this call could prove: a broker normally
#'   acknowledges before the fill, so even the last accepted exit usually
#'   returns `FALSE` and the fill finalises the run later. A refused exit is a
#'   failure, not a close: read the per-leg `ok`. A `leg_id` that names no
#'   open leg is a 409, not a 404.
#' @examples
#' \dontrun{
#' client$strategycloseleg(strategy_id = 12, leg_id = 3)
#' }
#' @family strategy module methods
#' @name strategycloseleg
NULL

#' List the runs of a strategy
#'
#' Get every activation of a strategy, newest first.
#'
#' @section Usage:
#' ```
#' client$strategyruns(strategy_id, limit = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `limit`: How many runs to return, 1 to 500. Optional; the server default
#'   is 100. A value outside the range is a 400, not a clamp.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list `list(status = "success", data = list(...))` with one
#'   entry per run carrying `id`, `mode`, `broker`, `started_at`,
#'   `stopped_at`, `stop_reason`, `stop_requested_at`,
#'   `stop_requested_reason`, `pnl_realized`, `pnl_peak`, `pnl_trough`,
#'   `trigger_source`, `webhook_event_id` and `resolved_expiries`.
#'
#'   The first row is the current run only while `stopped_at` is `NULL`.
#'   `pnl_peak` and `pnl_trough` are authoritative only once the run has
#'   stopped. A market exit fills at the available price, so `pnl_realized`
#'   can differ from the threshold that caused the stop.
#' @examples
#' \dontrun{
#' client$strategyruns(strategy_id = 12, limit = 10)
#' }
#' @family strategy module methods
#' @name strategyruns
NULL

#' List the orders of a strategy
#'
#' Get every order the engine placed across a strategy's runs.
#'
#' @section Usage:
#' ```
#' client$strategyorders(strategy_id, run_id = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `run_id`: Narrow the result to one run. Optional. A run of another
#'   strategy matches nothing.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list `list(status = "success", data = list(...))` with one
#'   entry per order carrying `id`, `run_id`, `leg_id`, `kind`,
#'   `position_ref`, `broker_order_id`, `symbol`, `exchange`, `action`,
#'   `qty`, `product`, `pricetype`, `price`, `status`, `placed_at`,
#'   `filled_at`, `avg_fill_price`, `filled_qty` and `reject_reason`.
#'
#'   Rows are oldest first, so an entry always precedes its exit (the
#'   opposite order to [strategyruns] and [strategyevents]). A row is written
#'   before the broker answers, so an order can appear with status
#'   `"pending"` and a `NULL` `broker_order_id`. A positive `filled_qty`
#'   proves exposure in every status, including cancelled and rejected. There
#'   is no limit parameter; narrow with `run_id`.
#' @examples
#' \dontrun{
#' client$strategyorders(strategy_id = 12, run_id = 40)
#' }
#' @family strategy module methods
#' @name strategyorders
NULL

#' List the risk events of a strategy
#'
#' Get the risk event audit trail for a strategy, newest first. The trail is
#' append-only.
#'
#' @section Usage:
#' ```
#' client$strategyevents(strategy_id, run_id = NULL, kind = NULL,
#'                       severity = NULL, limit = NULL, ...)
#' ```
#' @section Arguments:
#' * `strategy_id`: Strategy id, a positive integer. Required.
#' * `run_id`: Narrow the result to one run. Optional. Configuration events
#'   carry a `NULL` run id, so this filter excludes them.
#' * `kind`: Filter by event kind. Optional. Must be a member of the event
#'   kind vocabulary; anything else is a 400.
#' * `severity`: `"info"`, `"warn"` or `"critical"`. Optional.
#' * `limit`: How many events to return, 1 to 1000. Optional; the server
#'   default is 500. A value outside the range is a 400, not a clamp.
#' * `...`: Passed through unchanged for future API extensions.
#' @return A named list `list(status = "success", data = list(...))` with one
#'   entry per event carrying `id`, `run_id`, `strategy_id`, `ts`, `kind`,
#'   `severity`, `leg_id`, `message` and `payload` (free-form, `NULL` on most
#'   events; do not assume one shape across kinds).
#'
#'   Event kinds not to ignore: `run_stop_requested` (info: the stop is
#'   durable and new signal entries are gated, not proof of flatness),
#'   `run_stop_failed` (critical: the broker refused a stop's exits and the
#'   run still holds those positions), `order_ack_unrecorded` (critical: an
#'   accepted order whose acknowledgement could not be written; it reconciles
#'   itself), `leg_expiry_fallback` (warn: a nearer expiry was used) and
#'   `flip_outgoing_exit_rejected` (critical: the outgoing side of a signal
#'   flip is still held).
#' @examples
#' \dontrun{
#' client$strategyevents(strategy_id = 12, severity = "critical", limit = 50)
#' }
#' @family strategy module methods
#' @name strategyevents
NULL

strategy_api_private <- list(
  # POST to a strategy/ route, dropping unset optional filters: a NULL filter
  # is the same as omitting it, so it is not sent at all rather than as null.
  # Call it with `endpoint =` and `payload =` named, so a caller's extra field
  # can never be partially matched to them.
  strategy_request = function(endpoint, payload, ...) {
    kwargs <- dots_kwargs(...)
    payload <- add_kwargs(payload, kwargs)
    private$post(paste0("strategy/", endpoint), payload)
  }
)

strategy_api_public <- list(
  strategylist = function(..., status = NULL, q = NULL) {
    private$strategy_request(endpoint = "list", payload = list(apikey = self$api_key),
                             status = status, q = q, ...)
  },

  strategystatus = function(..., strategy_id) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "status", payload = payload, ...)
  },

  strategystart = function(..., strategy_id, mode) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id),
      # Passed through exactly as given: not lower-cased or otherwise
      # normalised, so the server's strictness stands.
      mode = mode
    )
    private$strategy_request(endpoint = "start", payload = payload, ...)
  },

  strategystop = function(..., strategy_id) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "stop", payload = payload, ...)
  },

  strategycloseall = function(..., strategy_id) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "close_all", payload = payload, ...)
  },

  strategycloseleg = function(..., strategy_id, leg_id) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id),
      leg_id = as_py_int(leg_id)
    )
    private$strategy_request(endpoint = "close_leg", payload = payload, ...)
  },

  strategyruns = function(..., strategy_id, limit = NULL) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "runs", payload = payload, limit = limit, ...)
  },

  strategyorders = function(..., strategy_id, run_id = NULL) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "orders", payload = payload, run_id = run_id, ...)
  },

  strategyevents = function(..., strategy_id, run_id = NULL, kind = NULL, severity = NULL,
                            limit = NULL) {
    payload <- list(
      apikey = self$api_key,
      strategy_id = as_py_int(strategy_id)
    )
    private$strategy_request(endpoint = "events", payload = payload, run_id = run_id,
                             kind = kind, severity = severity, limit = limit, ...)
  }
)
