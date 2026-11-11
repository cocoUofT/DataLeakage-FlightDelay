# Audit of the analysis procedure (2026-11-11)

Scope: midway analysis (`scripts/`, `results/midway/`, `results/tuning/`) and the final-study extension
(`final/`). Empirical checks: `final/R/90_audit_checks.R` (outputs `audit_checks.csv`,
`audit_rotation_gain_regular_only.csv`). All numbers below are validation (May–Jun 2025); the test period
has not been used by any modelling or evaluation script (only feature-building scripts read test files).

## Findings, most serious first

### 1. Aircraft-swap leakage through `Tail_Number` (final extension only) — HIGH
BTS records the aircraft that *finally* operated each flight. 2.6% of development flights have an
irregular recorded rotation right before them (previous row of the same tail is schedule-infeasible or ends
at another airport) — the trace of an aircraft swap. Swaps are decided around disruptions, so the record
carries post-cutoff information: delay rate 0.68 for these flights vs 0.22 otherwise (0.90 for
schedule-infeasible cases). The rotation chain breaks there, so 87% of them get `rot_state = no_prev`,
and the model learns "no previous leg ⇒ likely delayed".
Effect on the rotation gain (AP, rotation − base), all flights → regular-rotation flights only:

| model | 12 h | 6 h | 4 h | 2 h | 1 h | 30 min |
|---|---|---|---|---|---|---|
| LR | 0.049 → 0.014 | 0.064 → 0.035 | 0.094 → 0.072 | 0.156 → 0.144 | 0.175 → 0.169 | 0.175 → 0.168 |
| RF | 0.071 → 0.036 | 0.077 → 0.048 | 0.103 → 0.082 | 0.157 → 0.144 | 0.173 → 0.166 | 0.185 → 0.179 |

The gain at ≤ 2 h is robust; at long horizons it is overstated by roughly half or more. The planned
aircraft cannot be recovered from BTS. **Fix:** in the final study, report the rotation analysis on
regular-rotation flights (refit and evaluate without irregular flights, for every feature set so the
comparison stays paired) as the main result and the all-flights version as a sensitivity; state the
assumption that the recorded aircraft equals the planned one for regular rotations; add the same-day-legs-only
sensitivity already planned. The midway models do not use tail numbers and are unaffected.

### 2. Validation set reused for decisions — MEDIUM
Several choices were made by looking at validation results: keeping the network-wide features, RF
hyperparameters (selected by validation AP), the widened tuning grid, and the final-study feature design.
Validation numbers for tuned RF and for these choices are therefore optimistic (e.g., clean RF 0.463 untuned
vs 0.483 tuned). The final-study horizon results use the RF settings tuned at 2 h on validation.
**Fix:** treat all validation numbers as development results; freeze features, settings and the list of
sensitivity analyses in a written plan, then evaluate once on Jul–Sep. Midway slides should say the RF is
untuned and the numbers are validation results.

### 3. Information-availability assumptions — MEDIUM
- BTS outcomes (historical rates, same-day and recent delays, network rates, rotation status) are assumed
  known the moment they happen (reporting lag 0). This matches an airline/airport operations user; a
  traveller relying on public BTS data (released monthly, ~2 months later) would not have them.
- METAR reports are assumed available at their observation time (lag 0); IEM timestamps are not receipt
  times. The 15/30-minute lag sensitivity is in progress.
**Fix:** name the intended user in the report; run the weather-lag and BTS-release-lag sensitivities.

### 4. Population conditioned on completion — MEDIUM (interpretation)
Cancelled and diverted flights are excluded, and these are concentrated on disrupted days that a real
system would face. Performance applies to flights that operated. Also limited to 10 hubs (closed network)
and to May–Jun for validation. **Fix:** state the population and avoid generalising beyond it.

### 5. Uncertainty statements are conditional — LOW/MEDIUM
Bootstrap CIs resample validation days with models held fixed: they cover day-to-day variation in the
evaluation sample, not training variability or other seasons; 61 validation days. Midway checked 7-day
blocks (CIs essentially unchanged); the final-study CIs use 1-day blocks only. Many comparisons are
reported. **Fix:** add the 7-day-block check to the final study; describe CIs as conditional on the fitted
models; avoid over-reading marginal differences.

### 6. Calibration differs by model — LOW (interpretation)
All models under-predict the validation delay rate (seasonal shift 0.20 → 0.28); RF probabilities are too
conservative (calibration slope ≈ 1.4). Brier comparisons between LR and RF partly reflect calibration, not
ranking. Intercept-shift diagnostics use validation outcomes and are labelled diagnostic. **Fix:** planned
recalibration fitted on data separate from the evaluation data.

### 7. Minor data issues — LOW
- 3 flights departed > 30 min early (max 114 min, likely recording errors); at the 1 h / 30 min horizons
  each flight's own departure enters its same-day origin departure count. Negligible; fix by excluding the
  flight itself from that count.
- 18 legs have departure delays > 22 h (1,326–2,264 min); the departure time reconstructed from HHMM clock
  times wraps by a day for them. Negligible; fix by using `DepDelay` when available.

## Checks that passed
- `ArrDel15` equals `ArrDelay >= 15` for all 3.9 M completed legs.
- No flight's own arrival is known at its cutoff at any horizon; train/validation do not overlap and are
  chronological (last training day 2025-04-30).
- Clean weather never comes from after the cutoff; report age 0–84 min at every horizon (limit 120).
- History, same-day, recent-arrival and network features: exact match with independent implementations
  (Python vs R at 2 h; brute-force scans at 12 h and 30 min).
- Rotation information is always from before the cutoff; projected delays are never negative.
- C / W / WO and all horizons are evaluated on identical flights; imputation uses training statistics only;
  lasso selection uses training data only (month-blocked CV); no factor level appears only in validation.
- No modelling or evaluation script reads the Jul–Sep test files.
