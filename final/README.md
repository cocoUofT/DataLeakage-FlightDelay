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
Rscript final/R/03_fit_by_horizon.R keep                # flight lists: all_flights and regular
for pop in regular all_flights; do
  for h in 720 360 240 120 60 30; do Rscript final/R/03_fit_by_horizon.R $h $pop; done
  Rscript final/R/04_evaluate_horizons.R 1000 $pop      # tables, bootstrap CIs, figures
done
Rscript final/R/05_compare_populations.R                # main vs sensitivity
Rscript final/R/90_audit_checks.R                       # leakage / consistency checks
```

`final/data/` is git-ignored (rebuilt by 01–02). Results: `final/results/regular/` (**main**: flights with a
regular recorded aircraft rotation, about 2.6% probable aircraft swaps removed from training and evaluation)
and `final/results/all_flights/` (sensitivity: every eligible flight).

## Design

- **Prediction time** h ∈ {12 h, 6 h, 4 h, 2 h, 1 h, 30 min}; cutoff c = scheduled departure − h.
  Every time-dependent predictor is recomputed at c: weather, historical / same-day / recent / network rates,
  and rotation features. Same 82,883 validation flights at every h.
- **Rotation features** (Tail_Number): walk back ≤ 8 legs / 36 h along connected legs; schedule-infeasible
  legs (usually aircraft swaps) are skipped. At c take the latest known state — previous leg landed
  (arrival delay), in the air (departure delay), or an earlier leg known when the previous one has not
  departed — and project the delay forward through the remaining scheduled turns (minimum turn 30 min).
- **Population**: main = regular recorded rotations; sensitivity = all flights (see audit).
- **Feature sets**: `base` (midway clean predictors), `prev1` (previous leg only, no look-back),
  `rotation` (full chain), and at 2 h an `oracle` that adds the previous leg's final arrival (not available).
- **Models**: logistic regression; random forest with the clean settings tuned at 2 h (mtry 3, node 300).

## Key validation results (`results/regular/horizon_results.md`)

Main population: regular recorded rotations (80,509 validation flights, delay rate 0.267). Probable aircraft
swaps (irregular rotations) carry post-cutoff information (audit, `results/audit_report.md`) and are
excluded from training and evaluation for every feature set.

- Rotation features at 2 h: AP 0.456 → 0.604 (LR), 0.469 → 0.619 (RF); Brier 0.180 → 0.157. An oracle
  with the previous leg's final arrival reaches 0.651 / 0.666, so legal rotation information recovers about
  75% of that gain.
- AP of the RF with rotation features: 0.446 (12 h), 0.477 (6 h), 0.533 (4 h), 0.619 (2 h), 0.653 (1 h),
  0.675 (30 min). The steepest rise is between 4 h and 2 h, when most previous legs go from "not departed"
  to "in the air".
- At long horizons almost all of the rotation gain comes from looking further back along the chain: at 12 h
  the previous-leg-only version adds 0.002 AP (LR) while the full chain adds 0.024.
- Sensitivity (all flights): gains are larger at long horizons (LR at 12 h: 0.049) because they include the
  swap leakage; at ≤ 2 h they differ by at most 0.01 (`results/population_comparison.csv`).
- Calibration: all models under-predict the validation delay rate (seasonal shift); RF probabilities are too
  conservative (calibration slope about 1.4). See `horizon_calibration.csv`.

## Assumptions to report

Departure/arrival events are assumed known as soon as they happen (lag 0). BTS records the aircraft that
finally operated the flight; at long horizons the planned aircraft may differ, so rotation features at
12 h / 6 h may be optimistic.

## Plan for the final study (decided 2026-11-11, not yet done)

1. **Presentation**: report the final clean model's performance; show the contribution of information
   sources as a grouped ablation at 2 h (schedule / history and network / weather / aircraft rotation),
   each group removed in turn, rather than singling out one variable. The horizon curve is the main
   figure; rotation-state shares explain its shape; with/without-rotation comparisons go to the appendix.
2. **Main leakage analysis**: rerun C / W / WO with rotation features in the shared clean predictors
   (they were in the feature-availability table from the start). WO - C is expected to shrink because
   rotation features and DepDelay overlap; report this as a finding.
3. **Calibration**: try Platt scaling / isotonic recalibration for RF (fit the calibration on May-Jun,
   refit the model on Jan-Jun, apply to test). Report AP and Brier together.
4. **Sensitivity / audit fixes**: done — main rotation analysis on regular-rotation flights (refit, all feature
   sets), all-flights version kept as sensitivity. Still to do: same-day-legs-only sensitivity; 7-day-block
   bootstrap; exclude a flight from its own same-day count; use DepDelay for >22 h delays.
5. Freeze all settings, refit on Jan-Jun, evaluate once on the Jul-Sep test period.
