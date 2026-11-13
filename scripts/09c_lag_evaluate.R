# Reporting-lag sensitivity, step 3: validation AP of the clean models under each lag scenario,
#   AP(C_L) - AP(C_0), and the leakage contrasts W - C_L and WO - C_L (W / WO predictions from the
#   midway, results/midway/preds), with 1-day block bootstrap 95% CIs.
# Input : results/lag_sensitivity/preds/*.rds (09b_lag_fit.R), results/midway/preds/*_{W,WO}.rds, midway_split.rds
# Output: results/lag_sensitivity/{lag_ap.csv, lag_differences.csv, lag_results.md}
# Run from the project root:  Rscript scripts/09c_lag_evaluate.R [B]
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr); library(parallel) })
source("scripts/midway_helpers.R"); source("proposal/scripts/metrics.R")
args <- commandArgs(trailingOnly = TRUE); B <- if (length(args)) as.integer(args[1]) else 1000L
OUT <- "results/lag_sensitivity"; MODELS <- c("lr_full", "lr_lasso", "rf")
SCEN <- c("L0", "L15", "L30", "L60", "wx60", "bts60")
LAGS <- readRDS("data/processed/closed10/lag_features.rds")$scenarios

lagp <- bind_rows(lapply(list.files(file.path(OUT, "preds"), full.names = TRUE), readRDS)) %>%
  transmute(flight_id, key = paste0(model, "|C_", scenario), p)
midp <- bind_rows(lapply(list.files(file.path(MIDWAY_DIR, "preds"), pattern = "_(W|WO|C)\\.rds$", full.names = TRUE), readRDS)) %>%
  filter(model %in% MODELS) %>% transmute(flight_id, key = paste0(model, "|", condition, "_midway"), p)
y <- readRDS(SPLIT_FILE)$data %>% filter(split == "validation") %>% select(flight_id, FlightDate, ArrDel15)
wide <- bind_rows(lagp, midp) %>% pivot_wider(names_from = key, values_from = p) %>%
  inner_join(y, by = "flight_id") %>% filter(flight_id %in% lagp$flight_id) %>% arrange(FlightDate)
keys <- setdiff(names(wide), c("flight_id", "FlightDate", "ArrDel15"))
stopifnot(!anyNA(wide[keys]))
yv <- wide$ArrDel15; P <- as.matrix(wide[keys])
ap_vec <- function(idx) vapply(keys, function(k) average_precision(yv[idx], P[idx, k]), 0)

contr <- bind_rows(
  expand_grid(model = MODELS, scenario = SCEN[-1]) %>% mutate(contrast = "C_L - C_0", to = paste0("C_", scenario), from = "C_L0"),
  expand_grid(model = MODELS, scenario = SCEN) %>% mutate(contrast = "W - C_L", to = "W_midway", from = paste0("C_", scenario)),
  expand_grid(model = MODELS, scenario = SCEN) %>% mutate(contrast = "WO - C_L", to = "WO_midway", from = paste0("C_", scenario)))
diff_vals <- function(a) a[paste0(contr$model, "|", contr$to)] - a[paste0(contr$model, "|", contr$from)]

point <- ap_vec(seq_along(yv))
days <- sort(unique(wide$FlightDate)); day_idx <- split(seq_along(yv), factor(wide$FlightDate, levels = days))
t0 <- Sys.time()
reps <- do.call(rbind, mclapply(seq_len(B), function(b) {
  set.seed(20000 + b); diff_vals(ap_vec(unlist(day_idx[sample(seq_along(days), length(days), replace = TRUE)], use.names = FALSE)))
}, mc.cores = 4))
message("bootstrap ", B, " reps in ", round(difftime(Sys.time(), t0, units = "secs")), " s")

ap_tab <- tibble(key = keys, AP = point) %>% separate(key, c("model", "condition"), sep = "\\|") %>%
  mutate(n = nrow(wide), delay_rate = mean(yv))
write_csv(ap_tab, file.path(OUT, "lag_ap.csv"))
diffs <- contr %>% mutate(lag_weather = sapply(scenario, function(s) LAGS[[s]][["wx"]]),
                          lag_bts = sapply(scenario, function(s) LAGS[[s]][["bts"]]),
                          ap_diff = diff_vals(point), ci_lo = apply(reps, 2, quantile, .025), ci_hi = apply(reps, 2, quantile, .975),
                          block_days = 1, bootstrap_reps = B) %>% select(-to, -from)
write_csv(diffs, file.path(OUT, "lag_differences.csv"))

f3 <- function(x) sprintf("%.3f", x); f4 <- function(x) sprintf("%+.4f", x)
lab <- c(L0 = "0 / 0 (midway assumption)", L15 = "15 / 15", L30 = "30 / 30", L60 = "60 / 60", wx60 = "60 / 0 (weather only)", bts60 = "0 / 60 (BTS only)")
ci <- function(d) paste0(f4(d$ap_diff), " [", f4(d$ci_lo), ", ", f4(d$ci_hi), "]")
row <- function(s) {
  cells <- sapply(MODELS, function(m) {
    a <- ap_tab$AP[ap_tab$model == m & ap_tab$condition == paste0("C_", s)]
    d <- diffs %>% filter(model == m, scenario == s, contrast == "C_L - C_0")
    paste0(f3(a), if (nrow(d)) paste0(" (", ci(d), ")") else "")
  })
  paste0("| ", lab[[s]], " | ", paste(cells, collapse = " | "), " |")
}
row_w <- function(s, ct) paste0("| ", lab[[s]], " | ", paste(sapply(MODELS, function(m) ci(diffs %>% filter(model == m, scenario == s, contrast == ct))), collapse = " | "), " |")
hdr <- c("| Lag (min): weather / BTS | LR (all predictors) | LR (lasso-selected) | Random forest |", "|---|---|---|---|")
md <- c("# Reporting-lag sensitivity (validation, May–Jun 2025)", "",
  paste0("Clean predictors rebuilt as if METAR reports and BTS outcomes became available L minutes after they occurred; ",
         "clean models refit with the midway settings (lasso selection held fixed). Same ", format(nrow(wide), big.mark = ","),
         " validation flights in every row (delay rate ", f3(mean(yv)), "). 95% CIs: 1-day block bootstrap, ", B, " reps. ",
         "W and WO predictions are the midway ones."), "",
  "## Table L1. AP of the clean models, and AP(C_L) − AP(C_0) [95% CI]", "", hdr, sapply(SCEN, row), "",
  "## Table L2. Weather leakage gain AP(W) − AP(C_L) [95% CI]", "", hdr, sapply(SCEN, row_w, ct = "W - C_L"), "",
  "## Table L3. Weather + operational leakage gain AP(WO) − AP(C_L) [95% CI]", "", hdr, sapply(SCEN, row_w, ct = "WO - C_L"), "",
  paste0("Check: midway AP(C) on these flights = ", paste(sapply(MODELS, function(m) paste0(m, " ", f3(ap_tab$AP[ap_tab$model == m & ap_tab$condition == "C_midway"]))), collapse = ", "), "."))
writeLines(md, file.path(OUT, "lag_results.md"))
cat(md, sep = "\n")
