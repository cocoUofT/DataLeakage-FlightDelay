## Coco did these at midnight

教授的反馈主要有三点：
（1）可以缩小地理范围，dev 和 final test 要清楚分开；
（2）做一张 two-hour cutoff 的 feature-availability table（包括时区和 reporting delay），
     historical delay rates 只能用 cutoff 前已经知道的结果；
（3）调查 clean model 为什么弱。

所以我做了：

- **范围**：10 个机场的 closed network（ATL, ORD, DFW, DEN, LAX, SFO, JFK, SEA, PHX, MCO），
            origin 和 destination 都在里面。理论上 closed network 可行，因为 domestic flights
            也是由所有机场的 closed network 组成。做10个可以节省computaiton task。
            dev 是 Jan–Jun 2025，test 是 Jul–Sep 2025，分成不同的文件。数据在 `data/processed/closed10/`。
- **Feature-availability table**：`midway/feature_availability_full.md` 和 `feature_availability_memo.md`。
- **Historical delay rates**：只用 cutoff 前已经知道结果的航班，已经算好并验证过，在
  `features_history_dev.csv.gz`（用 `flight_id` join），里面也有每个航班的 `cutoff_utc`。

## 上午要做的：建好 model table（只是建议，具体可复制给AI，再决定下一步）
产出 `data/processed/closed10/model_table_dev.csv.gz`，每个 eligible 的 dev 航班一行。

1. **时间**：直接用 `cutoff_utc`。scheduled dep = cutoff + 120 min，
             scheduled arr = scheduled dep + `CRSElapsedTime`，都是 UTC。
2. **Weather matching**（复制 `proposal/scripts/weather_helpers.R` 到外层 `scripts/` 再改）。天气用
   `weather_10airports_2025JanSep.csv.gz`（UTC），origin 和 dest 都要做：
   - C：cutoff 之前最新的一份报告，最多 120 分钟前；
   - W：(cutoff, scheduled dep] 内最新的一份。dest 也另外做一份 (cutoff, scheduled arr]，下午再决定用哪个。
   - 变量：风速、阵风、能见度、`p01i`、降水强度、雷暴 flag、雪 / 冻雨 flag。
3. **Schedule 变量**：出发小时、到达小时、离节假日的天数。
4. **Join** history 特征，以及 WO 要用的 `DepDelay`、`TaxiOut`。
5. **检查**：每个机场天气缺失的比例；手动核对 3 个航班的天气报告；确认 C 的报告时间都没有晚于 cutoff。

时间不够的话，先做 origin weather，dest 下午再补。
