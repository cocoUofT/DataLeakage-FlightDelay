# Midway results: validation (May–Jun 2025)

Flights: 83,227 validation (delay rate 0.281); trained on Jan–Apr 2025. Same flights in every condition.

**Table 1A. Average Precision (AP) by model and information condition** (higher is better).

| Model | C | W | WO |
|---|---|---|---|
| Constant reference | 0.281 | 0.281 | 0.281 |
| Logistic regression (all predictors) | 0.472 | 0.493 | 0.922 |
| Logistic regression (lasso-selected) | 0.472 | 0.490 | 0.918 |
| Random forest | 0.463 | 0.488 | 0.912 |

**Table 1B. Brier Score by model and information condition** (lower is better).

| Model | C | W | WO |
|---|---|---|---|
| Constant reference | 0.208 | 0.208 | 0.208 |
| Logistic regression (all predictors) | 0.185 | 0.182 | 0.064 |
| Logistic regression (lasso-selected) | 0.183 | 0.181 | 0.066 |
| Random forest | 0.185 | 0.183 | 0.074 |

**Table 2. Paired apparent gains** (1000 bootstrap reps resampling validation days; 7-day moving blocks as a dependence check).

| Model | Contrast | AP gain [95% CI, 1-day blocks] | [7-day blocks] | Brier reduction [95% CI] |
|---|---|---|---|---|
| Logistic regression (all predictors) | W - C | 0.021 [0.015, 0.027] | [0.015, 0.027] | 0.0028 [0.0020, 0.0036] |
| Logistic regression (all predictors) | WO - C | 0.450 [0.425, 0.476] | [0.432, 0.476] | 0.1212 [0.1157, 0.1267] |
| Logistic regression (all predictors) | WO - W | 0.429 [0.403, 0.455] | [0.410, 0.453] | 0.1184 [0.1129, 0.1240] |
| Logistic regression (lasso-selected) | W - C | 0.019 [0.013, 0.024] | [0.013, 0.024] | 0.0024 [0.0015, 0.0032] |
| Logistic regression (lasso-selected) | WO - C | 0.447 [0.424, 0.471] | [0.429, 0.473] | 0.1171 [0.1121, 0.1221] |
| Logistic regression (lasso-selected) | WO - W | 0.428 [0.404, 0.453] | [0.410, 0.453] | 0.1147 [0.1095, 0.1199] |
| Random forest | W - C | 0.025 [0.019, 0.032] | [0.020, 0.030] | 0.0024 [0.0018, 0.0032] |
| Random forest | WO - C | 0.449 [0.425, 0.474] | [0.430, 0.475] | 0.1119 [0.1079, 0.1159] |
| Random forest | WO - W | 0.424 [0.398, 0.451] | [0.404, 0.450] | 0.1094 [0.1055, 0.1134] |

**Table 3. Impact of Weather Leakage Across Different Weather Subgroups (W vs. C)**
*(Highlights how leakage severity varies by meteorological conditions)*

| weather_group | n_flights | delay_rate | AP_C | AP_W | Diff_W_minus_C | CI_Lower | CI_Upper |
|---|---|---|---|---|---|---|---|
| Good Weather | 74096 | 0.2572743 | 0.4165636 | 0.4166023 | 3.862944e-05 | -0.002126681 | 0.001991555 |
| Severe Weather |  9131 | 0.4692805 | 0.6486919 | 0.7069127 | 5.822080e-02 |  0.044444349 | 0.074456866 |

Interpretation: gains are apparent improvements from information unavailable two hours before departure,
specific to these fitted models and this evaluation period; they are not better real-world prediction.
