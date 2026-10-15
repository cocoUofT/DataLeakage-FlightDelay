# Current executable scope: Atlanta-origin January 2025 pilot.
# Destination/nationwide weather needs an airport-to-station/timezone map first.
weather_config <- list(
  station = "ATL",
  network = "GA_ASOS",
  origin_timezone = "America/New_York",
  years = 2025L,
  cutoff_minutes = 120,
  maximum_report_age_minutes = 120,
  # The IEM valid field is observation time, not historical receipt time.
  # Zero reproduces the pilot assumption; change to 15/30 for lag sensitivity.
  assumed_reporting_lag_minutes = 0,
  precipitation_predictor = "intensity", # Clean model remains unchanged.
  leakage_precipitation_predictor = "amount" # W and WO use p01i inches.
)

# Shared observed-weather parsing and backward time matching; no TAF/HRRR input.

metar_precipitation <- function(report) {
  unknown <- list(intensity = NA_character_, codes = NA_character_)
  if (is.na(report) || !nzchar(report) || report == "M" ||
      grepl("\\b(NIL|PWINO)\\b", report)) return(unknown)
  body <- sub(" RMK .*", "", report)
  tokens <- strsplit(gsub("=", "", body, fixed = TRUE), "[[:space:]]+")[[1]]
  if (!any(grepl("^[A-Z][A-Z0-9]{3}$", tokens)) ||
      !any(grepl("^[0-9]{6}Z$", tokens))) return(unknown)
  pattern <- paste0("^[-+]?(VC)?(MI|PR|BC|DR|BL|SH|TS|FZ)?",
                    "(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$")
  codes <- tokens[grepl(pattern, tokens)]
  codes <- codes[!grepl("^[-+]?(VC|BL|DR)", codes)]
  contains_precipitation <- vapply(codes, function(token) {
    stripped <- sub("^[-+]", "", token)
    pairs <- substring(stripped, seq(1, nchar(stripped), 2), seq(2, nchar(stripped), 2))
    any(pairs %in% c("RA", "DZ", "SN", "SG", "PL", "GS", "UP", "GR", "IC"))
  }, logical(1))
  codes <- codes[contains_precipitation]
  if (!length(codes)) return(list(intensity = "none", codes = ""))
  # Hail/ice crystals alone do not have an assigned standard intensity category.
  supported <- vapply(codes, function(token) {
    stripped <- sub("^[-+]", "", token)
    pairs <- substring(stripped, seq(1, nchar(stripped), 2), seq(2, nchar(stripped), 2))
    any(pairs %in% c("RA", "DZ", "SN", "SG", "PL", "GS", "UP"))
  }, logical(1))
  if (!all(supported)) return(list(intensity = NA_character_, codes = paste(codes, collapse = " ")))
  severity <- ifelse(startsWith(codes, "-"), 1L, ifelse(startsWith(codes, "+"), 3L, 2L))
  list(intensity = c("light", "moderate", "heavy")[max(severity)], codes = paste(codes, collapse = " "))
}

read_origin_weather <- function(years) {
  paths <- sprintf("data/raw/weather/%s_JanJun_%d_weather.csv", weather_config$station, years)
  if (!all(file.exists(paths))) stop("Download weather first: source('scripts/00_download_weather.R')")
  weather <- do.call(rbind, lapply(paths, read.csv, stringsAsFactors = FALSE))
  weather <- weather[weather$station == weather_config$station, ]
  weather$observation_utc <- as.POSIXct(weather$valid, format = "%Y-%m-%d %H:%M", tz = "UTC")
  stopifnot(!anyNA(weather$observation_utc))
  # Resolve archive duplicates deterministically, retaining the last archive row.
  # This is not an as-of correction history; see the availability limitation in README.
  duplicates <- duplicated(weather$observation_utc, fromLast = TRUE)
  message("Duplicate observation timestamps removed: ", sum(duplicates))
  weather <- weather[!duplicates, ]
  weather <- weather[order(weather$observation_utc), ]
  weather$wind_knots <- suppressWarnings(as.numeric(weather$sknt))
  precipitation <- weather$p01i
  precipitation[precipitation == "T"] <- "0.0001" # Trace encoding, not a measured amount.
  weather$precipitation_inches <- suppressWarnings(as.numeric(precipitation))
  decoded <- lapply(weather$metar, metar_precipitation)
  weather$precipitation_intensity <- vapply(decoded, `[[`, character(1), "intensity")
  weather$precipitation_codes <- vapply(decoded, `[[`, character(1), "codes")
  weather
}

add_origin_weather <- function(flights, weather) {
  stopifnot(all(flights$Origin == weather_config$station))
  # HHMM=2400 is midnight on the following date. This handles January ATL;
  # wider DST/nationwide use requires an explicit local-time ambiguity policy.
  local_midnight <- as.POSIXct(as.character(flights$FlightDate), tz = weather_config$origin_timezone)
  departure_seconds <- as.numeric(local_midnight) + flights$scheduled_dep_minutes * 60
  cutoff_seconds <- departure_seconds - weather_config$cutoff_minutes * 60
  flights$scheduled_departure_utc <- as.POSIXct(departure_seconds, origin = "1970-01-01", tz = "UTC")
  flights$prediction_cutoff_utc <- as.POSIXct(cutoff_seconds, origin = "1970-01-01", tz = "UTC")
  for (condition in c("early", "departure")) {
    target <- if (condition == "early") cutoff_seconds else departure_seconds
    # Matching is backward only; no later-than-target observation is selected.
    available_seconds <- as.numeric(weather$observation_utc) +
      if (condition == "early") weather_config$assumed_reporting_lag_minutes * 60 else 0
    index <- findInterval(target, available_seconds)
    safe_index <- pmax(index, 1L)
    age <- (target - as.numeric(weather$observation_utc[safe_index])) / 60
    matched <- index > 0 & age >= 0 & age <= weather_config$maximum_report_age_minutes
    # Late reports must be strictly after prediction cutoff to count as leakage.
    if (condition == "departure") matched <- matched &
      as.numeric(weather$observation_utc[safe_index]) > cutoff_seconds
    assign_field <- function(values) {
      result <- values[safe_index]
      result[!matched] <- NA
      result
    }
    flights[[paste0(condition, "_observation_utc")]] <- assign_field(weather$observation_utc)
    flights[[paste0(condition, "_report_age_minutes")]] <- ifelse(matched, age, NA_real_)
    flights[[paste0(condition, "_wind_knots")]] <- assign_field(weather$wind_knots)
    flights[[paste0(condition, "_precipitation_intensity")]] <- factor(
      assign_field(weather$precipitation_intensity), levels = c("none", "light", "moderate", "heavy"))
    flights[[paste0(condition, "_precipitation_inches")]] <- assign_field(weather$precipitation_inches)
    flights[[paste0(condition, "_precipitation_codes")]] <- assign_field(weather$precipitation_codes)
    flights[[paste0(condition, "_raw_metar")]] <- assign_field(weather$metar)
  }
  flights
}

pilot_weather_formulas <- function() {
  baseline <- c("DayOfWeek", "scheduled_dep_minutes", "CRSElapsedTime", "Distance")
  precipitation_field <- function(specification) {
    switch(specification, intensity = "precipitation_intensity",
           amount = "precipitation_inches", stop("Unknown precipitation predictor"))
  }
  clean_suffix <- precipitation_field(weather_config$precipitation_predictor)
  leakage_suffix <- precipitation_field(weather_config$leakage_precipitation_predictor)
  list(
    clean = reformulate(c(baseline, "early_wind_knots", paste0("early_", clean_suffix)), response = "ArrDel15"),
    weather_leakage = reformulate(c(baseline, "departure_wind_knots", paste0("departure_", leakage_suffix)), response = "ArrDel15"),
    leakage = reformulate(c(baseline, "departure_wind_knots", paste0("departure_", leakage_suffix), "DepDelay", "TaxiOut"), response = "ArrDel15")
  )
}

common_model_rows <- function(pilot) {
  formulas <- pilot_weather_formulas()
  fields <- unique(unlist(lapply(formulas, all.vars)))
  output <- lapply(pilot[c("train", "validation")], function(d) {
    keep <- complete.cases(d[, fields])
    # No condition may improve its score by silently evaluating different flights.
    message("Common complete model rows: ", sum(keep), "/", nrow(d))
    d[keep, ]
  })
  if (!nrow(output$train) || !nrow(output$validation)) stop("No common complete-case flights")
  for (field in fields) {
    if (is.factor(output$train[[field]])) {
      supported <- levels(droplevels(output$train[[field]]))
      if (!all(as.character(output$validation[[field]]) %in% supported))
        stop("Validation contains a category not observed in training: ", field)
      output$train[[field]] <- factor(output$train[[field]], levels = supported)
      output$validation[[field]] <- factor(output$validation[[field]], levels = supported)
    }
  }
  output
}
