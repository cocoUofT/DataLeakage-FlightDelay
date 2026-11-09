"""Download IEM ASOS/METAR reports for the 10 study airports (2024-12-31 to 2025-10-01 UTC).

Same fields and report types (routine 3 + special 4) as scripts/00_download_weather.R.
Usage (from project root):  python3 scripts/01a_download_weather_10airports.py [--refresh]
Writes data/raw/weather/<IATA>_2025JanSep_weather.csv and data/raw/weather/manifest_10airports.csv
"""
import csv, datetime, hashlib, os, sys, time, urllib.parse, urllib.request

AIRPORTS = csv.DictReader(open("config/airports.csv"))
FIELDS = ["tmpf", "dwpf", "sknt", "gust", "vsby", "p01i", "wxcodes", "skyc1", "skyl1", "metar"]
STS, ETS = "2024-12-31T00:00:00Z", "2025-10-01T00:00:00Z"
OUT = "data/raw/weather"
refresh = "--refresh" in sys.argv
os.makedirs(OUT, exist_ok=True)
manifest = []
for ap in AIRPORTS:
    params = [("station", ap["iem_station"]), ("network", ap["iem_network"]), ("sts", STS), ("ets", ETS),
              ("tz", "Etc/UTC"), ("format", "onlycomma"), ("latlon", "no"), ("elev", "no"),
              ("missing", "M"), ("trace", "T"), ("direct", "no"), ("report_type", "3"), ("report_type", "4")]
    params += [("data", f) for f in FIELDS]
    url = "https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py?" + urllib.parse.urlencode(params)
    path = f"{OUT}/{ap['iata']}_2025JanSep_weather.csv"
    if refresh or not os.path.exists(path) or os.path.getsize(path) == 0:
        for attempt in range(3):
            try:
                data = urllib.request.urlopen(url, timeout=170).read()
                lines = data.decode().splitlines()
                if len(lines) > 1000 and lines[0].startswith("station,valid") and "p01i" in lines[0]:
                    break
            except Exception as e:  # network hiccup -> retry
                print("retry", ap["iata"], e)
            time.sleep(5)
        else:
            sys.exit(f"Download failed for {ap['iata']}: {url}")
        with open(path, "wb") as f:
            f.write(data)
        time.sleep(2)  # be polite to IEM
    rows = list(csv.DictReader(open(path)))
    assert all(r["station"] == ap["iem_station"] for r in rows)
    manifest.append(dict(iata=ap["iata"], file=path, rows=len(rows),
                         first_utc=rows[0]["valid"], last_utc=rows[-1]["valid"],
                         md5=hashlib.md5(open(path, "rb").read()).hexdigest(), url=url,
                         retrieved_utc=datetime.datetime.utcfromtimestamp(os.path.getmtime(path)).isoformat() + "Z"))
    print(ap["iata"], len(rows), rows[0]["valid"], rows[-1]["valid"])
with open(f"{OUT}/manifest_10airports.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(manifest[0])); w.writeheader(); w.writerows(manifest)
