"""SDUD reporting completeness (Module C step 0). For every state x quarter x utilization type, across ALL drugs, count rows, suppressed rows,
distinct NDCs and (unsuppressed) prescriptions from the full yearly SDUD files, 2018 Q1 to 2026 Q1. The files are re-downloaded one at a time
from the URLs in the manifest, their sha256 checked against the manifest, streamed through DuckDB (never loaded into PostgreSQL) and deleted.
Output: dbt/seeds/sdud_reporting.csv (aggregates only: no cell-level values) and data/interim/sdud_reporting/_checks.json.
A year whose sha256 differs from the manifest is still aggregated but listed under sha256_mismatch (the source revises files)."""
import hashlib
import json
from pathlib import Path

import duckdb
import pandas as pd

from common import INTERIM, RAW, ROOT, get_logger, manifest_add, manifest_lookup, request, sha256_file

log = get_logger("27_sdud_reporting")
OUT = INTERIM / "sdud_reporting"
SEED = ROOT / "dbt" / "seeds" / "sdud_reporting.csv"
YEARS = range(2018, 2027)


def stream_to(url, dest):
    h, n = hashlib.sha256(), 0
    with request("GET", url, log=log, stream=True, timeout=600) as r, open(dest, "wb") as f:
        for chunk in r.iter_content(1 << 20):
            f.write(chunk)
            h.update(chunk)
            n += len(chunk)
    return h.hexdigest(), n


def manifest_rows():
    m = pd.read_csv(ROOT / "data" / "manifest.csv", dtype=str)
    m = m[m.dataset == "sdud_raw"]
    return {int(r.years_covered): r for r in m.itertuples()}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (RAW / "sdud").mkdir(parents=True, exist_ok=True)
    rows = manifest_rows()
    parts, checks = [], {"sha256_mismatch": [], "rows": {}}
    for y in YEARS:
        r = rows[y]
        part = OUT / f"reporting_{y}.parquet"
        if part.exists():
            parts.append(pd.read_parquet(part))
            continue
        raw = RAW / "sdud" / Path(r.source_url).name
        log.info("%s: downloading %s", y, r.source_url)
        sha, nbytes = stream_to(r.source_url, raw)
        if sha != r.sha256:
            log.warning("%s: sha256 differs from manifest (%s vs %s)", y, sha, r.sha256)
            checks["sha256_mismatch"].append(dict(year=y, downloaded=sha, manifest=r.sha256, bytes=nbytes, manifest_bytes=r.bytes))
        con = duckdb.connect()
        df = con.execute(f"""
            select state, try_cast(_year as integer) as year, try_cast(_quarter as integer) as quarter, utilization_type,
                   count(*) as n_rows,
                   count(*) filter (where lower(suppression_used) = 'true') as n_suppressed_rows,
                   count(distinct ndc) as n_ndcs,
                   coalesce(sum(try_cast(number_of_prescriptions as double)) filter (where lower(suppression_used) <> 'true'), 0) as rx_observed
            from read_csv('{raw.as_posix()}', all_varchar=true, normalize_names=true, strict_mode=false)
            group by 1, 2, 3, 4""").df()
        con.close()
        checks["rows"][y] = int(df.n_rows.sum())
        df.to_parquet(part, index=False)
        parts.append(df)
        raw.unlink()
    allp = pd.concat(parts, ignore_index=True)
    allp = allp[(allp.year * 10 + allp.quarter) <= 20261].sort_values(["state", "year", "quarter", "utilization_type"])
    allp.to_csv(SEED, index=False)
    (OUT / "_checks.json").write_text(json.dumps(checks, indent=1, default=str), encoding="utf-8")
    manifest_add(dataset="seeds", file_name="sdud_reporting.csv", source_url="full yearly SDUD files (manifest sdud_raw rows)", release_or_version="dbt seed",
                 years_covered="2018-2026Q1", bytes=SEED.stat().st_size, sha256=sha256_file(SEED), row_count=len(allp),
                 notes="all-drug rows, suppressed rows, distinct NDCs and unsuppressed prescriptions per state x quarter x utilization type; aggregates only")
    print("rows:", len(allp), "| sha256 mismatches:", [c["year"] for c in checks["sha256_mismatch"]])


if __name__ == "__main__":
    main()
