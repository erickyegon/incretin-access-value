"""Step 5.1: Medicaid State Drug Utilization Data (SDUD), 2018 -> latest released year.

Discovery: data.medicaid.gov metastore (titles "State Drug Utilization Data YYYY") - no URL is guessed.
Each yearly CSV is streamed to disk (sha256 computed), filtered with DuckDB to product_map NDCs, and the
raw CSV is then deleted to conserve disk (sha256 + bytes stay in the manifest so it can be re-downloaded and
verified). Idempotent: a year is skipped if its interim Parquet exists and the manifest holds a raw sha256.
Suppressed values stay NULL (never 0); XX national-total rows go to a separate file.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

import duckdb

from common import INTERIM, RAW, REF, get_logger, manifest_add, manifest_lookup, request

log = get_logger("03_sdud")
CATALOG = "https://data.medicaid.gov/api/1/metastore/schemas/dataset/items"
OUT = INTERIM / "sdud"
NAME_RX = ("OZEMP|WEGOV|RYBEL|MOUNJ|ZEPB|VICTOZ|SAXEN|TRULIC|BYETT|BYDUR|ADLYX|SOLIQ|XULTO|FOUNDAY|TANZEUM|"
           "LIRAGL|EXENAT|SEMAGL|TIRZEP|DULAGL|LIXISEN|ORFORG|ALBIGL")


def discover():
    items = request("GET", CATALOG, log=log, timeout=180, params={"show-reference-ids": "false"}).json()
    found = {}
    for i in items:
        m = re.fullmatch(r"State Drug Utilization Data (20\d\d)", i["title"])
        if m and int(m.group(1)) >= 2018:
            d = i["distribution"][0]["data"]
            found[int(m.group(1))] = dict(id=i["identifier"], url=d["downloadURL"], modified=i["modified"],
                                          dictionary=d.get("describedBy"))
    return dict(sorted(found.items()))


def stream_to(url, dest):
    h, n = hashlib.sha256(), 0
    with request("GET", url, log=log, stream=True, timeout=600) as r, open(dest, "wb") as f:
        for chunk in r.iter_content(1 << 20):
            f.write(chunk)
            h.update(chunk)
            n += len(chunk)
    return h.hexdigest(), n


def process(year, meta, ndcs):
    raw_dir = RAW / "sdud"
    raw_dir.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    states_pq, xx_pq = OUT / f"sdud_{year}_states.parquet", OUT / f"sdud_{year}_national_xx.parquet"
    fname = Path(meta["url"]).name
    m = manifest_lookup("sdud_raw", fname)
    if states_pq.exists() and m and m["sha256"] and meta["modified"] in (m["release_or_version"] or ""):
        log.info("skip %s (interim parquet present, raw sha256 recorded)", year)
        return
    raw = raw_dir / fname
    log.info("%s: downloading %s", year, meta["url"])
    sha, nbytes = stream_to(meta["url"], raw)
    con = duckdb.connect()
    con.execute(f"create table src as select * from read_csv('{raw.as_posix()}', all_varchar=true, normalize_names=true, strict_mode=false)")
    cols = [r[0] for r in con.execute("describe src").fetchall()]
    log.info("%s columns: %s", year, cols)
    total = con.execute("select count(*) from src").fetchone()[0]
    with open(raw, "rb") as fh:
        nlines = sum(chunk.count(b"\n") for chunk in iter(lambda: fh.read(1 << 24), b"")) - 1
    if total != nlines:  # embedded newlines are not expected in SDUD; any mismatch means rows were lost/merged
        raise RuntimeError(f"{year}: parsed {total} rows but file has {nlines} data lines")
    con.register("pm", __import__("pandas").DataFrame({"ndc": sorted(ndcs)}))
    sel = f"""
      select utilization_type, state, lpad(ndc, 11, '0') as ndc, labeler_code, product_code, package_size,
             try_cast(_year as integer) as year, try_cast(_quarter as integer) as quarter,
             lower(suppression_used) = 'true' as suppression_used, product_name,
             try_cast(units_reimbursed as double) as units_reimbursed,
             try_cast(number_of_prescriptions as double) as number_of_prescriptions,
             try_cast(total_amount_reimbursed as double) as total_amount_reimbursed,
             try_cast(medicaid_amount_reimbursed as double) as medicaid_amount_reimbursed,
             try_cast(non_medicaid_amount_reimbursed as double) as non_medicaid_amount_reimbursed
      from src"""
    con.execute(f"create table f as select * from ({sel}) where ndc in (select ndc from pm)")
    con.execute(f"""create table cand as select * from ({sel})
                    where ndc not in (select ndc from pm) and regexp_matches(upper(product_name), '{NAME_RX}')""")
    stats = dict(year=year, raw_file=fname, raw_bytes=nbytes, raw_sha256=sha, raw_rows=total,
                 source_modified=meta["modified"])
    stats["raw_rows_by_quarter"] = dict(con.execute(
        "select cast(_quarter as integer), count(*) from src group by 1 order by 1").fetchall())
    stats["raw_rows_state_XX"] = con.execute("select count(*) from src where state = 'XX'").fetchone()[0]
    stats["raw_suppressed_rows"] = con.execute(
        "select count(*) from src where lower(suppression_used) = 'true'").fetchone()[0]
    stats["filtered_rows"] = con.execute("select count(*) from f").fetchone()[0]
    stats["filtered_suppressed_rows"] = con.execute("select count(*) from f where suppression_used").fetchone()[0]
    stats["filtered_by_quarter"] = dict(con.execute("select quarter, count(*) from f group by 1 order by 1").fetchall())
    stats["filtered_states_rows"] = con.execute("select count(*) from f where state <> 'XX'").fetchone()[0]
    stats["filtered_xx_rows"] = con.execute("select count(*) from f where state = 'XX'").fetchone()[0]
    stats["filtered_null_prescriptions"] = con.execute(
        "select count(*) from f where number_of_prescriptions is null").fetchone()[0]
    stats["filtered_suppressed_but_nonnull_rx"] = con.execute(
        "select count(*) from f where suppression_used and number_of_prescriptions is not null").fetchone()[0]
    stats["unmatched_candidates"] = con.execute(
        "select ndc, trim(product_name), count(*) from cand group by 1, 2 order by 3 desc").fetchall()
    con.execute(f"copy (select * from f where state <> 'XX' order by state, quarter, ndc, utilization_type) "
                f"to '{states_pq.as_posix()}' (format parquet)")
    con.execute(f"copy (select * from f where state = 'XX' order by quarter, ndc, utilization_type) "
                f"to '{xx_pq.as_posix()}' (format parquet)")
    con.execute(f"copy (select * from cand order by ndc, state, quarter) to "
                f"'{(OUT / f'sdud_{year}_unmatched_name_candidates.parquet').as_posix()}' (format parquet)")
    (OUT / f"_validation_{year}.json").write_text(json.dumps(stats, indent=1, default=str), encoding="utf-8")
    con.close()
    manifest_add(dataset="sdud_raw", file_name=fname, source_url=meta["url"],
                 release_or_version=f"data.medicaid.gov dataset {meta['id']} modified {meta['modified']}",
                 years_covered=str(year), bytes=nbytes, sha256=sha, row_count=total,
                 notes="raw CSV deleted after filtering to product_map NDCs; re-download from source_url and verify sha256")
    for pq, key in ((states_pq, "filtered_states_rows"), (xx_pq, "filtered_xx_rows")):
        manifest_add(dataset="sdud", file_name=pq.name, source_url=meta["url"],
                     release_or_version=f"modified {meta['modified']}", years_covered=str(year),
                     bytes=pq.stat().st_size, sha256=hashlib.sha256(pq.read_bytes()).hexdigest(),
                     row_count=stats[key], notes="filtered to product_map NDCs; suppressed values NULL; XX kept separate"
                     if "xx" in pq.name else "filtered to product_map NDCs; suppressed values NULL (never 0)")
    raw.unlink()
    log.info("%s done: raw rows %d, kept %d, suppressed %d; raw deleted", year, total, stats["filtered_rows"],
             stats["filtered_suppressed_rows"])


def main():
    import pandas as pd
    ndcs = set(pd.read_csv(REF / "product_map.csv", dtype=str).ndc11)
    years = discover()
    (RAW / "sdud").mkdir(parents=True, exist_ok=True)
    (RAW / "sdud" / "_discovered_datasets.json").write_text(json.dumps(years, indent=1), encoding="utf-8")
    log.info("discovered SDUD years: %s", {y: v["modified"] for y, v in years.items()})
    only = [int(a) for a in sys.argv[1:]]
    for y, meta in years.items():
        if only and y not in only:
            continue
        process(y, meta, ndcs)


if __name__ == "__main__":
    main()
