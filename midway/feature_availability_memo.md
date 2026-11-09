# Feature availability at the two-hour cutoff (memo version)

Cutoff *c* = scheduled departure (UTC) − 120 min. BTS clock times are local at the event airport and are
converted to UTC with each airport's IANA zone (DST-aware; PHX has none). Arrival times are derived as
departure (UTC) + elapsed minutes, which reproduces `CRSArrTime` for all but 8 of 237,138 development
flights. IEM weather times are UTC observation times. Weather comes from the latest report with
`valid` ≤ *c* − *L* and age ≤ 120 min, assumed reporting lag *L* = 0 (sensitivity: 15 and 30 min).
Weather features are built for **both origin and destination**. Full table: `midway/feature_availability_full.md`.

**Table X. Candidate clean (C) predictors available at *c*.** *Raw* = an existing source column used as is
(weather: the field from the matched report); *derived* = constructed by us.

| Type | Feature | Source (time zone) | Availability rule | Count |
|---|---|---|---|---:|
| Raw | Carrier, origin, destination | BTS schedule | Known weeks ahead | 3 |
| Raw | Scheduled duration (`CRSElapsedTime`), distance | BTS schedule | Known weeks ahead | 2 |
| Raw | Month, day of week | BTS (origin local date) | Calendar | 2 |
| Raw | Wind speed, gust, visibility, precipitation amount (`p01i`) | IEM METAR (UTC) | Latest report ≤ *c* − *L* | 4 × 2 |
| Derived | Scheduled departure hour, scheduled arrival hour | BTS (local) | From schedule | 2 |
| Derived | Days to nearest US federal holiday | Calendar | Known ahead | 1 |
| Derived | Precipitation intensity (none/light/moderate/heavy) | METAR present weather | Latest report ≤ *c* − *L* | 1 × 2 |
| Derived | Thunderstorm flag (`TS`) | METAR present weather | Latest report ≤ *c* − *L* | 1 × 2 |
| Derived | Snow / freezing precipitation flag (`SN`, `SG`, `PL`, `IC`, `FZRA`, `FZDZ`) | METAR present weather | Latest report ≤ *c* − *L* | 1 × 2 |
| Derived | Historical delay rates by origin, destination, carrier, route; 182-, 28- and 7-day windows | BTS history (UTC) | Only flights that **arrived** before *c* | 12 |
| Derived | Same-day share of origin departures ≥ 15 min late | BTS history (UTC) | Only flights that **departed** before *c* | 1 |
| Derived | Share of destination arrivals ≥ 15 min late in the last 3 h | BTS history (UTC) | Only flights that **arrived** in [*c* − 3 h, *c*) | 1 |
| | **Total** | | | **38** |

**Leakage conditions.** **W** keeps the C features but takes every weather feature from the latest report
in (*c*, scheduled departure] at the origin and (*c*, scheduled arrival] at the destination, unavailable at *c*.
**WO** adds departure delay (`DepDelay`) and taxi-out time (`TaxiOut`), realized at and after pushback.
All other post-departure fields (wheels-on, arrival times, air time) and delay-cause minutes are excluded
from every condition because they are determined by, or reported only with, the outcome `ArrDel15`.
