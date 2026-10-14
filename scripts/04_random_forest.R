
# Required packages
library(ranger)
source("scripts/metrics.R")

# Load the prepared sets
pilot <- readRDS("data/processed/january_pilot_split.rds")

train_rf <- pilot$train
validation <- pilot$validation

train_rf$ArrDel15 <- factor(train_rf$ArrDel15, levels = c(0, 1))

# Random forest model with clean information only
rf_clean <- ranger(ArrDel15 ~ DayOfWeek + scheduled_dep_minutes +
                     CRSElapsedTime + Distance, 
                   data = train_rf, probability = TRUE, num.trees = 500,
                   mtry = 2, min.node.size = 20, 
                   respect.unordered.factors = "partition", num.threads = 2,
                   seed = 924)

# Random forest model with leakage information
rf_leakage <- ranger(ArrDel15 ~ DayOfWeek + scheduled_dep_minutes +
                       CRSElapsedTime + Distance + DepDelay + TaxiOut,
                     data = train_rf, probability = TRUE, num.trees = 500,
                     mtry = 2, min.node.size = 20, 
                     respect.unordered.factors = "partition", num.threads = 2,
                     seed = 924)

# Extract probabilities for class "1": delayed flights
validation$prob_rf_clean <- predict(rf_clean, data = validation)$predictions[, "1"]
validation$prob_rf_leakage <- predict(rf_leakage, data = validation)$predictions[, "1"]

# Calculate primary AP and secondary Brier score on the same flights
ap_rf_clean <- average_precision(validation$ArrDel15, validation$prob_rf_clean)
ap_rf_leakage <- average_precision(validation$ArrDel15, validation$prob_rf_leakage)

# Use the numeric validation outcome, not the factor training outcome.
brier_rf_clean <- brier_score(validation$ArrDel15, validation$prob_rf_clean)
brier_rf_leakage <- brier_score(validation$ArrDel15, validation$prob_rf_leakage)

rf_results <- data.frame(model = c("Random forest: clean information",
                                   "Random forest: leakage added"),
                         AP = c(ap_rf_clean, ap_rf_leakage),
                         Brier = c(brier_rf_clean, brier_rf_leakage))

print(rf_results)
print(c(
  AP_gain = ap_rf_leakage - ap_rf_clean,
  Brier_reduction = brier_rf_clean - brier_rf_leakage
))

# Save results and models
dir.create("results/pilot", recursive = TRUE, showWarnings = FALSE)
write.csv(rf_results, "results/pilot/random_forest_validation_AP.csv",
          row.names = FALSE)

saveRDS(list(clean = rf_clean, leakage = rf_leakage),
        "results/pilot/random_forest_models.rds")

## CHECKING!!!

# Load logistic models saved earlier
logistic_models <- readRDS("results/pilot/logistic_models.rds")

validation$prob_logistic_clean <- predict(
  logistic_models$clean,
  newdata = validation,
  type = "response"
)

# Compare clean models within each validation date
daily_results <- do.call(
  rbind,
  lapply(split(validation, validation$FlightDate), function(d) {
    data.frame(
      date = as.character(d$FlightDate[1]),
      flights = nrow(d),
      delay_rate = mean(d$ArrDel15),
      logistic_AP = if (sum(d$ArrDel15) > 0)
        average_precision(d$ArrDel15, d$prob_logistic_clean) else NA_real_,
      forest_AP = if (sum(d$ArrDel15) > 0)
        average_precision(d$ArrDel15, d$prob_rf_clean) else NA_real_
    )
  })
)

rownames(daily_results) <- NULL
daily_results

daily_risk <- aggregate(
  cbind(
    actual_delay_rate = ArrDel15,
    logistic_mean_risk = prob_logistic_clean,
    forest_mean_risk = prob_rf_clean
  ) ~ FlightDate,
  data = validation,
  FUN = mean
)

daily_risk

# Numeric 0/1 outcome from the saved training data
weekday_training <- aggregate(
  ArrDel15 ~ DayOfWeek,
  data = pilot$train,
  FUN = mean
)

names(weekday_training)[2] <- "training_delay_rate"

# One row per validation date
validation_days <- unique(
  validation[, c("FlightDate", "DayOfWeek")]
)

weekday_check <- merge(
  validation_days,
  weekday_training,
  by = "DayOfWeek",
  all.x = TRUE
)

weekday_check[order(weekday_check$FlightDate), ]
