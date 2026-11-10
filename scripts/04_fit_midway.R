# Midway step 4: fit models on training flights (Jan-Apr) and predict validation flights (May-Jun).
#   constant  : training delay rate for every flight
#   lr_full   : logistic regression with all predictors (unpenalized glm)
#   lr_lasso  : lasso selection on C only (training data, month-blocked CV, lambda.1se);
#               the SAME selected variables are refit (unpenalized) under C, W and WO;
#               WO additionally gets DepDelay and TaxiOut, which are never subject to selection
#   rf        : random forest (ranger), all predictors, pilot settings
# Input : data/processed/closed10/midway_split.rds (scripts/03_prepare_midway.R)
# Output: results/midway/preds/<model>_<condition>.rds, lasso_selection.csv, rf_importance.csv
# Run from the project root:
#   Rscript scripts/04_fit_midway.R            # everything (RF takes a few minutes per condition)
#   Rscript scripts/04_fit_midway.R lr rf_C    # selected parts: lr | rf_C | rf_W | rf_WO
suppressPackageStartupMessages({ library(dplyr); library(readr); library(splines); library(glmnet); library(ranger) })
source("scripts/midway_helpers.R")
parts <- commandArgs(trailingOnly = TRUE)
if (!length(parts)) parts <- c("lr", "rf_C", "rf_W", "rf_WO")
pred_dir <- file.path(MIDWAY_DIR, "preds")
dir.create(pred_dir, recursive = TRUE, showWarnings = FALSE)

split <- readRDS(SPLIT_FILE)$data
train_all <- split[split$split == "train", ]
valid_all <- split[split$split == "validation", ]
save_pred <- function(name, condition, p, data = valid_all) {
  saveRDS(data.frame(flight_id = data$flight_id, model = name, condition = condition, p = as.numeric(p)),
          file.path(pred_dir, paste0(name, "_", condition, ".rds")))
}

# Formula: categorical schedule terms as factors, local hours as natural splines, everything else linear
lr_formula <- function(vars) {
  terms <- ifelse(vars %in% c("dep_hour", "arr_hour"), paste0("ns(", vars, ", df = 5)"), vars)
  as.formula(paste("ArrDel15 ~", paste(terms, collapse = " + ")))
}

if ("lr" %in% parts) {
  # ---- constant reference ----
  for (cond in c("C", "W", "WO")) save_pred("constant", cond, rep(mean(train_all$ArrDel15), nrow(valid_all)))

  # ---- full logistic regression ----
  for (cond in c("C", "W", "WO")) {
    tr <- condition_data(train_all, cond); va <- condition_data(valid_all, cond)
    fit <- glm(lr_formula(predictors(cond)), data = tr, family = binomial())
    save_pred("lr_full", cond, predict(fit, newdata = va, type = "response"))
    message("lr_full ", cond, " done (converged: ", fit$converged, ")")
  }

  # ---- lasso selection on C (training only) ----
  tr_c <- condition_data(train_all, "C")
  mf <- model.frame(lr_formula(predictors("C")), data = tr_c)
  X <- model.matrix(attr(mf, "terms"), mf)
  assign_var <- attr(X, "assign"); term_labels <- attr(attr(mf, "terms"), "term.labels")
  X <- X[, -1]; assign_var <- assign_var[-1]                       # drop intercept column
  foldid <- as.integer(factor(format(tr_c$FlightDate, "%m")))       # month-blocked folds: Jan, Feb, Mar, Apr
  set.seed(2112)
  cv <- cv.glmnet(X, tr_c$ArrDel15, family = "binomial", alpha = 1, foldid = foldid, type.measure = "deviance")
  beta <- as.matrix(coef(cv, s = "lambda.1se"))[-1, 1]
  selected_terms <- unique(term_labels[assign_var[beta != 0]])
  selected_vars <- predictors("C")[match(selected_terms,
                     ifelse(predictors("C") %in% c("dep_hour", "arr_hour"), paste0("ns(", predictors("C"), ", df = 5)"), predictors("C")))]
  write_csv(data.frame(variable = predictors("C"), selected = predictors("C") %in% selected_vars,
                       lambda_1se = cv$lambda.1se, lambda_min = cv$lambda.min),
            file.path(MIDWAY_DIR, "lasso_selection.csv"))
  message("lasso kept ", length(selected_vars), " of ", length(predictors("C")), " predictors")

  # ---- post-lasso refit: same selected variables under C, W, WO ----
  for (cond in c("C", "W", "WO")) {
    vars <- c(selected_vars, if (cond == "WO") OPERATIONAL_VARS)
    tr <- condition_data(train_all, cond); va <- condition_data(valid_all, cond)
    fit <- glm(lr_formula(vars), data = tr, family = binomial())
    save_pred("lr_lasso", cond, predict(fit, newdata = va, type = "response"))
  }
}

# ---- random forest, one condition per part so each run stays short ----
for (cond in c("C", "W", "WO")) {
  if (!paste0("rf_", cond) %in% parts) next
  tr <- condition_data(train_all, cond); va <- condition_data(valid_all, cond)
  tr$ArrDel15 <- factor(tr$ArrDel15, levels = c(0, 1))
  t0 <- Sys.time()
  fit <- ranger(dependent.variable.name = "ArrDel15", data = tr[, c("ArrDel15", predictors(cond))],
                probability = TRUE, num.trees = 500, min.node.size = 20, importance = "impurity",
                respect.unordered.factors = "order", num.threads = 4, seed = 924)
  save_pred("rf", cond, predict(fit, data = va[, predictors(cond)])$predictions[, "1"])
  imp <- data.frame(condition = cond, variable = names(fit$variable.importance),
                    importance = unname(fit$variable.importance))
  imp_file <- file.path(MIDWAY_DIR, "rf_importance.csv")
  old <- if (file.exists(imp_file)) read_csv(imp_file, show_col_types = FALSE) %>% filter(condition != cond) else NULL
  write_csv(bind_rows(old, imp), imp_file)
  message("rf ", cond, " done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min (mtry = ", fit$mtry, ")")
  rm(fit); gc(verbose = FALSE)
}
