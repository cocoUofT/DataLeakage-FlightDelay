
# Import clean data
pilot <- readRDS("data/processed/january_pilot_split.rds")
source("scripts/metrics.R")

train <- pilot$train
validation <- pilot$validation

# Logistic model with clean information only
logistic_clean <- glm(ArrDel15 ~ DayOfWeek + scheduled_dep_minutes +
                        CRSElapsedTime + Distance, 
                      data = train, family = binomial())

# Logistic model with leakage information
logistic_leakage <- glm(ArrDel15 ~ DayOfWeek + scheduled_dep_minutes +
                          CRSElapsedTime + Distance + DepDelay + TaxiOut,
                        data = train, family = binomial())

# Validation probability
validation$prob_clean <- predict(logistic_clean, newdata = validation,
                                 type = "response")

validation$prob_leakage <- predict(logistic_leakage, newdata = validation,
                                   type = "response")

# Compare AP and Brier score on the same validation flights

ap_clean <- average_precision(validation$ArrDel15, validation$prob_clean)

ap_leakage <- average_precision(validation$ArrDel15, validation$prob_leakage)

brier_clean <- brier_score(validation$ArrDel15, validation$prob_clean)
brier_leakage <- brier_score(validation$ArrDel15, validation$prob_leakage)

data.frame(model = c("Clean information", "Leakage added"),
           average_precision = c(ap_clean, ap_leakage),
           Brier = c(brier_clean, brier_leakage))

# Apparent performance gain from unavailable information
ap_leakage - ap_clean


## Save results
# Estimate the constant probability from training outcomes only.
constant_probability <- rep(mean(train$ArrDel15), nrow(validation))
ap_constant <- average_precision(validation$ArrDel15, constant_probability)
brier_constant <- brier_score(validation$ArrDel15, constant_probability)

validation_results <- data.frame(
  model = c("Constant probability", "Logistic: scheduled information",
            "Logistic: leakage added"), 
  AP = c(ap_constant, ap_clean, ap_leakage),
  Brier = c(brier_constant, brier_clean, brier_leakage))

print(validation_results)
# Both differences are positive when leakage improves apparent performance.
print(c(
  AP_gain = ap_leakage - ap_clean,
  Brier_reduction = brier_clean - brier_leakage
))

dir.create("results/pilot", recursive = TRUE, showWarnings = FALSE)

write.csv(validation_results, "results/pilot/logistic_validation_AP.csv",
          row.names = FALSE)

saveRDS(list(clean = logistic_clean, leakage = logistic_leakage),
        "results/pilot/logistic_models.rds")
