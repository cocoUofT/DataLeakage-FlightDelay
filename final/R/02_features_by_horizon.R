# Final study, step 2: every time-dependent clean predictor at prediction time h minutes before
# scheduled departure (cutoff c = scheduled departure - h). Only information realized before c is used.
#   weather  : latest METAR at origin / destination with valid <= c and age <= 120 min (reporting lag 0)
#   history  : origin / destination / carrier / route delay rates over 182, 28, 7 days (flights ARRIVED before c),
#              same-day origin departures before c, destination arrivals in the last 3 h, network 24 h / 7 d
#   rotation : the same aircraft's previous legs (Tail_Number), at most 8 legs / 36 h back, connected
#              (each leg ends where the next begins; schedule-infeasible legs, usually aircraft swaps, are
#              skipped). At c we take the latest known state:
#                prev_arrived   previous leg has landed               -> its arrival delay
#                prev_inflight  previous leg has departed, not landed -> its departure delay
#                chain_known    previous leg not yet departed, but an earlier leg of the chain is known
#                chain_unknown  previous legs exist but none has departed yet
#                no_prev        no connected previous leg within 36 h (first flight of the rotation)
#              rot_proj_delay propagates the latest known delay forward through the scheduled legs that
#              remain, each turn needing at least ROT_MTT minutes; it is 0 when nothing is known.
# Output: final/data/features_h<h>.rds
# Run from the project root:  Rscript final/R/02_features_by_horizon.R <h> [check]
#   check (h = 120 only): compares weather and history features with the midway files
suppressPackageStartupMessages({ library(dplyr); library(readr) })
source("final/R/final_helpers.R")
args <- commandArgs(trailingOnly = TRUE)
h <- as.integer(args[1]); stopifnot(!is.na(h))
legs <- readRDS(file.path(FINAL_DATA, "legs.rds"))
weather <- readRDS(file.path(FINAL_DATA, "weather.rds"))
study <- readRDS(file.path(FINAL_DATA, "study.rds"))
airports10 <- read_csv("config/airports.csv", show_col_types = FALSE)$iata
cmin <- study$dep_sched - h
out <- tibble(flight_id = study$flight_id, cutoff_min = cmin)

# ---- weather at the cutoff ----
SCALE <- 1e8
weather <- weather[order(match(weather$iata, airports10), weather$valid_min), ]
wk <- match(weather$iata, airports10)
wcomp <- wk * SCALE + weather$valid_min
stopifnot(!is.unsorted(wcomp), !anyNA(wk))
match_weather <- function(airport, prefix) {
  qk <- match(as.character(airport), airports10)
  idx <- findInterval(qk * SCALE + cmin, wcomp)              # last report with valid <= c
  ok <- idx > 0
  ok[ok] <- wk[idx[ok]] == qk[ok] & (cmin[ok] - weather$valid_min[idx[ok]]) <= 120
  vals <- weather[ifelse(ok, idx, NA), WEATHER_VARS]
  names(vals) <- paste0(prefix, WEATHER_VARS); vals
}
out <- bind_cols(out, match_weather(study$Origin, "o_"), match_weather(study$Dest, "d_"))

# ---- historical, same-day, recent and network rates ----
rate <- function(r) ifelse(r$n > 0, r$k / r$n, NA_real_)
wins <- c(`182d` = 182 * 1440, `28d` = 28 * 1440, `7d` = 7 * 1440)
groups <- list(origin = list(legs$Origin, study$Origin), dest = list(legs$Dest, study$Dest),
               carrier = list(legs$Reporting_Airline, study$Reporting_Airline),
               route = list(paste(legs$Origin, legs$Dest), paste(study$Origin, study$Dest)))
for (g in names(groups)) for (w in names(wins)) {
  r <- keyed_window(as.character(groups[[g]][[1]]), legs$arr_act, legs$ArrDel15,
                    as.character(groups[[g]][[2]]), cmin - wins[[w]], cmin)
  out[[paste0("hr_", g, "_", w, "_n")]] <- r$n; out[[paste0("hr_", g, "_", w, "_rate")]] <- rate(r)
}
r <- keyed_window(paste(legs$Origin, legs$FlightDate), legs$dep_act, legs$DepDel15,
                  paste(study$Origin, study$FlightDate), rep(0, length(cmin)), cmin)
out$sd_origin_n <- r$n; out$sd_origin_dep15_rate <- rate(r)
r <- keyed_window(legs$Dest, legs$arr_act, legs$ArrDel15, as.character(study$Dest), cmin - 180, cmin)
out$rc_dest_3h_n <- r$n; out$rc_dest_3h_rate <- rate(r)
net <- legs$Origin %in% airports10
for (w in c(`24h` = 1440, `7d` = 7 * 1440) |> names()) {
  width <- c(`24h` = 1440, `7d` = 7 * 1440)[[w]]
  r <- keyed_window(rep("all", sum(net)), legs$arr_act[net], legs$ArrDel15[net], rep("all", length(cmin)), cmin - width, cmin)
  out[[paste0("net_", w, "_n")]] <- r$n; out[[paste0("net_", w, "_rate")]] <- rate(r)
}

# ---- aircraft rotation chain ----
lg <- legs %>% filter(!is.na(Tail_Number)) %>% arrange(Tail_Number, dep_sched)
pos <- match(study$flight_id, lg$flight_id); stopifnot(!anyNA(pos))
K <- ROT_MAX_LEGS; n <- length(pos); SCAN <- K + 6L
# Walk back through the aircraft's earlier rows. A leg is accepted into the chain if it is the same tail,
# within 36 h, ends where the next accepted leg (or this flight) begins, and is schedule-feasible
# (scheduled arrival no later than the next leg's scheduled departure). Infeasible legs - typically an
# aircraft swap recorded under the final tail number - are skipped; a location break ends the chain.
alive <- rep(TRUE, n); cnt <- integer(n)
nxt_origin <- as.character(study$Origin); nxt_dep <- study$dep_sched
L <- list(dep_sched = matrix(NA_real_, n, K), arr_sched = matrix(NA_real_, n, K), dep_act = matrix(NA_real_, n, K),
          arr_act = matrix(NA_real_, n, K))
skipped <- 0L
for (t in seq_len(SCAN)) {
  p <- pos - t; inb <- p >= 1; p[!inb] <- 1
  cand <- alive & cnt < K & inb & lg$Tail_Number[p] == study$Tail_Number &
          (study$dep_sched - lg$dep_sched[p]) <= ROT_MAX_HOURS * 60
  alive <- alive & (cand | cnt >= K)                       # different tail / too old: stop scanning
  feasible <- cand & lg$arr_sched[p] <= nxt_dep
  skipped <- skipped + sum(cand & !feasible)
  accept <- feasible & lg$Dest[p] == nxt_origin
  alive <- alive & !(feasible & !accept)                   # location break: chain ends
  idx <- which(accept); slot <- cnt[idx] + 1L
  for (v in names(L)) L[[v]][cbind(idx, slot)] <- lg[[v]][p[idx]]
  cnt[idx] <- slot
  nxt_origin[idx] <- lg$Origin[p[idx]]; nxt_dep[idx] <- lg$dep_sched[p[idx]]
}
chain_len <- cnt
arrived_j  <- !is.na(L$arr_act) & L$arr_act < cmin
departed_j <- !is.na(L$dep_act) & L$dep_act < cmin
message("schedule-infeasible legs skipped: ", skipped)
first_true <- function(m) { r <- max.col(m, ties.method = "first"); r[rowSums(m) == 0] <- NA_integer_; r }
j_arr <- first_true(arrived_j)                               # closest landed leg
# in-flight leg: the leg right after the closest landed one (or the deepest leg if none landed), if departed
f <- ifelse(is.na(j_arr), chain_len, j_arr - 1L)
row_idx <- seq_len(n)
inflight <- f >= 1 & departed_j[cbind(row_idx, pmax(f, 1L))] & !arrived_j[cbind(row_idx, pmax(f, 1L))]
inflight[is.na(inflight)] <- FALSE
start <- ifelse(inflight, f, j_arr)                          # leg whose state is the latest known
known <- !is.na(start) & start >= 1
gi <- function(m, j) m[cbind(row_idx, pmax(ifelse(is.na(j), 1L, j), 1L))]
known_delay <- ifelse(inflight, gi(L$dep_act, start) - gi(L$dep_sched, start),
                      ifelse(known, gi(L$arr_act, start) - gi(L$arr_sched, start), NA))
known_time  <- ifelse(inflight, gi(L$dep_act, start), ifelse(known, gi(L$arr_act, start), NA))
# projected ready time after the latest known leg, then propagate through the remaining scheduled legs
ready <- ifelse(inflight, gi(L$arr_sched, start) + known_delay, ifelse(known, gi(L$arr_act, start), NA))
for (m in K:1) {
  upd <- known & m < start
  ready[upd] <- pmax(L$dep_sched[upd, m], ready[upd] + ROT_MTT) + (L$arr_sched[upd, m] - L$dep_sched[upd, m])
}
proj_dep <- pmax(study$dep_sched, ready + ROT_MTT)
out$rot_state <- factor(case_when(chain_len == 0 ~ "no_prev",
                                  inflight & start == 1 ~ "prev_inflight",
                                  known & start == 1 ~ "prev_arrived",
                                  known ~ "chain_known",
                                  TRUE ~ "chain_unknown"),
                        levels = c("no_prev", "chain_unknown", "chain_known", "prev_inflight", "prev_arrived"))
out$rot_known_delay <- ifelse(known, known_delay, 0)
out$rot_legs_to_go  <- ifelse(known, start - ifelse(inflight, 0L, 1L), chain_len)   # legs not yet landed before this flight
out$rot_proj_delay  <- ifelse(known, proj_dep - study$dep_sched, 0)
out$rot_turn_sched  <- ifelse(chain_len > 0, study$dep_sched - L$arr_sched[, 1], NA)
out$rot_known_age_h <- ifelse(known, (cmin - known_time) / 60, 0)
out$rot_chain_len   <- chain_len
# NOT a predictor: the previous leg's FINAL arrival delay, known only after it lands. Used solely for the
# "oracle" reference model that shows the value of perfect information about the inbound aircraft.
out$oracle_prev_arr_delay <- ifelse(chain_len > 0, L$arr_act[, 1] - L$arr_sched[, 1], NA)
saveRDS(out, file.path(FINAL_DATA, sprintf("features_h%03d.rds", h)))
cat(sprintf("h = %s: %d flights\n", horizon_label(h), nrow(out)))
print(round(prop.table(table(out$rot_state)), 3))

# ---- check against midway features (h = 120 only) ----
if ("check" %in% args) {
  stopifnot(h == 120)
  hist_py <- read_csv(file.path(CLOSED10, "features_history_dev.csv.gz"), show_col_types = FALSE)
  net_r   <- read_csv(file.path(CLOSED10, "features_network_dev.csv.gz"), show_col_types = FALSE)
  ref <- out %>% select(flight_id) %>% left_join(hist_py, by = "flight_id") %>% left_join(net_r, by = "flight_id")
  bad <- 0
  for (v in grep("_(n|rate)$", names(out), value = TRUE)) {
    if (!v %in% names(ref)) next
    a <- out[[v]]; b <- ref[[v]]
    d <- if (grepl("_n$", v)) sum(a != b, na.rm = TRUE) + sum(is.na(a) != is.na(b)) else
         sum(abs(a - b) > 1e-5, na.rm = TRUE) + sum(is.na(a) != is.na(b))
    if (d > 0) { bad <- bad + 1; message("MISMATCH ", v, ": ", d) }
  }
  mt <- read_csv(file.path(CLOSED10, "model_table_dev.csv.gz"), show_col_types = FALSE) %>%
    filter(eligible == 1) %>% select(flight_id, sknt_C, vsby_C, precip_intensity_C, snow_fzra_flag_C, sknt_Dest_C, p01i_Dest_C)
  cmp <- out %>% select(flight_id, o_sknt, o_vsby, o_precip_intensity, o_snow_fzra_flag, d_sknt, d_p01i_log) %>% left_join(mt, by = "flight_id")
  same <- function(a, b) sum(!((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) < 1e-9)))
  wbad <- c(same(cmp$o_sknt, cmp$sknt_C), same(cmp$o_vsby, cmp$vsby_C), same(cmp$o_precip_intensity, cmp$precip_intensity_C),
            same(cmp$o_snow_fzra_flag, cmp$snow_fzra_flag_C), same(cmp$d_sknt, cmp$sknt_Dest_C), same(cmp$d_p01i_log, log1p(100 * cmp$p01i_Dest_C)))
  cat("history/network columns with mismatches:", bad, " | weather mismatches:", paste(wbad, collapse = " "), "\n")
}
