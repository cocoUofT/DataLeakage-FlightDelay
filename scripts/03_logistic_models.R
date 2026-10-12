
# Import clean data
pilot <- readRDS("data/processed/january_pilot_split.rds")

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

# Calculate average precision (AP)
average_precision <- function(actual, probability) {
  stopifnot(length(actual) == length(probability), all(actual %in% c(0, 1)),
            all(is.finite(probability)), all(probability >= 0 & probability <= 1),
            sum(actual == 1) > 0)
  # Sort flights from highest to lowest predicted risk
  index <- order(probability, decreasing = TRUE)
  actual <- actual[index]
  probability <- probability[index]
  # Evaluate at the end of each group of tied probabilities
  endpoints <- cumsum(rle(probability)$lengths)
  true_positives <- cumsum(actual == 1)[endpoints]
  precision <- true_positives / endpoints
  recall <- true_positives / sum(actual == 1)
  
  sum(diff(c(0, recall)) * precision)}

# Compare AP

ap_clean <- average_precision(validation$ArrDel15, validation$prob_clean)

ap_leakage <- average_precision(validation$ArrDel15, validation$prob_leakage)

data.frame(model = c("Clean information", "Leakage added"),
           average_precision = c(ap_clean, ap_leakage))

# Apparent performance gain from unavailable information
ap_leakage - ap_clean


## Save results
ap_constant <- average_precision(validation$ArrDel15,
                                 rep(mean(train$ArrDel15), nrow(validation)))

validation_results <- data.frame(
  model = c("Constant probability", "Logistic: scheduled information",
            "Logistic: leakage added"), 
  AP = c(ap_constant, ap_clean, ap_leakage))

write.csv(validation_results, "results/pilot/logistic_validation_AP.csv",
          row.names = FALSE)

saveRDS(list(clean = logistic_clean, leakage = logistic_leakage),
        "results/pilot/logistic_models.rds")


