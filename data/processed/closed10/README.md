# 10-airport closed-network data (midway checkpoint)

Built by `scripts/01a_download_weather_10airports.py` and `scripts/01b_build_closed10_flights.py`
(Python 3, standard library only). Airport list, IEM stations and IANA time zones: `config/airports.csv`.

Airports: ATL, ORD, DFW, DEN, LAX, SFO, JFK, SEA, PHX, MCO (PHX does not observe DST).

## Files

| File | Rows | Contents |
|---|---:|---|
| `flights_closed10_dev_2025JanJun.csv.gz` | 237,138 | Flights with **origin and destination both** in the 10 airports, Jan–Jun 2025 (train Jan–Apr, validation May–Jun) |
| `flights_closed10_test_2025JulSep.csv.gz` | 122,896 | Same, Jul–Sep 2025. **Final test period: do not use for fitting, tuning or feature selection.** |
| `history_10airports_dev_2025JanJun.csv.gz` | 1,945,965 | Any flight with origin **or** destination in the 10 airports (17 columns). Source for historical delay rates. |
| `history_10airports_test_2025JulSep.csv.gz` | 1,034,586 | Same, Jul–Sep 2025 (outcomes known before a test flight's cutoff may be used for its historical rates). |
| `weather_10airports_2025JanSep.csv.gz` | ~76,000 | All IEM routine + special METAR reports, 2024-12-31 to 2025-09-30, **UTC** (`valid`), plus `iata` column |
| `summary_counts.csv` | — | Rows, eligible flights and ArrDel15 rate by month × origin |

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
