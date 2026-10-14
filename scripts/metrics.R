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


# Calculate Brier Score
calculate_brier_score <- function(actual, probability) {
  # Brier score is the mean squared difference between predicted probability and actual outcome
  mean((probability - actual)^2, na.rm = TRUE)
}

# Calculate Log-Loss (Cross-Entropy Loss)
calculate_log_loss <- function(actual, probability) {
  # Clip probabilities to prevent log(0) which results in -Inf or NaN
  eps <- 1e-15
  prob_clipped <- pmax(pmin(probability, 1 - eps), eps)
  
  # Calculate negative log-likelihood
  -mean(actual * log(prob_clipped) + (1 - actual) * log(1 - prob_clipped), na.rm = TRUE)
}
