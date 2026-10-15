
# Run from the R project root, after scripts/00_download_weather.R.
source("scripts/weather_helpers.R")

# Load the original data
flights_raw <- read.csv("data/raw/2025Jan.csv",
                        stringsAsFactors = FALSE,
                        check.names = FALSE)

# Select fields of interest
selected_fields <- c("FlightDate", "Month", "DayOfWeek","Reporting_Airline", 
                     "Origin", "Dest", "CRSDepTime", "CRSArrTime", "CRSElapsedTime", 
                     "Distance", "ArrDel15", "Cancelled", "Diverted", "DepDelay", 
                     "TaxiOut")

# Keep the selected fields
flights <- flights_raw[, selected_fields]
rm(flights_raw) # Release the unneeded raw columns before fitting.
flights$source_row <- seq_len(nrow(flights))

# Keep eligible flights departing from Atlanta
flights_clean <- subset(flights, Origin == "ATL" & Cancelled == 0 & 
                          Diverted == 0 & !is.na(ArrDel15))

# Convert dates
flights_clean$FlightDate <- as.Date(flights_clean$FlightDate)

# Treat airline, destination, and weekday as categories
flights_clean$Reporting_Airline <- factor(flights_clean$Reporting_Airline)
flights_clean$Dest <- factor(flights_clean$Dest)
flights_clean$DayOfWeek <- factor(flights_clean$DayOfWeek)

# Convert scheduled departure time from HHMM to minutes after midnight
# Example: 1430 becomes 870 minutes
flights_clean$scheduled_dep_minutes <- (flights_clean$CRSDepTime %/% 100) * 60 +
  (flights_clean$CRSDepTime %% 100)

# Retain both precipitation definitions for matching/audit.
# C uses early intensity; W and WO use later p01i accumulated amounts in inches.
weather <- read_origin_weather(unique(as.integer(format(flights_clean$FlightDate, "%Y"))))
flights_clean <- add_origin_weather(flights_clean, weather)

# Verify the information boundary for every matched report.
stopifnot(
  all(flights_clean$early_observation_utc <= flights_clean$prediction_cutoff_utc, na.rm = TRUE),
  all(as.numeric(flights_clean$prediction_cutoff_utc - flights_clean$early_observation_utc,
                 units = "mins") >= weather_config$assumed_reporting_lag_minutes, na.rm = TRUE),
  all(flights_clean$departure_observation_utc > flights_clean$prediction_cutoff_utc, na.rm = TRUE),
  all(flights_clean$departure_observation_utc <= flights_clean$scheduled_departure_utc, na.rm = TRUE)
)

# Create exclusive sets: training, validation, test
train <- subset(flights_clean, FlightDate <= as.Date("2025-01-20"))
validation <- subset(flights_clean, FlightDate >= as.Date("2025-01-21") &
                       FlightDate <= as.Date("2025-01-25"))
test <- subset(flights_clean, FlightDate >= as.Date("2025-01-26"))


# Save clean data
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(list(train = train, validation = validation, test = test),
        "data/processed/january_pilot_split.rds")

# Readable flight-level weather dataset; no test outcome evaluation.
weather_fields <- c("source_row", "FlightDate", "Origin", "Dest", "CRSDepTime",
                    "scheduled_departure_utc", "prediction_cutoff_utc",
                    grep("^(early|departure)_", names(flights_clean), value = TRUE))
joined <- flights_clean[, weather_fields]
joined$set <- ifelse(flights_clean$FlightDate <= as.Date("2025-01-20"), "train",
                     ifelse(flights_clean$FlightDate <= as.Date("2025-01-25"), "validation", "test"))
write.csv(joined, "data/processed/january_pilot_weather_matches.csv", row.names = FALSE, na = "")
summary <- do.call(rbind, lapply(list(train = train, validation = validation, test = test), function(d) {
  data.frame(flights = nrow(d),
             early_wind_present = sum(!is.na(d$early_wind_knots)),
             early_intensity_present = sum(!is.na(d$early_precipitation_intensity)),
             departure_wind_present = sum(!is.na(d$departure_wind_knots)),
             departure_intensity_present = sum(!is.na(d$departure_precipitation_intensity)),
             departure_amount_present = sum(!is.na(d$departure_precipitation_inches)))
}))
summary$set <- rownames(summary)
write.csv(summary, "data/processed/weather_match_summary.csv", row.names = FALSE)
saveRDS(weather_config, "data/processed/weather_config_used.rds")
print(summary)
