# Fit C (early intensity), W (later p01i amount), and WO (W + operational leakage).
# Same non-weather predictors and flights for logistic regression and random forest.
# Run from the project root after 02_prepare_data.R. Reserved test is not scored.
if (!requireNamespace("ranger", quietly = TRUE)) stop("Install the ranger package first.")
source("scripts/weather_helpers.R")
pilot <- readRDS("data/processed/january_pilot_split.rds")
stopifnot(identical(readRDS("data/processed/weather_config_used.rds"), weather_config))
development <- common_model_rows(pilot)
train <- development$train
validation <- development$validation
formulas <- pilot_weather_formulas()

logistic_models <- lapply(formulas, function(formula) {
  model <- glm(formula, data = train, family = binomial())
  stopifnot(model$converged, all(is.finite(coef(model))))
  model
})

train_rf <- train
train_rf$ArrDel15 <- factor(train_rf$ArrDel15, levels = c(0, 1))
rf_models <- lapply(formulas, function(formula) {
  ranger::ranger(formula, data = train_rf, probability = TRUE,
                 num.trees = 500, mtry = 2, min.node.size = 20,
                 respect.unordered.factors = "partition", num.threads = 2, seed = 924)
})

# One prediction file ensures every condition is evaluated on the same flights.
predictions <- validation[, c("source_row", "FlightDate", "ArrDel15")]
predictions$constant <- rep(mean(train$ArrDel15), nrow(validation))
for (condition in names(formulas)) {
  predictions[[paste0("logistic_", condition)]] <-
    predict(logistic_models[[condition]], newdata = validation, type = "response")
  predictions[[paste0("forest_", condition)]] <-
    predict(rf_models[[condition]], data = validation)$predictions[, "1"]
}
probabilities <- as.matrix(predictions[, -(1:3)])
stopifnot(!anyNA(predictions), all(is.finite(probabilities)),
          all(probabilities >= 0 & probabilities <= 1),
          !any(predictions$source_row %in% pilot$test$source_row))

dir.create("results/pilot", recursive = TRUE, showWarnings = FALSE)
write.csv(predictions, "results/pilot/proposal_validation_predictions.csv", row.names = FALSE)
saveRDS(list(logistic = logistic_models, random_forest = rf_models,
             formulas = formulas, weather_config = weather_config,
             training_flights = nrow(train), validation_flights = nrow(validation),
             validation_delay_rate = mean(validation$ArrDel15),
             reserved_test_flights = nrow(pilot$test)),
        "results/pilot/proposal_models.rds")
capture.output(sessionInfo(), file = "results/pilot/session_info.txt")
message("Models fitted; all validation predictions saved. Reserved test not scored.")
