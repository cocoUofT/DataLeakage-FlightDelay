# Data leakage in flight-delay prediction

*Channing Liu, Coco Liu, and Xinnan Zhao — STA2112 final project*

**How much does including information unavailable two hours before scheduled departure
change the measured performance of models predicting arrival delays of at least 15 minutes?**

## Repository layout

| Path | Contents |
|---|---|
| `proposal/` | Everything used for the October proposal: report, Atlanta January 2025 pilot scripts, prepared data and results. Self-contained; see `proposal/README.md`. |
| `config/airports.csv` | Study airports: IATA, IEM station/network, ICAO, IANA time zone, DST flag |
| `scripts/01a_download_weather_10airports.py` | Download IEM METAR reports for the 10 airports (Jan–Sep 2025, UTC) |
| `scripts/01b_build_closed10_flights.py` | Download BTS monthly files and build the closed-network flight files |
| `data/processed/closed10/` | Midway study data (see its `README.md`) |
| `data/raw/` | Raw BTS zips and per-station weather (git-ignored; rebuilt by the scripts) |
| `midway/` | Midway checkpoint materials and team notes |

## Midway study: 10-airport closed network

Flights whose origin **and** destination are among ATL, ORD, DFW, DEN, LAX, SFO, JFK, SEA,
PHX and MCO. Development: January–June 2025 (train Jan–Apr, validation May–Jun).
Final test: July–September 2025, stored in a separate file and not used before final evaluation.

Rebuild the data from the project root (Python 3, standard library only):

```bash
python3 scripts/01a_download_weather_10airports.py
python3 scripts/01b_build_closed10_flights.py 1 2 3 4 5 6 7 8 9
python3 scripts/01b_build_closed10_flights.py --combine
```

## Sources

- [BTS Reporting Carrier On-Time Performance](https://www.transtats.bts.gov/Fields.asp?gnoyr_VQ=FGJ)
- [Iowa Environmental Mesonet ASOS/METAR archive](https://mesonet.agron.iastate.edu/request/download.phtml)
