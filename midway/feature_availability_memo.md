# Feature availability at the two-hour cutoff (memo version)

Cutoff *c* = scheduled departure (UTC) − 120 min. BTS clock times are local at the event airport and are
converted to UTC with each airport's IANA zone (DST-aware; PHX has none). Arrival times are derived as
departure (UTC) + elapsed minutes, which reproduces `CRSArrTime` for all but 8 of 237,138 development
flights. IEM weather times are UTC observation times. Weather comes from the latest report with
`valid` ≤ *c* − *L* and age ≤ 120 min, assumed reporting lag *L* = 0 (sensitivity: 15 and 30 min).
Weather features are built for **both origin and destination**. Full table: `midway/feature_availability_full.md`.

**Table X. Clean (C) predictors used in the midway models, all available at *c*.** *Raw* = an existing source
column used as is (weather: the field from the matched report; precipitation amount on a log scale);
*derived* = constructed by us. Definitions in code: `scripts/midway_helpers.R`.

| Type | Feature | Source (time zone) | Availability rule | Count |
|---|---|---|---|---:|
| Raw | Carrier, origin, destination, day of week | BTS schedule (origin local date) | Known weeks ahead | 4 |
| Raw | Scheduled duration (`CRSElapsedTime`), distance | BTS schedule | Known weeks ahead | 2 |
| Raw | Wind speed, gust, visibility, precipitation amount (`log1p(100 × p01i)`) | IEM METAR (UTC) | Latest report ≤ *c* − *L* | 4 × 2 |
| Derived | Scheduled departure hour, scheduled arrival hour (local) | BTS schedule | Known weeks ahead | 2 |
| Derived | Days to nearest US federal holiday | Calendar (origin local date) | Known ahead | 1 |
| Derived | Gust-reported indicator; precipitation intensity (none/light/moderate/heavy); thunderstorm flag (`TS`); snow / freezing precipitation flag (`SN`, `SG`, `PL`, `IC`, `FZRA`, `FZDZ`) | METAR present weather | Latest report ≤ *c* − *L* | 4 × 2 |
| Derived | Historical delay rates by origin, destination, carrier, route; 182-, 28- and 7-day windows | BTS history (UTC) | Only flights that **arrived** before *c* | 12 |
| Derived | Same-day origin departures before *c*: share ≥ 15 min late, "none yet" indicator, count (log) | BTS history (UTC) | Only flights that **departed** before *c* | 3 |
| Derived | Destination arrivals in the last 3 h: share ≥ 15 min late, "none" indicator, count (log) | BTS history (UTC) | Only flights that **arrived** in [*c* − 3 h, *c*) | 3 |
| Derived | Network-wide delay rate (flights departing the 10 airports), last 24 h and 7 days | BTS history (UTC) | Only flights that **arrived** before *c* | 2 |
| | **Total** | | | **45** |

*Month is not a predictor: validation months (May–Jun) never occur in training (Jan–Apr). Rates with no
earlier flights are filled with the training mean, and the "none" indicator keeps that information.*

**Leakage conditions.** **W** uses the same 45 predictors but takes every weather feature from the latest
report in (*c*, scheduled departure] at both the origin and the destination, unavailable at *c*.
**WO** adds departure delay (`DepDelay`) and taxi-out time (`TaxiOut`), realized at and after pushback (47).
All other post-departure fields (wheels-on, arrival times, air time) and delay-cause minutes are excluded
from every condition because they are determined by, or reported only with, the outcome `ArrDel15`.
