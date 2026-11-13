# Reporting-lag sensitivity, step 1: rebuild the CLEAN (C) predictors as if every piece of information
# became available L minutes after it happened (the midway assumes L = 0).
#   weather (METAR): report valid at v is usable at the cutoff c only if v <= c - L_wx
#                    (same <= 120-min staleness rule, measured at c - L_wx)
#   BTS outcomes   : a flight's departure / arrival outcome is usable only if it happened before c - L_bts
#                    (all history windows hr_*, sd_*, rc_* and network net_* shift to c - L_bts)
# Schedule predictors are known in advance and do not change. W / WO predictors are not rebuilt.
# L = 0 must reproduce the midway features exactly (checked at the end).
# Input : data/processed/closed10/{model_table_dev, history_10airports_*, weather_10airports_2025JanSep}.csv.gz,
#         midway_split.rds (for the L = 0 check only)
# Output: data/processed/closed10/lag_features.rds (git-ignored), results/lag_sensitivity/feature_changes.csv
# Run from the project root:  Rscript scripts/09a_lag_features.R
suppressPackageStartupMessages({ library(dplyr); library(readr); library(lubridate) })
source("scripts/midway_helpers.R"); source("scripts/weather_decoder.R")
D <- "data/processed/closed10"
OUT_DIR <- "results/lag_sensitivity"; dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
OUT_FILE <- file.path(D, "lag_features.rds")
EVENT_CACHE <- file.path(D, "lag_events_cache.rds")   # temporary, git-ignored with data/processed

# lag in minutes for weather (wx) and BTS outcomes (bts)
SCENARIOS <- list(L0 = c(wx = 0, bts = 0), L15 = c(wx = 15, bts = 15), L30 = c(wx = 30, bts = 30),
                  L60 = c(wx = 60, bts = 60), wx60 = c(wx = 60, bts = 0), bts60 = c(wx = 0, bts = 60))
HR_WINDOWS <- c(`182d` = 182 * 1440, `28d` = 28 * 1440, `7d` = 7 * 1440)
NET_WINDOWS <- c(`24h` = 24 * 60, `7d` = 7 * 24 * 60)
BIG <- 1e8   # key * BIG + minutes-since-epoch gives one sortable number per event

# ---- eligible study flights (same population as scripts/03_prepare_midway.R) ----
fl <- read_csv(file.path(D, "model_table_dev.csv.gz"), show_col_types = FALSE,
               col_select = c(flight_id, FlightDate, Month, Origin, Dest, Reporting_Airline, eligible, cutoff_utc)) %>%
  filter(eligible == 1)
c_min <- as.numeric(force_tz(fl$cutoff_utc, "UTC")) / 60

# ---- BTS outcome events (same rules as scripts/02_history_features.py and 02b_network_features.R) ----
hhmm <- function(s) { n <- nchar(s); as.integer(ifelse(n > 2, substr(s, 1, n - 2), "0")) * 60L + as.integer(substr(s, pmax(1, n - 1), n)) }
tz_all <- read_csv("config/airport_timezones_all.csv", show_col_types = FALSE)
local_to_utc_min <- function(date, hhmm_str, tz) {
  mins <- hhmm(hhmm_str); day <- as.Date(date) + (mins == 1440L); mins <- mins %% 1440L
  out <- rep(NA_real_, length(date))
  for (z in unique(tz)) {
    i <- which(tz == z)
    out[i] <- as.numeric(with_tz(force_tz(as.POSIXct(day[i]) + 60 * mins[i], tzone = z, roll_dst = c("boundary", "pre")), "UTC")) / 60
  }
  out
}
if (file.exists(EVENT_CACHE)) ev <- readRDS(EVENT_CACHE) else {
  files <- file.path(D, paste0("history_10airports_", c("pre_2024JulDec", "dev_2025JanJun", "test_2025JulSep"), ".csv.gz"))
  ev <- bind_rows(lapply(files, function(f) {
    read_csv(f, show_col_types = FALSE,
             col_select = c(FlightDate, Origin, Dest, Reporting_Airline, CRSDepTime, DepTime, CRSElapsedTime,
                            ArrDelay, DepDel15, ArrDel15, eligible),
             col_types = cols(FlightDate = col_character(), CRSDepTime = col_character(), DepTime = col_character())) %>%
      filter(eligible == 1, !is.na(CRSElapsedTime), !is.na(ArrDelay)) %>%
      left_join(tz_all %>% select(iata, iana_timezone), by = c("Origin" = "iata")) %>%
      mutate(dep = local_to_utc_min(FlightDate, CRSDepTime, iana_timezone),
             has_dep = !is.na(DepTime) & DepTime != "",
             dep_known = ifelse(has_dep, dep + ((hhmm(ifelse(has_dep, DepTime, "0000")) - hhmm(CRSDepTime) + 120) %% 1440 - 120), NA),
             arr_known = dep + trunc(CRSElapsedTime) + trunc(ArrDelay)) %>%
      select(FlightDate, Origin, Dest, Reporting_Airline, has_dep, dep_known, DepDel15, arr_known, ArrDel15)
  }))
  stopifnot(!anyNA(ev$arr_known))
  saveRDS(ev, EVENT_CACHE)
}
message("events: ", nrow(ev))

# integer codes shared by events and flights
ap_lv <- sort(unique(c(ev$Origin, ev$Dest, fl$Origin, fl$Dest)))
car_lv <- sort(unique(c(ev$Reporting_Airline, as.character(fl$Reporting_Airline))))
day0 <- as.Date("2024-01-01")
code <- function(x, lv) match(as.character(x), lv)
make_index <- function(key, t, y) {
  o <- order(key, t); list(v = key[o] * BIG + t[o], cy = c(0, cumsum(y[o])))
}
win <- function(idx, key, lo, hi) {   # events with this key and time in [lo, hi): count n and outcome sum k
  a <- findInterval(key * BIG + lo, idx$v, left.open = TRUE)
  b <- findInterval(key * BIG + hi, idx$v, left.open = TRUE)
  list(n = b - a, k = idx$cy[b + 1] - idx$cy[a + 1])
}
hist_ev <- ev %>% filter(has_dep)        # 02_history_features.py also requires DepTime
eo <- code(hist_ev$Origin, ap_lv); ed <- code(hist_ev$Dest, ap_lv)
idx <- list(
  origin  = make_index(eo, hist_ev$arr_known, hist_ev$ArrDel15),
  dest    = make_index(ed, hist_ev$arr_known, hist_ev$ArrDel15),
  carrier = make_index(code(hist_ev$Reporting_Airline, car_lv), hist_ev$arr_known, hist_ev$ArrDel15),
  route   = make_index(eo * 1000 + ed, hist_ev$arr_known, hist_ev$ArrDel15),
  sameday = make_index(eo * 1000 + as.integer(as.Date(hist_ev$FlightDate) - day0), hist_ev$dep_known, hist_ev$DepDel15)
)
net_ev <- ev %>% filter(Origin %in% read_csv("config/airports.csv", show_col_types = FALSE)$iata)
idx$net <- make_index(rep(0, nrow(net_ev)), net_ev$arr_known, net_ev$ArrDel15)
rm(ev, hist_ev, net_ev); invisible(gc())

fo <- code(fl$Origin, ap_lv); fd <- code(fl$Dest, ap_lv)
fkey <- list(origin = fo, dest = fd, carrier = code(fl$Reporting_Airline, car_lv), route = fo * 1000 + fd)
fday <- fo * 1000 + as.integer(as.Date(fl$FlightDate) - day0)
rate5 <- function(r) ifelse(r$n > 0, round(r$k / r$n, 5), NA_real_)

history_features <- function(cc) {   # cc = information time (minutes since epoch, UTC)
  out <- list()
  for (g in names(fkey)) for (w in names(HR_WINDOWS))
    out[[paste0("hr_", g, "_", w, "_rate")]] <- rate5(win(idx[[g]], fkey[[g]], cc - HR_WINDOWS[[w]], cc))
  r <- win(idx$sameday, fday, 0, cc); out$sd_origin_n <- r$n; out$sd_origin_dep15_rate <- rate5(r)
  r <- win(idx$dest, fkey$dest, cc - 180, cc); out$rc_dest_3h_n <- r$n; out$rc_dest_3h_rate <- rate5(r)
  for (w in names(NET_WINDOWS)) out[[paste0("net_", w, "_rate")]] <- rate5(win(idx$net, 0, cc - NET_WINDOWS[[w]], cc))
  as_tibble(out)
}

# ---- weather (same processing as scripts/STA2112_Midway.Rmd) ----
weather <- read_csv(file.path(D, "weather_10airports_2025JanSep.csv.gz"), col_types = cols(.default = col_character())) %>%
  mutate(valid = ymd_hm(valid, tz = "UTC")) %>% filter(!is.na(valid)) %>%
  arrange(iata, valid) %>% group_by(iata, valid) %>% slice_tail(n = 1) %>% ungroup() %>%
  mutate(sknt = as.numeric(na_if(sknt, "M")), vsby = as.numeric(na_if(vsby, "M")),
         gust_indicator = ifelse(is.na(gust) | gust == "M", 0, 1),
         gust = as.numeric(ifelse(is.na(gust) | gust == "M", "0", gust)),
         p01i = as.numeric(ifelse(!is.na(p01i) & p01i == "T", "0.0001", na_if(p01i, "M"))),
         ts_flag = ifelse(grepl("TS", wxcodes), 1, 0)) %>%
  bind_cols(decode_present_weather(.$metar)) %>%
  mutate(p01i_log = log1p(100 * p01i), valid_min = as.numeric(valid) / 60) %>%
  select(iata, valid_min, all_of(WEATHER_VARS))
wx_by_ap <- split(weather, weather$iata)

weather_features <- function(airport, tt, suffix) {   # latest report with valid <= tt and age <= 120 min
  out <- matrix(NA_real_, length(tt), length(WEATHER_VARS) + 1, dimnames = list(NULL, c(WEATHER_VARS, "age")))
  for (a in unique(airport)) {
    i <- which(airport == a); w <- wx_by_ap[[a]]
    j <- findInterval(tt[i], w$valid_min)
    ok <- j > 0; ok[ok] <- tt[i][ok] - w$valid_min[j[ok]] <= 120
    out[i[ok], WEATHER_VARS] <- as.matrix(w[j[ok], WEATHER_VARS])
    out[i[ok], "age"] <- tt[i][ok] - w$valid_min[j[ok]]
  }
  colnames(out) <- paste0(colnames(out), suffix)
  as_tibble(out)
}

# ---- build every scenario ----
is_train <- fl$Month <= 4
features <- lapply(names(SCENARIOS), function(s) {
  L <- SCENARIOS[[s]]
  h <- history_features(c_min - L[["bts"]])
  wx <- bind_cols(weather_features(fl$Origin, c_min - L[["wx"]], "_C"),
                  weather_features(fl$Dest, c_min - L[["wx"]], "_Dest_C"))
  df <- bind_cols(tibble(flight_id = fl$flight_id), h, wx) %>% mutate(
    sd_origin_none = as.integer(sd_origin_n == 0), sd_origin_n_log = log1p(sd_origin_n),
    rc_dest_3h_none = as.integer(rc_dest_3h_n == 0), rc_dest_3h_n_log = log1p(rc_dest_3h_n))
  # rates with n = 0: training mean, as in 03_prepare_midway.R
  m_sd <- mean(df$sd_origin_dep15_rate[is_train], na.rm = TRUE); m_rc <- mean(df$rc_dest_3h_rate[is_train], na.rm = TRUE)
  df <- df %>% mutate(sd_origin_dep15_rate = ifelse(sd_origin_none == 1, m_sd, sd_origin_dep15_rate),
                      rc_dest_3h_rate = ifelse(rc_dest_3h_none == 1, m_rc, rc_dest_3h_rate))
  message(s, " built")
  df
})
names(features) <- names(SCENARIOS)

# ---- check: L = 0 reproduces the midway clean predictors ----
mid <- readRDS(SPLIT_FILE)$data
cols <- c(HISTORY_VARS, paste0(WEATHER_VARS, "_C"), paste0(WEATHER_VARS, "_Dest_C"))
l0 <- features$L0[match(mid$flight_id, features$L0$flight_id), ]
diffs <- sapply(cols, function(v) max(abs(as.numeric(l0[[v]]) - as.numeric(mid[[v]])), na.rm = TRUE))
nas <- sapply(cols, function(v) sum(is.na(l0[[v]])))
message("L0 vs midway: max |diff| = ", signif(max(diffs), 3), " (", names(which.max(diffs)), "); NA in midway flights: ", sum(nas))
stopifnot(max(diffs) < 1e-4, sum(nas) == 0)

# ---- how much do the clean predictors change? (midway-analysed flights) ----
changes <- bind_rows(lapply(names(SCENARIOS), function(s) {
  f <- features[[s]][match(mid$flight_id, features[[s]]$flight_id), ]
  tibble(scenario = s, lag_weather = SCENARIOS[[s]][["wx"]], lag_bts = SCENARIOS[[s]][["bts"]],
         flights = nrow(f),
         incomplete = sum(!complete.cases(f[, cols])),
         origin_report_changed = mean(f$sknt_C != l0$sknt_C | f$vsby_C != l0$vsby_C | f$age_C != l0$age_C, na.rm = TRUE),
         mean_origin_report_age = mean(f$age_C, na.rm = TRUE),
         rc_dest_3h_n_mean = mean(f$rc_dest_3h_n), sd_origin_n_mean = mean(f$sd_origin_n),
         cor_net_24h_with_L0 = cor(f$net_24h_rate, l0$net_24h_rate, use = "complete.obs"))
}))
write_csv(changes, file.path(OUT_DIR, "feature_changes.csv"))
print(changes, width = 200)
saveRDS(list(features = features, scenarios = SCENARIOS), OUT_FILE)
