# Final study, step 1: shared inputs for every prediction time.
#   legs.rds    : every completed, non-diverted flight touching the 10 airports, Jul 2024 - Jun 2025, with
#                 scheduled/actual departure and arrival in minutes since 1970 (UTC). Used for historical
#                 rates (by when outcomes became known) and for the aircraft rotation chain (by Tail_Number).
#   weather.rds : decoded METAR reports (same decoding as the midway model table), valid time in minutes UTC
#   study.rds   : eligible development flights (Jan-Jun 2025) with their time-independent predictors
# Input : data/processed/closed10/ (history, model_table_dev, weather), config/airport_timezones_all.csv
# Run from the project root:  Rscript final/R/01_build_inputs.R
suppressPackageStartupMessages({ library(dplyr); library(readr); library(lubridate); library(stringr) })
source("final/R/final_helpers.R")
source("scripts/weather_decoder.R")      # read-only reuse of the midway METAR decoder
dir.create(FINAL_DATA, recursive = TRUE, showWarnings = FALSE)
tz_all <- read_csv("config/airport_timezones_all.csv", show_col_types = FALSE)

# ---- legs ----
ct <- cols(CRSDepTime = col_character(), DepTime = col_character(), CRSArrTime = col_character(),
           ArrTime = col_character(), FlightDate = col_character(), Tail_Number = col_character(),
           Flight_Number_Reporting_Airline = col_character())
legs <- bind_rows(lapply(file.path(CLOSED10, c("history_10airports_pre_2024JulDec.csv.gz", "history_10airports_dev_2025JanJun.csv.gz")),
                         read_csv, show_col_types = FALSE, col_types = ct)) %>%
  filter(eligible == 1, !is.na(CRSElapsedTime), !is.na(ArrDelay), !is.na(DepTime)) %>%
  left_join(tz_all %>% select(iata, iana_timezone), by = c("Origin" = "iata"))
stopifnot(!anyNA(legs$iana_timezone))
hhmm_min <- function(x) as.integer(substr(x, 1, 2)) * 60L + as.integer(substr(x, 3, 4))
legs <- legs %>% mutate(
  flight_id = paste(FlightDate, Reporting_Airline, Flight_Number_Reporting_Airline, Origin, Dest, CRSDepTime, sep = "_"),
  dep_sched = to_min(local_to_utc(FlightDate, CRSDepTime, iana_timezone)),
  dep_act   = dep_sched + ((hhmm_min(DepTime) - hhmm_min(CRSDepTime) + 120L) %% 1440L - 120L),  # as 02_history_features.py
  arr_sched = dep_sched + CRSElapsedTime,
  arr_act   = arr_sched + ArrDelay,
  dep_delay = dep_act - dep_sched
) %>% select(flight_id, FlightDate, Tail_Number, Reporting_Airline, Origin, Dest, DepDel15, ArrDel15, ArrDelay,
             dep_sched, dep_act, arr_sched, arr_act, dep_delay)
stopifnot(!anyNA(legs$dep_sched), !anyDuplicated(legs$flight_id))
saveRDS(legs, file.path(FINAL_DATA, "legs.rds"))
message("legs: ", nrow(legs), " (with tail number: ", sum(!is.na(legs$Tail_Number)), ")")

# ---- weather: same cleaning and decoding as scripts/STA2112_Midway.Rmd ----
weather <- read_csv(file.path(CLOSED10, "weather_10airports_2025JanSep.csv.gz"), col_types = cols(.default = col_character())) %>%
  mutate(valid = ymd_hm(valid, tz = "UTC")) %>% filter(!is.na(valid)) %>%
  arrange(iata, valid) %>% group_by(iata, valid) %>% slice_tail(n = 1) %>% ungroup() %>%
  mutate(sknt = as.numeric(na_if(sknt, "M")), vsby = as.numeric(na_if(vsby, "M")),
         gust_indicator = ifelse(is.na(gust) | gust == "M", 0, 1),
         gust = as.numeric(ifelse(is.na(gust) | gust == "M", "0", gust)),
         p01i = as.numeric(ifelse(!is.na(p01i) & p01i == "T", "0.0001", na_if(p01i, "M"))),
         p01i_log = log1p(100 * p01i),
         ts_flag = ifelse(str_detect(wxcodes, "TS"), 1, 0)) %>%
  bind_cols(decode_present_weather(.$metar)) %>%
  mutate(valid_min = to_min(valid)) %>% select(iata, valid_min, all_of(WEATHER_VARS))
saveRDS(weather, file.path(FINAL_DATA, "weather.rds"))
message("weather reports: ", nrow(weather))

# ---- study flights: eligible development flights and time-independent predictors ----
study <- read_csv(file.path(CLOSED10, "model_table_dev.csv.gz"), show_col_types = FALSE,
                  col_types = cols(CRSDepTime = col_character(), CRSArrTime = col_character())) %>%
  filter(eligible == 1) %>%
  transmute(flight_id, FlightDate, Month, split = ifelse(Month <= 4, "train", "validation"),
            ArrDel15 = as.integer(ArrDel15), Reporting_Airline = factor(Reporting_Airline),
            Origin = factor(Origin), Dest = factor(Dest), DayOfWeek = factor(DayOfWeek, levels = 1:7),
            dep_hour, arr_hour, CRSElapsedTime, Distance, days_to_holiday, DepDelay, TaxiOut) %>%
  left_join(legs %>% select(flight_id, Tail_Number, dep_sched), by = "flight_id")
stopifnot(!anyNA(study$dep_sched))
saveRDS(study, file.path(FINAL_DATA, "study.rds"))
message("study flights: ", nrow(study), " (train ", sum(study$split == "train"), ", validation ", sum(study$split == "validation"), ")")
