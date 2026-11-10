# Random-forest tuning with an equal budget per information condition (for the FINAL analysis).
#   Grid: mtry in {2, 3, 6, 12, 20} x min.node.size in {20, 100, 300}; 500 trees; same grid for C, W and WO.
#   (First round used mtry {3, 6, 12} x node {20, 100}; the best C/W settings sat on the grid edge, so it was widened.)
#   mtry = 20 fits are grown as two 250-tree forests (seeds 924, 925) whose predictions are averaged;
#   a probability forest predicts the mean over trees, so this equals one 500-tree forest (same budget).
#   Fit on training flights (Jan-Apr), score on validation flights (May-Jun); select by validation AP.
#   The selected settings are frozen and used to refit on Jan-Jun for the final test evaluation.
#   Midway results (results/midway) stay untuned: validation AP after selecting on validation is optimistic.
# Input : data/processed/closed10/midway_split.rds (scripts/03_prepare_midway.R)
# Output: results/tuning/preds/*.rds, results/tuning/rf_grid.csv, rf_selected.csv, rf_leakage_by_setting.csv
# Run from the project root:  Rscript scripts/07_tune_rf.R [max_minutes]
#   Fits are cached, so the script can be rerun until all 45 fits exist; then it writes the summaries.
suppressPackageStartupMessages({ library(dplyr); library(readr); library(ranger); library(tidyr) })
source("scripts/midway_helpers.R"); source("proposal/scripts/metrics.R")
args <- commandArgs(trailingOnly = TRUE)
max_minutes <- if (length(args)) as.numeric(args[1]) else Inf
TUNE_DIR <- "results/tuning"; pred_dir <- file.path(TUNE_DIR, "preds")
dir.create(pred_dir, recursive = TRUE, showWarnings = FALSE)
GRID <- expand_grid(condition = c("C", "W", "WO"), mtry = c(2L, 3L, 6L, 12L, 20L), min_node = c(20L, 100L, 300L))
pred_file <- function(cond, mtry, node) file.path(pred_dir, sprintf("rf_%s_m%02d_n%03d.rds", cond, mtry, node))

split <- readRDS(SPLIT_FILE)$data
train_all <- split[split$split == "train", ]; valid_all <- split[split$split == "validation", ]
t_start <- Sys.time()
for (i in seq_len(nrow(GRID))) {
  g <- GRID[i, ]; f <- pred_file(g$condition, g$mtry, g$min_node)
  if (file.exists(f)) next
  if (as.numeric(difftime(Sys.time(), t_start, units = "mins")) > max_minutes) { message("time budget reached"); break }
  tr <- condition_data(train_all, g$condition); va <- condition_data(valid_all, g$condition)
  tr$ArrDel15 <- factor(tr$ArrDel15, levels = c(0, 1))
  t0 <- Sys.time()
  n_chunks <- if (g$mtry >= 20) 2L else 1L
  for (k in seq_len(n_chunks)) {
    chunk_file <- sub("\\.rds$", sprintf("_chunk%d.rds", k), f)
    if (n_chunks > 1 && file.exists(chunk_file)) next
    if (k > 1 && as.numeric(difftime(Sys.time(), t_start, units = "mins")) > max_minutes) break
    fit <- ranger(dependent.variable.name = "ArrDel15", data = tr[, c("ArrDel15", predictors(g$condition))],
                  probability = TRUE, num.trees = 500 / n_chunks, mtry = g$mtry, min.node.size = g$min_node,
                  respect.unordered.factors = "order", num.threads = 4, seed = 924 + k - 1)
    p <- predict(fit, data = va[, predictors(g$condition)])$predictions[, "1"]
    rm(fit); gc(verbose = FALSE)
    if (n_chunks > 1) saveRDS(data.frame(flight_id = va$flight_id, p = p), chunk_file)
  }
  if (n_chunks > 1) {
    chunks <- vapply(seq_len(n_chunks), function(k) sub("\\.rds$", sprintf("_chunk%d.rds", k), f), character(1))
    if (!all(file.exists(chunks))) { message("partial chunks saved; rerun"); break }
    p <- Reduce(`+`, lapply(chunks, function(x) readRDS(x)$p)) / n_chunks
  }
  saveRDS(data.frame(flight_id = va$flight_id, p = p), f)
  message(sprintf("%s mtry=%d node=%d: %.1f min", g$condition, g$mtry, g$min_node,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

done <- file.exists(mapply(pred_file, GRID$condition, GRID$mtry, GRID$min_node))
if (!all(done)) { message(sum(done), "/", nrow(GRID), " fits done; rerun to continue"); quit(save = "no") }

y <- valid_all %>% select(flight_id, ArrDel15)
grid <- GRID %>% rowwise() %>% mutate({
  d <- readRDS(pred_file(condition, mtry, min_node)) %>% inner_join(y, by = "flight_id")
  tibble(AP = average_precision(d$ArrDel15, d$p), Brier = mean((d$p - d$ArrDel15)^2), mean_p = mean(d$p))
}) %>% ungroup()
write_csv(grid, file.path(TUNE_DIR, "rf_grid.csv"))
selected <- grid %>% group_by(condition) %>% arrange(desc(AP), Brier, .by_group = TRUE) %>% slice(1) %>% ungroup()
write_csv(selected, file.path(TUNE_DIR, "rf_selected.csv"))
# Is the leakage contrast sensitive to the hyperparameters? Same setting under each condition.
leak <- grid %>% select(condition, mtry, min_node, AP) %>% pivot_wider(names_from = condition, values_from = AP) %>%
  mutate(`W - C` = W - C, `WO - C` = WO - C)
write_csv(leak, file.path(TUNE_DIR, "rf_leakage_by_setting.csv"))
print(grid %>% mutate(across(c(AP, Brier, mean_p), ~ round(.x, 4))), n = 30)
cat("\nSelected (max validation AP):\n"); print(selected)
cat("\nLeakage contrast by setting (AP):\n"); print(leak %>% mutate(across(where(is.double), ~ round(.x, 4))))
