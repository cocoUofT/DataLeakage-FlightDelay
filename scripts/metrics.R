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