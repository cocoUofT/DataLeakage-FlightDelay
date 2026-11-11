# Feature-availability table (draft v1, 2026-11-09)

**Prediction time.** For each flight, the cutoff is *c* = scheduled departure (UTC) − 120 min.
A feature is **clean (C)** only if its value is realized **and** would have been reported by *c*.
Population: completed, non-diverted flights between the 10 study airports (`eligible = 1`);
this conditions on completion, so results exclude cancellation/diversion risk.

## 1. Time handling (applies to every row)

| Item | Rule | Checked on the dev file (234,307 eligible flights) |
|---|---|---|
| BTS clock times | Local time at the airport where the event happens, HHMM. Convert with `config/airports.csv` (IANA zone). | Scheduled dep (UTC) + `CRSElapsedTime` reproduces `CRSArrTime` in dest local time for all but 8 of 237,138 rows → BTS times are local and the conversion is correct. |
| Dates | `FlightDate` is the local date of scheduled departure. Derive arrival times as dep (UTC) + elapsed minutes rather than from `ArrTime` + date, which is ambiguous overnight. | 16,169 flights (6.8%) arrive on a later local date. |
| `2400` | Means 00:00 of the next day. | No `2400` in scheduled times; 73 in `DepTime`, 140 in `ArrTime`. |
| Actual departure (UTC) | Scheduled dep (UTC) + `DepDelay`. | `DepTime` = `CRSDepTime` + `DepDelay` (mod 24 h) for every eligible row. |
| Actual arrival (UTC) | Actual dep (UTC) + `ActualElapsedTime`. | — |
| DST | 2025-03-09 spring-forward is inside the dev period; fall-back (11-02) is outside the data. PHX has no DST. Non-existent local times → flag, do not silently shift. | No scheduled departure falls in the non-existent hour. |
| Weather time | IEM `valid` is UTC observation time, not publication time. | Routine reports at :51–:56 past the hour; median gap 60 min; 11 gaps > 120 min across 10 stations. `p01i` never missing. |
| Reporting lag *L* | Use a weather report only if `valid` ≤ *c* − *L*. Primary *L* = 0; sensitivity *L* = 15 and 30 min. Maximum report age 120 min, otherwise missing. | — |

## 2. Feature table

C = clean, W = weather leakage, WO = weather + operational leakage, ✗ = never used as a predictor.

| Feature | Source | Native time / zone | When realized | Assumed reporting lag | Available at *c*? | Condition | Notes |
|---|---|---|---|---|---|---|---|
| **Schedule** | | | | | | | |
| Carrier (`Reporting_Airline`) | BTS | — | Schedule publication | Weeks before | Yes | C | |
| Origin, Dest, route | BTS | — | Schedule | Weeks before | Yes | C | 10 × 9 = 90 routes |
| Scheduled dep time (`CRSDepTime`) → hour of day | BTS | Origin local | Schedule | Weeks before | Yes | C | Use spline or blocks, not linear minutes (pilot issue) |
| Scheduled arr time (`CRSArrTime`) → hour | BTS | Dest local | Schedule | Weeks before | Yes | C | |
| `CRSElapsedTime`, `Distance` | BTS | — | Schedule | Weeks before | Yes | C | Collinear; may keep one |
| Month, day of week | BTS / calendar | Origin local date | Calendar | — | Yes | C (day of week only) | DayOfWeek was confounded with storm days in the pilot; check with Jan–Apr training; Month not used at midway (validation months absent from training) |
| US holiday / days to holiday | Calendar | Origin local date | Calendar | — | Yes | C | Build from a federal-holiday list |
| `DepTimeBlk`, `ArrTimeBlk` | BTS | Local | Schedule | — | Yes | C | Scheduled-time blocks, despite the name; redundant with hour |
| `Tail_Number` (aircraft) | BTS | — | Assigned before the day, can be swapped | Uncertain | **Assumed yes** | C (sensitivity) | Final reported tail may reflect same-day swaps; used only for previous-leg features below |
| **Weather at cutoff** | | | | | | | |
| Origin wind speed `sknt` | IEM | UTC | Observation `valid` | *L* | Yes if `valid` ≤ *c* − *L* | C | |
| Origin precipitation (intensity from METAR, or `p01i`) | IEM | UTC | Observation | *L* | Yes if `valid` ≤ *c* − *L* | C | **Use the same representation as W** so C vs W isolates timing |
| Origin visibility `vsby` | IEM | UTC | Observation | *L* | Yes | C | Raw. Below 3 statute miles in 2–13% of dev-period reports, depending on airport (PHX ≈ 0) |
| Origin thunderstorm flag (`TS` in `wxcodes`) | IEM | UTC | Observation | *L* | Yes | C | Derived. 2–4% of reports at ATL/DFW/MCO/DEN; ≈ 0 at LAX/SFO/SEA/PHX |
| Origin snow / freezing precipitation flag (`SN`, `SG`, `PL`, `IC`, `FZRA`, `FZDZ`; not `FZFG`) | IEM | UTC | Observation | *L* | Yes | C | Derived. 13% of reports at DEN, 8% at ORD, ≈ 0 at southern and western airports |
| Origin gust (`gust`) | IEM | UTC | Observation | *L* | Yes | C | Raw. `M` usually means no gust reported → 0 plus a "gust reported" indicator |
| Origin ceiling (`skyc1`/`skyl1`), temperature | IEM | UTC | Observation | *L* | Yes | C (optional) | Only the lowest cloud layer was downloaded; a true ceiling needs `skyc2`–`skyc4` |
| Destination weather (all weather fields and flags above) | IEM | UTC | Observation at dest | *L* | Yes if `valid` ≤ *c* − *L* | C | Same cutoff *c* as origin, not dest arrival time |
| **Weather after cutoff (leakage)** | | | | | | | |
| Origin weather nearest scheduled departure | IEM | UTC | Latest report in (*c*, scheduled dep] | — | **No** | W | Pilot definition |
| Destination weather nearest scheduled arrival | IEM | UTC | Latest report in (*c*, scheduled arr] | — | **No** | W | **Decision needed:** near scheduled arrival (more leakage) or near scheduled departure (parallel to origin) |
| **Historical and same-day operations (derived)** | | | | | | | |
| Historical delay rates (origin, dest, carrier, route) | BTS history files | UTC after conversion | Each past flight's actual arrival | 0 (operational) | Only flights with actual arrival (UTC) < *c* | C | **Built** (`scripts/02_history_features.py`): 182-, 28- and 7-day windows; Jul–Dec 2024 added so January has a full 182-day lookback. Origin × hour not built yet. **Public-data variant:** BTS releases each month about 2 months later, so only months released before *c* would count (sensitivity) |
| Same-day departure delays so far at origin | BTS history | UTC | Actual dep of earlier flights | 0 | Only flights with actual dep (UTC) < *c* | C | **Built.** Missing for 4% of training flights (no earlier departures) |
| Recent arrival delays at destination (last 3 h) | BTS history | UTC | Actual arrival of earlier flights | 0 | Only flights with actual arrival in [*c* − 3 h, *c*) | C | **Built.** Missing for 2% |
| Network-wide delay rate, last 24 h and 7 days (flights departing the 10 airports) | BTS history | UTC | Actual arrival of earlier flights | 0 | Only flights with actual arrival (UTC) < *c* | C | **Built** (`scripts/02b_network_features.R`); added after the first midway run, improves clean LR |
| Inbound aircraft (previous leg, same tail): scheduled turnaround time | BTS history | UTC | Schedule | — | Yes | C | Previous leg may be outside the 10 airports; history files cover any flight touching them |
| Inbound aircraft: delay, if the previous leg arrived (or departed) before *c* | BTS history | UTC | Previous leg's actual times | 0 | Only if realized before *c*; otherwise "not yet known" | C | Encode "not yet arrived" as its own category, not as zero delay |
| **Operational, after departure** | | | | | | | |
| `DepDelay` (`DepTime`, `DepDel15`, `DepDelayMinutes`) | BTS | Origin local | Actual pushback | — | **No** | WO | Pilot WO |
| `TaxiOut`, `WheelsOff` | BTS | Origin local | After pushback | — | **No** | WO | Pilot WO |
| `WheelsOn`, `TaxiIn`, `AirTime`, `ActualElapsedTime`, `ArrTime` | BTS | Dest local | After departure | — | **No** | ✗ | Close to a deterministic function of the outcome; would make WO trivial |
| `ArrDelay`, `ArrDelayMinutes`, `ArrivalDelayGroups` | BTS | — | Arrival | — | **No** | ✗ | Define the outcome |
| Delay causes (`CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, `LateAircraftDelay`) | BTS | — | Reported only when `ArrDel15` = 1 | — | **No** | ✗ | Missingness itself reveals the outcome |
| `Cancelled`, `Diverted`, `CancellationCode` | BTS | — | Day of operation | — | **No** | ✗ | Define eligibility only |
| **Outcome** | | | | | | | |
| `ArrDel15` | BTS | Dest | Arrival | — | — | Target | Arrival ≥ 15 min after `CRSArrTime` |

## 3. Open decisions for the team

1. Precipitation in C and W: intensity in both, or `p01i` in both? (Recommendation: one representation for both; keep the pilot's mixed version as a secondary check.)
2. Destination weather in W: near scheduled arrival or near scheduled departure?
3. Historical rates: built with operational known-by-cutoff (lag 0). Add a BTS public-release-lag sensitivity later? (365-day windows would need Jan–Jun 2024.)
4. Tail-number features: include in C, or only as a sensitivity because of same-day swaps?
5. Which of these are midway scope versus final scope? Suggestion for midway: schedule + origin and dest weather at cutoff (C), the W and WO definitions above, *L* = 0. Historical rates and inbound-aircraft features go to the final study.
