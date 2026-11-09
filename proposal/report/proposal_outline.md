---
output:
  pdf_document:
    latex_engine: pdflatex
    keep_tex: false
bibliography: references.bib
link-citations: true
fontsize: 10pt
geometry: margin=0.7in
colorlinks: true
linkcolor: black
urlcolor: blue
header-includes:
  - |
      \makeatletter
      \renewcommand{\section}{\@startsection{section}{1}{0pt}{8pt}{7pt}{\Large\bfseries}}
      \renewcommand{\subsection}{\@startsection{subsection}{2}{0pt}{9pt}{4pt}{\large\bfseries}}
      \renewcommand{\subsubsection}{\@startsection{subsubsection}{3}{0pt}{5pt}{2pt}{\normalsize\bfseries}}
      \makeatother
  - \setlength{\parindent}{0pt}
  - \setlength{\parskip}{4pt}
---

# Data leakage in flight-delay prediction

*Channing Liu, Coco Liu, and Xinnan Zhao*

**How much does including information unavailable two hours before scheduled departure change the measured performance of models predicting arrival delays of at least 15 minutes?**

\noindent\rule{\linewidth}{0.4pt}

## 1. Data and background

Advance flight-delay predictions support travel planning and airline decisions. Wu et al. [-@wu2022] used XGBoost to study flight and weather predictors, identifying departure time, carrier, and precipitation as important predictors. Our study focuses on predictions made two hours before scheduled departure. We compare models restricted to information available at this cutoff with models that deliberately include later information, to assess how input availability changes measured performance.

### Data sources

- **BTS Reporting Carrier On-Time Performance:** Provides flight information,  including flight dates, airlines, origin and destination airports,  scheduled departure and arrival times, distance, and arrival-delay outcomes [@btsfields; @btsarchive].
- **Iowa Environmental Mesonet (IEM) METAR/ASOS archive:** Provides airport-level  weather observations, including wind speed and precipitation, matched to flight  records by location and time [@iem].

### Full-study scope

We study completed, non-diverted U.S. domestic BTS flights with observed outcomes and weather at both airports. Development uses January–June 2025; testing uses July–September 2025. Results are conditional on flight completion and exclude cancellation and diversion risk.

### Data structure

The outcome is `ArrDel15`, indicating arrival at least 15 minutes late, predicted two hours before scheduled departure. Candidate predictors include scheduled departure time and duration, distance, carrier, airports, weekday, weather, holidays, and historical delay rates.

## 2. Proposed comparison and primary estimands

We will compare logistic regression and random forest under the three information conditions below.

| Condition | Weather and operational information |
|---------------|------------------------------------------------------------|
| Clean (C) | Information on wind speed and precipitation at the takeoff and landing sites that is available before the cutoff; operational information that is available before the cutoff.|
| Weather leakage (W) |  Includes subsequent wind speed measurements and cumulative precipitation values close to the planned takeoff time based on feature set C.|
| Weather + operational leakage (WO) | Based on feature set W, further includes unavailable operational information such as `DepDelay` (departure delay) and `TaxiOut` (taxiing time) |

- **Primary metric:** Average Precision (AP) summarizes precision across prediction thresholds, weighted by the corresponding increases in sensitivity. It measures how well the model ranks delayed flights above on-time flights and is useful when the outcome classes are imbalanced. *Higher AP indicates better model performance.* [@averageprecision]
- **Secondary metric:** The Brier score is the mean squared error between the predicted probability and the actual binary observation. It is introduced to measure the accuracy and calibration of the model's output probability. *A lower Brier score reflects better model performance.* [@brierscore]
- **Primary estimands:** For each model, estimate $\mathrm{AP}(W)-\mathrm{AP}(C)$ and $\mathrm{AP}(WO)-\mathrm{AP}(C)$ on the same eligible test flights. Positive differences indicate higher apparent performance.

## 3. Evaluation plan

- **Data Split:** The fixed chronological split will use January–April 2025 for training and May–June for validation; July–September remains untouched for final evaluation.
- **Model Development and Control:** Fit preprocessing and perform variable selection using training data only. Use validation data for budget-capped tuning of both models. Freeze predictor sets and tuning settings before refitting on January–June. Clean predictors must be available two hours before scheduled departure.
- **Paired comparison:** The clean (C), weather leakage (W), and weather and operational leakage (WO) conditions must be paired and evaluated on the same test flights using equivalent parameter tuning budgets.
- **Evaluation:** Assess AP and Brier score, and report the delay rate and a constant probability reference benchmark based on the development set.
- **Uncertainty:** We will estimate 95% confidence intervals for paired performance differences by resampling test dates, using longer date blocks if needed to account for temporal dependence. Models will remain fixed during resampling.
- **Interpretation:** We will report the size and uncertainty of each performance change. Because leaked information is not available two hours before departure, any gain it produces reflects inflated evaluation, not better real-world prediction.

## 4. Minimum viable experiment

The Atlanta January 2025 pilot used 14,093 training flights (January 1–20), 3,636 validation flights (January 21–25), and 4,851 reserved test flights (January 26–31). Origin weather was matched to each flight; the test set remains unevaluated.

The pipeline runs end to end; results are in the Appendix. The validation delay rate (33.55%) exceeded the training rate (24.52%). Both clean models had higher Brier scores than the constant reference, and clean logistic regression had AP below the delay rate. We will investigate calibration and January weather disruptions before the midway checkpoint.

The minimum viable experiment compares both models under the three information conditions using a sample limited in time and geographic coverage. The full study will expand coverage to IEM-covered airports across the United States and include weather conditions at destination airports.

## 5. Computing requirements and verified access to data and code

We will use R and the `ranger` package on a CPU-based laptop [@ranger2017]. Data will be downloaded and processed month by month.

Access to the required BTS monthly files has been verified, and IEM weather data have been verified for selected airports. The preliminary analysis has confirmed that flight and weather data can be combined for model fitting. Information availability and computing requirements, including runtime and memory use, will be checked further in the full study.

## 6. Fallback and responsibilities

If computing limits require sampling, we will sample proportionally within each month and origin airport. Sample coverage will be checked, and weights will be applied if flights have unequal selection probabilities. Further fallbacks include shortening historical-delay-rate windows from 365 to 182 days and reducing tuning or tree budgets. Forecast data are an option for investigating the association between weather and flight delays.

Responsibilities will be divided as follows:

| Name | Responsibilities |
|---------------|------------------------------------------------------------|
| Xinnan Zhao | Academic literature review; proposal and final report writing; presentation preparation. |
| Channing Liu | Data collection and access checks; data cleaning and feature construction; code organization and reproducibility checks. |
| Coco Liu | Model fitting and tuning; performance evaluation and uncertainty analysis; results interpretation and visualization. |

\newpage

## References

::: {#refs}
:::

\newpage

## Appendix: Preliminary pilot results

Table 1 presents the results of the untuned models on the same 3,636 validation flights departing from Atlanta from January 21 to 25, 2025. The January 26–31 test set was not evaluated.

**Table 1. Pilot validation performance under three information conditions.**

| Model | Clean | Weather leakage only | Weather + operational leakage |
|---|---:|---:|---:|
| Constant reference | 0.3355 / 0.2311 | 0.3355 / 0.2311 | 0.3355 / 0.2311 |
| Logistic regression | 0.2291 / 0.2776 | 0.2261 / 0.2777 | 0.9764 / 0.0389 |
| Random forest | 0.3509 / 0.2570 | 0.4286 / 0.2421 | 0.9710 / 0.0414 |

*Each cell reports AP / Brier, where higher AP and lower Brier indicate better performance.*

The constant reference predicts the training delay rate (24.52%) for every validation flight. Its AP equals the validation delay rate (33.55%); the same benchmark applies to all three conditions. The shift in delay rate coincides with winter storms in Atlanta on January 10–11 (training window) and January 21 (validation window).

The clean random forest slightly exceeded the reference AP, while clean logistic regression fell below it. Both clean models had higher Brier scores, indicating less accurate probability predictions.

The weather-leakage condition improved random forest performance but produced little change in logistic regression performance. Adding departure delay and taxi-out duration produced much larger apparent gains for both models.
