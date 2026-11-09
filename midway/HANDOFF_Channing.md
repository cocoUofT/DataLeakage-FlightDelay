# Midway 交接说明（2026-11-09 晚，Coco）

## 已完成
- 研究范围定为 **10 个机场的 closed network**：ATL, ORD, DFW, DEN, LAX, SFO, JFK, SEA, PHX, MCO。
  origin 和 destination 都在这 10 个里面。1 月约 3.6 万个 eligible flights，Jan–Jun 共约 23.4 万个。
- BTS 2025 年 Jan–Sep 和 10 个 station 的 IEM weather 都已下载并筛选好，放在 `data/processed/closed10/`。
  说明见那里的 `README.md`。
- `config/airports.csv`：IATA → IEM station / ICAO / **IANA timezone** / 是否实行 DST（PHX 不实行）。
- dev（Jan–Jun）和 test（Jul–Sep）存成不同的文件。**test 文件不要拿来 fit 或 tune**。

## 明天（周二）要做
1. **改 `weather_helpers.R` / `02_prepare_data.R`，支持多机场**
   - 读 `config/airports.csv`，用 `iana_timezone` 把每个航班的 CRS dep/arr 时间转成 UTC
     （origin 用 origin 的 tz，arr 用 dest 的 tz；处理 `2400`、跨午夜；DST 切换日 3/9）。
   - cutoff = scheduled departure (UTC) − 120 min。
   - 原本的 backward matching 对 **origin 和 destination 各做一次**。两边都用同一个 cutoff，
     station 换成对应机场。weather 来自 `weather_10airports_2025JanSep.csv.gz`（`valid` 是 UTC）。
   - W condition 一样取 cutoff 之后、接近 scheduled departure 的观测。
2. **Feature-availability table 初版**（放在 `midway/feature_availability.md`）
   - 每个 feature 写：来源、原始时区、实际发生时间、假设的 reporting lag、在 T − 2h 能不能拿到、属于 C/W/WO 哪个 condition。
3. **（时间够再做）historical delay rates**：用 `history_10airports_*` 文件，只算
   *actual arrival (UTC) < cutoff* 的航班，即在 cutoff 前已经知道结果的航班。

## 时间点
- **周三中午**检查：多机场 + destination weather 的 pipeline 能不能跑通。
  跑不通的话，先交 origin weather only 的版本，destination weather 写进 revised plan。
- 周三晚：Coco 跑 C/W/WO × LR/RF 的 validation 结果和图。周四做 slides 和 memo。

## 要注意的发现
- **Delay rate 季节变化很大**：train（Jan–Apr）约 0.18–0.21，validation（May–Jun）0.25–0.31，
  July 0.32。和 pilot 一样会有 calibration shift，这是 midway 的 main unresolved issue 之一。
- Pilot 诊断：clean LR 的 AP 低于 prevalence，但把 validation 按天拆开后，每天之内的 AP ≈ 当天的 delay rate，
  也就是说排序没有反向，不像 label coding 错误。问题出在不同天之间：DayOfWeek 和 1/10–11（周五、周六）
  暴风雪混在一起，模型给周六的预测概率最高，但周六其实最准点。用 Jan–Apr 的长训练期时要再检查一次。
- 这台机器的 VM 里没有 R，所以这两个下载和筛选脚本是用 Python（标准库）写的。
  需要的话可以改写成 R，但输出文件应该完全一样。
