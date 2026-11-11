library(tidyverse)
library(PRROC) 

midway_data <- readRDS("data/processed/closed10/midway_split.rds")$data %>%
  filter(split == "validation")

# Read model prediction results
preds_C <- readRDS("results/midway/preds/lr_lasso_C.rds") %>% select(flight_id, pred_C = p)
preds_W <- readRDS("results/midway/preds/lr_lasso_W.rds")%>% select(flight_id, pred_W = p)

# Merge predictions and flag severe weather
val_eval <- midway_data %>%
  left_join(preds_C, by = "flight_id") %>%
  left_join(preds_W, by = "flight_id") %>%
  mutate(
    is_severe = if_any(
      matches("ts_flag.*(C|W)|snow_fzra_flag.*(C|W)"), ~ coalesce(.x == 1, FALSE)
    ) | if_any(
      matches("vsby.*(C|W)"), ~ coalesce(.x < 3, FALSE)
    ) | if_any(
      matches("precip_intensity.*(C|W)"), ~ coalesce(.x >= 2, FALSE)
    ),
    weather_group = ifelse(is_severe, "Severe Weather", "Good Weather")
  )

# Calculate AP and perform daily block bootstrap CI 
calc_ap <- function(df, pred_col) {
  if(sum(df$ArrDel15) == 0 || sum(df$ArrDel15) == nrow(df)) return(NA)
  pr.curve(scores.class0 = df[[pred_col]][df$ArrDel15 == 1],
           scores.class1 = df[[pred_col]][df$ArrDel15 == 0])$auc.integral
}

boot_diff <- function(df, n_boot = 100) {
  dates <- unique(df$FlightDate)
  diffs <- numeric(n_boot)
  for (i in 1:n_boot) {
    boot_dates <- sample(dates, replace = TRUE)
    boot_df <- tibble(FlightDate = boot_dates) %>% left_join(df, by = "FlightDate")
    diffs[i] <- calc_ap(boot_df, "pred_W") - calc_ap(boot_df, "pred_C")
  }
  return(quantile(diffs, probs = c(0.025, 0.975), na.rm = TRUE))
}

# Summarize AP and the W-C difference for both groups
results <- val_eval %>%
  group_by(weather_group) %>%
  summarise(
    n_flights = n(),
    delay_rate = mean(ArrDel15),
    AP_C = calc_ap(cur_data(), "pred_C"),
    AP_W = calc_ap(cur_data(), "pred_W"),
    Diff_W_minus_C = AP_W - AP_C,
    .groups = "drop"
  )

# Run Bootstrap CI by group 
cat("Calculating Bootstrap CIs (this may take a minute)...\n")
severe_ci <- boot_diff(val_eval %>% filter(weather_group == "Severe Weather"))
good_ci <- boot_diff(val_eval %>% filter(weather_group == "Good Weather"))

# Merge confidence intervals into the results table
results <- results %>%
  mutate(
    CI_Lower = c(good_ci[1], severe_ci[1]),
    CI_Upper = c(good_ci[2], severe_ci[2])
  )

cat("\n--- Leakage (W - C) by Weather Condition ---\n")
print(results)