# Final study (extension): prediction time and aircraft rotation — validation May–Jun 2025 — all flights

n = 82,883 validation flights (delay rate 0.280), identical at every prediction time. Bootstrap: 1000 reps over validation days.

**AP [95% CI] by prediction time**

| horizon | Logistic regression base | Logistic regression prev1 | Logistic regression rotation | Random forest base | Random forest prev1 | Random forest rotation |
|---|---|---|---|---|---|---|
| 12 h | 0.427 [0.392, 0.460] | 0.459 [0.429, 0.488] | 0.475 [0.446, 0.503] | 0.417 [0.385, 0.448] | 0.481 [0.454, 0.508] | 0.488 [0.461, 0.514] |
| 6 h | 0.427 [0.396, 0.458] | 0.463 [0.436, 0.491] | 0.491 [0.465, 0.517] | 0.437 [0.406, 0.470] | 0.496 [0.469, 0.522] | 0.514 [0.488, 0.539] |
| 4 h | 0.442 [0.411, 0.474] | 0.515 [0.487, 0.544] | 0.536 [0.509, 0.562] | 0.458 [0.427, 0.492] | 0.546 [0.519, 0.574] | 0.561 [0.536, 0.587] |
| 2 h | 0.472 [0.439, 0.505] | 0.628 [0.602, 0.651] | 0.628 [0.602, 0.651] | 0.483 [0.451, 0.516] | 0.637 [0.613, 0.659] | 0.640 [0.616, 0.662] |
| 1 h | 0.494 [0.461, 0.526] | 0.669 [0.646, 0.692] | 0.669 [0.646, 0.691] | 0.498 [0.467, 0.532] | 0.673 [0.649, 0.694] | 0.672 [0.648, 0.694] |
| 30 min | 0.506 [0.474, 0.539] | 0.681 [0.658, 0.704] | 0.681 [0.658, 0.703] | 0.508 [0.476, 0.542] | 0.693 [0.670, 0.713] | 0.693 [0.671, 0.714] |

**Paired differences in AP [95% CI]**

| comparison | model | horizon | cell |
|---|---|---|---|
| rotation - base | Logistic regression | 12 h | 0.049 [0.041, 0.056] |
| rotation - base | Logistic regression | 6 h | 0.064 [0.056, 0.071] |
| rotation - base | Logistic regression | 4 h | 0.094 [0.085, 0.103] |
| rotation - base | Logistic regression | 2 h | 0.156 [0.143, 0.168] |
| rotation - base | Logistic regression | 1 h | 0.175 [0.161, 0.189] |
| rotation - base | Logistic regression | 30 min | 0.175 [0.161, 0.189] |
| rotation - base | Random forest | 12 h | 0.071 [0.062, 0.080] |
| rotation - base | Random forest | 6 h | 0.077 [0.067, 0.086] |
| rotation - base | Random forest | 4 h | 0.103 [0.092, 0.114] |
| rotation - base | Random forest | 2 h | 0.157 [0.143, 0.171] |
| rotation - base | Random forest | 1 h | 0.173 [0.158, 0.189] |
| rotation - base | Random forest | 30 min | 0.185 [0.169, 0.201] |
| prev1 - base | Logistic regression | 12 h | 0.032 [0.026, 0.038] |
| prev1 - base | Logistic regression | 6 h | 0.037 [0.031, 0.042] |
| prev1 - base | Logistic regression | 4 h | 0.074 [0.066, 0.081] |
| prev1 - base | Logistic regression | 2 h | 0.155 [0.142, 0.168] |
| prev1 - base | Logistic regression | 1 h | 0.175 [0.161, 0.189] |
| prev1 - base | Logistic regression | 30 min | 0.176 [0.161, 0.189] |
| prev1 - base | Random forest | 12 h | 0.064 [0.055, 0.071] |
| prev1 - base | Random forest | 6 h | 0.059 [0.051, 0.066] |
| prev1 - base | Random forest | 4 h | 0.088 [0.079, 0.097] |
| prev1 - base | Random forest | 2 h | 0.154 [0.140, 0.168] |
| prev1 - base | Random forest | 1 h | 0.175 [0.159, 0.190] |
| prev1 - base | Random forest | 30 min | 0.184 [0.168, 0.201] |
| rotation - prev1 | Logistic regression | 12 h | 0.016 [0.014, 0.019] |
| rotation - prev1 | Logistic regression | 6 h | 0.028 [0.024, 0.032] |
| rotation - prev1 | Logistic regression | 4 h | 0.020 [0.017, 0.024] |
| rotation - prev1 | Logistic regression | 2 h | 0.000 [-0.000, 0.001] |
| rotation - prev1 | Logistic regression | 1 h | -0.000 [-0.000, -0.000] |
| rotation - prev1 | Logistic regression | 30 min | -0.000 [-0.000, 0.000] |
| rotation - prev1 | Random forest | 12 h | 0.007 [0.005, 0.010] |
| rotation - prev1 | Random forest | 6 h | 0.018 [0.014, 0.021] |
| rotation - prev1 | Random forest | 4 h | 0.015 [0.011, 0.019] |
| rotation - prev1 | Random forest | 2 h | 0.003 [0.001, 0.005] |
| rotation - prev1 | Random forest | 1 h | -0.001 [-0.002, -0.001] |
| rotation - prev1 | Random forest | 30 min | 0.000 [-0.000, 0.001] |
| horizon - 2h (rotation) | Logistic regression | 12 h | -0.152 [-0.165, -0.140] |
| horizon - 2h (rotation) | Logistic regression | 6 h | -0.137 [-0.143, -0.130] |
| horizon - 2h (rotation) | Logistic regression | 4 h | -0.092 [-0.097, -0.087] |
| horizon - 2h (rotation) | Logistic regression | 1 h | 0.041 [0.037, 0.045] |
| horizon - 2h (rotation) | Logistic regression | 30 min | 0.053 [0.049, 0.058] |
| horizon - 2h (rotation) | Random forest | 12 h | -0.152 [-0.161, -0.142] |
| horizon - 2h (rotation) | Random forest | 6 h | -0.126 [-0.132, -0.119] |
| horizon - 2h (rotation) | Random forest | 4 h | -0.079 [-0.084, -0.073] |
| horizon - 2h (rotation) | Random forest | 1 h | 0.032 [0.029, 0.034] |
| horizon - 2h (rotation) | Random forest | 30 min | 0.053 [0.049, 0.057] |
| oracle - rotation (2h) | Logistic regression | 2 h | 0.044 [0.041, 0.048] |
| oracle - rotation (2h) | Random forest | 2 h | 0.046 [0.042, 0.050] |

**Brier [95% CI] by prediction time** (constant reference = training delay rate: 0.2079)

| horizon | Logistic regression base | Logistic regression prev1 | Logistic regression rotation | Random forest base | Random forest prev1 | Random forest rotation |
|---|---|---|---|---|---|---|
| 12 h | 0.1890 [0.1816, 0.1973] | 0.1853 [0.1777, 0.1935] | 0.1835 [0.1760, 0.1917] | 0.1905 [0.1836, 0.1979] | 0.1846 [0.1777, 0.1921] | 0.1835 [0.1765, 0.1910] |
| 6 h | 0.1891 [0.1817, 0.1973] | 0.1849 [0.1775, 0.1930] | 0.1818 [0.1745, 0.1900] | 0.1890 [0.1821, 0.1966] | 0.1828 [0.1760, 0.1904] | 0.1804 [0.1736, 0.1879] |
| 4 h | 0.1884 [0.1808, 0.1963] | 0.1785 [0.1713, 0.1863] | 0.1760 [0.1688, 0.1837] | 0.1869 [0.1803, 0.1942] | 0.1765 [0.1701, 0.1835] | 0.1738 [0.1675, 0.1808] |
| 2 h | 0.1846 [0.1774, 0.1921] | 0.1590 [0.1530, 0.1656] | 0.1590 [0.1531, 0.1656] | 0.1841 [0.1776, 0.1912] | 0.1582 [0.1526, 0.1643] | 0.1587 [0.1530, 0.1649] |
| 1 h | 0.1813 [0.1744, 0.1883] | 0.1498 [0.1446, 0.1558] | 0.1499 [0.1446, 0.1559] | 0.1824 [0.1760, 0.1891] | 0.1513 [0.1463, 0.1569] | 0.1515 [0.1466, 0.1572] |
| 30 min | 0.1796 [0.1729, 0.1865] | 0.1465 [0.1412, 0.1524] | 0.1465 [0.1412, 0.1524] | 0.1811 [0.1748, 0.1877] | 0.1447 [0.1400, 0.1500] | 0.1447 [0.1399, 0.1500] |

**Paired Brier reductions [95% CI]** (positive = first model more accurate)

| comparison | model | horizon | cell |
|---|---|---|---|
| rotation - base | Logistic regression | 12 h | 0.0054 [0.0049, 0.0060] |
| rotation - base | Logistic regression | 6 h | 0.0073 [0.0065, 0.0080] |
| rotation - base | Logistic regression | 4 h | 0.0124 [0.0113, 0.0134] |
| rotation - base | Logistic regression | 2 h | 0.0256 [0.0236, 0.0275] |
| rotation - base | Logistic regression | 1 h | 0.0314 [0.0291, 0.0336] |
| rotation - base | Logistic regression | 30 min | 0.0331 [0.0307, 0.0353] |
| rotation - base | Random forest | 12 h | 0.0070 [0.0065, 0.0075] |
| rotation - base | Random forest | 6 h | 0.0086 [0.0080, 0.0093] |
| rotation - base | Random forest | 4 h | 0.0131 [0.0122, 0.0139] |
| rotation - base | Random forest | 2 h | 0.0254 [0.0237, 0.0270] |
| rotation - base | Random forest | 1 h | 0.0309 [0.0289, 0.0329] |
| rotation - base | Random forest | 30 min | 0.0365 [0.0342, 0.0386] |
| oracle - rotation (2h) | Logistic regression | 2 h | 0.0103 [0.0094, 0.0112] |
| oracle - rotation (2h) | Random forest | 2 h | 0.0114 [0.0106, 0.0122] |

**Calibration (diagnostic)**: mean prediction, calibration-in-the-large (mean - observed), slope, Brier after intercept shift

| model | set | horizon | mean_p | citl | slope | brier | brier_shifted |
|---|---|---|---|---|---|---|---|
| Logistic regression | base | 12 h | 0.244 | -0.036 | 1.02 | 0.1890 | 0.1875 |
| Logistic regression | base | 6 h | 0.240 | -0.040 | 0.98 | 0.1891 | 0.1873 |
| Logistic regression | base | 4 h | 0.233 | -0.048 | 0.96 | 0.1884 | 0.1860 |
| Logistic regression | base | 2 h | 0.236 | -0.044 | 0.95 | 0.1846 | 0.1825 |
| Logistic regression | base | 1 h | 0.240 | -0.040 | 0.98 | 0.1813 | 0.1795 |
| Logistic regression | base | 30 min | 0.239 | -0.041 | 1.01 | 0.1796 | 0.1776 |
| Logistic regression | rotation | 12 h | 0.241 | -0.039 | 0.98 | 0.1835 | 0.1818 |
| Logistic regression | rotation | 6 h | 0.237 | -0.043 | 0.94 | 0.1818 | 0.1799 |
| Logistic regression | rotation | 4 h | 0.233 | -0.047 | 0.92 | 0.1760 | 0.1737 |
| Logistic regression | rotation | 2 h | 0.242 | -0.038 | 0.93 | 0.1590 | 0.1575 |
| Logistic regression | rotation | 1 h | 0.246 | -0.034 | 0.95 | 0.1499 | 0.1486 |
| Logistic regression | rotation | 30 min | 0.249 | -0.032 | 0.95 | 0.1465 | 0.1455 |
| Random forest | base | 12 h | 0.263 | -0.018 | 1.35 | 0.1905 | 0.1900 |
| Random forest | base | 6 h | 0.258 | -0.023 | 1.39 | 0.1890 | 0.1882 |
| Random forest | base | 4 h | 0.257 | -0.023 | 1.44 | 0.1869 | 0.1861 |
| Random forest | base | 2 h | 0.259 | -0.021 | 1.46 | 0.1841 | 0.1834 |
| Random forest | base | 1 h | 0.261 | -0.020 | 1.45 | 0.1824 | 0.1817 |
| Random forest | base | 30 min | 0.263 | -0.017 | 1.48 | 0.1811 | 0.1805 |
| Random forest | rotation | 12 h | 0.258 | -0.022 | 1.49 | 0.1835 | 0.1826 |
| Random forest | rotation | 6 h | 0.256 | -0.025 | 1.45 | 0.1804 | 0.1793 |
| Random forest | rotation | 4 h | 0.257 | -0.023 | 1.47 | 0.1738 | 0.1728 |
| Random forest | rotation | 2 h | 0.261 | -0.020 | 1.44 | 0.1587 | 0.1580 |
| Random forest | rotation | 1 h | 0.264 | -0.017 | 1.38 | 0.1515 | 0.1510 |
| Random forest | rotation | 30 min | 0.267 | -0.013 | 1.33 | 0.1447 | 0.1443 |
