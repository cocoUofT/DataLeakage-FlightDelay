"""As-of historical delay rates and same-day congestion for the closed-network flights.

Every feature for flight i uses ONLY outcomes known before its cutoff
    c_i = scheduled departure (UTC) - 120 minutes,
with an assumed BTS outcome reporting lag of 0 (operational knowledge).

Usage (from project root, Python 3.9+ standard library):
  python3 scripts/02_history_features.py events pre   # 2024 Jul-Dec history -> event part
  python3 scripts/02_history_features.py events dev   # 2025 Jan-Jun
  python3 scripts/02_history_features.py events test  # 2025 Jul-Sep
  python3 scripts/02_history_features.py features     # -> data/processed/closed10/features_history_{dev,test}.csv.gz
  python3 scripts/02_history_features.py check 300    # brute-force recomputation for a random sample

Event times (minutes since 1970-01-01 UTC):
  scheduled dep (UTC) = FlightDate + CRSDepTime in the ORIGIN's IANA zone (config/airport_timezones_all.csv)
  scheduled arr (UTC) = scheduled dep + CRSElapsedTime
  actual arr (UTC)    = scheduled arr + ArrDelay        -> time ArrDel15 becomes known
  actual dep (UTC)    = scheduled dep + DepTime - CRSDepTime (minute difference wrapped to [-120, 1320))
Only completed, non-diverted flights with ArrDel15 observed enter the rates.

Features, for windows W in {182d, 28d, 7d} (columns hr_<group>_<W>_n / _rate):
  hr_origin_*   flights departing the same origin, arrival known in [c_i - W, c_i)
  hr_dest_*     flights arriving at the same destination
  hr_carrier_*  same carrier (among flights touching the 10 airports, i.e. the history files)
  hr_route_*    same origin-destination pair
  *_n = number of flights, *_rate = share with ArrDel15 = 1 (empty if n = 0)
  sd_origin_n, sd_origin_dep15_rate: flights from the same origin on the same local FlightDate
      that actually departed before c_i, and their share departing >= 15 min late.
  rc_dest_3h_n, rc_dest_3h_rate: flights that ARRIVED at the destination in [c_i - 3h, c_i),
      and their share arriving >= 15 min late (recent congestion at the destination).
"""
from array import array
import bisect, csv, datetime as dt, gzip, io, os, random, sys
from zoneinfo import ZoneInfo

D = "data/processed/closed10"
PARTS = "data/raw/bts/parts"
HIST = {"pre": "history_10airports_pre_2024JulDec", "dev": "history_10airports_dev_2025JanJun",
        "test": "history_10airports_test_2025JulSep"}
STUDY = {"dev": "flights_closed10_dev_2025JanJun", "test": "flights_closed10_test_2025JulSep"}
WINDOWS = {"182d": 182 * 1440, "28d": 28 * 1440, "7d": 7 * 1440}
W = WINDOWS["182d"]  # longest lookback
RECENT_DEST = 180   # minutes: recent arrivals at the destination
CUTOFF = 120
EPOCH = dt.datetime(1970, 1, 1, tzinfo=dt.timezone.utc)
TZ = {r["iata"]: ZoneInfo(r["iana_timezone"]) for r in csv.DictReader(open("config/airport_timezones_all.csv"))}

def reader(path):
    return csv.DictReader(io.TextIOWrapper(gzip.open(path), newline=""))

def hhmm(s):
    return int(s[:-2] or 0) * 60 + int(s[-2:])

def sched_dep_utc(date, crs, origin):
    d = dt.date.fromisoformat(date); mins = hhmm(crs)
    if mins == 1440: d += dt.timedelta(days=1); mins = 0
    local = dt.datetime(d.year, d.month, d.day, mins // 60, mins % 60, tzinfo=TZ[origin])
    return int((local - EPOCH).total_seconds() // 60)

def events(period):
    os.makedirs(PARTS, exist_ok=True)
    out = io.TextIOWrapper(gzip.GzipFile(f"{PARTS}/events_{period}.csv.gz", "wb", mtime=0), newline="")
    w = csv.writer(out)
    w.writerow(["origin", "dest", "carrier", "date", "dep_known", "dep15", "arr_known", "arr15"])
    n = 0
    for r in reader(f"{D}/{HIST[period]}.csv.gz"):
        if r["eligible"] != "1" or not r["CRSElapsedTime"] or not r["ArrDelay"] or not r["DepTime"]:
            continue
        dep = sched_dep_utc(r["FlightDate"], r["CRSDepTime"], r["Origin"])
        diff = (hhmm(r["DepTime"]) - hhmm(r["CRSDepTime"]) + 120) % 1440 - 120
        arr_known = dep + int(float(r["CRSElapsedTime"])) + int(float(r["ArrDelay"]))
        w.writerow([r["Origin"], r["Dest"], r["Reporting_Airline"], r["FlightDate"], dep + diff,
                    int(float(r["DepDel15"])), arr_known, int(float(r["ArrDel15"]))])
        n += 1
    out.close(); print(period, "events:", n)

def iter_events():
    for p in ("pre", "dev", "test"):
        with io.TextIOWrapper(gzip.open(f"{PARTS}/events_{p}.csv.gz"), newline="") as f:
            rd = csv.reader(f); next(rd)
            for o, d, c, date, dk, d15, ak, a15 in rd:
                yield o, d, c, date, int(dk), int(d15), int(ak), int(a15)

def build_index():
    """Stream events into compact arrays: value = time * 2 + outcome, so one sort orders by time."""
    groups, sameday = {}, {}
    def add(store, key, v):
        a = store.get(key)
        if a is None: a = store[key] = array("q")
        a.append(v)
    for o, d, c, date, dk, d15, ak, a15 in iter_events():
        v = ak * 2 + a15
        add(groups, ("origin", o), v); add(groups, ("dest", d), v)
        add(groups, ("carrier", c), v); add(groups, ("route", o, d), v)
        add(sameday, (o, date), dk * 2 + d15)
    def prefix(a):
        a = sorted(a); t = array("q", (x >> 1 for x in a)); cum = array("l", [0]); s = 0
        for x in a: s += x & 1; cum.append(s)
        return t, cum
    return ({k: prefix(v) for k, v in groups.items()}, {k: prefix(v) for k, v in sameday.items()})

def window(idx, key, lo, hi):
    if key not in idx: return 0, 0
    t, cum = idx[key]; a = bisect.bisect_left(t, lo); b = bisect.bisect_left(t, hi)
    return b - a, cum[b] - cum[a]

def flight_features(r, groups, sameday):
    c = sched_dep_utc(r["FlightDate"], r["CRSDepTime"], r["Origin"]) - CUTOFF
    o, d, car = r["Origin"], r["Dest"], r["Reporting_Airline"]
    row = {"flight_id": r["flight_id"], "cutoff_utc": (EPOCH + dt.timedelta(minutes=c)).strftime("%Y-%m-%d %H:%M")}
    for name, key in (("origin", ("origin", o)), ("dest", ("dest", d)), ("carrier", ("carrier", car)),
                      ("route", ("route", o, d))):
        for wname, wlen in WINDOWS.items():
            n, k = window(groups, key, c - wlen, c)
            row[f"hr_{name}_{wname}_n"] = n; row[f"hr_{name}_{wname}_rate"] = round(k / n, 5) if n else ""
    n, k = window(sameday, (o, r["FlightDate"]), -10**12, c)
    row["sd_origin_n"] = n; row["sd_origin_dep15_rate"] = round(k / n, 5) if n else ""
    n, k = window(groups, ("dest", d), c - RECENT_DEST, c)
    row["rc_dest_3h_n"] = n; row["rc_dest_3h_rate"] = round(k / n, 5) if n else ""
    return row

def features():
    groups, sameday = build_index()
    for period, fn in STUDY.items():
        out = io.TextIOWrapper(gzip.GzipFile(f"{D}/features_history_{period}.csv.gz", "wb", mtime=0), newline="")
        w = None; n = 0
        for r in reader(f"{D}/{fn}.csv.gz"):
            row = flight_features(r, groups, sameday)
            if w is None: w = csv.DictWriter(out, fieldnames=list(row)); w.writeheader()
            w.writerow(row); n += 1
        out.close(); print(period, "flights:", n)

def check(k):
    """Recompute features for k random study flights by one linear pass over all events (no index)."""
    random.seed(2112)
    flights = [r for p in STUDY.values() for r in reader(f"{D}/{p}.csv.gz")]
    sample = random.sample(flights, k)
    feats = {}
    for p in STUDY:
        for r in reader(f"{D}/features_history_{p}.csv.gz"): feats[r["flight_id"]] = r
    info = []
    for r in sample:
        c = sched_dep_utc(r["FlightDate"], r["CRSDepTime"], r["Origin"]) - CUTOFF
        info.append(dict(id=r["flight_id"], c=c, o=r["Origin"], d=r["Dest"], car=r["Reporting_Airline"],
                         date=r["FlightDate"], acc={x: [0, 0] for x in
                             [f"{g}_{w}" for g in ("origin", "dest", "carrier", "route") for w in WINDOWS] + ["sd", "rc"]}))
    by_o, by_d, by_c = {}, {}, {}
    for f in info:
        by_o.setdefault(f["o"], []).append(f); by_d.setdefault(f["d"], []).append(f); by_c.setdefault(f["car"], []).append(f)
    for o, d, car, date, dk, d15, ak, a15 in iter_events():
        for f in by_o.get(o, ()):
            for w, wl in WINDOWS.items():
                if f["c"] - wl <= ak < f["c"]:
                    f["acc"][f"origin_{w}"][0] += 1; f["acc"][f"origin_{w}"][1] += a15
                    if d == f["d"]: f["acc"][f"route_{w}"][0] += 1; f["acc"][f"route_{w}"][1] += a15
            if date == f["date"] and dk < f["c"]: f["acc"]["sd"][0] += 1; f["acc"]["sd"][1] += d15
        for f in by_d.get(d, ()):
            for w, wl in WINDOWS.items():
                if f["c"] - wl <= ak < f["c"]: f["acc"][f"dest_{w}"][0] += 1; f["acc"][f"dest_{w}"][1] += a15
            if f["c"] - RECENT_DEST <= ak < f["c"]: f["acc"]["rc"][0] += 1; f["acc"]["rc"][1] += a15
        for f in by_c.get(car, ()):
            for w, wl in WINDOWS.items():
                if f["c"] - wl <= ak < f["c"]: f["acc"][f"carrier_{w}"][0] += 1; f["acc"][f"carrier_{w}"][1] += a15
    bad = 0
    for f in info:
        got = feats[f["id"]]
        for name in f["acc"]:
            n, y = f["acc"][name]
            col_n, col_r = {"sd": ("sd_origin_n", "sd_origin_dep15_rate"),
                            "rc": ("rc_dest_3h_n", "rc_dest_3h_rate")}.get(name, (f"hr_{name}_n", f"hr_{name}_rate"))
            ok = int(got[col_n]) == n and ((n == 0 and got[col_r] == "") or (n > 0 and abs(float(got[col_r]) - y / n) < 1e-5))
            if not ok: bad += 1; print("MISMATCH", f["id"], name, got[col_n], n)
    print(f"checked {k} flights x {len(info[0]['acc'])} features, mismatches: {bad}")

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "events": events(sys.argv[2])
    elif cmd == "features": features()
    elif cmd == "check": check(int(sys.argv[2]))
