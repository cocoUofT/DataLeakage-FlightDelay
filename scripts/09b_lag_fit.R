# Reporting-lag sensitivity, step 2: refit the CLEAN models with the lagged C predictors.
#   Same models and settings as scripts/04_fit_midway.R: lr_full; lr_lasso with the midway lasso
#   selection held fixed (results/midway/lasso_selection.csv), refit unpenalized; rf (ranger, 500 trees).
#   Flights: midway-analysed flights that are complete under every lag scenario (same flights everywhere).
# Input : data/processed/closed10/{midway_split.rds, lag_features.rds} (09a_lag_features.R)
# Output: results/lag_sensitivity/preds/<model>_<scenario>.rds
# Run from the project root:  Rscript scripts/09b_lag_fit.R <scenario> [lr] [rf]
suppressPackageStartupMessages({ library(dplyr); library(readr); library(splines); library(ranger) })
source("scripts/midway_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
scen <- args[1]; parts <- if (length(args) > 1) args[-1] else c("lr", "rf")
pred_dir <- "results/lag_sensitivity/preds"; dir.create(pred_dir, recursive = TRUE, showWarnings = FALSE)

lag <- readRDS("data/processed/closed10/lag_features.rds")
mid <- readRDS(SPLIT_FILE)$data
c_cols <- c(HISTORY_VARS, paste0(WEATHER_VARS, "_C"), paste0(WEATHER_VARS, "_Dest_C"))
common <- Reduce(intersect, lapply(lag$features, function(f) {
  f <- f[f$flight_id %in% mid$flight_id, ]; f$flight_id[complete.cases(f[, c_cols])]
}))
f <- lag$features[[scen]]
df <- mid[mid$flight_id %in% common, ]
df[, c_cols] <- f[match(df$flight_id, f$flight_id), c_cols]
rm(lag, mid, f); invisible(gc())
tr <- condition_data(df[df$split == "train", ], "C"); va <- condition_data(df[df$split == "validation", ], "C")
message(scen, ": train ", nrow(tr), ", validation ", nrow(va))
save_pred <- function(name, p) saveRDS(data.frame(flight_id = va$flight_id, model = name, scenario = scen, p = as.numeric(p)),
                                       file.path(pred_dir, paste0(name, "_", scen, ".rds")))
lr_formula <- function(vars) {
  terms <- ifelse(vars %in% c("dep_hour", "arr_hour"), paste0("ns(", vars, ", df = 5)"), vars)
  as.formula(paste("ArrDel15 ~", paste(terms, collapse = " + ")))
}
if ("lr" %in% parts) {
  fit <- glm(lr_formula(predictors("C")), data = tr, family = binomial())
  save_pred("lr_full", predict(fit, newdata = va, type = "response"))
  sel <- read_csv(file.path(MIDWAY_DIR, "lasso_selection.csv"), show_col_types = FALSE)
  fit <- glm(lr_formula(sel$variable[sel$selected]), data = tr, family = binomial())
  save_pred("lr_lasso", predict(fit, newdata = va, type = "response"))
  message("lr done")
}
if ("rf" %in% parts) {
  tr$ArrDel15 <- factor(tr$ArrDel15, levels = c(0, 1)); t0 <- Sys.time()
  fit <- ranger(dependent.variable.name = "ArrDel15", data = tr[, c("ArrDel15", predictors("C"))],
                probability = TRUE, num.trees = 500, min.node.size = 20,
                respect.unordered.factors = "order", num.threads = 4, seed = 924)
  save_pred("rf", predict(fit, data = va[, predictors("C")])$predictions[, "1"])
  message("rf done in ", round(difftime(Sys.time(), t0, units = "secs")), " s")
}
