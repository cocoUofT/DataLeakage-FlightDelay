# Final study (extension): prediction time and aircraft rotation — validation May–Jun 2025 — regular aircraft rotations only

n = 80,509 validation flights (delay rate 0.267), identical at every prediction time. Bootstrap: 1000 reps over validation days.

**AP [95% CI] by prediction time**

| horizon | Logistic regression base | Logistic regression prev1 | Logistic regression rotation | Random forest base | Random forest prev1 | Random forest rotation |
|---|---|---|---|---|---|---|
| 12 h | 0.410 [0.377, 0.443] | 0.413 [0.379, 0.445] | 0.435 [0.403, 0.465] | 0.410 [0.377, 0.442] | 0.441 [0.411, 0.470] | 0.446 [0.416, 0.474] |
| 6 h | 0.411 [0.381, 0.441] | 0.420 [0.390, 0.450] | 0.454 [0.426, 0.481] | 0.427 [0.397, 0.460] | 0.459 [0.432, 0.489] | 0.477 [0.450, 0.505] |
| 4 h | 0.425 [0.394, 0.456] | 0.483 [0.453, 0.512] | 0.505 [0.477, 0.532] | 0.445 [0.414, 0.478] | 0.518 [0.489, 0.547] | 0.533 [0.504, 0.561] |
| 2 h | 0.456 [0.423, 0.488] | 0.604 [0.577, 0.627] | 0.604 [0.577, 0.628] | 0.469 [0.438, 0.502] | 0.616 [0.591, 0.639] | 0.619 [0.594, 0.643] |
| 1 h | 0.477 [0.445, 0.510] | 0.651 [0.627, 0.674] | 0.651 [0.627, 0.674] | 0.486 [0.455, 0.519] | 0.654 [0.630, 0.677] | 0.653 [0.628, 0.675] |
| 30 min | 0.491 [0.459, 0.523] | 0.661 [0.637, 0.684] | 0.661 [0.637, 0.684] | 0.494 [0.462, 0.528] | 0.677 [0.653, 0.699] | 0.675 [0.651, 0.697] |

**Paired differences in AP [95% CI]**

| comparison | model | horizon | cell |
|---|---|---|---|
| rotation - base | Logistic regression | 12 h | 0.024 [0.020, 0.027] |
| rotation - base | Logistic regression | 6 h | 0.043 [0.036, 0.048] |
| rotation - base | Logistic regression | 4 h | 0.080 [0.072, 0.088] |
| rotation - base | Logistic regression | 2 h | 0.148 [0.136, 0.160] |
| rotation - base | Logistic regression | 1 h | 0.174 [0.160, 0.187] |
| rotation - base | Logistic regression | 30 min | 0.171 [0.157, 0.183] |
| rotation - base | Random forest | 12 h | 0.036 [0.029, 0.042] |
| rotation - base | Random forest | 6 h | 0.050 [0.043, 0.057] |
| rotation - base | Random forest | 4 h | 0.088 [0.079, 0.097] |
| rotation - base | Random forest | 2 h | 0.150 [0.136, 0.163] |
| rotation - base | Random forest | 1 h | 0.167 [0.152, 0.182] |
| rotation - base | Random forest | 30 min | 0.181 [0.166, 0.196] |
| prev1 - base | Logistic regression | 12 h | 0.002 [0.001, 0.004] |
| prev1 - base | Logistic regression | 6 h | 0.009 [0.006, 0.011] |
| prev1 - base | Logistic regression | 4 h | 0.058 [0.052, 0.063] |
| prev1 - base | Logistic regression | 2 h | 0.148 [0.136, 0.160] |
| prev1 - base | Logistic regression | 1 h | 0.174 [0.160, 0.187] |
| prev1 - base | Logistic regression | 30 min | 0.171 [0.158, 0.183] |
| prev1 - base | Random forest | 12 h | 0.031 [0.025, 0.036] |
| prev1 - base | Random forest | 6 h | 0.032 [0.027, 0.037] |
| prev1 - base | Random forest | 4 h | 0.073 [0.065, 0.079] |
| prev1 - base | Random forest | 2 h | 0.147 [0.133, 0.160] |
| prev1 - base | Random forest | 1 h | 0.168 [0.153, 0.183] |
| prev1 - base | Random forest | 30 min | 0.183 [0.168, 0.198] |
| rotation - prev1 | Logistic regression | 12 h | 0.022 [0.018, 0.025] |
| rotation - prev1 | Logistic regression | 6 h | 0.034 [0.029, 0.038] |
| rotation - prev1 | Logistic regression | 4 h | 0.023 [0.019, 0.027] |
| rotation - prev1 | Logistic regression | 2 h | 0.000 [-0.000, 0.001] |
| rotation - prev1 | Logistic regression | 1 h | -0.000 [-0.000, -0.000] |
| rotation - prev1 | Logistic regression | 30 min | -0.000 [-0.000, 0.000] |
| rotation - prev1 | Random forest | 12 h | 0.005 [0.003, 0.008] |
| rotation - prev1 | Random forest | 6 h | 0.018 [0.014, 0.021] |
| rotation - prev1 | Random forest | 4 h | 0.016 [0.012, 0.019] |
| rotation - prev1 | Random forest | 2 h | 0.003 [0.002, 0.005] |
| rotation - prev1 | Random forest | 1 h | -0.001 [-0.002, -0.001] |
| rotation - prev1 | Random forest | 30 min | -0.002 [-0.002, -0.001] |
| horizon - 2h (rotation) | Logistic regression | 12 h | -0.169 [-0.184, -0.154] |
| horizon - 2h (rotation) | Logistic regression | 6 h | -0.150 [-0.158, -0.142] |
| horizon - 2h (rotation) | Logistic regression | 4 h | -0.098 [-0.104, -0.093] |
| horizon - 2h (rotation) | Logistic regression | 1 h | 0.047 [0.043, 0.052] |
| horizon - 2h (rotation) | Logistic regression | 30 min | 0.057 [0.053, 0.062] |
| horizon - 2h (rotation) | Random forest | 12 h | -0.173 [-0.185, -0.162] |
| horizon - 2h (rotation) | Random forest | 6 h | -0.142 [-0.149, -0.133] |
| horizon - 2h (rotation) | Random forest | 4 h | -0.086 [-0.092, -0.080] |
| horizon - 2h (rotation) | Random forest | 1 h | 0.034 [0.030, 0.037] |
| horizon - 2h (rotation) | Random forest | 30 min | 0.056 [0.051, 0.060] |
| oracle - rotation (2h) | Logistic regression | 2 h | 0.048 [0.044, 0.051] |
| oracle - rotation (2h) | Random forest | 2 h | 0.047 [0.043, 0.051] |

**Brier [95% CI] by prediction time** (constant reference = training delay rate: 0.2018)

| horizon | Logistic regression base | Logistic regression prev1 | Logistic regression rotation | Random forest base | Random forest prev1 | Random forest rotation |
|---|---|---|---|---|---|---|
| 12 h | 0.1837 [0.1761, 0.1923] | 0.1834 [0.1757, 0.1920] | 0.1815 [0.1738, 0.1900] | 0.1850 [0.1777, 0.1930] | 0.1828 [0.1755, 0.1909] | 0.1819 [0.1746, 0.1899] |
| 6 h | 0.1838 [0.1762, 0.1922] | 0.1828 [0.1753, 0.1913] | 0.1797 [0.1719, 0.1882] | 0.1834 [0.1764, 0.1914] | 0.1808 [0.1737, 0.1888] | 0.1788 [0.1717, 0.1869] |
| 4 h | 0.1832 [0.1756, 0.1918] | 0.1764 [0.1688, 0.1847] | 0.1737 [0.1663, 0.1821] | 0.1817 [0.1748, 0.1895] | 0.1743 [0.1676, 0.1819] | 0.1719 [0.1653, 0.1793] |
| 2 h | 0.1796 [0.1721, 0.1875] | 0.1566 [0.1504, 0.1634] | 0.1566 [0.1503, 0.1634] | 0.1791 [0.1724, 0.1866] | 0.1562 [0.1504, 0.1628] | 0.1566 [0.1508, 0.1631] |
| 1 h | 0.1763 [0.1693, 0.1839] | 0.1470 [0.1415, 0.1534] | 0.1471 [0.1415, 0.1534] | 0.1770 [0.1704, 0.1841] | 0.1490 [0.1437, 0.1549] | 0.1491 [0.1438, 0.1551] |
| 30 min | 0.1746 [0.1677, 0.1821] | 0.1438 [0.1382, 0.1501] | 0.1438 [0.1382, 0.1501] | 0.1762 [0.1697, 0.1831] | 0.1423 [0.1373, 0.1480] | 0.1425 [0.1376, 0.1482] |

**Paired Brier reductions [95% CI]** (positive = first model more accurate)

| comparison | model | horizon | cell |
|---|---|---|---|
| rotation - base | Logistic regression | 12 h | 0.0022 [0.0018, 0.0025] |
| rotation - base | Logistic regression | 6 h | 0.0041 [0.0034, 0.0047] |
| rotation - base | Logistic regression | 4 h | 0.0095 [0.0085, 0.0104] |
| rotation - base | Logistic regression | 2 h | 0.0230 [0.0211, 0.0249] |
| rotation - base | Logistic regression | 1 h | 0.0293 [0.0271, 0.0315] |
| rotation - base | Logistic regression | 30 min | 0.0308 [0.0285, 0.0329] |
| rotation - base | Random forest | 12 h | 0.0031 [0.0028, 0.0033] |
| rotation - base | Random forest | 6 h | 0.0047 [0.0042, 0.0051] |
| rotation - base | Random forest | 4 h | 0.0098 [0.0090, 0.0106] |
| rotation - base | Random forest | 2 h | 0.0224 [0.0209, 0.0239] |
| rotation - base | Random forest | 1 h | 0.0278 [0.0259, 0.0298] |
| rotation - base | Random forest | 30 min | 0.0336 [0.0314, 0.0358] |
| oracle - rotation (2h) | Logistic regression | 2 h | 0.0105 [0.0097, 0.0115] |
| oracle - rotation (2h) | Random forest | 2 h | 0.0117 [0.0108, 0.0125] |

**Calibration (diagnostic)**: mean prediction, calibration-in-the-large (mean - observed), slope, Brier after intercept shift

| model | set | horizon | mean_p | citl | slope | brier | brier_shifted |
|---|---|---|---|---|---|---|---|
| Logistic regression | base | 12 h | 0.234 | -0.033 | 0.99 | 0.1837 | 0.1825 |
| Logistic regression | base | 6 h | 0.230 | -0.037 | 0.96 | 0.1838 | 0.1823 |
| Logistic regression | base | 4 h | 0.222 | -0.045 | 0.93 | 0.1832 | 0.1811 |
| Logistic regression | base | 2 h | 0.225 | -0.042 | 0.93 | 0.1796 | 0.1777 |
| Logistic regression | base | 1 h | 0.229 | -0.038 | 0.96 | 0.1763 | 0.1747 |
| Logistic regression | base | 30 min | 0.228 | -0.039 | 0.99 | 0.1746 | 0.1729 |
| Logistic regression | rotation | 12 h | 0.232 | -0.036 | 0.98 | 0.1815 | 0.1801 |
| Logistic regression | rotation | 6 h | 0.228 | -0.039 | 0.94 | 0.1797 | 0.1781 |
| Logistic regression | rotation | 4 h | 0.224 | -0.044 | 0.91 | 0.1737 | 0.1718 |
| Logistic regression | rotation | 2 h | 0.231 | -0.036 | 0.92 | 0.1566 | 0.1554 |
| Logistic regression | rotation | 1 h | 0.237 | -0.031 | 0.94 | 0.1471 | 0.1461 |
| Logistic regression | rotation | 30 min | 0.239 | -0.028 | 0.95 | 0.1438 | 0.1431 |
| Random forest | base | 12 h | 0.248 | -0.019 | 1.44 | 0.1850 | 0.1844 |
| Random forest | base | 6 h | 0.244 | -0.023 | 1.42 | 0.1834 | 0.1826 |
| Random forest | base | 4 h | 0.243 | -0.024 | 1.44 | 0.1817 | 0.1807 |
| Random forest | base | 2 h | 0.245 | -0.022 | 1.45 | 0.1791 | 0.1782 |
| Random forest | base | 1 h | 0.248 | -0.019 | 1.44 | 0.1770 | 0.1763 |
| Random forest | base | 30 min | 0.250 | -0.017 | 1.47 | 0.1762 | 0.1756 |
| Random forest | rotation | 12 h | 0.247 | -0.021 | 1.50 | 0.1819 | 0.1812 |
| Random forest | rotation | 6 h | 0.242 | -0.025 | 1.47 | 0.1788 | 0.1777 |
| Random forest | rotation | 4 h | 0.243 | -0.024 | 1.51 | 0.1719 | 0.1708 |
| Random forest | rotation | 2 h | 0.248 | -0.019 | 1.50 | 0.1566 | 0.1559 |
| Random forest | rotation | 1 h | 0.250 | -0.017 | 1.40 | 0.1491 | 0.1486 |
| Random forest | rotation | 30 min | 0.255 | -0.012 | 1.34 | 0.1425 | 0.1423 |
