# Final study, step 4: validation performance by prediction time, value of rotation features, figures.
# Input : final/results/<population>/preds/*.rds (03), final/data/{study,keep_ids_<population>,features_h*}.rds
# Output: final/results/<population>/ horizon_metrics.csv, horizon_gains.csv, rotation_states.csv,
#         rotation_importance.csv, horizon_calibration*.csv, fig_*.png, horizon_results.md
# Run from the project root:  Rscript final/R/04_evaluate_horizons.R [B] [population]   (default 1000, regular)
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr); library(ggplot2); library(parallel) })
source("final/R/final_helpers.R"); source("proposal/scripts/metrics.R")
args <- commandArgs(trailingOnly = TRUE); B <- if (length(args)) as.integer(args[1]) else 1000L
pop <- if (length(args) >= 2) args[2] else "regular"; RES <- pop_dir(pop)
POP_LABEL <- c(regular = "regular aircraft rotations only", all_flights = "all flights")[[pop]]
CORES <- max(1L, min(4L, detectCores()))

study <- readRDS(file.path(FINAL_DATA, "study.rds")); keep <- readRDS(file.path(FINAL_DATA, paste0("keep_ids_", pop, ".rds")))
y <- study %>% filter(flight_id %in% keep, split == "validation") %>% select(flight_id, FlightDate, ArrDel15)
preds <- bind_rows(lapply(list.files(file.path(RES, "preds"), pattern = "^(lr|rf)_", full.names = TRUE), readRDS))
wide <- preds %>% mutate(key = paste(model, set, horizon, sep = "|")) %>% select(flight_id, key, p) %>%
  pivot_wider(names_from = key, values_from = p) %>% inner_join(y, by = "flight_id") %>% arrange(FlightDate)
keys <- setdiff(names(wide), c("flight_id", "FlightDate", "ArrDel15"))
stopifnot(nrow(wide) == nrow(y), !anyNA(wide[keys]))
yv <- wide$ArrDel15; P <- as.matrix(wide[keys])
ap_all <- function(idx) c(vapply(keys, function(k) average_precision(yv[idx], P[idx, k]), 0),
                          setNames(vapply(keys, function(k) mean((P[idx, k] - yv[idx])^2), 0), paste0("B:", keys)))
train_rate <- mean(study$ArrDel15[study$split == "train" & study$flight_id %in% keep])

# ---- point estimates + bootstrap over validation days ----
days <- split(seq_along(yv), wide$FlightDate)
point <- ap_all(seq_along(yv))
set.seed(2112)
reps <- do.call(rbind, mclapply(seq_len(B), function(b) { set.seed(b); ap_all(unlist(days[sample(length(days), replace = TRUE)], use.names = FALSE)) }, mc.cores = CORES))
parse_key <- function(k) { s <- strsplit(k, "|", fixed = TRUE); tibble(model = sapply(s, `[`, 1), set = sapply(s, `[`, 2), horizon = as.integer(sapply(s, `[`, 3))) }
bk <- paste0("B:", keys)
metrics <- parse_key(keys) %>% mutate(
  AP = point[keys], AP_lo = apply(reps[, keys], 2, quantile, .025), AP_hi = apply(reps[, keys], 2, quantile, .975),
  Brier = point[bk], Brier_lo = apply(reps[, bk], 2, quantile, .025), Brier_hi = apply(reps[, bk], 2, quantile, .975),
  mean_p = colMeans(P), n = length(yv), delay_rate = mean(yv),
  constant_brier = mean((train_rate - yv)^2)) %>%
  arrange(model, set, desc(horizon))
write_csv(metrics, file.path(RES, "horizon_metrics.csv"))

diff_ci <- function(a, b) { d <- reps[, a] - reps[, b]; c(est = point[[a]] - point[[b]], lo = quantile(d, .025, names = FALSE), hi = quantile(d, .975, names = FALSE),
  # Brier reduction (b minus a: positive = a has lower Brier)
  b_est = point[[paste0("B:", b)]] - point[[paste0("B:", a)]],
  b_lo = quantile(reps[, paste0("B:", b)] - reps[, paste0("B:", a)], .025, names = FALSE),
  b_hi = quantile(reps[, paste0("B:", b)] - reps[, paste0("B:", a)], .975, names = FALSE)) }
gains <- bind_rows(
  # value of rotation features at each horizon
  expand_grid(model = c("lr", "rf"), horizon = HORIZONS) %>% rowwise() %>%
    mutate(comparison = "rotation - base", v = list(diff_ci(paste(model, "rotation", horizon, sep = "|"), paste(model, "base", horizon, sep = "|")))) %>% ungroup(),
  # value of looking back along the chain (vs previous leg only)
  expand_grid(model = c("lr", "rf"), horizon = HORIZONS) %>% rowwise() %>%
    mutate(comparison = "prev1 - base", v = list(diff_ci(paste(model, "prev1", horizon, sep = "|"), paste(model, "base", horizon, sep = "|")))) %>% ungroup(),
  expand_grid(model = c("lr", "rf"), horizon = HORIZONS) %>% rowwise() %>%
    mutate(comparison = "rotation - prev1", v = list(diff_ci(paste(model, "rotation", horizon, sep = "|"), paste(model, "prev1", horizon, sep = "|")))) %>% ungroup(),
  # each horizon relative to the 2-hour cutoff (rotation models)
  expand_grid(model = c("lr", "rf"), horizon = setdiff(HORIZONS, 120L)) %>% rowwise() %>%
    mutate(comparison = "horizon - 2h (rotation)", v = list(diff_ci(paste(model, "rotation", horizon, sep = "|"), paste(model, "rotation", 120, sep = "|")))) %>% ungroup(),
  # oracle (previous leg's final arrival delay) vs legal rotation features at 2 h
  tibble(model = c("lr", "rf"), horizon = 120L) %>% rowwise() %>%
    mutate(comparison = "oracle - rotation (2h)", v = list(diff_ci(paste(model, "oracle", 120, sep = "|"), paste(model, "rotation", 120, sep = "|")))) %>% ungroup()
) %>% mutate(ap_diff = sapply(v, `[`, "est"), lo = sapply(v, `[`, "lo"), hi = sapply(v, `[`, "hi"),
         brier_reduction = sapply(v, `[`, "b_est"), brier_lo = sapply(v, `[`, "b_lo"), brier_hi = sapply(v, `[`, "b_hi")) %>% select(-v)
write_csv(gains, file.path(RES, "horizon_gains.csv"))

# ---- rotation state shares and importance ----
states <- bind_rows(lapply(HORIZONS, function(h) readRDS(file.path(FINAL_DATA, sprintf("features_h%03d.rds", h))) %>%
  filter(flight_id %in% keep) %>% count(rot_state) %>% mutate(horizon = h, share = n / sum(n))))
write_csv(states, file.path(RES, "rotation_states.csv"))
imp <- bind_rows(lapply(list.files(file.path(RES, "preds"), pattern = "^importance", full.names = TRUE), readRDS)) %>%
  filter(set == "rotation") %>% group_by(horizon) %>% mutate(rank = rank(-importance), share = importance / sum(importance)) %>% ungroup()
write_csv(imp, file.path(RES, "rotation_importance.csv"))

# ---- figures ----
SERIES <- c(lr = "#2a78d6", rf = "#1baf7a"); INK <- "#52514e"
MODEL <- c(lr = "Logistic regression", rf = "Random forest")
theme_viz <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#e6e5e1", linewidth = 0.3),
        axis.text = element_text(color = INK), axis.title = element_text(color = INK), legend.position = "top",
        legend.title = element_blank(), plot.title.position = "plot", strip.text = element_text(face = "bold", hjust = 0))
hx <- function(h) factor(horizon_label(h), levels = horizon_label(HORIZONS))
m_plot <- metrics %>% filter(set %in% c("base", "rotation")) %>%
  mutate(x = hx(horizon), series = paste0(MODEL[model], ifelse(set == "rotation", " + aircraft rotation", " (midway clean predictors)")))
oracle <- metrics %>% filter(set == "oracle") %>% mutate(x = hx(horizon))
cols <- setNames(rep(SERIES, each = 2), c(paste0(MODEL, " (midway clean predictors)"), paste0(MODEL, " + aircraft rotation"))[c(1, 3, 2, 4)])
p1 <- ggplot(m_plot, aes(x, AP, color = series, linetype = series, group = series)) +
  geom_errorbar(aes(ymin = AP_lo, ymax = AP_hi), width = 0, linewidth = 0.5, alpha = 0.6, linetype = "solid", show.legend = FALSE) +
  geom_line(linewidth = 0.8) + geom_point(size = 2.2) +
  geom_point(data = oracle, aes(x, AP), inherit.aes = FALSE, shape = 4, size = 3.2, stroke = 1.1, color = INK) +
  annotate("text", x = hx(120), y = max(oracle$AP), label = "oracle at 2 h (×): rotation + previous\nleg's final arrival (not available)", vjust = -0.4, size = 3, color = INK) +
  scale_color_manual(values = c("Logistic regression (midway clean predictors)" = SERIES[["lr"]], "Logistic regression + aircraft rotation" = SERIES[["lr"]],
                                "Random forest (midway clean predictors)" = SERIES[["rf"]], "Random forest + aircraft rotation" = SERIES[["rf"]])) +
  scale_linetype_manual(values = c("Logistic regression (midway clean predictors)" = "dashed", "Logistic regression + aircraft rotation" = "solid",
                                   "Random forest (midway clean predictors)" = "dashed", "Random forest + aircraft rotation" = "solid")) +
  guides(color = guide_legend(nrow = 2), linetype = guide_legend(nrow = 2)) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.15))) +
  labs(x = "Prediction time (before scheduled departure)", y = "Average precision (95% CI)",
       title = "Clean-model performance rises as the prediction time moves closer to departure",
       subtitle = sprintf("Validation flights May–Jun 2025, %s (n = %s, delay rate %.3f).\nSame flights at every prediction time; each model uses only information known at its prediction time.",
                          POP_LABEL, format(length(yv), big.mark = ","), mean(yv))) +
  theme_viz
ggsave(file.path(RES, "fig_horizon_ap.png"), p1, width = 9.5, height = 5, dpi = 200, bg = "white")

VAR <- c("rotation - base" = "Full chain: latest known leg of the aircraft", "prev1 - base" = "Previous leg only")
g_plot <- gains %>% filter(comparison %in% names(VAR)) %>%
  mutate(x = hx(horizon), model = factor(MODEL[model], levels = MODEL), variant = factor(VAR[comparison], levels = VAR))
p2 <- ggplot(g_plot, aes(x, ap_diff, color = variant, group = variant)) +
  geom_hline(yintercept = 0, color = "#b5b4ae", linewidth = 0.4) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, linewidth = 0.7, position = position_dodge(width = 0.4)) +
  geom_line(linewidth = 0.6, position = position_dodge(width = 0.4)) +
  geom_point(size = 2.4, position = position_dodge(width = 0.4)) +
  facet_wrap(~ model, ncol = 2) +
  scale_color_manual(values = setNames(c("#1f5fb0", "#9cc0ee"), VAR)) +
  labs(x = "Prediction time (before scheduled departure)", y = "AP gain over midway clean predictors (95% CI)",
       title = "Inbound-aircraft information helps most near departure; looking further back helps early on") + theme_viz
ggsave(file.path(RES, "fig_rotation_gain.png"), p2, width = 9.5, height = 4.4, dpi = 200, bg = "white")

state_lab <- c(no_prev = "No previous leg within 36 h", chain_unknown = "Previous legs, none departed yet",
               chain_known = "Earlier leg known, previous not departed", prev_inflight = "Previous leg in the air",
               prev_arrived = "Previous leg landed")
state_col <- c(no_prev = "#c9c8c2", chain_unknown = "#d6e4f7", chain_known = "#9cc0ee", prev_inflight = "#5a95e0", prev_arrived = "#1f5fb0")
p3 <- ggplot(states %>% mutate(x = hx(horizon), state = factor(state_lab[as.character(rot_state)], levels = state_lab[names(state_col)])),
             aes(x, share, fill = state)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.5) +
  scale_fill_manual(values = setNames(state_col, state_lab[names(state_col)])) +
  scale_y_continuous(labels = scales::percent) + guides(fill = guide_legend(nrow = 2)) +
  labs(x = "Prediction time (before scheduled departure)", y = "Share of flights",
       title = "What is known about the inbound aircraft at each prediction time") + theme_viz
ggsave(file.path(RES, "fig_rotation_states.png"), p3, width = 9, height = 4.6, dpi = 200, bg = "white")


# ---- calibration (diagnostic) ----
# calibration-in-the-large = mean prediction - observed rate; slope from logit(y) ~ logit(p) (1 = ideal,
# < 1 = predictions too extreme); Brier after an intercept-only shift (uses validation outcomes: diagnostic only)
lg <- function(p) qlogis(pmin(pmax(p, 1e-6), 1 - 1e-6))
calib <- parse_key(keys) %>% mutate(
  mean_p = colMeans(P), observed = mean(yv), citl = mean_p - observed,
  slope = vapply(keys, function(k) unname(coef(glm(yv ~ lg(P[, k]), family = binomial()))[2]), 0),
  brier = vapply(keys, function(k) mean((P[, k] - yv)^2), 0),
  brier_shifted = vapply(keys, function(k) { o <- lg(P[, k]); a <- coef(glm(yv ~ 1 + offset(o), family = binomial()))[1]; mean((plogis(o + a) - yv)^2) }, 0)) %>%
  arrange(model, set, desc(horizon))
write_csv(calib, file.path(RES, "horizon_calibration.csv"))
bins <- bind_rows(lapply(keys, function(k) { kk <- parse_key(k)
  tibble(p = P[, k], y = yv) %>% mutate(bin = ntile(p, 10)) %>% group_by(bin) %>%
    summarise(mean_predicted = mean(p), observed_rate = mean(y), .groups = "drop") %>% bind_cols(kk) }))
write_csv(bins, file.path(RES, "horizon_calibration_bins.csv"))

b_plot <- metrics %>% filter(set %in% c("base", "rotation")) %>%
  mutate(x = hx(horizon), series = paste0(MODEL[model], ifelse(set == "rotation", " + aircraft rotation", " (midway clean predictors)")))
p4 <- ggplot(b_plot, aes(x, Brier, color = series, linetype = series, group = series)) +
  geom_hline(yintercept = unique(metrics$constant_brier), color = "#8f8e88", linetype = "dotted", linewidth = 0.6) +
  annotate("text", x = hx(720), y = unique(metrics$constant_brier), label = "constant reference (training delay rate)",
           hjust = 0, vjust = -0.6, size = 3, color = INK) +
  geom_errorbar(aes(ymin = Brier_lo, ymax = Brier_hi), width = 0, linewidth = 0.5, alpha = 0.6, linetype = "solid", show.legend = FALSE) +
  geom_line(linewidth = 0.8) + geom_point(size = 2.2) +
  scale_color_manual(values = c("Logistic regression (midway clean predictors)" = SERIES[["lr"]], "Logistic regression + aircraft rotation" = SERIES[["lr"]],
                                "Random forest (midway clean predictors)" = SERIES[["rf"]], "Random forest + aircraft rotation" = SERIES[["rf"]])) +
  scale_linetype_manual(values = c("Logistic regression (midway clean predictors)" = "dashed", "Logistic regression + aircraft rotation" = "solid",
                                   "Random forest (midway clean predictors)" = "dashed", "Random forest + aircraft rotation" = "solid")) +
  guides(color = guide_legend(nrow = 2), linetype = guide_legend(nrow = 2)) +
  labs(x = "Prediction time (before scheduled departure)", y = "Brier score (95% CI; lower is better)",
       title = "Probability accuracy improves the same way as ranking as departure approaches") + theme_viz
ggsave(file.path(RES, "fig_horizon_brier.png"), p4, width = 9.5, height = 5, dpi = 200, bg = "white")

HCOL <- c("12 h" = "#9cc0ee", "2 h" = "#4f8fdc", "30 min" = "#1a4f94")
c_plot <- bins %>% filter(set == "rotation", horizon %in% c(720, 120, 30)) %>%
  mutate(h = factor(horizon_label(horizon), levels = names(HCOL)), model = factor(MODEL[model], levels = MODEL))
p5 <- ggplot(c_plot, aes(mean_predicted, observed_rate, color = h)) +
  geom_abline(slope = 1, intercept = 0, color = "#b5b4ae", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.7) + geom_point(size = 2) +
  facet_wrap(~ model, ncol = 2) + coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  scale_color_manual(values = HCOL, name = "Prediction time") +
  labs(x = "Mean predicted probability (decile of risk)", y = "Observed delay rate",
       title = "Calibration of clean models with rotation features",
       subtitle = sprintf("Validation delay rate %.3f vs training %.3f; points above the line = delays under-predicted.", mean(yv), train_rate),
       caption = "Points above the dashed line: the model under-predicts delays.") +
  theme_viz + theme(legend.title = element_text(color = INK))
ggsave(file.path(RES, "fig_horizon_calibration.png"), p5, width = 9, height = 5.2, dpi = 200, bg = "white")

# ---- readable summary ----
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
t1 <- metrics %>% filter(set != "oracle") %>% mutate(cell = paste0(fmt(AP), " [", fmt(AP_lo), ", ", fmt(AP_hi), "]")) %>%
  mutate(col = paste(MODEL[model], set)) %>% select(horizon, col, cell) %>% pivot_wider(names_from = col, values_from = cell) %>%
  arrange(desc(horizon)) %>% mutate(horizon = horizon_label(horizon))
t2 <- gains %>% mutate(cell = paste0(fmt(ap_diff), " [", fmt(lo), ", ", fmt(hi), "]"), model = MODEL[model], horizon = horizon_label(horizon)) %>%
  select(comparison, model, horizon, cell)
t3 <- metrics %>% filter(set != "oracle") %>% mutate(cell = paste0(fmt(Brier, 4), " [", fmt(Brier_lo, 4), ", ", fmt(Brier_hi, 4), "]")) %>%
  mutate(col = paste(MODEL[model], set)) %>% select(horizon, col, cell) %>% pivot_wider(names_from = col, values_from = cell) %>%
  arrange(desc(horizon)) %>% mutate(horizon = horizon_label(horizon))
t4 <- gains %>% filter(comparison %in% c("rotation - base", "oracle - rotation (2h)")) %>%
  mutate(cell = paste0(fmt(brier_reduction, 4), " [", fmt(brier_lo, 4), ", ", fmt(brier_hi, 4), "]"), model = MODEL[model], horizon = horizon_label(horizon)) %>%
  select(comparison, model, horizon, cell)
t5 <- calib %>% filter(set %in% c("base", "rotation")) %>%
  transmute(model = MODEL[model], set, horizon = horizon_label(horizon), mean_p = fmt(mean_p), citl = fmt(citl), slope = fmt(slope, 2),
            brier = fmt(brier, 4), brier_shifted = fmt(brier_shifted, 4))
md <- function(d) c(paste0("| ", paste(names(d), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
                    apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
writeLines(c(paste0("# Final study (extension): prediction time and aircraft rotation — validation May–Jun 2025 — ", POP_LABEL), "",
  sprintf("n = %s validation flights (delay rate %.3f), identical at every prediction time. Bootstrap: %d reps over validation days.", format(length(yv), big.mark = ","), mean(yv), B), "",
  "**AP [95% CI] by prediction time**", "", md(t1), "", "**Paired differences in AP [95% CI]**", "", md(t2), "",
  sprintf("**Brier [95%% CI] by prediction time** (constant reference = training delay rate: %.4f)", unique(metrics$constant_brier)), "", md(t3), "",
  "**Paired Brier reductions [95% CI]** (positive = first model more accurate)", "", md(t4), "",
  "**Calibration (diagnostic)**: mean prediction, calibration-in-the-large (mean - observed), slope, Brier after intercept shift", "", md(t5)),
  file.path(RES, "horizon_results.md"))
message("done")
