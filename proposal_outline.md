# Proposal outline: Data leakage in flight-delay prediction

**Course:** STA2112, Fall 2026  
**Proposal deadline:** October 16, 2026

## 1. Research question and motivation — approximately 80 words

**Main question:** How does information unavailable before departure affect flight-delay prediction performance?

Explain the setting and why it matters:
- Make the prediction two hours before scheduled departure.
- Predict whether arrival is at least 15 minutes late.
- A model using later operational information can look effective retrospectively while being unusable at the stated prediction time.
- Investigate the magnitude of the apparent performance gain. Changes in model ranking are a secondary question, not a promised finding.

Possible hypothesis: Including information unavailable before departure increases apparent predictive performance and may change which model appears best.

## 2. Data source and background — approximately 100–120 words

**Source:** Bureau of Transportation Statistics (BTS), Reporting Carrier On-Time Performance (1987–present). One row represents one reported flight.

**Proposed full-study scope:** 2025 flights departing from Atlanta (ATL). Confirm the scope and access to the remaining months before submission.

**Target population and outcome:**
- Completed, nondiverted flights with an observed arrival-delay indicator.
- Outcome: `ArrDel15`, where 1 indicates arrival at least 15 minutes late.
- Cancellation and diversion flags define eligibility; they are not model predictors.
- Findings concern arrival delay among completed, nondiverted flights, not all travel disruption.

**Predictor groups used in the pilot:**
- Scheduled information: `DayOfWeek`, scheduled departure minutes, `CRSElapsedTime`, and `Distance`.
- Deliberately unavailable information: `DepDelay` and `TaxiOut`, added to the same scheduled predictors.
- Never include `ArrDel15` or direct encodings of arrival delay as predictors.

Explain the feature-availability assumptions using BTS documentation. The archive is retrospective; treating recorded scheduled fields as known at the cutoff is an assumption to acknowledge. Airline and destination are downloaded but are not predictors in the current pilot.

## 3. Proposed comparison and primary estimand — approximately 120–150 words

Use two models and two feature conditions:

| Model | Scheduled information only | Scheduled + unavailable information |
|---|---|---|
| Logistic regression | Clean condition | Deliberate leakage condition |
| Random forest | Clean condition | Deliberate leakage condition |

For each paired feature comparison, use identical eligible flights, training dates, and evaluation dates. Describe the latter condition as a constructed hindsight workflow; do not imply that it reproduces a published study unless a specific protocol is identified.

**Primary metric:** Average precision (AP), computed using the same tie-aware function in `scripts/metrics.R` for every model. AP measures ranking and is not classification accuracy or trapezoidal PR-AUC.

**Secondary metric:** Binary Brier score, `mean((predicted_probability - actual_outcome)^2)`, calculated on the same flights; lower is better. It evaluates probability accuracy and reflects both calibration and discrimination, rather than calibration alone. Use numeric 0/1 validation outcomes. Log loss can remain an optional extension; it is not calculated in the current pilot.

**Primary estimand, separately for each model:**

`Delta_AP = AP_leakage - AP_clean`

**Secondary estimand:** `Delta_Brier = Brier_clean - Brier_leakage`. With these sign conventions, a positive difference indicates improved apparent performance with unavailable information for either metric.

**Secondary comparison:** Does correcting information availability change the model ranking? Interpret small differences using uncertainty estimates. Boosting is optional and outside the minimum core study.

## 4. Evaluation plan — approximately 150–180 words

Specify a chronological design before final evaluation. A proposed annual allocation is:
- January–August: training.
- September–October: validation and model selection. For more robust model and parameter selection, a time-based expanding window validation strategy will be applied to the development data (e.g., using January–June to predict July, January–July to predict August, etc.) to better capture the temporal dynamics of real-world operational scenarios.
- November–December: untouched final evaluation.

Include:
- Fit learned preprocessing using training data only.
- Use a bounded, documented tuning budget for each model and feature condition; report settings and seeds.
- Evaluate paired conditions on exactly the same final flights.
- Report delay prevalence, AP, and Brier score for each evaluation window. Use a constant-probability reference estimated from the training outcomes only; do not fit the reference probability to validation or test outcomes.
- Estimate uncertainty in AP and Brier-score differences with paired resampling of test dates. State that this addresses variation across evaluation dates, conditional on fitted models; it does not capture all training uncertainty. Consider longer blocks if dependence across dates is material.
- Use additional chronological development windows to assess sensitivity to time periods, keeping final evaluation separate.

If retained, random-split evaluation is a separate diagnostic. Do not combine feature removal and split changes into one comparison and attribute the full difference to either factor.

## 5. Minimum viable experiment and preliminary evidence — approximately 80–100 words

**Completed pilot:** January 2025 Atlanta departures; 22,580 eligible flights, with no missing values in the selected fields.

| Pilot set | Dates | Flights | Delay rate |
|---|---|---:|---:|
| Training | January 1–20 | 14,093 | 24.52% |
| Validation | January 21–25 | 3,636 | 33.55% |
| Reserved pilot test | January 26–31 | 4,851 | 11.79% |

**Preliminary, untuned validation results:**

| Model | Scheduled-only AP | Leakage AP | Difference |
|---|---:|---:|---:|
| Logistic regression | 0.225 | 0.976 | 0.752 |
| Random forest | 0.278 | 0.973 | 0.695 |

**Secondary Brier-score results on the same 3,636 validation flights (lower is better):**

| Model | Scheduled-only Brier | Leakage Brier | Reduction: clean minus leakage |
|---|---:|---:|---:|
| Logistic regression | 0.2769 | 0.0390 | 0.2378 |
| Random forest | 0.2865 | 0.0399 | 0.2466 |

The training-rate constant-probability reference has Brier score **0.2311**. Both clean models have larger probability errors than this reference. Random forest has higher clean AP (0.278 versus 0.225) but worse clean Brier score (0.2865 versus 0.2769), illustrating that ranking and probability accuracy need not favour the same model. Adding unavailable information improves both metrics substantially; these are retrospective validation findings, not deployable performance estimates.

The constant-probability reference AP is 0.336. Both clean models fall below it overall. Daily diagnostics show average predicted risks closely follow training weekday rates that do not hold in the validation period. This supports investigating time sensitivity; it does not establish the cause of the disruptions.

The minimum viable experiment is the paired feature comparison with these two models. The full study expands the time coverage and adds uncertainty estimates. Keep the proposal's pilot summary brief; the detailed tables can remain in project materials. Do not present validation findings as final test results.

Saved results (the existing CSV filenames now contain both `AP` and `Brier` columns):

- `results/pilot/logistic_validation_AP.csv`
- `results/pilot/random_forest_validation_AP.csv`

## 6. Feasibility, fallback, and responsibilities — approximately 100–120 words

**Access already verified:**
- January 2025 data downloaded and processed.
- Logistic-regression and random-forest scripts ran in the team's RStudio project.
- Shared AP calculation and saved model/result files are available.

**Still to verify:** access to remaining planned monthly files; package versions; execution on teammates' computers; full-study runtime and memory.

**Computing plan:** R on an available CPU laptop, using base R and `ranger`. Record versions, seeds, runtime, and relevant resource limits. No GPU or paid API is planned.

**Fallback:** restrict data coverage or sample training flights if needed; use fewer or smaller trees under a declared budget. Preserve the same-flight leakage comparison. Weather and aircraft-history joins remain optional.

**Responsibilities:** 

| Name | Part | Detail |
|---|---|---|
|--NAME--|Data Cleaning & Preprocessing|Transform the original tables into "clean" data that the model can use directly, while strictly controlling the usability boundaries of the information.|
|--NAME--| Model Training - Logistic Regression & Random Forest | To train the model and find the most robust parameters under both "clean" and "leaked" data conditions. |
|--NAME--| Evaluation & Inference| Calculating metrics and generating a final report on the completely untouched November-December test set. |  

## References to use

- STA2112, *Final Project Guidelines and Seed Questions*, Fall 2026, September 9, 2026; relevant lectures on legitimate information and evaluation.
- [BTS field documentation](https://www.transtats.bts.gov/Fields.asp?gnoyr_VQ=FGJ).
- [BTS monthly download archive](https://transtats.bts.gov/PREZIP/).
- [Average precision definition](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.average_precision_score.html): methodological reference; the pilot calculates AP in R.
- [Brier score definition](https://scikit-learn.org/stable/modules/model_evaluation.html#brier-score-loss): methodological reference for binary mean squared probability error; the pilot calculates Brier score in R.
- [ranger documentation](https://imbs-hl.github.io/ranger/reference/ranger.html).
- Optional model-background reference: Probst, Wright, and Boulesteix (2019), [Hyperparameters and tuning strategies for random forest](https://arxiv.org/abs/1804.03515).
