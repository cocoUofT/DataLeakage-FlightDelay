# Midway step 5: validation performance, paired leakage contrasts with date-block bootstrap CIs,
# and diagnostics (daily performance, calibration).
# Input : results/midway/preds/*.rds (04_fit_midway.R), data/processed/closed10/midway_split.rds
# Output: results/midway/  metrics_validation.csv, paired_differences.csv, daily_metrics.csv,
#         calibration_bins.csv, calibration_summary.csv, fig_*.png, midway_results.md
# Run from the project root:  Rscript scripts/05_evaluate_midway.R [B]     (B = bootstrap reps, default 1000)
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr); library(ggplot2); library(parallel) })
source("scripts/midway_helpers.R"); source("proposal/scripts/metrics.R")
args <- commandArgs(trailingOnly = TRUE)
B <- if (length(args)) as.integer(args[1]) else 1000L
CORES <- max(1L, min(4L, detectCores()))
set.seed(2112)

MODEL_LABEL <- c(constant = "Constant reference", lr_full = "Logistic regression (all predictors)",
                 lr_lasso = "Logistic regression (lasso-selected)", rf = "Random forest")
COND_LABEL <- c(C = "Clean (C)", W = "Weather leakage (W)", WO = "Weather + operational (WO)")
SERIES <- c(lr_full = "#2a78d6", lr_lasso = "#eb6834", rf = "#1baf7a")   # categorical slots 1-3
INK <- "#52514e"

y <- readRDS(SPLIT_FILE)$data %>% filter(split == "validation") %>% select(flight_id, FlightDate, ArrDel15)
preds <- bind_rows(lapply(list.files(file.path(MIDWAY_DIR, "preds"), full.names = TRUE), readRDS))
wide <- preds %>% mutate(key = paste(model, condition, sep = "|")) %>% select(flight_id, key, p) %>%
  pivot_wider(names_from = key, values_from = p) %>% inner_join(y, by = "flight_id") %>% arrange(FlightDate)
keys <- setdiff(names(wide), c("flight_id", "FlightDate", "ArrDel15"))
stopifnot(nrow(wide) == nrow(y), !anyNA(wide[keys]))
yv <- wide$ArrDel15; P <- as.matrix(wide[keys])

# ---- 1. point estimates ----
metric_vec <- function(idx) {
  yy <- yv[idx]
  c(setNames(vapply(keys, function(k) average_precision(yy, P[idx, k]), 0), paste0("AP|", keys)),
    setNames(vapply(keys, function(k) mean((P[idx, k] - yy)^2), 0), paste0("Brier|", keys)))
}
point <- metric_vec(seq_along(yv))
metrics <- tibble(name = names(point), value = point) %>%
  separate(name, c("metric", "model", "condition"), sep = "\\|") %>%
  pivot_wider(names_from = metric, values_from = value) %>%
  left_join(preds %>% group_by(model, condition) %>% summarise(mean_p = mean(p), .groups = "drop"),
            by = c("model", "condition")) %>%
  mutate(n = nrow(wide), delay_rate = mean(yv)) %>% arrange(match(model, names(MODEL_LABEL)), condition)
write_csv(metrics, file.path(MIDWAY_DIR, "metrics_validation.csv"))

# ---- 2. paired contrasts with date-block bootstrap ----
contrasts <- expand_grid(model = c("lr_full", "lr_lasso", "rf"),
                         tibble(contrast = c("W - C", "WO - C", "WO - W"), to = c("W", "WO", "WO"), from = c("C", "C", "W")))
contrast_values <- function(m) {
  bind_rows(lapply(seq_len(nrow(contrasts)), function(i) with(contrasts[i, ], tibble(
    model = model, contrast = contrast,
    ap_gain = m[paste0("AP|", model, "|", to)] - m[paste0("AP|", model, "|", from)],
    brier_reduction = m[paste0("Brier|", model, "|", from)] - m[paste0("Brier|", model, "|", to)]))))
}
days <- sort(unique(wide$FlightDate)); day_idx <- split(seq_along(yv), factor(wide$FlightDate, levels = days))
draw <- function(block) {          # block = 1: resample days; block = 7: circular moving 7-day blocks
  if (block == 1) sel <- sample(seq_along(days), length(days), replace = TRUE) else {
    starts <- sample(seq_along(days), ceiling(length(days) / block), replace = TRUE)
    sel <- unlist(lapply(starts, function(s) ((s - 1 + 0:(block - 1)) %% length(days)) + 1))[seq_along(days)]
  }
  unlist(day_idx[sel], use.names = FALSE)
}
boot <- function(block) {
  reps <- mclapply(seq_len(B), function(b) { set.seed(10000 * block + b); contrast_values(metric_vec(draw(block))) },
                   mc.cores = CORES)
  bind_rows(reps, .id = "rep") %>% group_by(model, contrast) %>%
    summarise(ap_lo = quantile(ap_gain, .025), ap_hi = quantile(ap_gain, .975),
              brier_lo = quantile(brier_reduction, .025), brier_hi = quantile(brier_reduction, .975), .groups = "drop") %>%
    mutate(block_days = block)
}
t0 <- Sys.time()
ci <- bind_rows(boot(1), boot(7))
paired <- contrast_values(point) %>% left_join(ci, by = c("model", "contrast")) %>%
  mutate(bootstrap_reps = B) %>% arrange(block_days, match(model, names(MODEL_LABEL)), contrast)
write_csv(paired, file.path(MIDWAY_DIR, "paired_differences.csv"))
message("bootstrap: ", B, " reps x 2 block lengths in ", round(difftime(Sys.time(), t0, units = "secs")), " s")

# ---- 3. diagnostics ----
# daily delay rate and within-day AP of the clean models
daily <- wide %>% group_by(FlightDate) %>% group_modify(function(d, k) {
  tibble(n = nrow(d), delay_rate = mean(d$ArrDel15),
         ap_lr_full = average_precision(d$ArrDel15, d$`lr_full|C`),
         ap_lr_lasso = average_precision(d$ArrDel15, d$`lr_lasso|C`),
         ap_rf = average_precision(d$ArrDel15, d$`rf|C`),
         mean_p_lr_full = mean(d$`lr_full|C`), mean_p_rf = mean(d$`rf|C`))
}) %>% ungroup()
write_csv(daily, file.path(MIDWAY_DIR, "daily_metrics.csv"))

# calibration: deciles of predicted risk (clean models), calibration-in-the-large,
# and the Brier score after an intercept-only shift (diagnostic only: uses validation outcomes)
calib_bins <- bind_rows(lapply(c("lr_full", "lr_lasso", "rf"), function(m) {
  p <- wide[[paste0(m, "|C")]]
  tibble(model = m, p = p, y = yv) %>% mutate(bin = ntile(p, 10)) %>% group_by(model, bin) %>%
    summarise(mean_predicted = mean(p), observed_rate = mean(y), n = n(), .groups = "drop")
}))
write_csv(calib_bins, file.path(MIDWAY_DIR, "calibration_bins.csv"))
shifted_brier <- function(p, y) {
  off <- qlogis(pmin(pmax(p, 1e-6), 1 - 1e-6))
  a <- coef(glm(y ~ 1 + offset(off), family = binomial()))[1]
  mean((plogis(off + a) - y)^2)
}
calib_summary <- metrics %>% filter(model != "constant") %>% rowwise() %>%
  mutate(brier_intercept_shifted = shifted_brier(wide[[paste0(model, "|", condition)]], yv)) %>% ungroup() %>%
  select(model, condition, mean_p, delay_rate, Brier, brier_intercept_shifted)
write_csv(calib_summary, file.path(MIDWAY_DIR, "calibration_summary.csv"))

# ---- 4. figures ----
theme_viz <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#e6e5e1", linewidth = 0.3),
        axis.text = element_text(color = INK), axis.title = element_text(color = INK),
        strip.text = element_text(face = "bold", hjust = 0), legend.position = "top",
        legend.title = element_blank(), plot.title.position = "plot")

fig_gain <- paired %>% filter(block_days == 1, contrast != "WO - W") %>%
  mutate(model = factor(MODEL_LABEL[model], levels = rev(MODEL_LABEL[c("lr_full", "lr_lasso", "rf")])),
         contrast = factor(recode(contrast, "W - C" = "Weather leakage: AP(W) − AP(C)",
                                  "WO - C" = "Weather + operational: AP(WO) − AP(C)"),
                           levels = c("Weather leakage: AP(W) − AP(C)", "Weather + operational: AP(WO) − AP(C)")))
# Both panels share the same scale (identical AP span per panel width), so interval widths are
# directly comparable; only the starting point differs. The W panel includes 0.
SPAN <- 0.08
w_lab <- levels(fig_gain$contrast)[1]; wo_lab <- levels(fig_gain$contrast)[2]
wo_hi <- max(fig_gain$ap_hi[fig_gain$contrast == wo_lab])
wo_lo <- ceiling((wo_hi + 0.004 - SPAN) * 100) / 100              # start on a 0.01 gridline
stopifnot(max(fig_gain$ap_hi[fig_gain$contrast == w_lab]) < SPAN,
          min(fig_gain$ap_lo[fig_gain$contrast == wo_lab]) > wo_lo, wo_lo + SPAN > wo_hi)
panel_limits <- data.frame(contrast = factor(c(w_lab, w_lab, wo_lab, wo_lab), levels = levels(fig_gain$contrast)),
                           ap_gain = c(0, SPAN, wo_lo, wo_lo + SPAN))
p1 <- ggplot(fig_gain, aes(x = ap_gain, y = model, color = model)) +
  geom_blank(data = panel_limits, aes(x = ap_gain), inherit.aes = FALSE) +
  geom_vline(data = data.frame(contrast = factor(w_lab, levels = levels(fig_gain$contrast)), x = 0),
             aes(xintercept = x), color = "#b5b4ae", linewidth = 0.4) +
  geom_errorbar(aes(xmin = ap_lo, xmax = ap_hi), orientation = "y", width = 0, linewidth = 0.8) +
  geom_point(size = 2.6) +
  facet_wrap(~ contrast, scales = "free_x", ncol = 2) +
  scale_x_continuous(breaks = seq(-1, 1, by = 0.02), expand = c(0, 0)) +
  scale_color_manual(values = setNames(SERIES[c("lr_full", "lr_lasso", "rf")], MODEL_LABEL[c("lr_full", "lr_lasso", "rf")]),
                     guide = "none") +
  labs(x = "Apparent gain in average precision (95% CI, bootstrap over validation days)", y = NULL,
       title = "Leakage inflates measured performance; operational leakage dominates",
       subtitle = sprintf(paste0("Validation flights May–Jun 2025 (n = %s); same flights in every condition.\n",
                                 "Both panels use the same scale (%.2f AP across each panel); the right panel starts at %.2f, not 0."),
                          format(nrow(wide), big.mark = ","), SPAN, wo_lo)) +
  theme_viz + theme(panel.spacing.x = unit(1.6, "lines"), plot.margin = margin(5.5, 14, 5.5, 5.5))
ggsave(file.path(MIDWAY_DIR, "fig_leakage_gain.png"), p1, width = 9, height = 3.5, dpi = 200, bg = "white")

daily_long <- daily %>% select(FlightDate, delay_rate, ap_lr_full, ap_lr_lasso, ap_rf) %>%
  pivot_longer(-FlightDate) %>%
  mutate(series = recode(name, delay_rate = "Day's delay rate (AP of a random ranking)",
                         ap_lr_full = MODEL_LABEL[["lr_full"]], ap_lr_lasso = MODEL_LABEL[["lr_lasso"]],
                         ap_rf = MODEL_LABEL[["rf"]]))
p2 <- ggplot(daily_long, aes(FlightDate, value, color = series, linetype = series)) +
  geom_line(linewidth = 0.7) +
  scale_color_manual(values = c("Day's delay rate (AP of a random ranking)" = "#8f8e88", setNames(SERIES, MODEL_LABEL[names(SERIES)]))) +
  scale_linetype_manual(values = c("Day's delay rate (AP of a random ranking)" = "dashed", setNames(rep("solid", 3), MODEL_LABEL[names(SERIES)]))) +
  scale_x_date(date_breaks = "1 week", date_labels = "%b %d") +
  scale_y_continuous(limits = c(0, NA)) +
  guides(color = guide_legend(nrow = 2), linetype = guide_legend(nrow = 2)) +
  labs(x = NULL, y = "Within-day average precision",
       title = "Clean models rank delayed flights above the random baseline on every validation day",
       subtitle = sprintf("Smallest daily margin over the day's delay rate: %.3f. Daily AP rises and falls with the day's delay rate.",
                          min(c(daily$ap_lr_full, daily$ap_lr_lasso, daily$ap_rf) - rep(daily$delay_rate, 3)))) +
  theme_viz
ggsave(file.path(MIDWAY_DIR, "fig_daily.png"), p2, width = 9, height = 4.2, dpi = 200, bg = "white")

p3 <- ggplot(calib_bins %>% mutate(model = MODEL_LABEL[model]), aes(mean_predicted, observed_rate, color = model)) +
  geom_abline(slope = 1, intercept = 0, color = "#b5b4ae", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.7) + geom_point(size = 2.2) +
  scale_color_manual(values = setNames(SERIES, MODEL_LABEL[names(SERIES)])) +
  coord_equal(xlim = c(0, 0.65), ylim = c(0, 0.65)) +
  guides(color = guide_legend(ncol = 1)) +
  labs(x = "Mean predicted probability (decile of risk)", y = "Observed delay rate",
       title = "Clean-model calibration on validation flights",
       caption = "Points above the dashed line: the model under-predicts delays.",
       subtitle = sprintf("Training delay rate %.3f vs validation %.3f", mean(readRDS(SPLIT_FILE)$data$ArrDel15[readRDS(SPLIT_FILE)$data$split == "train"]), mean(yv))) +
  theme_viz + theme(legend.position = c(0.02, 0.98), legend.justification = c(0, 1))
ggsave(file.path(MIDWAY_DIR, "fig_calibration.png"), p3, width = 5.5, height = 5.5, dpi = 200, bg = "white")

# ---- 5. readable summary ----
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
tab1 <- metrics %>% mutate(cell = paste0(fmt(AP), " / ", fmt(Brier))) %>% select(model, condition, cell) %>%
  pivot_wider(names_from = condition, values_from = cell) %>% mutate(model = MODEL_LABEL[model])
tab2 <- paired %>% filter(block_days == 1) %>%
  left_join(paired %>% filter(block_days == 7) %>% select(model, contrast, ap_lo7 = ap_lo, ap_hi7 = ap_hi), by = c("model", "contrast")) %>%
  transmute(Model = MODEL_LABEL[model], Contrast = contrast,
            `AP gain [95% CI, 1-day blocks]` = paste0(fmt(ap_gain), " [", fmt(ap_lo), ", ", fmt(ap_hi), "]"),
            `[7-day blocks]` = paste0("[", fmt(ap_lo7), ", ", fmt(ap_hi7), "]"),
            `Brier reduction [95% CI]` = paste0(fmt(brier_reduction, 4), " [", fmt(brier_lo, 4), ", ", fmt(brier_hi, 4), "]"))
md_table <- function(d) c(paste0("| ", paste(names(d), collapse = " | "), " |"),
                          paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
                          apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
writeLines(c(
  "# Midway results: validation (May–Jun 2025)", "",
  sprintf("Flights: %s validation (delay rate %.3f); trained on Jan–Apr 2025. Same flights in every condition.",
          format(nrow(wide), big.mark = ","), mean(yv)), "",
  "**Table 1. AP / Brier by model and information condition** (AP higher is better; Brier lower is better).", "",
  md_table(tab1 %>% rename(Model = model)), "",
  sprintf("**Table 2. Paired apparent gains** (%d bootstrap reps resampling validation days; 7-day moving blocks as a dependence check).", B), "",
  md_table(tab2), "",
  "Interpretation: gains are apparent improvements from information unavailable two hours before departure,",
  "specific to these fitted models and this evaluation period; they are not better real-world prediction."
), file.path(MIDWAY_DIR, "midway_results.md"))
message("done")
