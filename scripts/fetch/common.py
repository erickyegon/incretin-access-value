"""Shared helpers for the fetch scripts: retrying HTTP, checksummed downloads, manifest, logging."""
import csv
import datetime as dt
import hashlib
import logging
import shutil
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
INTERIM = ROOT / "data" / "interim"
REF = ROOT / "data" / "reference"
LOGS = ROOT / "logs"
MANIFEST = ROOT / "data" / "manifest.csv"
MANIFEST_COLS = ["dataset", "file_name", "source_url", "release_or_version", "years_covered",
                 "date_accessed", "bytes", "sha256", "row_count", "notes"]
UA = {"User-Agent": "incretin-access-value-research/0.1 (keyegon@gmail.com)"}

_session = requests.Session()
_session.headers.update(UA)


def get_logger(name):
    LOGS.mkdir(exist_ok=True)
    log = logging.getLogger(name)
    if not log.handlers:
        log.setLevel(logging.INFO)
        fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
        fh = logging.FileHandler(LOGS / f"{name}.log", encoding="utf-8")
        sh = logging.StreamHandler(sys.stdout)
        for h in (fh, sh):
            h.setFormatter(fmt)
            log.addHandler(h)
    return log


def request(method, url, log=None, retries=6, backoff=2.0, timeout=120, **kw):
    """HTTP with exponential backoff; honours Retry-After on 429/503."""
    for i in range(retries):
        try:
            r = _session.request(method, url, timeout=timeout, **kw)
            if r.status_code in (429, 500, 502, 503, 504):
                wait = float(r.headers.get("Retry-After", backoff ** (i + 1)))
                if log:
                    log.warning("HTTP %s on %s; sleeping %.0fs", r.status_code, url, wait)
                time.sleep(wait)
                continue
            r.raise_for_status()
            return r
        except requests.RequestException as e:
            if getattr(e.response, "status_code", None) in (400, 401, 403, 404) or i == retries - 1:
                raise
            wait = backoff ** (i + 1)
            if log:
                log.warning("%s on %s; retry in %.0fs", e, url, wait)
            time.sleep(wait)


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while b := f.read(chunk):
            h.update(b)
    return h.hexdigest()


def manifest_rows():
    if not MANIFEST.exists():
        return []
    with open(MANIFEST, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def manifest_add(**row):
    """Upsert by (dataset, file_name)."""
    rows = [r for r in manifest_rows()
            if not (r["dataset"] == row["dataset"] and r["file_name"] == row["file_name"])]
    row.setdefault("date_accessed", dt.date.today().isoformat())
    rows.append({c: row.get(c, "") for c in MANIFEST_COLS})
    rows.sort(key=lambda r: (r["dataset"], r["file_name"]))
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=MANIFEST_COLS)
        w.writeheader()
        w.writerows(rows)


def manifest_lookup(dataset, file_name):
    for r in manifest_rows():
        if r["dataset"] == dataset and r["file_name"] == file_name:
            return r


def download(url, dest, dataset, log, release="", years="", notes="", keep=True):
    """Idempotent streamed download. Skips if file exists and matches manifest sha256.
    keep=False deletes the file after hashing (manifest still records sha256/bytes)."""
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    m = manifest_lookup(dataset, dest.name)
    if dest.exists() and m and sha256_file(dest) == m["sha256"]:
        log.info("skip (verified) %s", dest.name)
        return dest
    free = shutil.disk_usage(dest.parent).free / 1e9
    log.info("downloading %s (free disk %.1f GB)", url, free)
    tmp = dest.with_suffix(dest.suffix + ".part")
    with request("GET", url, log=log, stream=True, timeout=300) as r:
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
    tmp.replace(dest)
    manifest_add(dataset=dataset, file_name=dest.name, source_url=url, release_or_version=release,
                 years_covered=years, bytes=dest.stat().st_size, sha256=sha256_file(dest), notes=notes)
    log.info("saved %s (%d bytes)", dest.name, dest.stat().st_size)
    return dest


def medicaid_catalog(log=None):
    """data.medicaid.gov metastore dataset list (cached in data/raw/medicaid_catalog.json for the day)."""
    import json
    f = RAW / "medicaid_catalog.json"
    if f.exists() and dt.date.fromtimestamp(f.stat().st_mtime) == dt.date.today():
        return json.loads(f.read_text(encoding="utf-8"))
    items = request("GET", "https://data.medicaid.gov/api/1/metastore/schemas/dataset/items", log=log,
                    timeout=180, params={"show-reference-ids": "false"}).json()
    f.write_text(json.dumps(items), encoding="utf-8")
    return items
