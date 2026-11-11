# Compare the main population (regular aircraft rotations) with the all-flights sensitivity.
# Output: final/results/population_comparison.csv; prints a summary. Run from the project root.
suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
source("final/R/final_helpers.R")
read_pop <- function(pop) {
  m <- read_csv(file.path(pop_dir(pop), "horizon_metrics.csv"), show_col_types = FALSE) %>% mutate(population = pop)
  g <- read_csv(file.path(pop_dir(pop), "horizon_gains.csv"), show_col_types = FALSE) %>% mutate(population = pop)
  list(m = m, g = g)
}
r <- read_pop("regular"); a <- read_pop("all_flights")
m <- bind_rows(r$m, a$m); g <- bind_rows(r$g, a$g)
tab <- m %>% filter(set %in% c("base", "rotation", "oracle")) %>%
  select(population, model, set, horizon, n, delay_rate, AP, Brier) %>%
  left_join(g %>% filter(comparison == "rotation - base") %>% select(population, model, horizon, rot_gain = ap_diff, rot_lo = lo, rot_hi = hi),
            by = c("population", "model", "horizon")) %>%
  arrange(model, set, desc(horizon), population)
write_csv(tab, file.path(FINAL_RES, "population_comparison.csv"))
cat("flights: regular", unique(r$m$n), "| all", unique(a$m$n), " delay rate: regular", round(unique(r$m$delay_rate), 3), "| all", round(unique(a$m$delay_rate), 3), "\n\n")
w <- g %>% filter(comparison %in% c("rotation - base", "rotation - prev1", "oracle - rotation (2h)")) %>%
  mutate(cell = sprintf("%.3f [%.3f, %.3f]", ap_diff, lo, hi)) %>% select(comparison, model, horizon, population, cell) %>%
  pivot_wider(names_from = population, values_from = cell) %>% arrange(comparison, model, desc(horizon))
print(w, n = 40)
cat("\nAP with rotation features:\n")
print(m %>% filter(set == "rotation") %>% select(model, horizon, population, AP) %>% mutate(AP = round(AP, 3)) %>%
        pivot_wider(names_from = population, values_from = AP) %>% arrange(model, desc(horizon)))
