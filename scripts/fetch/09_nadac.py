"""Step 5.6: NADAC weekly files, 2018 -> latest (data.medicaid.gov, datasets "NADAC (National Average Drug Acquisition
Cost) YYYY" found in the metastore). Yearly CSV streamed, filtered to product_map NDCs with DuckDB, raw deleted after
filtering (sha256/bytes in manifest). NADAC is a pharmacy acquisition-cost survey: not a net price, not a list price."""
import hashlib
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

from common import INTERIM, RAW, REF, get_logger, manifest_add, manifest_lookup, medicaid_catalog, request

log = get_logger("09_nadac")
OUT = INTERIM / "nadac"


def main():
    ndcs = pd.DataFrame({"ndc": sorted(set(pd.read_csv(REF / "product_map.csv", dtype=str).ndc11))})
    cat = {}
    for i in medicaid_catalog(log):
        m = re.fullmatch(r"NADAC \(National Average Drug Acquisition Cost\) (20\d\d)", i["title"])
        if m and int(m.group(1)) >= 2018:
            cat[int(m.group(1))] = i
    OUT.mkdir(parents=True, exist_ok=True)
    (RAW / "nadac").mkdir(parents=True, exist_ok=True)
    only = [int(a) for a in sys.argv[1:]]
    for y, i in sorted(cat.items()):
        if only and y not in only:
            continue
        url = i["distribution"][0]["data"]["downloadURL"]
        pq, fname = OUT / f"nadac_{y}.parquet", Path(url).name
        m = manifest_lookup("nadac_raw", fname)
        if pq.exists() and m and i["modified"] in m["release_or_version"]:
            log.info("skip %s", y); continue
        raw = RAW / "nadac" / fname
        h, n = hashlib.sha256(), 0
        with request("GET", url, log=log, stream=True, timeout=600) as r, open(raw, "wb") as f:
            for ch in r.iter_content(1 << 20):
                f.write(ch); h.update(ch); n += len(ch)
        con = duckdb.connect()
        con.register("pm", ndcs)
        con.execute(f"create table src as select * from read_csv('{raw.as_posix()}', all_varchar=true, normalize_names=true, strict_mode=false, parallel=false)")
        total = con.execute("select count(*) from src").fetchone()[0]
        with open(raw, "rb") as fh:
            nl = sum(c.count(b"\n") for c in iter(lambda: fh.read(1 << 24), b"")) - 1
        with open(raw, "rb") as fh:  # last line may lack a trailing newline
            fh.seek(-1, 2)
            nl += 0 if fh.read(1) == b"\n" else 1
        assert total == nl, f"{y}: parsed {total} != lines {nl}"
        cols = [r[0] for r in con.execute("describe src").fetchall()]
        log.info("%s columns %s", y, cols)
        con.execute(f"""create table f as select lpad(ndc, 11, '0') ndc, ndc_description, try_cast(nadac_per_unit as double) nadac_per_unit,
            pricing_unit, coalesce(try_strptime(effective_date, '%m/%d/%Y'), try_cast(effective_date as date))::date effective_date,
            classification_for_rate_setting, explanation_code, pharmacy_type_indicator,
            coalesce(try_strptime(as_of_date, '%m/%d/%Y'), try_cast(as_of_date as date))::date as_of_date,
            effective_date as effective_date_raw, as_of_date as as_of_date_raw
            from src where lpad(ndc, 11, '0') in (select ndc from pm)""")
        k = con.execute("select count(*) from f").fetchone()[0]
        nbad = con.execute("select count(*) from f where effective_date is null or as_of_date is null or nadac_per_unit is null").fetchone()[0]
        assert nbad == 0, f"{y}: {nbad} rows with unparsed date or price"
        con.execute(f"copy (select * from f order by ndc, effective_date) to '{pq.as_posix()}' (format parquet)")
        manifest_add(dataset="nadac_raw", file_name=fname, source_url=url,
                     release_or_version=f"dataset {i['identifier']} modified {i['modified']}", years_covered=str(y),
                     bytes=n, sha256=h.hexdigest(), row_count=total,
                     notes="raw deleted after filtering; re-download and verify sha256. NADAC = acquisition cost survey, not net/list price")
        manifest_add(dataset="nadac", file_name=pq.name, source_url=url, release_or_version=f"modified {i['modified']}",
                     years_covered=str(y), bytes=pq.stat().st_size, sha256=hashlib.sha256(pq.read_bytes()).hexdigest(),
                     row_count=k, notes="filtered to product_map NDCs")
        con.close(); raw.unlink()
        log.info("%s done: %d raw rows, %d kept", y, total, k)


if __name__ == "__main__":
    main()
