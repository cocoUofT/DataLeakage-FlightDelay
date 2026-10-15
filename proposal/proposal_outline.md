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
This project will use two models and three feature conditions for comparison.

- **Model Selection:** Logistic regression and Random forest
- **Feature conditions:** "Clean condition," which only contains planning information, and "Deliberate leakage condition," which adds unavailable information. The "deliberate leakage condition" includes two levels: weather leakage and weather + operational leakage.

| Condition | Weather and operational information |
|---|---|
| Clean (C) | Information on wind direction/speed and precipitation at the takeoff and landing sites that is available before the cutoff; operational information that is available before the cutoff.|
| Weather leakage (W) |  Includes subsequent wind direction/speed measurements and cumulative precipitation values ​​close to the planned takeoff time based on feature set C.|
| Weather + operational leakage (WO) | Based on feature set W, further includes unavailable operational information such as `DepDelay`(departure delay) and `TaxiOut`(taxiing time) |

- **Primary metric:** Average Precision (AP): AP summarizes the area under the precision-recall curve (PR curve) at different thresholds, which can comprehensively evaluate the predictive performance of the model when dealing with imbalanced data (such as flight delays). *Higher AP indicates better model performance.*
- **Secondary metric:** Brier score: The Brier score is the mean squared error between the predicted probability and the actual binary observation. It is introduced to measure the accuracy and calibration of the model's output probability. *A lower Brier score reflects better model performance.*
- **The primary estimand is the difference in performance between the leakage conditions and the clean condition**
  
  `Delta_AP = AP_leakage - AP_clean`.


## 4. Evaluation plan 

**Data Split:**
To ensure a robust and realistic assessment, we will implement a chronological data split prior to the final evaluation. The proposed annual allocation for the 2025 flight data is:
*   **Training:** Jan.–Aug.
*   **Validation & Model Selection:** Sep.–Oct.
*   **Untouched Final Evaluation:** Nov.–Dec.

**Model Development and Control:**
Use only development data for preprocessing fitting (e.g. standardization) and budget-capped hyperparameter tuning. All configurations must be frozen before testing, and clean condition (C) features must be strictly limited to 2 hours before takeoff.

**Paired comparison:** The clean (C), weather leakage (W), and weather and operational leakage (WO) conditions must be paired and evaluated on the same test flights using equivalent parameter tuning budgets.

**Evaluation:** Assess AP and Brier score and report the delay rate and a constant probability reference benchmark based on the training set.

**Uncertainty:**
Perform paired resampling for the test date to estimate paired confidence intervals for performance metric differences. If the time dependency between dates is significant, longer time blocks will be considered for resampling. It's important to clarify that this method primarily addresses the variation in results caused by different evaluation dates (based on a fixed-fit model), but it does not cover all training uncertainties.

**Interpretation:**
When we compare clean (C) and weather leakage (W), both time and the standards for measuring the weather have changed; both factors influence the process, so we cannot assert that the model improvement is because of time. To compensate for the inaccuracies above, we further introduce weather and operational leakage (WO) to compare W and WO. In this case, weather conditions are frozen, making the operation conditions the only factor influencing the model. In this way, any difference in the accuracy of the two predictions can be attributed entirely to the "leakage of operational information." This is a very elegant and rigorous step in scientific experiments.


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
