"""Helper for coverage research (step 5.3): fetch a URL (or its Wayback snapshot nearest a date) into
data/raw/coverage_sources/<state>/, convert PDF/HTML to text, log URL + access date in a sources log.
usage: python covtool.py STATE URL [URL...]         plain fetch
       python covtool.py STATE wb:YYYYMMDD:URL      Wayback snapshot nearest YYYYMMDD
       python covtool.py grep STATE REGEX [ctx]     grep all saved texts for STATE"""
import csv
import datetime as dt
import io
import re
import sys

import pypdf
import requests

from common import RAW, request

D = RAW / "coverage_sources"
LOG = D / "_sources_log.csv"


def to_text(r):
    if r.content[:4] == b"%PDF":
        rd = pypdf.PdfReader(io.BytesIO(r.content))
        return "\n".join((p.extract_text() or "") + f"\n[[p{i+1}]]" for i, p in enumerate(rd.pages)), "pdf"
    t = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", r.text)
    t = re.sub(r"(?s)<[^>]+>", " ", t)
    import html
    return re.sub(r"[ \t\r\f\v]+", " ", html.unescape(t)), "html"


def grab(state, spec):
    url, snap = spec, ""
    if spec.startswith("wb:"):
        _, ts, url = spec.split(":", 2)
        fetch_url = f"https://web.archive.org/web/{ts}id_/{url}"
    else:
        fetch_url = url
    try:
        r = request("GET", fetch_url, timeout=120, allow_redirects=True)
    except requests.HTTPError as e:
        if e.response is None or e.response.status_code != 403:
            raise
        # some state sites reject non-browser agents; retry once with a browser user agent (public documents)
        r = requests.get(fetch_url, timeout=120, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}, allow_redirects=True)
        r.raise_for_status()
    if snap or spec.startswith("wb:"):
        m = re.search(r"/web/(\d{14})", r.url)
        snap = m.group(1) if m else ts
        print("snapshot", snap)
    text, kind = to_text(r)
    name = re.sub(r"\W+", "_", url.split("//")[-1])[-50:] + "_" + __import__("hashlib").md5(url.encode()).hexdigest()[:6] + (f"__wb{snap}" if snap else "")
    (D / state).mkdir(parents=True, exist_ok=True)
    (D / state / (name + "." + kind)).write_bytes(r.content)
    (D / state / (name + ".txt")).write_text(text, encoding="utf-8")
    new = not LOG.exists()
    with open(LOG, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["state", "source_url", "snapshot_timestamp", "date_accessed", "saved_as", "chars"])
        w.writerow([state, url, snap, dt.date.today().isoformat(), f"{state}/{name}.{kind}", len(text)])
    print("saved", f"{state}/{name}.txt", len(text), "chars")


def grep(state, rx, ctx=200):
    for f in sorted((D / state).glob("*.txt")):
        t = f.read_text(encoding="utf-8")
        for m in list(re.finditer(rx, t, re.I))[:6]:
            print(f"[{f.name}] ...", re.sub(r"\s+", " ", t[max(0, m.start() - ctx):m.end() + ctx]), "\n")


if __name__ == "__main__":
    if sys.argv[1] == "grep":
        grep(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 200)
    else:
        for u in sys.argv[2:]:
            try:
                grab(sys.argv[1], u)
            except Exception as e:
                print("FAIL", u, e)
