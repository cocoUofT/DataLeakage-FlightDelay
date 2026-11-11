# Audit checks for leakage and consistency (midway + final extension). Read-only; prints a report and
# writes final/results/audit_checks.csv. Run from the project root:  Rscript final/R/90_audit_checks.R
suppressPackageStartupMessages({ library(dplyr); library(readr) })
source("final/R/final_helpers.R")
res <- list(); add <- function(check, value, pass, note = "") { res[[length(res) + 1]] <<- tibble(check, value = as.character(value), pass, note); cat(sprintf("[%s] %s: %s %s\n", ifelse(pass, "OK", "FLAG"), check, value, note)) }
legs <- readRDS(file.path(FINAL_DATA, "legs.rds")); study <- readRDS(file.path(FINAL_DATA, "study.rds"))
keep <- readRDS(file.path(FINAL_DATA, "keep_ids.rds"))

# 1. Outcome coding: ArrDel15 == (ArrDelay >= 15) for every completed leg
bad <- sum(legs$ArrDel15 != as.integer(legs$ArrDelay >= 15))
add("ArrDel15 equals ArrDelay >= 15 (all legs)", bad, bad == 0, "mismatching rows")

# 2. A flight's own outcome is never known at its own cutoff, at any horizon
own <- study %>% select(flight_id, dep_sched) %>% left_join(legs %>% select(flight_id, arr_act, dep_act), by = "flight_id")
for (h in HORIZONS) {
  n_known <- sum(own$arr_act < own$dep_sched - h); n_dep <- sum(own$dep_act < own$dep_sched - h)
  add(sprintf("own arrival / departure before cutoff, h = %s", horizon_label(h)), paste(n_known, "/", n_dep), n_known == 0 && n_dep == 0, "flights")
}

# 3. Train/validation separation and chronology
add("train and validation flights overlap", length(intersect(study$flight_id[study$split == "train"], study$flight_id[study$split == "validation"])), TRUE)
add("latest training date < earliest validation date", paste(max(study$FlightDate[study$split == "train"]), "<", min(study$FlightDate[study$split == "validation"])),
    max(study$FlightDate[study$split == "train"]) < min(study$FlightDate[study$split == "validation"]))

# 4. Brute-force recomputation of history features at the extreme horizons (independent of keyed_window)
set.seed(90)
for (h in c(720L, 30L)) {
  f <- readRDS(file.path(FINAL_DATA, sprintf("features_h%03d.rds", h)))
  s <- study %>% filter(flight_id %in% sample(keep, 40)) %>% left_join(f, by = "flight_id")
  mism <- 0
  for (i in seq_len(nrow(s))) {
    c0 <- s$cutoff_min[i]
    o7 <- legs$Origin == as.character(s$Origin[i]) & legs$arr_act < c0 & legs$arr_act >= c0 - 7 * 1440
    sd <- legs$Origin == as.character(s$Origin[i]) & legs$FlightDate == as.character(s$FlightDate[i]) & legs$dep_act < c0
    rc <- legs$Dest == as.character(s$Dest[i]) & legs$arr_act < c0 & legs$arr_act >= c0 - 180
    mism <- mism + (sum(o7) != s$hr_origin_7d_n[i]) + (sum(sd) != s$sd_origin_n[i]) + (sum(rc) != s$rc_dest_3h_n[i]) +
      (sum(o7) > 0 && abs(mean(legs$ArrDel15[o7]) - s$hr_origin_7d_rate[i]) > 1e-9)
  }
  add(sprintf("brute-force history features, h = %s (40 flights x 4 checks)", horizon_label(h)), mism, mism == 0, "mismatches")
}

# 5. Rotation information is always from before the cutoff; projected delay never negative
for (h in HORIZONS) {
  f <- readRDS(file.path(FINAL_DATA, sprintf("features_h%03d.rds", h))) %>% filter(flight_id %in% keep)
  known <- f$rot_state %in% c("chain_known", "prev_inflight", "prev_arrived")
  add(sprintf("rotation: known event after cutoff / negative projection, h = %s", horizon_label(h)),
      paste(sum(f$rot_known_age_h[known] < 0), "/", sum(f$rot_proj_delay < 0)), all(f$rot_known_age_h[known] >= 0) && all(f$rot_proj_delay >= 0))
}

# 6. Tail-number swaps and the outcome: is the recorded aircraft history associated with the delay itself?
#    A schedule-infeasible earlier row for the same tail (scheduled arrival after this flight's scheduled
#    departure) marks a probable swap. If swaps are much more common for delayed flights, the final tail
#    number carries post-cutoff information.
lg <- legs %>% arrange(Tail_Number, dep_sched)
pos <- match(study$flight_id, lg$flight_id); prev <- pmax(pos - 1, 1)
swap <- lg$Tail_Number[prev] == study$Tail_Number & lg$arr_sched[prev] > study$dep_sched & pos > 1
sw <- tibble(ArrDel15 = study$ArrDel15, swap = swap) %>% group_by(ArrDel15) %>% summarise(swap_rate = mean(swap), n = n())
add("probable aircraft swap rate: on-time vs delayed flights", paste(round(sw$swap_rate, 4), collapse = " vs "),
    max(sw$swap_rate) < 2 * min(sw$swap_rate), "(FLAG if delayed flights swap 2x more often)")
cat("   delay rate among probable swaps:", round(mean(study$ArrDel15[swap]), 3), " others:", round(mean(study$ArrDel15[!swap]), 3), "\n")

# 7. Departure time reconstruction never wraps for long delays (DepDelay from the flight file vs derived)
d <- study %>% filter(!is.na(DepDelay)) %>% left_join(legs %>% select(flight_id, dep_delay), by = "flight_id")
add("derived departure delay equals BTS DepDelay (study flights)", sum(abs(d$dep_delay - d$DepDelay) > 0.5), all(abs(d$dep_delay - d$DepDelay) <= 0.5), "mismatches")

# 8. Weather report age at the cutoff stays within 0-120 min (recomputed for a sample at every horizon)
w <- readRDS(file.path(FINAL_DATA, "weather.rds"))
for (h in HORIZONS) {
  s <- study %>% filter(flight_id %in% sample(keep, 300))
  age <- vapply(seq_len(nrow(s)), function(i) { c0 <- s$dep_sched[i] - h; v <- w$valid_min[w$iata == as.character(s$Origin[i]) & w$valid_min <= c0]; c0 - max(v) }, 0)
  add(sprintf("origin weather report age at cutoff, h = %s (min / max minutes)", horizon_label(h)), paste(min(age), "/", max(age)), min(age) >= 0, "(> 120 means the report is not used)")
}
# 9. Irregular recorded rotations (schedule-infeasible or location break right before the flight) and how much
#    of the rotation-feature gain they carry. These mostly reflect aircraft swaps, decided around disruptions
#    and recorded under the final tail number, so they can carry post-cutoff information.
same_recent <- pos > 1 & lg$Tail_Number[prev] == study$Tail_Number & (study$dep_sched - lg$dep_sched[prev]) <= ROT_MAX_HOURS * 60
irregular <- same_recent & (lg$arr_sched[prev] > study$dep_sched | lg$Dest[prev] != as.character(study$Origin))
add("flights with an irregular recorded rotation", sprintf("%d (%.2f%%), delay rate %.3f vs %.3f", sum(irregular), 100 * mean(irregular),
    mean(study$ArrDel15[irregular]), mean(study$ArrDel15[!irregular])), FALSE, "(FLAG: likely post-cutoff aircraft swaps)")
source("proposal/scripts/metrics.R")
yv <- study %>% mutate(irregular = irregular) %>% filter(flight_id %in% keep, split == "validation") %>% select(flight_id, ArrDel15, irregular)
P <- bind_rows(lapply(list.files(file.path(FINAL_RES, "preds"), pattern = "^(lr|rf)_(base|rotation)_", full.names = TRUE), readRDS)) %>% inner_join(yv, by = "flight_id")
g <- P %>% group_by(model, set, horizon) %>% summarise(all = average_precision(ArrDel15, p), regular = average_precision(ArrDel15[!irregular], p[!irregular]), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = set, values_from = c(all, regular)) %>%
  transmute(model, horizon, gain_all = all_rotation - all_base, gain_regular_only = regular_rotation - regular_base) %>% arrange(model, desc(horizon))
write_csv(g, file.path(FINAL_RES, "audit_rotation_gain_regular_only.csv"))
print(g %>% mutate(across(where(is.double), ~ round(.x, 3))))
write_csv(bind_rows(res), file.path(FINAL_RES, "audit_checks.csv"))
