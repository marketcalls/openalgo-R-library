# Telegram notification method (Python: openalgo/telegram.py, class TelegramAPI).

#' Send a Telegram alert
#'
#' Send a custom alert message to a Telegram user linked to OpenAlgo. All
#' parameters must be named.
#'
#' Prerequisites:
#' 1. The Telegram bot must be running (start it from the OpenAlgo Telegram
#'    settings).
#' 2. The user must have linked their account with the `/link` command in
#'    Telegram. The username is the OpenAlgo login username, not the Telegram
#'    handle.
#' 3. The API key must be active and valid.
#'
#' @section Usage:
#' ```
#' client$telegram(username, message, priority = 5, ...)
#' ```
#' @section Arguments:
#' * `username`: OpenAlgo login username (case-sensitive; the username used
#'   to log in to OpenAlgo, not the Telegram username). Required.
#' * `message`: Alert message to send. Supports Markdown and line breaks.
#'   Maximum length 4096 characters (Telegram limit). Required.
#' * `priority`: Message priority from 1 to 10, higher is more urgent.
#'   Defaults to 5. Levels: 1 to 3 low (general updates, market news), 4 to 6
#'   normal (trade signals, daily summaries), 7 to 8 high (price alerts,
#'   position updates), 9 to 10 urgent (stop loss hits, risk alerts).
#' * `...`: Optional additional fields for future API extensions.
#'
#' Message formatting: bold `*text*` or `**text**`, italic `_text_` or
#' `__text__`, code with backticks, links as `[text](url)`.
#' @return A named list with `status` (`"success"` or `"error"`) and
#'   `message`.
#'
#' Common error messages: "Invalid or missing API key" (the key is incorrect
#' or expired), "User not found or not linked to Telegram" (the account is not
#' linked, or the wrong username was used), "Username and message are
#' required" and "Failed to send notification" (the bot is not running).
#' The server allows 30 requests per minute per user and answers 429 above
#' that. Messages are queued if delivery fails temporarily.
#' @examples
#' \dontrun{
#' client <- api(api_key = "your_api_key", host = "http://127.0.0.1:5000")
#'
#' # Basic notification
#' client$telegram(username = "john_trader",
#'                 message = "NIFTY crossed 24000! Consider taking profit.")
#'
#' # High priority alert
#' client$telegram(username = "john_trader",
#'                 message = "URGENT: Stop loss hit on BANKNIFTY position!",
#'                 priority = 10)
#'
#' # Multi-line trading summary
#' client$telegram(username = "john_trader",
#'                 message = paste("Daily Trading Summary",
#'                                 "Winning Trades: 8",
#'                                 "Losing Trades: 2",
#'                                 "Win Rate: 80 percent", sep = "\n"),
#'                 priority = 5)
#' }
#' @family notification methods
#' @name telegram
NULL

telegram_public <- list(
  telegram = function(..., username, message, priority = 5) {
    kwargs <- dots_kwargs(...)
    payload <- list(
      apikey = self$api_key,
      username = username,
      message = message,
      priority = priority
    )
    payload <- add_kwargs(payload, kwargs)
    private$make_request("telegram/notify", payload)
  }
)
