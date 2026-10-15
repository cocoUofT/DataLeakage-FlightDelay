# Proposal pilot performance comparison

Atlanta departures, January 2025: 14,093 training flights and 3,636 validation flights (January 21–25).

Wind speed is measured at the origin in knots in all conditions.

**Clean precipitation:** categorical precipitation intensity (none/light/moderate/heavy), including snow and other supported falling precipitation.

**Leakage precipitation amount:** IEM's p01i, measured in inches accumulated since the previous hourly precipitation reset—not categorical intensity. Trace values are encoded as 0.0001 inch, not a measured trace amount.

C uses measurements before scheduled departure minus two hours. W replaces them with measurements near scheduled departure, strictly after cutoff. WO adds DepDelay and TaxiOut. All conditions use identical flights and non-weather predictors. W versus C changes both timing and precipitation representation; this difference does not isolate timing alone. WO versus W holds the weather definition fixed.

AP: higher is better. Brier: lower is better.

| Model | Condition | AP | Brier |
|---|---|---:|---:|
| Constant reference | Training delay prevalence | 0.3355 | 0.2311 |
| Logistic regression | Clean early weather (C) | 0.2291 | 0.2776 |
| Logistic regression | Later weather (W) | 0.2261 | 0.2777 |
| Logistic regression | Later weather + operational leakage (WO) | 0.9764 | 0.0389 |
| Random forest | Clean early weather (C) | 0.3509 | 0.2570 |
| Random forest | Later weather (W) | 0.4286 | 0.2421 |
| Random forest | Later weather + operational leakage (WO) | 0.9710 | 0.0414 |

## Paired apparent performance changes

Positive AP gains and Brier reductions indicate better apparent performance.

| Model | Comparison | AP gain | Brier reduction |
|---|---|---:|---:|
| Logistic regression | clean -> weather_leakage | -0.0031 | -0.0001 |
| Logistic regression | weather_leakage -> leakage | +0.7503 | +0.2388 |
| Logistic regression | clean -> leakage | +0.7472 | +0.2387 |
| Random forest | clean -> weather_leakage | +0.0777 | +0.0148 |
| Random forest | weather_leakage -> leakage | +0.5424 | +0.2007 |
| Random forest | clean -> leakage | +0.6201 | +0.2155 |

## Interpretation limits

These are untuned, origin-only pilot validation results over five dates. They do not demonstrate nationwide/destination performance or a causal weather effect. Forecasts, historical rates, selection and tuning are not included in these fits.

The archive observation timestamp is not verified publication/receipt time; reporting latency and later corrections remain availability assumptions. Observations are backward-matched, not necessarily measured at each flight's exact target minute.

The 4,851 January 26–31 pilot test flights remain reserved from model-performance evaluation.

