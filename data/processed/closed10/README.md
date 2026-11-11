# 10-airport closed-network data (midway checkpoint)

Built by `scripts/01a_download_weather_10airports.py`, `scripts/01b_build_closed10_flights.py` and
`scripts/02_history_features.py`
(Python 3, standard library only). Airport list, IEM stations and IANA time zones: `config/airports.csv`.

Airports: ATL, ORD, DFW, DEN, LAX, SFO, JFK, SEA, PHX, MCO (PHX does not observe DST).

## Files

| File | Rows | Variables | Contents |
|---|---:|---:|---|
| `flights_closed10_dev_2025JanJun.csv.gz` | 237,138 | 43 | Flights with **origin and destination both** in the 10 airports, Jan–Jun 2025 (train Jan–Apr, validation May–Jun) |
| `flights_closed10_test_2025JulSep.csv.gz` | 122,896 | 43 | Same, Jul–Sep 2025. **Final test period: do not use for fitting, tuning or feature selection.** |
| `history_10airports_dev_2025JanJun.csv.gz` | 1,945,965 | 18 | Any flight with origin **or** destination in the 10 airports (17 columns). Source for historical delay rates. |
| `history_10airports_test_2025JulSep.csv.gz` | 1,034,586 |18 | Same, Jul–Sep 2025 (outcomes known before a test flight's cutoff may be used for its historical rates). |
| `history_10airports_pre_2024JulDec.csv.gz` | 2,024,992 | 18 | Same, Jul–Dec 2024. **Lookback only**, so January 2025 flights have a full 182-day window. |
| `features_history_dev.csv.gz` / `features_history_test.csv.gz` | 237,138 / 122,896 | 30/30 | As-of historical and same-day features per study flight; join on `flight_id` (see below). |
| `weather_10airports_2025JanSep.csv.gz` | 75893 | 13 | All IEM routine + special METAR reports, 2024-12-31 to 2025-09-30, **UTC** (`valid`), plus `iata` column |
| `model_table_dev.csv.gz` | 237,138 | 122 | Final merged dataset for model training and validation (Jan–Jun 2025), combining flight, history, and weather features |
| `model_table_test.csv.gz` | 122,896 | 122 |Final merged dataset for the test period (Jul–Sep 2025) |
| `summary_counts.csv` | — | - | Rows, eligible flights and ArrDel15 rate by month × origin |

Read in R with `read.csv(gzfile(path))` or `data.table::fread(path)`.

## Notes

- No flights are dropped for cancellation or diversion. `eligible = 1` means completed, not
  diverted, and `ArrDel15` observed — the study population. Cancelled/diverted rows are kept for
  historical-rate and previous-leg features.
- `flight_id` = date_carrier_flightnumber_origin_dest_CRSDepTime (unique; checked).
- BTS times (`CRSDepTime`, `DepTime`, `CRSArrTime`, `ArrTime`, `WheelsOff`, …) are **local time at
  the respective airport**, HHMM, with `2400` possible. Weather `valid` is UTC. Convert everything
  to UTC with `config/airports.csv` before applying the T − 2h cutoff.
- Leakage columns are kept on purpose (`DepDelay`, `TaxiOut`, `WheelsOff`, delay-cause minutes, …).
  Only the feature-availability table decides which columns enter the clean model.
- Eligible ArrDel15 rate by month: Jan 0.178, Feb 0.205, Mar 0.208, Apr 0.214, May 0.253,
  Jun 0.309 | Jul 0.322, Aug 0.268, Sep 0.186. Validation (May–Jun) and July are much more
  delayed than training (Jan–Apr) — expect calibration shift, as in the pilot.
- Raw BTS zips (`data/raw/bts/`) and per-station weather (`data/raw/weather/`) are git-ignored;
  rerun the two scripts to rebuild everything (≈3 minutes plus downloads).

## As-of historical features (`features_history_*.csv.gz`)

Cutoff `c` = scheduled departure (UTC) − 120 min (column `cutoff_utc`). Only completed, non-diverted
history flights whose outcome was **known before `c`** are used, assuming the outcome is known when it
happens (reporting lag 0). Time zones for all 297 airports in the history files: `config/airport_timezones_all.csv`.

| Columns | Definition |
|---|---|
| `hr_{origin,dest,carrier,route}_{182d,28d,7d}_{n,rate}` | Flights with the same origin / destination / carrier / route whose **actual arrival** (UTC) is in [c − window, c); `rate` = share with ArrDel15 = 1 |
| `sd_origin_n`, `sd_origin_dep15_rate` | Flights from the same origin on the same local date that **actually departed** before c; share departing ≥ 15 min late |
| `rc_dest_3h_n`, `rc_dest_3h_rate` | Flights that **arrived** at the destination in [c − 3 h, c); share arriving ≥ 15 min late |

`rate` is empty when `n` = 0 (same-day: 4% of training flights, mostly early-morning departures;
recent destination arrivals: 2%). Carrier rates use only flights touching the 10 airports.

Checks: actual arrival (UTC) = scheduled departure + `CRSElapsedTime` + `ArrDelay` reproduces BTS
`ArrTime` for all but 18 of 600,001 flights; `python3 scripts/02_history_features.py check 120`
recomputes all 14 features for random flights by a brute-force scan (0 mismatches).

Training (Jan–Apr) mean of each rate, on-time vs delayed flights: 182-day rates barely differ
(origin 0.183 vs 0.187), 7-day rates differ more (route 0.196 vs 0.233), and same-day/recent features
differ most (same-day origin 0.095 vs 0.145; recent destination 0.195 vs 0.246).
