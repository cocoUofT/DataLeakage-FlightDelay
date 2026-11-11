# Shared definitions for the final-study extension: prediction-time (horizon) analysis.
# Run every script from the project root. Nothing here changes midway files; midway inputs are only read.

FINAL_DATA <- "final/data"          # git-ignored intermediate files (rebuilt by 01-02)
FINAL_RES  <- "final/results"
CLOSED10   <- "data/processed/closed10"

# Prediction times: minutes before scheduled departure (cutoff c = scheduled departure - h)
HORIZONS <- c(720L, 360L, 240L, 120L, 60L, 30L)
horizon_label <- function(h) ifelse(h >= 60, paste0(h / 60, " h"), paste0(h, " min"))

# Aircraft rotation chain settings
ROT_MAX_LEGS  <- 8L     # look back at most 8 legs of the same aircraft
ROT_MAX_HOURS <- 36     # ... and at most 36 h before this flight's scheduled departure
ROT_MTT       <- 30     # assumed minimum turnaround (min) used only to project delay propagation

# Predictors shared with the midway clean model
SCHEDULE_VARS <- c("Reporting_Airline", "Origin", "Dest", "DayOfWeek", "dep_hour", "arr_hour",
                   "CRSElapsedTime", "Distance", "days_to_holiday")
HISTORY_VARS <- c(
  paste0("hr_", rep(c("origin", "dest", "carrier", "route"), each = 3), "_", c("182d", "28d", "7d"), "_rate"),
  "sd_origin_dep15_rate", "sd_origin_none", "sd_origin_n_log",
  "rc_dest_3h_rate", "rc_dest_3h_none", "rc_dest_3h_n_log",
  "net_24h_rate", "net_7d_rate")
WEATHER_VARS <- c("sknt", "gust", "gust_indicator", "vsby", "p01i_log", "precip_intensity", "ts_flag", "snow_fzra_flag")
WEATHER_COLS <- c(paste0("o_", WEATHER_VARS), paste0("d_", WEATHER_VARS))
# New: aircraft rotation features, all evaluated at the cutoff
ROTATION_VARS <- c("rot_state", "rot_known_delay", "rot_legs_to_go", "rot_proj_delay",
                   "rot_turn_sched", "rot_known_age_h")
predictors_final <- function(rotation = TRUE) c(SCHEDULE_VARS, HISTORY_VARS, WEATHER_COLS, if (rotation) ROTATION_VARS)

# Local clock time (HHMM, "2400" allowed) on a local date -> POSIXct UTC; repeated fall-back hour -> first instance
local_to_utc <- function(date, hhmm, tz) {
  mins <- as.integer(substr(hhmm, 1, 2)) * 60L + as.integer(substr(hhmm, 3, 4))
  day <- as.Date(date) + (mins == 1440L); mins <- mins %% 1440L
  out <- rep(as.POSIXct(NA, tz = "UTC"), length(date))
  for (z in unique(tz)) {
    i <- which(tz == z)
    out[i] <- lubridate::with_tz(lubridate::force_tz(as.POSIXct(day[i], tz = "UTC") + 60 * mins[i], tzone = z,
                                                     roll_dst = c("boundary", "pre")), "UTC")
  }
  out
}
to_min <- function(t) as.numeric(t) / 60      # POSIXct -> minutes since epoch

# Count events and successes per key with time in [lo, hi): events sorted once with a composite (key, time) index.
keyed_window <- function(ev_key, ev_time, ev_y, q_key, q_lo, q_hi) {
  levels_all <- unique(c(ev_key, q_key))
  ek <- match(ev_key, levels_all); qk <- match(q_key, levels_all)
  SCALE <- 1e8                                   # > any time value in minutes since 1970 (~2.9e7)
  comp <- ek * SCALE + ev_time
  o <- order(comp); comp <- comp[o]; cy <- c(0, cumsum(ev_y[o]))
  hi <- findInterval(qk * SCALE + q_hi, comp, left.open = TRUE)
  lo <- findInterval(qk * SCALE + q_lo, comp, left.open = TRUE)
  n <- hi - lo
  list(n = n, k = cy[hi + 1] - cy[lo + 1])
}

# Analysis populations. "regular" (main): flights whose recorded aircraft rotation is regular right before them.
# "all_flights" (sensitivity): every eligible flight. Irregular = the same aircraft's previous row (within 36 h)
# is schedule-infeasible (scheduled arrival after this flight's scheduled departure) or ends at another airport.
# These are mostly aircraft swaps recorded under the final tail number; swaps follow disruptions, so the
# record carries post-cutoff information (final/results/audit_report.md). Excluded from training AND evaluation.
POPULATIONS <- c("regular", "all_flights")
pop_dir <- function(pop) { stopifnot(pop %in% POPULATIONS); file.path(FINAL_RES, pop) }
irregular_rotation <- function(legs, study) {
  lg <- legs[!is.na(legs$Tail_Number), ]; lg <- lg[order(lg$Tail_Number, lg$dep_sched), ]
  pos <- match(study$flight_id, lg$flight_id); prev <- pmax(pos - 1L, 1L)
  recent <- pos > 1 & lg$Tail_Number[prev] == study$Tail_Number & (study$dep_sched - lg$dep_sched[prev]) <= ROT_MAX_HOURS * 60
  recent & (lg$arr_sched[prev] > study$dep_sched | lg$Dest[prev] != as.character(study$Origin))
}
