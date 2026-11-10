# Network-wide recent delay rate, known before each flight's two-hour cutoff.
#   net_24h_* / net_7d_*: among completed, non-diverted flights DEPARTING any of the 10 study airports
#   (any destination), those whose actual arrival (UTC) is in [c - window, c); rate = share with ArrDel15 = 1.
#   c = scheduled departure (UTC) - 120 min, taken from features_history_*.csv.gz (cutoff_utc).
#   Actual arrival (UTC) = scheduled departure in the origin's IANA zone + CRSElapsedTime + ArrDelay,
#   the same rule as scripts/02_history_features.py. Reporting lag of BTS outcomes assumed 0.
# Purpose: lets the clean model track system-wide shifts in the delay level (e.g. the summer peak)
#   using only information available at the cutoff.
# Input : data/processed/closed10/history_10airports_{pre_2024JulDec,dev_2025JanJun,test_2025JulSep}.csv.gz,
#         features_history_{dev,test}.csv.gz, config/airports.csv
# Output: data/processed/closed10/features_network_{dev,test}.csv.gz
# Run from the project root:  Rscript scripts/02b_network_features.R [check]
suppressPackageStartupMessages({ library(dplyr); library(readr); library(lubridate) })
D <- "data/processed/closed10"
airports <- read_csv("config/airports.csv", show_col_types = FALSE)
WINDOWS <- c(`24h` = 24 * 60, `7d` = 7 * 24 * 60)   # minutes

# ---- outcome events: when each flight's ArrDel15 became known ----
hist_files <- file.path(D, paste0("history_10airports_", c("pre_2024JulDec", "dev_2025JanJun", "test_2025JulSep"), ".csv.gz"))
events <- bind_rows(lapply(hist_files, function(f) read_csv(f, show_col_types = FALSE,
            col_select = c(FlightDate, Origin, CRSDepTime, CRSElapsedTime, ArrDelay, ArrDel15, eligible),
            col_types = cols(CRSDepTime = col_character(), FlightDate = col_character())))) %>%
  filter(eligible == 1, Origin %in% airports$iata, !is.na(CRSElapsedTime), !is.na(ArrDelay)) %>%
  left_join(airports %>% select(iata, iana_timezone), by = c("Origin" = "iata"))

local_to_utc <- function(date, hhmm, tz) {
  mins <- as.integer(substr(hhmm, 1, 2)) * 60L + as.integer(substr(hhmm, 3, 4))
  day <- as.Date(date) + (mins == 1440L)                     # 2400 = 00:00 next day
  mins <- mins %% 1440L
  out <- rep(as.POSIXct(NA, tz = "UTC"), length(date))
  for (z in unique(tz)) {
    i <- which(tz == z)
    out[i] <- with_tz(force_tz(as.POSIXct(day[i]) + 60 * mins[i], tzone = z, roll_dst = c("boundary", "pre")), "UTC")  # repeated fall-back hour -> first (daylight) instance, as in 02_history_features.py
  }
  out
}
events <- events %>%
  mutate(dep_utc = local_to_utc(FlightDate, CRSDepTime, iana_timezone),
         known_min = as.numeric(dep_utc) / 60 + CRSElapsedTime + ArrDelay) %>%   # minutes since epoch, UTC
  arrange(known_min)
stopifnot(!anyNA(events$known_min))
t_known <- events$known_min
cum_y <- c(0, cumsum(events$ArrDel15))

window_rate <- function(cutoff_min, width) {
  hi <- findInterval(cutoff_min, t_known, left.open = TRUE)          # events with known < cutoff
  lo <- findInterval(cutoff_min - width, t_known, left.open = TRUE)  # events with known < cutoff - width
  n <- hi - lo
  list(n = n, rate = ifelse(n > 0, (cum_y[hi + 1] - cum_y[lo + 1]) / n, NA_real_))
}

build <- function(period) {
  fh <- read_csv(file.path(D, paste0("features_history_", period, ".csv.gz")), show_col_types = FALSE,
                 col_select = c(flight_id, cutoff_utc))
  cmin <- as.numeric(force_tz(fh$cutoff_utc, "UTC")) / 60
  out <- fh %>% select(flight_id)
  for (w in names(WINDOWS)) {
    r <- window_rate(cmin, WINDOWS[[w]])
    out[[paste0("net_", w, "_n")]] <- r$n
    out[[paste0("net_", w, "_rate")]] <- round(r$rate, 5)
  }
  write_csv(out, file.path(D, paste0("features_network_", period, ".csv.gz")))
  message(period, ": ", nrow(out), " flights; net_24h_n range ", min(out$net_24h_n), "-", max(out$net_24h_n))
  invisible(list(out = out, cmin = cmin))
}
res <- lapply(c(dev = "dev", test = "test"), build)

# ---- check: brute-force recomputation for random flights (no sorting / findInterval) ----
if ("check" %in% commandArgs(trailingOnly = TRUE)) {
  set.seed(2112); bad <- 0
  for (period in names(res)) {
    idx <- sample(seq_along(res[[period]]$cmin), 100)
    for (i in idx) {
      c0 <- res[[period]]$cmin[i]
      for (w in names(WINDOWS)) {
        use <- events$known_min < c0 & events$known_min >= c0 - WINDOWS[[w]]
        n <- sum(use); rate <- if (n) mean(events$ArrDel15[use]) else NA
        got_n <- res[[period]]$out[[paste0("net_", w, "_n")]][i]
        got_r <- res[[period]]$out[[paste0("net_", w, "_rate")]][i]
        if (got_n != n || (n > 0 && abs(got_r - rate) > 1e-5)) { bad <- bad + 1; message("MISMATCH ", period, " ", i, " ", w) }
      }
    }
  }
  message("check: 200 flights x 2 windows, mismatches: ", bad)
}
