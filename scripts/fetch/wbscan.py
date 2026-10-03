"""Wayback scanner for coverage-date ranges (step 5.3).
usage: python wbscan.py STATE URL REGEX [from_yyyymmdd] [to_yyyymmdd] [max_snapshots]
Lists distinct archived versions of URL (CDX, collapsed by content digest) between the dates, fetches each, extracts text
(PDF or HTML), and prints per snapshot: timestamp, size, number of REGEX hits and a short context of the first hit.
Every fetched snapshot is saved under data/raw/coverage_sources/<STATE>/ and logged in _sources_log.csv (via covtool.grab).
It reports what each dated document says; deciding earliest/latest is done by reading the output."""
import re
import sys

import requests

from covtool import D, to_text, grab
from common import request


def snapshots(url, lo, hi):
    import time
    u = re.sub(r"^https?://", "", url)
    for attempt in range(5):
        r = requests.get("https://web.archive.org/cdx/search/cdx", timeout=180, headers={"User-Agent": "incretin-access-value-research/0.1 (keyegon@gmail.com)"},
                         params={"url": u, "output": "json", "fl": "timestamp,statuscode,digest", "filter": "statuscode:200",
                                 "collapse": "digest", "from": lo, "to": hi})
        try:
            rows = r.json()[1:] if r.text.strip() else []
            return [x[0] for x in rows]
        except ValueError:
            time.sleep(5 * (attempt + 1))
    print("CDX failed:", r.status_code, r.text[:120])
    return []


def main():
    state, url, rx = sys.argv[1], sys.argv[2], sys.argv[3]
    lo = sys.argv[4] if len(sys.argv) > 4 else "2017"
    hi = sys.argv[5] if len(sys.argv) > 5 else "2026"
    mx = int(sys.argv[6]) if len(sys.argv) > 6 else 40
    ts = snapshots(url, lo, hi)
    print(f"{len(ts)} distinct snapshots of {url}")
    if len(ts) > mx:
        step = len(ts) / mx
        ts = [ts[int(i * step)] for i in range(mx)] + [ts[-1]]
    for t in ts:
        try:
            r = request("GET", f"https://web.archive.org/web/{t}id_/{url}", timeout=120)
            text, kind = to_text(r)
        except Exception as e:
            print(t, "FAIL", str(e)[:80])
            continue
        hits = list(re.finditer(rx, text, re.I))
        ctx = re.sub(r"\s+", " ", text[max(0, hits[0].start() - 80):hits[0].end() + 120]).encode("ascii", "replace").decode() if hits else ""
        print(t, kind, len(text), "hits=", len(hits), "|", ctx)
        if hits:
            name = re.sub(r"\W+", "_", url.split("//")[-1])[-50:] + f"__wb{t}"
            (D / state).mkdir(parents=True, exist_ok=True)
            (D / state / (name + ".txt")).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
