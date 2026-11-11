# Final study extension: prediction time and the inbound aircraft

Question: how does a **clean** (leakage-free) model's performance depend on *when* the prediction is made,
and how much does information about the aircraft's previous legs (its rotation) add at each prediction time?

Midway files are not changed; this folder only reads `data/processed/closed10/`, `config/`,
`scripts/weather_decoder.R` and `proposal/scripts/metrics.R`. Validation only (train Jan–Apr 2025,
validate May–Jun 2025); the Jul–Sep test period is untouched.

## Run (from the project root)

```bash
Rscript final/R/01_build_inputs.R                       # legs (UTC times), decoded weather, study flights
for h in 720 360 240 120 60 30; do Rscript final/R/02_features_by_horizon.R $h; done
Rscript final/R/02_features_by_horizon.R 120 check      # 2 h features equal the midway features exactly
Rscript final/R/03_fit_by_horizon.R keep                # flights complete at every prediction time
for h in 720 360 240 120 60 30; do Rscript final/R/03_fit_by_horizon.R $h; done
Rscript final/R/04_evaluate_horizons.R                  # tables, bootstrap CIs, figures
```

`final/data/` is git-ignored (rebuilt by 01–02); predictions and results are in `final/results/`.

## Design

- **Prediction time** h ∈ {12 h, 6 h, 4 h, 2 h, 1 h, 30 min}; cutoff c = scheduled departure − h.
  Every time-dependent predictor is recomputed at c: weather, historical / same-day / recent / network rates,
  and rotation features. Same 82,883 validation flights at every h.
- **Rotation features** (Tail_Number): walk back ≤ 8 legs / 36 h along connected legs; schedule-infeasible
  legs (usually aircraft swaps) are skipped. At c take the latest known state — previous leg landed
  (arrival delay), in the air (departure delay), or an earlier leg known when the previous one has not
  departed — and project the delay forward through the remaining scheduled turns (minimum turn 30 min).
- **Feature sets**: `base` (midway clean predictors), `prev1` (previous leg only, no look-back),
  `rotation` (full chain), and at 2 h an `oracle` that adds the previous leg's final arrival (not available).
- **Models**: logistic regression; random forest with the clean settings tuned at 2 h (mtry 3, node 300).

## Key validation results (`horizon_results.md`)

- Rotation features at 2 h: AP 0.472 → 0.628 (LR), 0.483 → 0.640 (RF); they recover about 77% of the gain
  an oracle with the previous leg's final arrival would give.
- Performance rises steadily as the prediction moves closer to departure (RF with rotation: 0.488 at 12 h,
  0.640 at 2 h, 0.693 at 30 min).
- Looking further back along the chain matters at long horizons (+0.016 to +0.028 AP for LR at 4–12 h)
  and not at ≤ 2 h, where the previous leg's status is almost always known.

- Brier improves the same way (RF with rotation: 0.184 at 12 h, 0.159 at 2 h, 0.145 at 30 min; constant
  reference 0.208). All models under-predict the validation delay rate (seasonal shift: training 0.202,
  validation 0.280): LR by 3-5 points with slope near 1; RF by about 2 points but with calibration slope
  about 1.4, i.e. its probabilities are too conservative (shrunk toward the mean). An intercept shift changes
  Brier by at most 0.002, so most of the remaining error is not a level shift. See `horizon_calibration.csv`.

## Assumptions to report

Departure/arrival events are assumed known as soon as they happen (lag 0). BTS records the aircraft that
finally operated the flight; at long horizons the planned aircraft may differ, so rotation features at
12 h / 6 h may be optimistic.
