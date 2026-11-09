"""Build the 10-airport closed-network flight files from BTS monthly data (2025 Jan-Sep).

Usage (from project root, Python 3 standard library only):
  python3 scripts/01b_build_closed10_flights.py 1 2 3   # 2025 months: download (if needed) + filter -> parts
  python3 scripts/01b_build_closed10_flights.py 2024-07 2024-12  # 2024 months: history only (lookback)
  python3 scripts/01b_build_closed10_flights.py --combine  # merge parts into final files + summary

Inputs : data/raw/bts/bts_YYYY_MM.zip (BTS PREZIP; downloaded if missing).
Outputs: data/processed/closed10/ (see data/processed/closed10/README.md)
  flights_closed10_dev_2025JanJun.csv.gz   origin AND dest in the 10 airports, development period
  flights_closed10_test_2025JulSep.csv.gz  same, FINAL TEST period -- do not use for fitting/tuning
  history_10airports_*.csv.gz              any flight touching the 10 airports (few columns),
                                           source for historical delay rates; *_pre_2024JulDec is
                                           lookback only (no 2024 study flights)
  weather_10airports_2025JanSep.csv.gz     all IEM reports for the 10 stations (UTC)
  summary_counts.csv                       counts and delay rates by month x origin
No rows are dropped for cancellation/diversion here; use the `eligible` column
(completed, not diverted, ArrDel15 observed) to define the study population.
"""
import csv, glob, gzip, io, os, sys, urllib.request, zipfile

AIRPORTS = [r["iata"] for r in csv.DictReader(open("config/airports.csv"))]
SET = set(AIRPORTS)
RAW, PARTS, OUT = "data/raw/bts", "data/raw/bts/parts", "data/processed/closed10"
URL = "https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_{y}_{m}.zip"
DEV_MONTHS, TEST_MONTHS = range(1, 7), range(7, 10)

# Flight-level columns kept (everything up to the delay-cause block; diversion detail dropped).
FLIGHT_COLS = ["Year", "Month", "DayofMonth", "DayOfWeek", "FlightDate", "Reporting_Airline",
    "Tail_Number", "Flight_Number_Reporting_Airline", "Origin", "OriginState", "Dest", "DestState",
    "CRSDepTime", "DepTime", "DepDelay", "DepDelayMinutes", "DepDel15", "DepTimeBlk", "TaxiOut",
    "WheelsOff", "WheelsOn", "TaxiIn", "CRSArrTime", "ArrTime", "ArrDelay", "ArrDelayMinutes",
    "ArrDel15", "ArrTimeBlk", "Cancelled", "CancellationCode", "Diverted", "CRSElapsedTime",
    "ActualElapsedTime", "AirTime", "Distance", "DistanceGroup", "CarrierDelay", "WeatherDelay",
    "NASDelay", "SecurityDelay", "LateAircraftDelay"]
HIST_COLS = ["FlightDate", "Reporting_Airline", "Tail_Number", "Flight_Number_Reporting_Airline",
    "Origin", "Dest", "CRSDepTime", "DepTime", "CRSArrTime", "ArrTime", "DepDel15", "ArrDelay",
    "ArrDel15", "Cancelled", "Diverted", "CRSElapsedTime", "Distance"]

def flight_id(r):
    return f'{r["FlightDate"]}_{r["Reporting_Airline"]}_{r["Flight_Number_Reporting_Airline"]}_{r["Origin"]}_{r["Dest"]}_{r["CRSDepTime"]}'

def eligible(r):
    return int(r["Cancelled"] in ("0", "0.00") and r["Diverted"] in ("0", "0.00") and r["ArrDel15"] != "")

def open_month(y, m):
    z = f"{RAW}/bts_{y}_{m:02d}.zip"
    if not os.path.exists(z):
        os.makedirs(RAW, exist_ok=True)
        urllib.request.urlretrieve(URL.format(y=y, m=m), z)
    zf = zipfile.ZipFile(z)
    name = [n for n in zf.namelist() if n.endswith(".csv")][0]
    return io.TextIOWrapper(zf.open(name), newline="")

def gz_writer(path, cols):
    f = gzip.GzipFile(path, "wb", mtime=0)  # mtime=0 -> byte-identical reruns
    t = io.TextIOWrapper(f, newline="")
    w = csv.writer(t); w.writerow(cols)
    return t, w

def filter_month(y, m):
    """2025 months -> closed-network + history parts; earlier years -> history part only."""
    os.makedirs(PARTS, exist_ok=True)
    study = y == 2025
    if study:
        tf, wf = gz_writer(f"{PARTS}/closed_{m:02d}.csv.gz", ["flight_id"] + FLIGHT_COLS + ["eligible"])
    hist_name = f"{PARTS}/hist_{m:02d}.csv.gz" if study else f"{PARTS}/hist_{y}_{m:02d}.csv.gz"
    th, wh = gz_writer(hist_name, HIST_COLS + ["eligible"])
    n_all = n_c = n_h = 0
    with open_month(y, m) as src:
        for r in csv.DictReader(src):
            n_all += 1
            assert int(r["Month"]) == m and r["Year"] == str(y)
            o, d = r["Origin"], r["Dest"]
            if o in SET or d in SET:
                n_h += 1; wh.writerow([r[c] for c in HIST_COLS] + [eligible(r)])
                if study and o in SET and d in SET:
                    n_c += 1; wf.writerow([flight_id(r)] + [r[c] for c in FLIGHT_COLS] + [eligible(r)])
    if study: tf.close()
    th.close()
    print(f"{y}-{m:02d}: {n_all} BTS rows, {n_h} touching 10 airports, {n_c} closed-network")

def combine():
    os.makedirs(OUT, exist_ok=True)
    def merge(prefix, months, out):
        files = [f"{PARTS}/{prefix}_{m:02d}.csv.gz" if isinstance(m, int) else f"{PARTS}/{prefix}_{m}.csv.gz"
                 for m in months]
        assert all(os.path.exists(f) for f in files), f"missing parts for {out}"
        t, w = None, None
        rows = 0
        for i, fn in enumerate(files):
            with io.TextIOWrapper(gzip.open(fn), newline="") as f:
                rd = csv.reader(f); header = next(rd)
                if t is None: t, w = gz_writer(f"{OUT}/{out}", header)
                for row in rd: w.writerow(row); rows += 1
        t.close(); print(out, rows)
    merge("closed", DEV_MONTHS, "flights_closed10_dev_2025JanJun.csv.gz")
    merge("closed", TEST_MONTHS, "flights_closed10_test_2025JulSep.csv.gz")
    merge("hist", DEV_MONTHS, "history_10airports_dev_2025JanJun.csv.gz")
    merge("hist", TEST_MONTHS, "history_10airports_test_2025JulSep.csv.gz")
    merge("hist", [f"2024_{m:02d}" for m in range(7, 13)], "history_10airports_pre_2024JulDec.csv.gz")
    # duplicate-ID check + summary by month x origin
    summary, seen, dup = {}, set(), 0
    for fn in ["flights_closed10_dev_2025JanJun.csv.gz", "flights_closed10_test_2025JulSep.csv.gz"]:
        with io.TextIOWrapper(gzip.open(f"{OUT}/{fn}"), newline="") as f:
            for r in csv.DictReader(f):
                dup += r["flight_id"] in seen; seen.add(r["flight_id"])
                k = (int(r["Month"]), r["Origin"]); s = summary.setdefault(k, [0, 0, 0])
                s[0] += 1; s[1] += int(r["eligible"]); s[2] += int(r["eligible"] == "1" and r["ArrDel15"].startswith("1"))
    print("duplicate flight_id:", dup)
    with open(f"{OUT}/summary_counts.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(["period", "month", "origin", "rows", "eligible", "arr_del15_rate_eligible"])
        for (m, o), (n, e, dl) in sorted(summary.items()):
            w.writerow(["dev" if m <= 6 else "test", m, o, n, e, round(dl / e, 4) if e else ""])
    # weather: stack the 10 station files, add iata column
    t, w = None, None
    for ap in AIRPORTS:
        with open(f"data/raw/weather/{ap}_2025JanSep_weather.csv", newline="") as f:
            rd = csv.reader(f); header = next(rd)
            if t is None: t, w = gz_writer(f"{OUT}/weather_10airports_2025JanSep.csv.gz", ["iata"] + header)
            for row in rd: w.writerow([ap] + row)
    t.close(); print("weather combined")

if __name__ == "__main__":
    if "--combine" in sys.argv: combine()
    else:
        for a in sys.argv[1:]:
            y, m = (int(a[:4]), int(a[5:])) if "-" in a else (2025, int(a))
            filter_month(y, m)
