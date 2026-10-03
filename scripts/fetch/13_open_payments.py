"""Step 5.7: CMS Open Payments General Payment Data, program years found in the openpaymentsdata.cms.gov catalog.
Deviation from the brief (logged): the datastore API needs 27-65 s per 500 rows (about 200k Ozempic rows in 2024 alone), so each
yearly CSV is downloaded (sha256 recorded), filtered with DuckDB to rows where ANY of the five product-name fields contains an
in-scope brand or generic (case-insensitive), and then deleted. Idempotent per year. The exact matched strings are logged to
data/interim/open_payments/_matched_strings_<year>.csv.
Program years in the catalog: 2019-2025 (2018 is not in the current catalog)."""
import hashlib
import json
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

from common import INTERIM, RAW, REF, get_logger, manifest_add, manifest_lookup, request

log = get_logger("13_open_payments")
OUT = INTERIM / "open_payments"
CAT = "https://openpaymentsdata.cms.gov/api/1/metastore/schemas/dataset/items"
NAME_COLS = [f"Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_{i}" for i in range(1, 6)]
KEEP = ["Record_ID", "Program_Year", "Change_Type", "Dispute_Status_for_Publication", "Covered_Recipient_Type", "Covered_Recipient_NPI",
        "Covered_Recipient_Primary_Type_1", "Covered_Recipient_Specialty_1", "Recipient_State", "Recipient_Zip_Code",
        "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name", "Total_Amount_of_Payment_USDollars", "Date_of_Payment",
        "Nature_of_Payment_or_Transfer_of_Value", "Form_of_Payment_or_Transfer_of_Value"] + NAME_COLS + \
       [f"Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_{i}" for i in range(1, 6)] + \
       [f"Product_Category_or_Therapeutic_Area_{i}" for i in range(1, 6)]


def terms():
    pm = pd.read_csv(REF / "product_map.csv", dtype=str)
    t = set(x.lower() for x in pm.ingredient.dropna()) | set(x.lower() for x in pm.brand.dropna())
    t |= {"foundayo", "orforglipron", "albiglutide", "tanzeum", "adlyxin", "bydureon", "wegovy", "zepbound", "ozempic", "rybelsus", "mounjaro",
          "saxenda", "victoza", "trulicity", "byetta", "soliqua", "xultophy", "semaglutide", "tirzepatide", "liraglutide", "dulaglutide",
          "exenatide", "lixisenatide"}
    return sorted(x for x in t if len(x) >= 5)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (RAW / "open_payments").mkdir(parents=True, exist_ok=True)
    items = request("GET", CAT, log=log, timeout=300, params={"show-reference-ids": "false"}).json()
    ds = {}
    for i in items:
        m = re.fullmatch(r"(20\d\d) General Payment Data", i["title"])
        if m:
            ds[int(m.group(1))] = dict(id=i["identifier"], url=i["distribution"][0]["data"]["downloadURL"], modified=i["modified"])
    ds = dict(sorted(ds.items()))
    (RAW / "open_payments" / "_discovered_datasets.json").write_text(json.dumps(ds, indent=1), encoding="utf-8")
    log.info("discovered program years: %s", {y: v["modified"] for y, v in ds.items()})
    rx = "|".join(re.escape(t) for t in terms())
    only = [int(a) for a in sys.argv[1:]]
    for y, v in ds.items():
        if only and y not in only:
            continue
        pq = OUT / f"open_payments_{y}.parquet"
        fname = Path(v["url"]).name
        m = manifest_lookup("open_payments_raw", fname)
        if pq.exists() and m and v["modified"] in (m["release_or_version"] or ""):
            log.info("skip %s", y); continue
        raw = RAW / "open_payments" / fname
        h, n = hashlib.sha256(), 0
        log.info("%s: downloading %s", y, v["url"])
        with request("GET", v["url"], log=log, stream=True, timeout=900) as r, open(raw, "wb") as f:
            for ch in r.iter_content(1 << 22):
                f.write(ch); h.update(ch); n += len(ch)
        log.info("%s: %.2f GB downloaded", y, n / 1e9)
        con = duckdb.connect()
        con.execute("pragma threads=4")
        con.execute(f"create view src as select * from read_csv('{raw.as_posix()}', all_varchar=true, strict_mode=false, parallel=false)")
        cols = [r[0] for r in con.execute("describe src").fetchall()]
        keep = [c for c in KEEP if c in cols]
        missing = [c for c in KEEP if c not in cols]
        if missing:
            log.warning("%s: columns not found: %s", y, missing)
        namecols = [c for c in NAME_COLS if c in cols]
        cond = " or ".join(f"regexp_matches(lower(coalesce({c},'')), '{rx}')" for c in namecols)
        sel = ", ".join(f'"{c}"' for c in keep)
        con.execute(f"create table f as select {sel} from src where {cond}")
        total = con.execute("select count(*) from src").fetchone()[0]
        k = con.execute("select count(*) from f").fetchone()[0]
        # matched product name = first name field that matches; matched strings logged exactly
        pn = " , ".join(f"case when regexp_matches(lower(coalesce({c},'')), '{rx}') then {c} end" for c in namecols)
        con.execute(f"alter table f add column matched_product_name varchar")
        con.execute(f"update f set matched_product_name = coalesce({pn})")
        strings = con.execute("select matched_product_name, count(*) n, round(sum(try_cast(Total_Amount_of_Payment_USDollars as double))) usd from f group by 1 order by 2 desc").df()
        strings.to_csv(OUT / f"_matched_strings_{y}.csv", index=False, encoding="utf-8")
        con.execute(f"copy (select * from f order by Record_ID) to '{pq.as_posix()}' (format parquet)")
        con.close()
        manifest_add(dataset="open_payments_raw", file_name=fname, source_url=v["url"],
                     release_or_version=f"dataset {v['id']} modified {v['modified']}", years_covered=str(y), bytes=n,
                     sha256=h.hexdigest(), row_count=total, notes="raw CSV deleted after filtering; re-download and verify sha256")
        manifest_add(dataset="open_payments", file_name=pq.name, source_url=v["url"], release_or_version=f"modified {v['modified']}",
                     years_covered=str(y), bytes=pq.stat().st_size, sha256=hashlib.sha256(pq.read_bytes()).hexdigest(), row_count=k,
                     notes="rows where any of Name_of_Drug..._1..5 matches an in-scope brand/generic (case-insensitive); matched strings in _matched_strings_YYYY.csv")
        raw.unlink()
        log.info("%s done: %d raw rows, %d kept", y, total, k)


if __name__ == "__main__":
    main()
