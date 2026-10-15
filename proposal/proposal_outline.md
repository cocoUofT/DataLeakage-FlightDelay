# Proposal outline: Data leakage in flight-delay prediction

## 1. Research question

- **Main question:** How much does information unavailable two hours before scheduled departure influence prediction of arrival delay?
- **Focus:** Investigate how using information unavailable at the prediction time changes model performance, comparing a clean predictor set with predefined leakage conditions.

## 2. Data and background

### Background and motivation

- **Existing problem:** Why it matters? How is it connected to our study**
- **Relevant studies**

### Data sources

- **BTS Reporting Carrier On-Time Performance:** Provides flight related information: flight dates, airlines, origin/destination airports, schedules, distance, arrival-delay outcomes, etc..
- **Iowa Environmental Mesonet (IEM) METAR/ASOS archive:** Provides airport-level weather observations: match wind speed and precipitation to corresponding flight locations and times.

### Full-study scope

- **Locations:** U.S. domestic flights across airports availably represented in the BTS dataset, with weather matched at both origin and destination.
- **Development (training + validation) period:** January–June 2025, including chronological validation for selection and tuning.
- **Final evaluation (test) period:** July-September 2025, final testing only.
- **Eligible flights:** Completed, non-diverted flights with available observed outcome.

### Data Structure

- **Outcome:** Whether arrival is at least 15 minutes late, represented by `ArrDel15`.
- **Prediction time (cutoff):** Two hours prior to the scheduled departure.
- **Leakage Variables:** 
  - Weather leakage: wind measurements and accumulated precipitation amounts taken near the scheduled departure time. 
  - Operational leakage: `DepDelay` and `TaxiOut`.
- **Candidate Predictors:**
  - Predictors from source datasets: scheduled departure time, scheduled duration, distance, airline, origin/destination, weekday, and weather measurements.
  - Derived predictors: holiday indicators, historical delay rates.


## 3. Proposed comparison and primary estimands

- **Comparison:** Fit both logistic regression and random forest models under three conditions: 

| Condition | Weather and operational information |
|---|---|
| Clean (C) | Origin&destination wind and precipitation available before the cutoff;  operational information available before the cutoff|
| Weather leakage (W) |  Add later wind measurements and accumulated precipitation amounts taken near the scheduled departure time, on the basis of model C|
| Weather + operational leakage (WO) | W plus `DepDelay` and `TaxiOut` |

- **Primary metric:** Average Precision (AP): definition? Higher the better.
- **Secondary metric:** Brier score: definition? Lower the better.

## 4. Evaluation plan (NOT YET CHECKED!)

- **Development data:** January–June 2025. Use expanding chronological training windows followed by later validation periods.
- **Model development:** select predictors, assess a limited set of plausible interactions, and tune logistic regression and random forest using development data only. Learn preprocessing within each training window; standardize numerical predictors if using penalized logistic regression.
- **Final fitting:** freeze feature definitions, selected predictors, preprocessing, and tuning choices, then refit on the declared development data.
- **Final test:** July–September 2025. Reserve this period from model selection and tuning.
- **Paired comparison:** evaluate clean (C), weather leakage (W), and weather plus operational leakage (WO) on identical test flights. Use comparable tuning budgets and consistent missing-data handling.
- **Information timing:** clean features must be available before the two-hour prediction cutoff. Historical rates may update sequentially using earlier observable outcomes, without refitting or tuning.
- **Performance evaluation:** evaluate all model conditions using AP and Brier score, and estimate the paired performance differences defined in the estimand section.
- **Reference and reporting:** include a constant-probability reference estimated from training outcomes. Report pooled and monthly scores and delay prevalence. Month is an evaluation grouping, not a candidate predictor.
- **Uncertainty:** estimate paired confidence intervals by resampling test dates, considering longer date blocks if dependence is material.
- **Interpretation:** the current C-to-W comparison changes both weather timing and precipitation representation—early intensity versus later accumulated amount. It therefore does not isolate timing alone. W-to-WO holds weather fixed.

## 5. Minimum viable experiment and preliminary evidence

- **Pilot sample:**
  - Training: January 1–20, 2025 — 14,093 flights used to fit the models.
  - Validation: January 21–25 — 3,636 flights used to calculate the reported AP and Brier scores.
  - Reserved test: January 26–31 — 4,851 flights, not yet scored.
- **Feasibility:** Weather integration is verified at the origin airport.

**Preliminary pilot validation results (untuned models):**

| Model | Clean | Weather leakage | Weather + operational leakage |
|---|---:|---:|---:|
| Logistic regression | 0.2291 / 0.2776 | 0.2261 / 0.2777 | 0.9764 / 0.0389 |
| Random forest | 0.3509 / 0.2570 | 0.4286 / 0.2421 | 0.9710 / 0.0414 |

*Each cell reports AP / Brier. Higher AP and lower Brier are better.*

- **Finding:** Later weather improves random forest but slightly worsens logistic regression; adding operational leakage produces much larger apparent gains for both models.
- **Reserved test:** The 4,851 January 26–31 pilot test flights remain reserved and were not scored.
- **Minimum experiment:** The minimum viable experiment uses both models and these three conditions on a bounded sample (both time and location wise); nationwide destination integration remains planned.

## 6. Computing, access, fallback, and responsibilities — approximately 120–140 words

- **Verified access:** BTS January 2025 data, model scripts, shared metrics, Atlanta observation downloads, and pilot weather joins are verified.
- **Still to verify:** Remaining BTS/history downloads, nationwide station coverage, destination timing, publication availability, and full-scale resource use require verification.

- **Computing plan:** Use CPU-based R, bounded tuning, monthly processing, cached weather, and compact history summaries.
- **Sampling:** If needed, sample proportionally within month × origin airport × airline, preserving natural prevalence and matched flights.
- Check representativeness; weight unequal-probability samples appropriately.
- **Order of processing:** Calculate history before sampling model rows.
- **Fallbacks:** Fallbacks are 182-day history, smaller tuning/tree budgets, and a declared narrower airport scope.
- Forecasts remain an open option; weather leakage itself is core.

| Name | Responsibility |
|---|---|
| --NAME-- | Data cleaning, feature construction, sampling, and weather/time-availability joins |
| --NAME-- | Variable/interaction selection, tuning, and logistic/RF fitting |
| --NAME-- | Reserved 2026 evaluation, paired inference, and reporting |

## References to use

- STA2112, *Final Project Guidelines and Seed Questions*, Fall 2026, September 9, 2026; relevant lectures on legitimate information and evaluation.
- [BTS field documentation](https://www.transtats.bts.gov/Fields.asp?gnoyr_VQ=FGJ).
- [BTS monthly download archive](https://transtats.bts.gov/PREZIP/).
- [IEM METAR/ASOS observations and field definitions](https://mesonet.agron.iastate.edu/request/download.phtml).
- [IEM archived TAF forecasts](https://mesonet.agron.iastate.edu/request/taf.php): a future clean-weather option, not the current primary baseline.
- [National Weather Service weather-product documentation](https://aviationweather.gov/help/data/): observation/forecast interpretation.
- [U.S. federal holiday calendars](https://www.opm.gov/policy-data-oversight/pay-leave/federal-holidays/).
- [Chronological validation guidance](https://otexts.com/fpp3/tscv.html).
- [Statistics Canada sampling guidance](https://www150.statcan.gc.ca/n1/en/pub/12-587-x/12-587-x2003001-eng.pdf).
- [Average precision definition](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.average_precision_score.html): methodological reference; the pilot calculates AP in R.
- [Brier score definition](https://scikit-learn.org/stable/modules/model_evaluation.html#brier-score-loss): methodological reference for binary mean squared probability error; the pilot calculates Brier score in R.
- [ranger documentation](https://imbs-hl.github.io/ranger/reference/ranger.html).
- [glmnet documentation](https://glmnet.stanford.edu/articles/glmnet.html): penalized logistic regression, alpha/lambda tuning, and predictor standardization.
- [Feature-selection and preprocessing leakage guidance](https://scikit-learn.org/stable/common_pitfalls.html#data-leakage): methodological guidance applicable to the R workflow.
- Optional model-background reference: Probst, Wright, and Boulesteix (2019), [Hyperparameters and tuning strategies for random forest](https://arxiv.org/abs/1804.03515).


## Appendix: working notes and supporting evidence — exclude from the submitted two-page proposal

### A. Predictor construction and information timing

- **Predictor groups used in the pilot:**
- Scheduled information: `DayOfWeek`, scheduled departure minutes, `CRSElapsedTime`, and `Distance`.
- Unavailable information at prediction time: `DepDelay` and `TaxiOut`, added to the same clean predictors.
- Never include `ArrDel15` or direct encodings of arrival delay as predictors.

- Explain the feature-availability assumptions using BTS documentation.
- The archive is retrospective; treating recorded scheduled fields as known at the cutoff is an assumption to acknowledge.
- Airline and destination are downloaded but are not predictors in the current pilot.

- **Candidate predictors and feature construction:**
- **Raw and transformed fields:** audited airline, origin/destination airport, route, scheduled times, duration, distance, and weekday.
- Remove constant and redundant representations before selection.
- **Calendar:** categorical month, a U.S. federal-holiday indicator, and a predefined surrounding-holiday window derived from flight dates and an official calendar.
- Specify actual versus observed holiday dates.
- Month represents calendar variation, not direct control of climate; plausible geographic interactions may be investigated during development.
- **Historical delay rates:** construct rolling **365-day** rates for airline, origin–destination route, and airline–flight-number–route groups, using only eligible outcomes observable before each prediction cutoff.
- Include history counts and prespecify smoothing or broader-group fallbacks for sparse or new services.
- Use **182 days** as a computational fallback.
- Complete histories require approximately January 2024–June 2026 records; these additional records support features, not extra model-fitting periods.
- **Clean weather:** latest origin and destination observations available by the common cutoff, two hours before scheduled departure.
- Convert times to UTC, use backward matching with a maximum report age, and audit publication latency/corrections; observation time alone does not prove availability.
- Document the condition-specific precipitation definitions, wind units, accumulation intervals, trace values, and missing-data rules.
- The current clean model uses categorical intensity; both leakage models use `p01i` accumulated amounts in inches.
- The ASOS `p01i` field is accumulated precipitation, potentially including frozen precipitation, not an instantaneous rain-only rate; document this limitation if used.
- **Forecast option:** whether forecasts or pre-cutoff measurements should be the eventual clean weather representation remains open.
- Use pre-cutoff METAR/ASOS measurements for the current proposal design.
- Reassess forecasts during post-proposal development, before final testing, rather than conclude that they are generally inferior from the pilot.
- Eligible forecasts must be available by the same cutoff; origin and destination target times would be scheduled departure and arrival respectively.

### B. Comparison and metric implementation

- The current C-to-W comparison changes both weather timing and precipitation representation (clean intensity versus later `p01i` amount), so it does not isolate timing alone.
- W-to-WO holds weather fixed and adds operational information.
- A future timing-only sensitivity check would require the same precipitation representation at both times.
- Check that later reports occur after the prediction cutoff.
- Prespecify the destination leakage matching time before final evaluation, with scheduled arrival a candidate; actual arrival time is not a settled choice and would introduce an additional outcome-dependent matching mechanism.
- A secondary nested comparison may retain early weather and add later weather, but label it separately because it increases predictor count.

- For each paired feature comparison, use identical eligible flights, training dates, and evaluation dates.
- Before final model fitting and comparison, develop the clean models through variable selection and hyperparameter tuning using chronological development windows.
- Within each model, freeze selected non-weather predictors and prespecify condition-specific weather definitions before comparing conditions or adding operational leakage.
- Use comparable tuning rules and budgets across all three information conditions.
- Describe the latter condition as a constructed hindsight workflow; do not imply that it reproduces a published study unless a specific protocol is identified.

- **Primary metric:** Average precision (AP), computed using the same tie-aware function in `scripts/metrics.R` for every model.
- AP measures ranking and is not classification accuracy or trapezoidal PR-AUC.

- **Secondary metric:** Binary Brier score, calculated with the shared `calculate_brier_score(actual, probability)` helper in `scripts/metrics.R`: `mean((probability - actual)^2, na.rm = TRUE)`.
- Lower is better.
- It evaluates probability accuracy and reflects both calibration and discrimination, rather than calibration alone.
- Use numeric 0/1 outcomes and the same evaluation flights for every model.
- The simple helper omits missing squared errors; the current pilot has complete outcomes and probabilities, so its scores are unchanged.
- For future comparisons, use a common complete evaluation set.
- Log loss can remain an optional extension; it is not calculated in the current pilot.

- **Primary estimands, separately for each model:**
- Weather-information/representation contrast: `Delta_AP_weather = AP_W - AP_C`; do not attribute the full difference to timing alone.
- Additional operational leakage: `Delta_AP_operational = AP_WO - AP_W`.
- Total apparent gain: `Delta_AP_total = AP_WO - AP_C`.

- **Secondary estimands:** the corresponding Brier reductions, `Brier_C - Brier_W`, `Brier_W - Brier_WO`, and `Brier_C - Brier_WO`.
- Positive differences indicate improved apparent performance.
- These are paired predictive-performance contrasts, not causal estimates of weather effects.
- Report improvements or deterioration rather than assuming a monotonic increase across conditions.

- **Secondary comparison:** Does correcting information availability change the model ranking?
- Interpret small differences using uncertainty estimates.
- Boosting is optional and outside the minimum core study.

### C. Detailed chronological development and evaluation protocol

**Specify the design before final evaluation:**

- **Development: January–June 2025.** Use expanding chronological windows for variable selection, interaction assessment, and tuning.
- For a categorical month predictor, include earlier observations from the validation month in training: e.g., train through March 15 and validate March 16–31, then expand through April 15 and validate April 16–30.
- Continue into May and June; prespecify folds and handling of unseen airport/airline levels.
- Each validation window follows its training data.
- **Final fitting:** freeze feature definitions, selected terms, weather matching, missing-data rules, and tuning choices, then refit on the declared January–June 2025 development sample.
- **Final evaluation: January–June 2026.** Reserve outcomes from model selection and tuning.
- Generate predictions chronologically at the two-hour cutoff; fitting data and any outcome-based training features must respect outcome-availability times.
- **Sequential history updates:** model parameters remain fixed, while historical-rate features may update using earlier outcomes once observable.
- This prospective simulation can use earlier 2026 outcomes for later histories, but never the current/future outcome or test-based retuning.
- Data in intervening months are needed to maintain full rolling histories.

**Include:**

- **Variable selection:** Compare the full audited clean pool with parsimonious predictor-group subsets.
- Learn data-driven selection inside each training window and use its subsequent validation period to choose subsets; never select using the final test outcomes.
- **Interaction investigation:** assess a limited, flight-operation-motivated set, such as month × location/region or holiday timing × location.
- Logistic regression requires explicit candidate interaction terms, retaining their main effects; random forest can learn interactions through tree splits.
- Selection alone does not automatically generate logistic interactions.
- Evaluate these choices inside development windows rather than searching all combinations.
- **Scaling:** Standardize numerical predictors for penalized logistic regression using each training window's means and standard deviations, applied unchanged to its validation data.
- Encode categorical variables appropriately.
- Scaling is not generally required for the current unpenalized logistic model or random forest; random-forest predictors will retain their original numerical scales.
- **Logistic tuning:** Retain the existing unpenalized logistic regression as a reference and consider a lasso/elastic-net extension, tuning penalty strength (lambda) and mixing (alpha) over a bounded grid.
- Ordinary glm() coefficient estimation is model fitting, not hyperparameter tuning.
- **Random-forest tuning:** Tune predictors considered at each split (mtry), node size, and possibly tree depth; bound the number of trees for feasible computation.
- Record candidate settings, seeds, and budgets.
- Use AP as the primary selection criterion and report Brier score as a secondary diagnostic.
- Predefine a tie rule and avoid choosing whichever metric happens to favour a candidate.
- Fit all learned preprocessing, including scaling and selection, within the training portion of each chronological window.
- After choices are frozen, refit on the declared development data and apply the resulting transformations to the untouched final period.
- Evaluate all three conditions on exactly the same final flights.
- Prespecify missing-weather handling rather than dropping different flights by condition; estimate learned imputations from training data only.
- Report pooled and monthly delay prevalence, AP, and Brier score.
- Pooled AP must be computed from pooled predictions, not by averaging monthly AP.
- Report the same metrics for development windows.
- Use a constant-probability reference estimated from the training outcomes only; do not fit the reference probability to validation or test outcomes.
- Estimate uncertainty in AP and Brier-score differences with paired resampling of test dates.
- State that this addresses variation across evaluation dates, conditional on fitted models; it does not capture all training uncertainty.
- Consider longer blocks if dependence across dates is material.
- Use additional chronological development windows to assess sensitivity to time periods, keeping final evaluation separate.

- If retained, random-split evaluation is a separate diagnostic.
- Do not combine feature removal and split changes into one comparison and attribute the full difference to either factor.

### D. Supporting pilot tables and interpretation

- **Completed pilot:** January 2025 Atlanta departures; 22,580 eligible flights.
- All training and validation flights remain under the shared complete-case mask.

| Pilot set | Dates | Flights | Delay rate |
|---|---|---:|---:|
| Training | January 1–20 | 14,093 | 24.52% |
| Validation | January 21–25 | 3,636 | 33.55% |
| Reserved pilot test | January 26–31 | 4,851 | 11.79% |

- **Current weather definitions:** origin wind in knots for all conditions.
- Clean precipitation remains unordered METAR intensity (none/light/moderate/heavy), including snow and other supported falling precipitation.
- For both leakage conditions, **Precipitation amount:** IEM’s `p01i`, measured in inches accumulated since the previous hourly precipitation reset—not categorical intensity.
- Special-report accumulation windows can be shorter than an hour; the amount can include frozen precipitation and is not an instantaneous rain-only rate.
- Trace values retain the existing 0.0001-inch encoding, not a measured trace amount.

- C uses early wind/intensity; W uses later wind/amount near scheduled departure; WO adds `DepDelay` and `TaxiOut` to W.
- The same non-weather predictors and flight rows are used throughout, but C-to-W changes precipitation representation as well as timing.
- W-to-WO holds weather fixed.

| Model | Condition | AP (higher is better) | Brier (lower is better) |
|---|---|---:|---:|
| Constant reference | Training delay prevalence | 0.3355 | 0.2311 |
| Logistic regression | Clean early weather (C) | 0.2291 | 0.2776 |
| Logistic regression | Later weather (W) | 0.2261 | 0.2777 |
| Logistic regression | Later weather + operational leakage (WO) | 0.9764 | 0.0389 |
| Random forest | Clean early weather (C) | 0.3509 | 0.2570 |
| Random forest | Later weather (W) | 0.4286 | 0.2421 |
| Random forest | Later weather + operational leakage (WO) | 0.9710 | 0.0414 |

- **Paired apparent performance changes:** positive values indicate better apparent performance; negative values indicate deterioration.

| Model | Comparison | AP gain | Brier reduction |
|---|---|---:|---:|
| Logistic regression | clean -> weather_leakage | -0.0031 | -0.0001 |
| Logistic regression | weather_leakage -> leakage | +0.7503 | +0.2388 |
| Logistic regression | clean -> leakage | +0.7472 | +0.2387 |
| Random forest | clean -> weather_leakage | +0.0777 | +0.0148 |
| Random forest | weather_leakage -> leakage | +0.5424 | +0.2007 |
| Random forest | clean -> leakage | +0.6201 | +0.2155 |

- The clean random forest exceeds the constant reference on AP (0.3509 versus 0.3355), while clean logistic regression does not (0.2291).
- Both clean models have larger Brier error than the constant reference (0.2311).
- The later-amount weather condition improves random forest AP and Brier, but slightly worsens both metrics for logistic regression.
- Operational leakage gives a much larger gain.
- The C-to-W difference cannot be attributed solely to timing because the precipitation representation changes too; none of these results estimates a causal weather effect.

- Origin-only integration is verified; destination and nationwide matching remain later work.
- Later reports were 0–59 minutes before scheduled departure and 61–120 minutes after cutoff.
- Historical publication/receipt times and corrections remain availability assumptions.
- Do not mix the current mixed-representation results with earlier all-intensity, all-amount, or forecast experiments.
- The pilot test was not predicted or scored.

- The minimum experiment uses a bounded sample, both model families, and three conditions.
- The intended full study expands to nationwide origin and destination weather and paired uncertainty.
- Keep only a brief pilot summary in the submitted two-page proposal; these detailed tables are supporting material.

- **Reproducible workflow:** `source("scripts/run_pilot.R")` from the RStudio project root.
- To regenerate tables without refitting, use `source("scripts/04_proposal_results.R")`.

- **Current proposal artifacts:**
- `results/pilot/proposal_comparison.md`: readable comparison.
- `results/pilot/proposal_validation_results.csv`: full-precision AP/Brier scores.
- `results/pilot/proposal_performance_changes.csv`: paired changes.
- `results/pilot/proposal_validation_predictions.csv`: common flight IDs and probabilities.
- `results/pilot/proposal_models.rds`: both model families and fitted specifications.

- Earlier scripts, diagnostics, and result files are preserved under the dated `archive/proposal_cleanup_*` directory and are not required for the current proposal workflow.

### E. Detailed access, computing, and task allocation

- **Access already verified:**
- January 2025 data downloaded and processed.
- Logistic-regression and random-forest scripts ran in the team's RStudio project.
- Shared AP calculation and saved model/result files are available.
- IEM Atlanta observation downloads for January–June 2025 and 2026 and pilot weather/model joins succeeded; pilot archived TAF access also succeeded.
- Nationwide destination coverage has not yet been verified.
- The repository now contains the integrated observed-weather pilot workflow, paired AP/Brier tables, fitted models, and shared validation predictions.
- Separate forecast experiments remain development options outside this primary workflow.

- **Still to verify:** remaining BTS development, evaluation, and 365-day history files; nationwide origin/destination weather coverage; airport–station/timezone mapping; report availability and correction handling; missingness; destination leakage matching time; package versions; execution on teammates' computers; full-study runtime and memory.

- **Computing plan:** R on an available CPU laptop, using base R and `ranger`; `glmnet` is a planned dependency if the penalized logistic extension is adopted and its installation must be verified.
- Use bounded selection and tuning searches.
- Record versions, seeds, runtime, and relevant resource limits.
- Process historical records and station reports in batches, retaining only needed fields and compact group summaries; calculate historical rates from full available past records before sampling modeling rows.
- Cache airport weather once and reuse it across flights.
- Benchmark time and memory before fixing sample size.
- No GPU or paid API is planned.

- **Sampling and fallback:** first reduce model-fitting cost through proportional random sampling within month × origin airport × airline groups, after chronological periods are defined.
- Preserve natural delay prevalence and identical sampled flights across conditions.
- Prefer full or fixed representative evaluation samples with batched prediction; use inclusion-probability weights for population evaluation and appropriate training weights if rare groups are deliberately oversampled.
- Check sample composition and development-seed sensitivity.
- If necessary, shorten histories from 365 to 182 days, reduce tuning/tree budgets, or declare a narrower airport scope.
- Weather leakage remains a core investigation; forecasts and extra aircraft-history joins are optional extensions.

- **Responsibilities:**

| Name | Part | Detail |
|---|---|---|
|--NAME--|Data Cleaning & Preprocessing|Audit eligibility and information timing; build holiday/history features, airport–station/timezone mappings, and origin/destination weather joins; document sampling and missingness.|
|--NAME--| Model Training - Logistic Regression & Random Forest | Audit candidate subsets with the preprocessing member, assess plausible interactions, perform chronological selection/tuning, and fit the three conditions under documented budgets. |
|--NAME--| Evaluation & Inference| Prespecify paired AP/Brier comparisons and uncertainty, evaluate January–June 2026 after choices are frozen, and report pooled/monthly results and limitations without test-based tuning. |
