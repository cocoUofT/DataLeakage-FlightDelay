# Data leakage in flight-delay prediction

The proposal pilot compares logistic regression and random forest using the same
Atlanta January 2025 training and validation flights. Wind speed and precipitation
are measured at the origin airport. Nationwide and destination weather are planned
for the later study and are not implemented by these pilot scripts.

## Run the pilot

Open `DataLeakage-FlightDelay.Rproj` in RStudio. Install `ranger` if needed, place
the BTS flight file at `data/raw/2025Jan.csv`, then run from the project root:

```r
source("scripts/run_pilot.R")
```

The weather downloader reuses the existing January–June 2025 Atlanta cache. If it
is missing, it downloads it from IEM. The 2026 observation files already present
are retained for future work but are not required or downloaded by this pilot.
No forecasts are used. All other code uses base R.

## Files and responsibilities

| File | Purpose |
|---|---|
| `scripts/run_pilot.R` | Run the four numbered steps in order |
| `scripts/00_download_weather.R` | Download/cache the pilot's airport weather and record provenance |
| `scripts/02_prepare_data.R` | Select eligible flights, match weather backward in time, verify timing, and split chronologically |
| `scripts/03_fit_models.R` | Fit both model families with shared definitions and save validation predictions |
| `scripts/04_proposal_results.R` | Calculate AP/Brier, paired changes, and a readable proposal table |
| `scripts/weather_helpers.R` | Pilot configuration, METAR decoding, matching, formulas, and shared model-row selection |
| `scripts/metrics.R` | Tie-aware AP and the simple mean-squared-error Brier calculation |

To regenerate tables from the saved models' predictions without refitting:

```r
source("scripts/04_proposal_results.R")
```

## Comparison definitions

The fixed non-weather predictors are `DayOfWeek`, scheduled departure minutes,
`CRSElapsedTime`, and `Distance`. Wind is in knots in all conditions.

- **Clean model:** unordered METAR intensity categories (none/light/moderate/heavy), including snow, drizzle and other supported falling precipitation.
- **Leakage models (W and WO): Precipitation amount:** IEM’s `p01i`, measured in inches accumulated since the previous hourly precipitation reset—not categorical intensity.

`p01i` is an accumulated precipitation amount, not an instantaneous rate or a
rain-only measurement; special-report intervals can be shorter than an hour.
The existing trace encoding is 0.0001 inch, not a measured trace amount. Missing
amounts stay missing. Configuration in `weather_helpers.R` explicitly separates
`precipitation_predictor` (clean) and `leakage_precipitation_predictor` (W/WO).

| Condition | Predictors |
|---|---|
| C: clean | Scheduled predictors + wind/precipitation available before scheduled departure minus two hours |
| W: weather leakage | Wind + accumulated p01i amount near scheduled departure, strictly after cutoff |
| WO: weather + operational leakage | W + `DepDelay` and `TaxiOut` |

C versus W changes timing and precipitation representation; it is not a pure timing comparison. W versus WO holds weather fixed and adds operational information. Both model families use the same complete-case flights for every condition. The
constant reference uses training prevalence. RF settings remain 500 trees, mtry 2,
minimum node size 20, factor partitioning, two threads, and seed 924. Logistic
regression remains the existing untuned additive binomial GLM. Variable selection,
interactions, historical rates, tuning, and forecasts are later study work.

Training is January 1–20; validation is January 21–25. January 26–31 test flights
are retained but are not predicted or scored. The script checks for unsupported
validation categories rather than silently recoding them.

## Proposal outputs

- `results/pilot/proposal_comparison.md`: readable scores and changes to use in the proposal.
- `results/pilot/proposal_validation_results.csv`: full-precision AP and Brier scores.
- `results/pilot/proposal_performance_changes.csv`: W−C, WO−W, and WO−C differences for each model.
- `results/pilot/proposal_validation_predictions.csv`: one shared set of flight IDs, outcomes, and probabilities.
- `results/pilot/proposal_models.rds`: both model families, configuration, formulas, and sample counts.
- `results/pilot/session_info.txt`: reproducibility information.

Prepared splits, a readable weather join, a matching summary, and configuration
are saved under `data/processed/`. Earlier scripts, duplicate result files, and
exploratory daily/weekday diagnostics have been moved to the dated
`archive/proposal_cleanup_*` directory. They are preserved but are not required by
the proposal workflow. Raw data and archive contents are ignored by Git.

## Weather timing and interpretation

Use the latest eligible report at or before the target; do not use unrestricted
nearest-time matching or interpolate future observations. The maximum report age
is 120 minutes. Matching uses Atlanta local time converted to UTC, including
HHMM 2400 rollover. This implementation is for January Atlanta; expanding to
multiple origins or DST transitions requires airport/timezone mapping and an
explicit ambiguity policy.

IEM's observation timestamp does not prove historical publication/receipt time.
The default assumes zero reporting lag; set `assumed_reporting_lag_minutes` in
`weather_helpers.R` to 15 or 30 for a sensitivity run. Duplicate timestamps retain
the last archive row, not a reconstructed as-of correction history. These
availability assumptions must accompany clean-model claims.

The decoder uses precipitation codes in the METAR body, excluding remarks,
vicinity-only weather, and blowing/drifting snow. Invalid/unreported conditions
are missing, not automatically dry. Where supported codes coexist, the highest
intensity is used. It is a pilot decoder, not a full international parser. The
amount predictor uses `p01i`, accumulated since the station's previous hourly
reset; intervals can differ for special reports. Trace is encoded as 0.0001 inch,
not a measured trace amount.

These are untuned five-day, origin-only validation findings, not final or causal
weather effects. AP is higher-is-better; Brier is lower-is-better.

## Sources

- [BTS flight data](https://www.transtats.bts.gov/Fields.asp?gnoyr_VQ=FGJ)
- [IEM archive and weather fields](https://mesonet.agron.iastate.edu/request/download.phtml)
- [NWS METAR interpretation](https://aviationweather.gov/help/data/#metar)
