#!/usr/bin/env Rscript
# Parity runner for the R client: executes every scenario in scenarios.json
# against the mock server and writes out/r.json for compare.py.
#
# Usage:
#   Rscript run_r.R [--installed] [--only TEXT] [--out PATH] [--python PATH] [--mock-url URL]
#
# By default the package is loaded from this repository's working tree by
# sourcing R/*.R in the DESCRIPTION Collate order (no install needed).
# --installed uses library(openalgo) instead. The mock server is started with
# --python (default "python") unless --mock-url points at a running one.

suppressPackageStartupMessages({
  library(jsonlite)
  library(curl)
})

script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(f)) dirname(normalizePath(f[1], winslash = "/")) else normalizePath(getwd(), winslash = "/")
}
HERE <- script_dir()
REPO <- normalizePath(file.path(HERE, "..", ".."), winslash = "/")
OUT_DIR <- file.path(HERE, "out")

parse_args <- function(argv) {
  opts <- list(installed = FALSE, only = NULL, out = file.path(OUT_DIR, "r.json"),
               python = Sys.getenv("PARITY_PYTHON", "python"), mock_url = NULL)
  i <- 1
  while (i <= length(argv)) {
    a <- argv[i]
    if (a == "--installed") {
      opts$installed <- TRUE
    } else if (a %in% c("--only", "--out", "--python", "--mock-url")) {
      opts[[sub("-", "_", substring(a, 3), fixed = TRUE)]] <- argv[i + 1]
      i <- i + 1
    } else {
      stop("unknown argument: ", a)
    }
    i <- i + 1
  }
  opts
}

# ---------------------------------------------------------------- loading
load_openalgo <- function(installed) {
  if (installed) {
    suppressPackageStartupMessages(library(openalgo))
    return(list(api = openalgo::api, Strategy = openalgo::Strategy,
                how = paste("installed", as.character(utils::packageVersion("openalgo")))))
  }
  desc <- read.dcf(file.path(REPO, "DESCRIPTION"))
  collate <- scan(text = desc[1, "Collate"], what = "", quiet = TRUE)
  files <- file.path(REPO, "R", collate)
  missing <- files[!file.exists(files)]
  if (length(missing)) {
    stop("R package incomplete, missing: ", paste(basename(missing), collapse = ", "))
  }
  for (p in c("R6", "curl", "jsonlite", "websocket", "later")) {
    suppressPackageStartupMessages(library(p, character.only = TRUE))
  }
  env <- new.env(parent = globalenv())
  for (f in files) sys.source(f, envir = env, keep.source = FALSE)
  list(api = get("api", envir = env), Strategy = get("Strategy", envir = env),
       how = paste("sourced from", file.path(REPO, "R")))
}

# ------------------------------------------------------------ mock server
http_text <- function(url, body = NULL) {
  h <- curl::new_handle()
  if (!is.null(body)) {
    curl::handle_setopt(h, copypostfields = body)
    curl::handle_setheaders(h, "Content-Type" = "application/json")
  }
  r <- curl::curl_fetch_memory(url, handle = h)
  txt <- rawToChar(r$content)
  Encoding(txt) <- "UTF-8"
  txt
}

start_mock <- function(python, mock_url) {
  dir.create(OUT_DIR, showWarnings = FALSE)
  if (!is.null(mock_url)) {
    base <- sub("/+$", "", mock_url)
  } else {
    pf <- file.path(OUT_DIR, "mock_port_r.txt")
    unlink(pf)
    logf <- file.path(OUT_DIR, "mock_server_r.log")
    system2(python, c(shQuote(file.path(HERE, "mock_server.py")), "--port", "0",
                      "--port-file", shQuote(pf),
                      "--log", shQuote(file.path(OUT_DIR, "requests_r.jsonl"))),
            wait = FALSE, stdout = logf, stderr = logf)
    deadline <- Sys.time() + 20
    while (!file.exists(pf)) {
      if (Sys.time() > deadline) stop("mock server did not start; see ", logf)
      Sys.sleep(0.05)
    }
    Sys.sleep(0.05)
    base <- paste0("http://127.0.0.1:", trimws(readLines(pf, warn = FALSE)[1]))
  }
  info <- jsonlite::fromJSON(http_text(paste0(base, "/__control__/ping")), simplifyVector = FALSE)
  list(base = base, closed = paste0("http://127.0.0.1:", info$closed_port), spawned = is.null(mock_url))
}

# ----------------------------------------------------- argument decoding
# Language-neutral JSON -> idiomatic R:
#   string -> character(1), number -> double, boolean -> logical, null -> NULL,
#   object -> named list, array of scalars -> atomic vector c(...),
#   array of objects -> list of named lists, {"$list": [...]} -> unnamed list().
to_r <- function(v) {
  if (is.null(v)) return(NULL)
  if (is.list(v)) {
    nm <- names(v)
    if (!is.null(nm)) {
      if (identical(nm, "$list")) return(lapply(v[["$list"]], to_r))
      out <- list()
      for (k in nm) out[k] <- list(to_r(v[[k]]))
      return(out)
    }
    if (length(v) == 0) return(list())
    items <- lapply(v, to_r)
    scalar <- vapply(items, function(x) !is.null(x) && is.atomic(x) && length(x) == 1, logical(1))
    if (all(scalar) && length(unique(vapply(items, typeof, ""))) == 1) return(unlist(items))
    return(items)
  }
  if (is.integer(v)) return(as.numeric(v))
  v
}

substitute_hosts <- function(x, mock) {
  if (is.character(x)) {
    x <- gsub("$MOCK", mock$base, x, fixed = TRUE)
    x <- gsub("$CLOSED", mock$closed, x, fixed = TRUE)
  }
  x
}

# ------------------------------------------------------ result normalizing
iso_time <- function(x) {
  x <- as.POSIXct(x)
  tz <- attr(x, "tzone")
  tz <- if (is.null(tz) || !nzchar(tz[1])) "" else tz[1]
  s <- format(x, "%Y-%m-%dT%H:%M:%S%z", tz = tz)
  s <- sub("([+-][0-9]{2})([0-9]{2})$", "\\1:\\2", s)
  s[is.na(x)] <- NA_character_
  s
}

scalar <- function(v) {
  if (is.na(v)) return(NULL)
  if (is.double(v) && !is.finite(v)) return(NULL)
  v
}

named_empty <- function() setNames(list(), character(0))

normalize <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) return(normalize_frame(x))
  if (inherits(x, "POSIXt")) x <- iso_time(x)
  if (inherits(x, "Date")) x <- format(x, "%Y-%m-%d")
  if (is.factor(x)) x <- as.character(x)
  if (is.environment(x) || is.function(x)) return(paste0("<", class(x)[1], ">"))
  if (is.list(x)) {
    nm <- names(x)
    if (!is.null(nm)) {
      out <- named_empty()
      for (i in seq_along(x)) out[nm[i]] <- list(normalize(x[[i]]))
      return(out)
    }
    return(lapply(x, normalize))
  }
  if (is.atomic(x)) {
    if (!is.null(names(x))) {
      out <- named_empty()
      for (i in seq_along(x)) out[names(x)[i]] <- list(scalar(unname(x[i])))
      return(out)
    }
    if (length(x) == 1) return(scalar(x))
    return(lapply(seq_along(x), function(i) scalar(x[[i]])))
  }
  paste0("<", class(x)[1], ">")
}

normalize_frame <- function(df) {
  cols <- names(df)
  tz <- named_empty()
  conv <- list()
  for (j in seq_along(cols)) {
    v <- df[[j]]
    if (inherits(v, "POSIXt")) {
      t <- attr(as.POSIXct(v), "tzone")
      tz[cols[j]] <- list(if (is.null(t) || !nzchar(t[1])) "" else t[1])
      v <- iso_time(v)
    } else if (inherits(v, "Date")) {
      tz[cols[j]] <- list(NULL)
      v <- format(v, "%Y-%m-%d")
    } else if (is.factor(v)) {
      v <- as.character(v)
    }
    conv[[j]] <- v
  }
  rn <- if (.row_names_info(df) > 0) rownames(df) else NULL
  records <- lapply(seq_len(nrow(df)), function(i) {
    rec <- named_empty()
    if (!is.null(rn)) rec["__rownames__"] <- list(rn[i])
    for (j in seq_along(cols)) rec[cols[j]] <- list(normalize(conv[[j]][[i]]))
    rec
  })
  list(`__type__` = "table",
       columns = as.list(c(if (!is.null(rn)) "__rownames__", cols)),
       nrow = nrow(df), tz = tz, records = records)
}

# ---------------------------------------------------------------- running
run_scenario <- function(lib, mock, sc, api_key) {
  http_text(paste0(mock$base, "/__control__/scenario"),
            jsonlite::toJSON(list(id = sc$id, rules = sc$rules %||% list()),
                             auto_unbox = TRUE, null = "null", digits = I(17)))
  args <- to_r(sc$args)
  if (is.null(args)) args <- list()
  warns <- character(0)
  obj <- NULL
  outcome <- withCallingHandlers(
    tryCatch({
      if (identical(sc$target, "strategy")) {
        ctor <- lapply(to_r(sc$strategy) %||% list(), substitute_hosts, mock = mock)
        obj <- do.call(lib$Strategy, ctor)
      } else {
        copts <- to_r(sc$client) %||% list()
        if (is.null(copts$host)) copts$host <- "$MOCK"
        copts <- lapply(copts, substitute_hosts, mock = mock)
        obj <- do.call(lib$api, c(list(api_key = api_key), copts))
      }
      member <- obj[[sc$method]]
      if (is.null(member)) stop("no method or field named '", sc$method, "'")
      value <- if (isTRUE(sc$property)) {
        if (is.function(member)) member() else member
      } else {
        do.call(member, args)
      }
      list(raised = FALSE, value = normalize(value))
    }, error = function(e) {
      list(raised = TRUE, error_class = class(e)[1], message = conditionMessage(e))
    }),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  if (!is.null(obj) && !is.null(obj[["close"]]) && is.function(obj[["close"]])) {
    try(obj$close(), silent = TRUE)
  }
  reqs <- http_text(paste0(mock$base, "/__control__/requests?bare=1&id=", curl::curl_escape(sc$id)))
  list(requests = structure(reqs, class = "json"), outcome = outcome, warnings = as.list(warns))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

main <- function() {
  opts <- parse_args(commandArgs(trailingOnly = TRUE))
  lib <- load_openalgo(opts$installed)
  doc <- jsonlite::read_json(file.path(HERE, "scenarios.json"), simplifyVector = FALSE)
  mock <- start_mock(opts$python, opts$mock_url)
  on.exit(if (mock$spawned) try(http_text(paste0(mock$base, "/__control__/shutdown"), "{}"), silent = TRUE))
  results <- named_empty()
  t0 <- Sys.time()
  for (sc in doc$scenarios) {
    if (!is.null(opts$only) && !grepl(opts$only, sc$id, fixed = TRUE)) next
    t <- Sys.time()
    res <- run_scenario(lib, mock, sc, doc$api_key)
    res$seconds <- round(as.numeric(difftime(Sys.time(), t, units = "secs")), 3)
    results[[sc$id]] <- res
    cat(sprintf("%-55s %s\n", sc$id, if (isTRUE(res$outcome$raised)) "raised" else "ok"))
  }
  out <- list(
    lang = "r",
    meta = list(mock_base = mock$base, closed_base = mock$closed, sdk_version = lib$how,
                runtime = R.version.string,
                generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
                seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)),
    results = results)
  txt <- jsonlite::toJSON(out, auto_unbox = TRUE, null = "null", na = "null", digits = I(17),
                          json_verbatim = TRUE)
  dir.create(dirname(opts$out), showWarnings = FALSE, recursive = TRUE)
  con <- file(opts$out, open = "wb")
  writeBin(charToRaw(enc2utf8(as.character(txt))), con)
  close(con)
  cat(sprintf("wrote %s (%d scenarios, %.1fs)\n", opts$out, length(results),
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

main()
