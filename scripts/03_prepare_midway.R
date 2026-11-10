# Midway step 3: eligible flights, chronological split, shared complete cases.
# Input : data/processed/closed10/model_table_dev.csv.gz (scripts/STA2112_Midway.Rmd),
#         features_network_dev.csv.gz (scripts/02b_network_features.R)
# Output: data/processed/closed10/midway_split.rds, results/midway/prep_summary.csv
# Run from the project root:  Rscript scripts/03_prepare_midway.R
suppressPackageStartupMessages({ library(dplyr); library(readr) })
source("scripts/midway_helpers.R")
dir.create(MIDWAY_DIR, recursive = TRUE, showWarnings = FALSE)

raw <- read_csv("data/processed/closed10/model_table_dev.csv.gz", show_col_types = FALSE,
                col_types = cols(CRSDepTime = col_character(), CRSArrTime = col_character()))

suffixes <- unique(unlist(WEATHER_SUFFIX))
network <- read_csv("data/processed/closed10/features_network_dev.csv.gz", show_col_types = FALSE) %>%
  select(flight_id, net_24h_rate, net_7d_rate)
df <- raw %>%
  left_join(network, by = "flight_id") %>%
  filter(eligible == 1) %>%
  mutate(
    split = ifelse(Month <= 4, "train", "validation"),   # train Jan-Apr, validation May-Jun
    ArrDel15 = as.integer(ArrDel15),
    across(c(Reporting_Airline, Origin, Dest), as.factor),
    DayOfWeek = factor(DayOfWeek, levels = 1:7),
    # history features: "no earlier flight yet today / in the last 3 h" gets its own indicator
    sd_origin_none = as.integer(sd_origin_n == 0),
    sd_origin_n_log = log1p(sd_origin_n),
    rc_dest_3h_none = as.integer(rc_dest_3h_n == 0),
    rc_dest_3h_n_log = log1p(rc_dest_3h_n)
  )
# precipitation amount: log scale in hundredths of an inch (p01i is mostly 0 and right-skewed)
for (s in suffixes) df[[paste0("p01i_log", s)]] <- log1p(100 * df[[paste0("p01i", s)]])

# Rates with n = 0 are undefined: fill with the TRAINING mean (indicator above keeps the information)
train_means <- df %>% filter(split == "train") %>%
  summarise(sd = mean(sd_origin_dep15_rate, na.rm = TRUE), rc = mean(rc_dest_3h_rate, na.rm = TRUE))
df <- df %>% mutate(
  sd_origin_dep15_rate = ifelse(sd_origin_none == 1, train_means$sd, sd_origin_dep15_rate),
  rc_dest_3h_rate = ifelse(rc_dest_3h_none == 1, train_means$rc, rc_dest_3h_rate)
)

# Shared complete cases: a flight is kept only if it is complete under C, W AND WO,
# so all paired comparisons use exactly the same flights.
needed <- unique(unlist(lapply(c("C", "W", "WO"), function(cond) {
  s <- WEATHER_SUFFIX[[cond]]
  c(SCHEDULE_VARS, HISTORY_VARS, paste0(WEATHER_VARS, s[["origin"]]), paste0(WEATHER_VARS, s[["dest"]]),
    if (cond == "WO") OPERATIONAL_VARS)
})))
complete <- complete.cases(df[, needed])
summary_tab <- df %>% mutate(complete = complete) %>% group_by(split) %>%
  summarise(eligible = n(), dropped_incomplete = sum(!complete), analysed = sum(complete),
            delay_rate = round(mean(ArrDel15[complete]), 4),
            first_date = min(FlightDate), last_date = max(FlightDate), .groups = "drop")
na_counts <- colSums(is.na(df[, needed]))   # among eligible flights, before dropping
df <- df[complete, ]

# Factor levels in validation must be seen in training
for (v in c("Reporting_Airline", "Origin", "Dest", "DayOfWeek")) {
  unseen <- setdiff(unique(as.character(df[[v]][df$split == "validation"])),
                    unique(as.character(df[[v]][df$split == "train"])))
  if (length(unseen)) stop(v, ": validation levels not in training: ", paste(unseen, collapse = ", "))
}

keep <- unique(c("flight_id", "FlightDate", "split", "ArrDel15", needed))
saveRDS(list(data = df[, keep], train_means = train_means,
             note = "Month is not a predictor: validation months (May-Jun) never occur in training (Jan-Apr)."),
        SPLIT_FILE)
write_csv(summary_tab, file.path(MIDWAY_DIR, "prep_summary.csv"))
print(summary_tab)
cat("\nColumns with missing values among eligible flights (count of NA):\n")
print(na_counts[na_counts > 0])
cat("\nPredictors per condition:", sapply(c("C", "W", "WO"), function(x) length(predictors(x))), "\n")
