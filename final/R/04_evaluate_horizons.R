# Final study, step 4: validation performance by prediction time, value of rotation features, figures.
# Input : final/results/preds/*.rds (03), final/data/{study,keep_ids,features_h*}.rds
# Output: final/results/ horizon_metrics.csv, horizon_gains.csv, rotation_states.csv, rotation_importance.csv,
#         fig_horizon_ap.png, fig_rotation_gain.png, fig_rotation_states.png, horizon_results.md
# Run from the project root:  Rscript final/R/04_evaluate_horizons.R [B]
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr); library(ggplot2); library(parallel) })
source("final/R/final_helpers.R"); source("proposal/scripts/metrics.R")
args <- commandArgs(trailingOnly = TRUE); B <- if (length(args)) as.integer(args[1]) else 1000L
CORES <- max(1L, min(4L, detectCores()))

study <- readRDS(file.path(FINAL_DATA, "study.rds")); keep <- readRDS(file.path(FINAL_DATA, "keep_ids.rds"))
y <- study %>% filter(flight_id %in% keep, split == "validation") %>% select(flight_id, FlightDate, ArrDel15)
preds <- bind_rows(lapply(list.files(file.path(FINAL_RES, "preds"), pattern = "^(lr|rf)_", full.names = TRUE), readRDS))
wide <- preds %>% mutate(key = paste(model, set, horizon, sep = "|")) %>% select(flight_id, key, p) %>%
  pivot_wider(names_from = key, values_from = p) %>% inner_join(y, by = "flight_id") %>% arrange(FlightDate)
keys <- setdiff(names(wide), c("flight_id", "FlightDate", "ArrDel15"))
stopifnot(nrow(wide) == nrow(y), !anyNA(wide[keys]))
yv <- wide$ArrDel15; P <- as.matrix(wide[keys])
ap_all <- function(idx) vapply(keys, function(k) average_precision(yv[idx], P[idx, k]), 0)

# ---- point estimates + bootstrap over validation days ----
days <- split(seq_along(yv), wide$FlightDate)
point <- ap_all(seq_along(yv))
set.seed(2112)
reps <- do.call(rbind, mclapply(seq_len(B), function(b) { set.seed(b); ap_all(unlist(days[sample(length(days), replace = TRUE)], use.names = FALSE)) }, mc.cores = CORES))
parse_key <- function(k) { s <- strsplit(k, "|", fixed = TRUE); tibble(model = sapply(s, `[`, 1), set = sapply(s, `[`, 2), horizon = as.integer(sapply(s, `[`, 3))) }
metrics <- parse_key(keys) %>% mutate(
  AP = point, AP_lo = apply(reps, 2, quantile, .025), AP_hi = apply(reps, 2, quantile, .975),
  Brier = vapply(keys, function(k) mean((P[, k] - yv)^2), 0), mean_p = colMeans(P), n = length(yv), delay_rate = mean(yv)) %>%
  arrange(model, set, desc(horizon))
write_csv(metrics, file.path(FINAL_RES, "horizon_metrics.csv"))

diff_ci <- function(a, b) { d <- reps[, a] - reps[, b]; c(est = point[[a]] - point[[b]], lo = quantile(d, .025, names = FALSE), hi = quantile(d, .975, names = FALSE)) }
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
) %>% mutate(ap_diff = sapply(v, `[`, "est"), lo = sapply(v, `[`, "lo"), hi = sapply(v, `[`, "hi")) %>% select(-v)
write_csv(gains, file.path(FINAL_RES, "horizon_gains.csv"))

# ---- rotation state shares and importance ----
states <- bind_rows(lapply(HORIZONS, function(h) readRDS(file.path(FINAL_DATA, sprintf("features_h%03d.rds", h))) %>%
  filter(flight_id %in% keep) %>% count(rot_state) %>% mutate(horizon = h, share = n / sum(n))))
write_csv(states, file.path(FINAL_RES, "rotation_states.csv"))
imp <- bind_rows(lapply(list.files(file.path(FINAL_RES, "preds"), pattern = "^importance", full.names = TRUE), readRDS)) %>%
  filter(set == "rotation") %>% group_by(horizon) %>% mutate(rank = rank(-importance), share = importance / sum(importance)) %>% ungroup()
write_csv(imp, file.path(FINAL_RES, "rotation_importance.csv"))

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
       subtitle = sprintf("Validation flights May–Jun 2025 (n = %s, delay rate %.3f); same flights at every prediction time.\nEach model uses only information known at its prediction time.",
                          format(length(yv), big.mark = ","), mean(yv))) +
  theme_viz
ggsave(file.path(FINAL_RES, "fig_horizon_ap.png"), p1, width = 9.5, height = 5, dpi = 200, bg = "white")

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
ggsave(file.path(FINAL_RES, "fig_rotation_gain.png"), p2, width = 9.5, height = 4.4, dpi = 200, bg = "white")

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
ggsave(file.path(FINAL_RES, "fig_rotation_states.png"), p3, width = 9, height = 4.6, dpi = 200, bg = "white")

# ---- readable summary ----
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
t1 <- metrics %>% filter(set != "oracle") %>% mutate(cell = paste0(fmt(AP), " [", fmt(AP_lo), ", ", fmt(AP_hi), "]")) %>%
  mutate(col = paste(MODEL[model], set)) %>% select(horizon, col, cell) %>% pivot_wider(names_from = col, values_from = cell) %>%
  arrange(desc(horizon)) %>% mutate(horizon = horizon_label(horizon))
t2 <- gains %>% mutate(cell = paste0(fmt(ap_diff), " [", fmt(lo), ", ", fmt(hi), "]"), model = MODEL[model], horizon = horizon_label(horizon)) %>%
  select(comparison, model, horizon, cell)
md <- function(d) c(paste0("| ", paste(names(d), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
                    apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
writeLines(c("# Final study (extension): prediction time and aircraft rotation — validation May–Jun 2025", "",
  sprintf("n = %s validation flights (delay rate %.3f), identical at every prediction time. Bootstrap: %d reps over validation days.", format(length(yv), big.mark = ","), mean(yv), B), "",
  "**AP [95% CI] by prediction time**", "", md(t1), "", "**Paired differences in AP [95% CI]**", "", md(t2)),
  file.path(FINAL_RES, "horizon_results.md"))
message("done")
