# Midway results: validation (May–Jun 2025)

Flights: 83,227 validation (delay rate 0.281); trained on Jan–Apr 2025. Same flights in every condition.

**Table 1. AP / Brier by model and information condition** (AP higher is better; Brier lower is better).

| Model | C | W | WO |
|---|---|---|---|
| Constant reference | 0.281 / 0.208 | 0.281 / 0.208 | 0.281 / 0.208 |
| Logistic regression (all predictors) | 0.461 / 0.189 | 0.483 / 0.186 | 0.922 / 0.064 |
| Logistic regression (lasso-selected) | 0.461 / 0.186 | 0.479 / 0.184 | 0.918 / 0.066 |
| Random forest | 0.463 / 0.185 | 0.489 / 0.182 | 0.913 / 0.073 |

**Table 2. Paired apparent gains** (1000 bootstrap reps resampling validation days; 7-day moving blocks as a dependence check).

| Model | Contrast | AP gain [95% CI, 1-day blocks] | [7-day blocks] | Brier reduction [95% CI] |
|---|---|---|---|---|
| Logistic regression (all predictors) | W - C | 0.022 [0.016, 0.027] | [0.016, 0.027] | 0.0030 [0.0022, 0.0039] |
| Logistic regression (all predictors) | WO - C | 0.461 [0.435, 0.486] | [0.440, 0.486] | 0.1250 [0.1186, 0.1314] |
| Logistic regression (all predictors) | WO - W | 0.439 [0.413, 0.465] | [0.417, 0.463] | 0.1219 [0.1155, 0.1285] |
| Logistic regression (lasso-selected) | W - C | 0.017 [0.012, 0.022] | [0.012, 0.023] | 0.0022 [0.0015, 0.0030] |
| Logistic regression (lasso-selected) | WO - C | 0.457 [0.433, 0.482] | [0.437, 0.482] | 0.1204 [0.1145, 0.1263] |
| Logistic regression (lasso-selected) | WO - W | 0.440 [0.414, 0.466] | [0.419, 0.465] | 0.1182 [0.1122, 0.1241] |
| Random forest | W - C | 0.025 [0.019, 0.031] | [0.021, 0.029] | 0.0027 [0.0020, 0.0035] |
| Random forest | WO - C | 0.449 [0.425, 0.475] | [0.430, 0.474] | 0.1122 [0.1081, 0.1165] |
| Random forest | WO - W | 0.424 [0.397, 0.452] | [0.404, 0.450] | 0.1095 [0.1055, 0.1136] |

Interpretation: gains are apparent improvements from information unavailable two hours before departure,
specific to these fitted models and this evaluation period; they are not better real-world prediction.
