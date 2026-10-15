# WhatsApp notification method (Python: openalgo/whatsapp.py, class WhatsAppAPI).
#
# One ergonomic call, client$whatsapp("message"), translated into the exact
# JSON shape the server's notify endpoint expects (multi-recipient broadcast
# capped at 5, image and document attachments).

#' Send a WhatsApp message
#'
#' Send a WhatsApp message through the device paired with the OpenAlgo
#' server. One call handles every common case: send to yourself, to a single
#' number or to a small broadcast (at most 5 recipients), with text, an image
#' or a document. The server must already be paired to a WhatsApp account
#' from the `/whatsapp` admin page; pairing is deliberately not exposed through
#' the API, so a leaked API key cannot re-pair the device.
#'
#' Prerequisites:
#' 1. The WhatsApp device must be paired: open `/whatsapp` in the OpenAlgo web
#'    UI and scan the QR code with your phone.
#' 2. The bot must be connected. It reconnects on every server boot from the
#'    encrypted session stored in the OpenAlgo database.
#' 3. The API key must be active.
#'
#' @section Usage:
#' ```
#' client$whatsapp(message = NULL, ..., to = NULL, username = NULL,
#'                 image = NULL, document = NULL, caption = NULL,
#'                 filename = NULL, wait_for_delivery = TRUE)
#' ```
#' @section Arguments:
#' Recipient (give one form; the message goes to yourself when none is
#' given). Every argument except `message` must be named.
#' * `to`: A single phone number as a string of E.164 digits, for example
#'   `"919876543210"`, or a list or character vector of up to 5 such numbers.
#'   Numbers beyond 5 are dropped server-side, a safety guardrail because
#'   bulk-messaging patterns can get the paired device unlinked.
#' * `username`: An OpenAlgo username, resolved through the linked-users table
#'   on the server. Takes precedence over `to`.
#'
#' Content (combine freely):
#' * `message`: Plain text body, at most 4096 characters. May be given
#'   positionally.
#' * `image`: Server-local path to an image file. The caption falls back to
#'   `message` when no `caption` is given.
#' * `document`: Server-local path to a document (PDF, CSV and so on).
#' * `caption`: Caption for an image, or follow-up text for a document.
#' * `filename`: Display name of the document on the recipient's device.
#'
#' Behaviour:
#' * `wait_for_delivery`: When `TRUE` (default) the call blocks until
#'   WhatsApp confirms delivery and returns a per-recipient report. Set it to
#'   `FALSE` for fire-and-forget; the response is a generic "queued"
#'   acknowledgement.
#' * `...`: Extra named fields, sent unchanged unless the payload already has
#'   that key.
#' @return A named list with the JSON response. With
#'   `wait_for_delivery = TRUE`:
#'   `list(status = "success", message = "Delivered to 1, failed 0",
#'   data = list(sent = list("<self>"), failed = list(), skipped = 0))`.
#'   With `wait_for_delivery = FALSE`:
#'   `list(status = "success", message = "Queued for 1 recipient(s)",
#'   queued = 1)`.
#'
#' Common error messages: "WhatsApp is not paired or not connected..." (pair
#' the device from the `/whatsapp` page), "Username not found or not linked to
#' WhatsApp", "image_path is not allowed" or "document_path is not allowed"
#' (the path is outside the server's attachment allowlist, contains traversal
#' tokens or points to a sensitive system tree), "Provide at least one of:
#' message, image_path, document_path" (empty payload) and "Invalid or missing
#' API key".
#'
#' Rate limits: 30 requests per minute by default, 5 per minute for
#' multi-recipient broadcasts; the server answers 429 above that.
#'
#' Attachments are read from the OpenAlgo server's filesystem, not uploaded
#' by the call: place files under the server's attachment roots (by default
#' `db/attachments/` in the OpenAlgo folder). This method uses the notify
#' endpoint, the only public REST surface for WhatsApp; pairing, start and
#' stop, users, configuration, broadcast, statistics and preferences are
#' admin-only in the web UI.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#'
#' # Send to yourself
#' client$whatsapp("Build #482 deployed. P&L: +1.2 percent")
#'
#' # Send to a single number
#' client$whatsapp("Are you free for a quick call?", to = "919876543210")
#'
#' # Small broadcast (up to 5 numbers)
#' client$whatsapp("Server maintenance in 10 minutes",
#'                 to = c("919876543210", "919812345678", "919900112233"))
#'
#' # Send a chart image with a caption
#' client$whatsapp("NIFTY end-of-day chart", to = "919876543210",
#'                 image = "/srv/charts/nifty_eod.png")
#'
#' # Send a daily report PDF
#' client$whatsapp("Daily P&L report attached", username = "alice",
#'                 document = "/srv/reports/2026-05-17.pdf",
#'                 filename = "summary.pdf")
#'
#' # Fire-and-forget for time-critical alerts
#' client$whatsapp("Stop-loss hit on BANKNIFTY!", wait_for_delivery = FALSE)
#' }
#' @family notification methods
#' @name whatsapp
NULL

whatsapp_public <- list(
  whatsapp = function(message = NULL, ..., to = NULL, username = NULL, image = NULL,
                      document = NULL, caption = NULL, filename = NULL,
                      wait_for_delivery = TRUE) {
    kwargs <- dots_kwargs(...)

    # Pick exactly one of self / username / phone / phones, defaulting to
    # self so the simplest call sends to the operator.
    payload <- list(apikey = self$api_key)

    if (py_truthy(username)) {
      payload["username"] <- list(username)
    } else if (is.list(to) || (is.character(to) && length(to) > 1)) {
      payload["phones"] <- list(unname(as.list(to)))
    } else if (is.character(to) && length(to) == 1 && !is.na(to) &&
               nzchar(trimws(to, whitespace = "[\\h\\v]"))) {
      payload[["phone"]] <- to
    } else {
      payload[["self"]] <- TRUE
    }

    if (!is.null(message)) payload["message"] <- list(message)
    if (!is.null(image)) payload["image_path"] <- list(image)
    if (!is.null(document)) payload["document_path"] <- list(document)
    if (!is.null(caption)) payload["caption"] <- list(caption)
    if (!is.null(filename)) payload["filename"] <- list(filename)
    payload[["wait_for_delivery"]] <- py_truthy(wait_for_delivery)

    # Forward unrecognised fields verbatim so future server-side fields work
    # without a package release.
    payload <- add_kwargs(payload, kwargs, skip_existing = TRUE)

    private$make_request("whatsapp/notify", payload)
  }
)
