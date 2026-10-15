---
output:
  html_document: default
---
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

## 5. Minimum viable experiment

We conducted a preliminary experiment using flights departing from Atlanta in 
January 2025. Model fitting uses 14,093 flights from January 1 to 20 and the performance
was evaluated on 3,636 validation flights from January 21 to 25. The test set contains 
4,851 flights from January 26 to 31, which have remained untouched. Weather observations 
were matched to the corresponding flights at the departure airport.

The preliminary validation results and their interpretation are provided in Appendix A. 
The completed data matching, model fitting, and evaluation demonstrates the feasibility 
of our proposed experiment.

The minimum viable experiment compares both models under the three information 
conditions using a sample limited in time and geographic coverage. The full study 
will expand coverage to IEM-covered airports across the United States and include 
weather conditions at destination airports.

## 6. Computing requirements and verified access to data and code

We will use R and the `ranger` package on a CPU-based laptop. Data will be downloaded
and processed in a month unit.

Access to the required BTS monthly files has been verified, and IEM weather data 
have been verified for selected airports. The preliminary analysis has confirmed 
that flight and weather data can be combined for model fitting. Information availability, 
and computing requirements, including runtime and memory use, will be checked further 
upon the full study.

## 7. Fallback and responsibilities

If computing limits require sampling, we will sample proportionally within each 
month and origin airport. Sample coverage will be checked, and weights will be 
applied if flights have unequal selection probabilities. Further fallbacks include 
shortening historical-delay-rate windows from 365 to 182 days and reducing tuning 
or tree budgets. Forecast data are an option for investigating the association 
between weather and flight delays.

Responsibilities will be divided as follows:

\newpage

## References to use

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

\newpage

## Appendix A. Preliminary pilot results

Table A1 presents the results of the untuned models on the same 3,636 validation 
flights departing from Atlanta from January 21 to 25, 2025. The January 26–31 
test set was not evaluated.

**Table A1. Pilot validation performance under three information conditions.**

| Model | Clean | Weather leakage only | Weather + operational leakage |
|---|---:|---:|---:|
| Logistic regression | 0.2291 / 0.2776 | 0.2261 / 0.2777 | 0.9764 / 0.0389 |
| Random forest | 0.3509 / 0.2570 | 0.4286 / 0.2421 | 0.9710 / 0.0414 |

*Each cell reports AP / Brier, where higher AP and lower Brier indicate better performance.*

The weather-leakage condition improved random forest performance but produced little 
change in logistic regression performance. Adding departure delay and taxi-out 
duration produced much larger apparent gains for both models.
