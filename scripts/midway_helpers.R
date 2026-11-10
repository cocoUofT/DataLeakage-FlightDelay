# Shared definitions for the midway analysis (sourced by scripts/03-05). Run from the project root.

MIDWAY_DIR <- "results/midway"
SPLIT_FILE <- "data/processed/closed10/midway_split.rds"   # git-ignored; rebuilt by 03_prepare_midway.R

# Weather variables built for each report (scripts/STA2112_Midway.Rmd)
WEATHER_VARS <- c("sknt", "gust", "gust_indicator", "vsby", "p01i_log", "precip_intensity",
                  "ts_flag", "snow_fzra_flag")

# Column suffixes of the matched report for each information condition.
#   C: latest report at or before the cutoff (<= 120 min old), origin and destination
#   W: latest report in (cutoff, scheduled departure], origin and destination (dest uses _W_dep)
WEATHER_SUFFIX <- list(
  C  = c(origin = "_C", dest = "_Dest_C"),
  W  = c(origin = "_W", dest = "_Dest_W_dep"),
  WO = c(origin = "_W", dest = "_Dest_W_dep")
)

# Non-weather clean predictors, identical in all conditions
SCHEDULE_VARS <- c("Reporting_Airline", "Origin", "Dest", "DayOfWeek", "dep_hour", "arr_hour",
                   "CRSElapsedTime", "Distance", "days_to_holiday")
HISTORY_VARS <- c(
  paste0("hr_", rep(c("origin", "dest", "carrier", "route"), each = 3), "_", c("182d", "28d", "7d"), "_rate"),
  "sd_origin_dep15_rate", "sd_origin_none", "sd_origin_n_log",
  "rc_dest_3h_rate", "rc_dest_3h_none", "rc_dest_3h_n_log",
  "net_24h_rate", "net_7d_rate"   # network-wide recent delay rate (scripts/02b_network_features.R)
)
OPERATIONAL_VARS <- c("DepDelay", "TaxiOut")   # WO only

# Standardized weather column names used inside models: o_<var>, d_<var>
weather_names <- function() c(paste0("o_", WEATHER_VARS), paste0("d_", WEATHER_VARS))

predictors <- function(condition) {
  c(SCHEDULE_VARS, HISTORY_VARS, weather_names(), if (condition == "WO") OPERATIONAL_VARS)
}

# Return the data for one condition with weather columns renamed to o_*/d_*, so every condition
# uses the same predictor names and the only difference is which report (or DepDelay/TaxiOut) feeds them.
condition_data <- function(df, condition) {
  s <- WEATHER_SUFFIX[[condition]]
  src <- c(paste0(WEATHER_VARS, s[["origin"]]), paste0(WEATHER_VARS, s[["dest"]]))
  out <- df[, c("flight_id", "FlightDate", "ArrDel15", SCHEDULE_VARS, HISTORY_VARS,
                if (condition == "WO") OPERATIONAL_VARS)]
  out[weather_names()] <- df[src]
  out
}
