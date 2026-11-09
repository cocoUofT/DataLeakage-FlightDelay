# Produce the proposal tables from saved validation predictions; no refitting.
source("scripts/metrics.R")
predictions <- read.csv("results/pilot/proposal_validation_predictions.csv")
model_info <- readRDS("results/pilot/proposal_models.rds")
conditions <- c("clean", "weather_leakage", "leakage")
condition_labels <- c(clean = "Clean early weather (C)",
                      weather_leakage = "Later weather (W)",
                      leakage = "Later weather + operational leakage (WO)")
score <- function(probability) {
  stopifnot(length(probability) == nrow(predictions),
            !anyNA(predictions$ArrDel15), all(is.finite(probability)),
            all(probability >= 0 & probability <= 1))
  list(AP = average_precision(predictions$ArrDel15, probability),
       Brier = calculate_brier_score(predictions$ArrDel15, probability))
}
results <- data.frame(model = "Constant reference", condition = "constant",
                      information = "Training delay prevalence",
                      as.data.frame(score(predictions$constant)), row.names = NULL)
for (model in c("logistic", "forest")) {
  for (condition in conditions) {
    results <- rbind(results, data.frame(
      model = if (model == "logistic") "Logistic regression" else "Random forest",
      condition = condition, information = condition_labels[[condition]],
      as.data.frame(score(predictions[[paste0(model, "_", condition)]])), row.names = NULL))
  }
}

pairs <- list(c("clean", "weather_leakage"), c("weather_leakage", "leakage"),
              c("clean", "leakage"))
changes <- do.call(rbind, lapply(c("Logistic regression", "Random forest"), function(model) {
  do.call(rbind, lapply(pairs, function(pair) {
    before <- results[results$model == model & results$condition == pair[1], ]
    after <- results[results$model == model & results$condition == pair[2], ]
    data.frame(model = model, comparison = paste(pair, collapse = " -> "),
               AP_gain = after$AP - before$AP,
               Brier_reduction = before$Brier - after$Brier)
  }))
}))
write.csv(results, "results/pilot/proposal_validation_results.csv", row.names = FALSE)
write.csv(changes, "results/pilot/proposal_performance_changes.csv", row.names = FALSE)

# A readable table to copy into the proposal; full precision remains in the CSVs.
precipitation_description <- function(specification) {
  switch(specification,
    intensity = "categorical precipitation intensity (none/light/moderate/heavy), including snow and other supported falling precipitation",
    amount = "IEM's p01i, measured in inches accumulated since the previous hourly precipitation reset—not categorical intensity. Trace values are encoded as 0.0001 inch, not a measured trace amount",
    stop("Unknown precipitation definition"))
}
clean_description <- precipitation_description(model_info$weather_config$precipitation_predictor)
leakage_description <- precipitation_description(model_info$weather_config$leakage_precipitation_predictor)
report <- c(
  "# Proposal pilot performance comparison", "",
  sprintf("Atlanta departures, January 2025: %s training flights and %s validation flights (January 21–25).",
          format(model_info$training_flights, big.mark = ","),
          format(model_info$validation_flights, big.mark = ",")), "",
  "Wind speed is measured at the origin in knots in all conditions.", "",
  paste0("**Clean precipitation:** ", clean_description, "."), "",
  paste0("**Leakage precipitation amount:** ", leakage_description, "."), "",
  "C uses measurements before scheduled departure minus two hours. W replaces them with measurements near scheduled departure, strictly after cutoff. WO adds DepDelay and TaxiOut. All conditions use identical flights and non-weather predictors. W versus C changes both timing and precipitation representation; this difference does not isolate timing alone. WO versus W holds the weather definition fixed.", "",
  "AP: higher is better. Brier: lower is better.", "",
  "| Model | Condition | AP | Brier |", "|---|---|---:|---:|",
  vapply(seq_len(nrow(results)), function(i)
    sprintf("| %s | %s | %.4f | %.4f |", results$model[i], results$information[i],
            results$AP[i], results$Brier[i]), character(1)), "",
  "## Paired apparent performance changes", "",
  "Positive AP gains and Brier reductions indicate better apparent performance.", "",
  "| Model | Comparison | AP gain | Brier reduction |", "|---|---|---:|---:|",
  vapply(seq_len(nrow(changes)), function(i)
    sprintf("| %s | %s | %+.4f | %+.4f |", changes$model[i], changes$comparison[i],
            changes$AP_gain[i], changes$Brier_reduction[i]), character(1)), "",
  "## Interpretation limits", "",
  "These are untuned, origin-only pilot validation results over five dates. They do not demonstrate nationwide/destination performance or a causal weather effect. Forecasts, historical rates, selection and tuning are not included in these fits.", "",
  "The archive observation timestamp is not verified publication/receipt time; reporting latency and later corrections remain availability assumptions. Observations are backward-matched, not necessarily measured at each flight's exact target minute.", "",
  sprintf("The %s January 26–31 pilot test flights remain reserved from model-performance evaluation.",
          format(model_info$reserved_test_flights, big.mark = ",")), ""
)
writeLines(report, "results/pilot/proposal_comparison.md")
print(results, row.names = FALSE)
print(changes, row.names = FALSE)
message("Proposal tables saved to results/pilot/proposal_comparison.md")
