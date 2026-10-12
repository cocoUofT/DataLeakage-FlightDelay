
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

# Create exclusive sets: training, validation, test
train <- subset(flights_clean, FlightDate <= as.Date("2025-01-20"))
validation <- subset(flights_clean, FlightDate >= as.Date("2025-01-21") &
                       FlightDate <= as.Date("2025-01-25"))
test <- subset(flights_clean, FlightDate >= as.Date("2025-01-26"))


#data.frame(set = c("Training", "Validation", "Test"),
#flights = c(nrow(train), nrow(validation), nrow(test)),
#delay_rate = c(mean(train$ArrDel15), mean(validation$ArrDel15),
#mean(test$ArrDel15)))

# Save clean data
saveRDS(list(train = train, validation = validation, test = test),
        "data/processed/january_pilot_split.rds")
