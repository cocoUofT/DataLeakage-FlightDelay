# Final study, step 3: fit clean models at each prediction time, with and without rotation features.
#   Train Jan-Apr 2025, predict validation May-Jun 2025 (test period untouched).
#   Same flights at every horizon: a flight is kept only if complete at ALL horizons.
#   Models: logistic regression (all predictors; hours as natural splines) and random forest with the
#   clean settings tuned at 2 h (scripts/07_tune_rf.R: mtry 3, min.node.size 300, 500 trees), held fixed.
#   Feature sets: "base"     midway clean predictors
#                 "rotation" base + aircraft rotation features (latest known state along the chain)
#                 "prev1"    same, but using ONLY the previous leg: if it has not departed by the cutoff, nothing
#                            is known (no look-back to earlier legs) - measures the value of the chain look-back
#   At h = 120 also "oracle": rotation + the previous leg's FINAL arrival delay and the delay it implies for
#   this flight (unavailable at the cutoff) - an upper bound for perfect inbound-aircraft information.
#   Existing prediction files are reused; delete one to refit it.
#   Population (2nd argument): "regular" (main; irregular recorded rotations excluded from training and
#   evaluation, see final_helpers.R) or "all_flights" (sensitivity).
# Output: final/results/<population>/preds/<model>_<set>_h<h>.rds, final/data/keep_ids_<population>.rds
# Run from the project root:  Rscript final/R/03_fit_by_horizon.R keep              (once, after all horizons are built)
#                             Rscript final/R/03_fit_by_horizon.R <h> [population]  (one horizon per run; default regular)
suppressPackageStartupMessages({ library(dplyr); library(splines); library(ranger) })
source("final/R/final_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
pop <- if (length(args) >= 2) args[2] else "regular"
pred_dir <- file.path(pop_dir(pop), "preds"); dir.create(pred_dir, recursive = TRUE, showWarnings = FALSE)
study <- readRDS(file.path(FINAL_DATA, "study.rds"))

prepare <- function(h) {
  f <- readRDS(file.path(FINAL_DATA, sprintf("features_h%03d.rds", h)))
  d <- study %>% select(flight_id, FlightDate, split, ArrDel15, all_of(SCHEDULE_VARS)) %>%
    inner_join(f, by = "flight_id") %>%
    mutate(sd_origin_none = as.integer(sd_origin_n == 0), sd_origin_n_log = log1p(sd_origin_n),
           rc_dest_3h_none = as.integer(rc_dest_3h_n == 0), rc_dest_3h_n_log = log1p(rc_dest_3h_n))
  tr <- d$split == "train"
  for (v in c("sd_origin_dep15_rate", "rc_dest_3h_rate")) d[[v]][is.na(d[[v]])] <- mean(d[[v]][tr], na.rm = TRUE)
  d$rot_turn_sched[is.na(d$rot_turn_sched)] <- median(d$rot_turn_sched[tr], na.rm = TRUE)   # no_prev flights
  d
}

if (args[1] == "keep") {
  needed <- predictors_final(TRUE)
  ok <- Reduce(`&`, lapply(HORIZONS, function(h) {
    d <- prepare(h); message("h = ", h, ": incomplete ", sum(!complete.cases(d[, needed])))
    complete.cases(d[, needed])
  }))
  ids <- prepare(HORIZONS[1])$flight_id[ok]
  saveRDS(ids, file.path(FINAL_DATA, "keep_ids_all_flights.rds"))
  irr <- study$flight_id[irregular_rotation(readRDS(file.path(FINAL_DATA, "legs.rds")), study)]
  reg <- setdiff(ids, irr)
  saveRDS(reg, file.path(FINAL_DATA, "keep_ids_regular.rds"))
  message("all_flights: kept ", length(ids), " of ", length(ok), " flights (complete at every horizon); ",
          "regular: ", length(reg), " (", length(ids) - length(reg), " irregular rotations removed)")
  quit(save = "no")
}

h <- as.integer(args[1])
keep <- readRDS(file.path(FINAL_DATA, paste0("keep_ids_", pop, ".rds")))
d <- prepare(h) %>% filter(flight_id %in% keep)
tr <- d[d$split == "train", ]; va <- d[d$split == "validation", ]
lr_formula <- function(vars) {
  terms <- ifelse(vars %in% c("dep_hour", "arr_hour"), paste0("ns(", vars, ", df = 5)"), vars)
  as.formula(paste("ArrDel15 ~", paste(terms, collapse = " + ")))
}
save_pred <- function(model, set, p) saveRDS(data.frame(flight_id = va$flight_id, model = model, set = set, horizon = h, p = as.numeric(p)),
                                             file.path(pred_dir, sprintf("%s_%s_h%03d.rds", model, set, h)))
# prev1-only version of the rotation features
prev1_only <- function(x) {
  deep <- x$rot_state == "chain_known"
  x$p1_state <- x$rot_state; x$p1_state[deep] <- "chain_unknown"; x$p1_state <- droplevels(x$p1_state)
  x$p1_known_delay <- ifelse(deep, 0, x$rot_known_delay); x$p1_proj_delay <- ifelse(deep, 0, x$rot_proj_delay)
  x$p1_legs_to_go <- ifelse(deep, x$rot_chain_len, x$rot_legs_to_go); x$p1_known_age_h <- ifelse(deep, 0, x$rot_known_age_h)
  x
}
tr <- prev1_only(tr); va <- prev1_only(va)
sets <- list(base = predictors_final(FALSE), rotation = predictors_final(TRUE),
             prev1 = c(predictors_final(FALSE), "p1_state", "p1_known_delay", "p1_legs_to_go", "p1_proj_delay", "rot_turn_sched", "p1_known_age_h"))
if (h == 120) {
  add_oracle <- function(x) {
    has <- !is.na(x$oracle_prev_arr_delay)
    x$oracle_prev_late <- ifelse(has, x$oracle_prev_arr_delay, 0)
    x$oracle_proj <- ifelse(has, pmax(0, x$oracle_prev_arr_delay + ROT_MTT - x$rot_turn_sched), 0)
    x
  }
  tr <- add_oracle(tr); va <- add_oracle(va)
  sets$oracle <- c(predictors_final(TRUE), "oracle_prev_late", "oracle_proj")
}
imp_file <- file.path(pred_dir, sprintf("importance_h%03d.rds", h))
imp <- if (file.exists(imp_file)) split(readRDS(imp_file), readRDS(imp_file)$set) else list()
for (s in names(sets)) {
  vars <- sets[[s]]
  if (file.exists(file.path(pred_dir, sprintf("rf_%s_h%03d.rds", s, h))) && file.exists(file.path(pred_dir, sprintf("lr_%s_h%03d.rds", s, h)))) next
  t0 <- Sys.time()
  fit <- glm(lr_formula(vars), data = tr, family = binomial())
  save_pred("lr", s, predict(fit, newdata = va, type = "response"))
  trf <- tr[, c("ArrDel15", vars)]; trf$ArrDel15 <- factor(trf$ArrDel15, levels = c(0, 1))
  rf <- ranger(dependent.variable.name = "ArrDel15", data = trf, probability = TRUE, num.trees = 500,
               mtry = 3, min.node.size = 300, respect.unordered.factors = "order", importance = "impurity",
               num.threads = 4, seed = 924)
  save_pred("rf", s, predict(rf, data = va[, vars])$predictions[, "1"])
  imp[[s]] <- data.frame(horizon = h, set = s, variable = names(rf$variable.importance), importance = unname(rf$variable.importance))
  message(sprintf("h = %s, %s: %.1f min", horizon_label(h), s, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(fit, rf); gc(verbose = FALSE)
}
saveRDS(bind_rows(imp), imp_file)
