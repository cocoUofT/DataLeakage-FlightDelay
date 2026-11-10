# Compare midway results without (v1) and with (v2, results/midway) the network-wide recent delay-rate
# features. The saved outputs (results/midway/compare_network_feature*.csv) are the record of this check.
# v1 results are no longer kept in the working tree; to rerun, restore them from commit e876758:
#   mkdir -p results/midway_v1_no_network && git archive e876758 results/midway | tar -x --strip-components=2 -C results/midway_v1_no_network
# Output: results/midway/compare_network_feature.csv, compare_network_feature_bootstrap.csv
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
v1 <- "results/midway_v1_no_network"; v2 <- "results/midway"
m <- bind_rows(read_csv(file.path(v1, "metrics_validation.csv"), show_col_types = FALSE) %>% mutate(version = "v1"),
               read_csv(file.path(v2, "metrics_validation.csv"), show_col_types = FALSE) %>% mutate(version = "v2"))
cal <- bind_rows(read_csv(file.path(v1, "calibration_summary.csv"), show_col_types = FALSE) %>% mutate(version = "v1"),
                 read_csv(file.path(v2, "calibration_summary.csv"), show_col_types = FALSE) %>% mutate(version = "v2")) %>%
  select(model, condition, version, brier_intercept_shifted)
pd <- bind_rows(read_csv(file.path(v1, "paired_differences.csv"), show_col_types = FALSE) %>% mutate(version = "v1"),
                read_csv(file.path(v2, "paired_differences.csv"), show_col_types = FALSE) %>% mutate(version = "v2")) %>%
  filter(block_days == 1, contrast != "WO - W") %>%
  transmute(model, version, contrast, gain = sprintf("%.3f [%.3f, %.3f]", ap_gain, ap_lo, ap_hi))
tab <- m %>% filter(model != "constant") %>% left_join(cal, by = c("model", "condition", "version")) %>%
  select(model, condition, version, AP, Brier, mean_p, brier_intercept_shifted) %>%
  mutate(across(c(AP, Brier, mean_p, brier_intercept_shifted), ~ round(.x, 4)))
write_csv(tab, file.path(v2, "compare_network_feature.csv"))
cat("validation delay rate:", round(unique(m$delay_rate), 3), "\n\n")
print(tab %>% filter(condition == "C") %>% arrange(model, version), n = 50)
cat("\nPaired AP gains (95% CI):\n"); print(pd %>% pivot_wider(names_from = contrast, values_from = gain) %>% arrange(model, version))

# Paired bootstrap (resampling validation days) of the clean-model change v2 - v1
source("proposal/scripts/metrics.R"); source("scripts/midway_helpers.R")
y <- readRDS(SPLIT_FILE)$data %>% filter(split == "validation") %>% select(flight_id, FlightDate, ArrDel15)
get_p <- function(dir, model) readRDS(file.path(dir, "preds", paste0(model, "_C.rds"))) %>% select(flight_id, p)
set.seed(2112)
boot_tab <- bind_rows(lapply(c("lr_full", "lr_lasso", "rf"), function(mod) {
  d <- y %>% inner_join(get_p(v1, mod) %>% rename(p1 = p), by = "flight_id") %>%
    inner_join(get_p(v2, mod) %>% rename(p2 = p), by = "flight_id")
  days <- split(seq_len(nrow(d)), d$FlightDate)
  stat <- function(i) c(ap = average_precision(d$ArrDel15[i], d$p2[i]) - average_precision(d$ArrDel15[i], d$p1[i]),
                        brier = mean((d$p1[i] - d$ArrDel15[i])^2) - mean((d$p2[i] - d$ArrDel15[i])^2))
  est <- stat(seq_len(nrow(d)))
  reps <- t(replicate(1000, stat(unlist(days[sample(length(days), replace = TRUE)], use.names = FALSE))))
  tibble(model = mod, ap_change = est[["ap"]], ap_lo = quantile(reps[, "ap"], .025), ap_hi = quantile(reps[, "ap"], .975),
         brier_reduction = est[["brier"]], brier_lo = quantile(reps[, "brier"], .025), brier_hi = quantile(reps[, "brier"], .975))
}))
write_csv(boot_tab, file.path(v2, "compare_network_feature_bootstrap.csv"))
cat("\nClean model, v2 - v1 (95% CI, 1000 reps over validation days):\n"); print(boot_tab %>% mutate(across(-model, ~ round(.x, 4))))
