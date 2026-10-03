"""Step 5.4: Medicare Part D Prescribers - by Provider and Drug (data.cms.gov data API, server-side filter on Gnrc_Name).
Year datasets are found in the data.cms.gov catalog by title. Years 2013..latest are queried; years with no in-scope
rows are reported. Rows are deduplicated across filter terms. Suppressed values are kept as NULL with the CMS flags."""
import json
import re

import pandas as pd

from common import INTERIM, RAW, cms_catalog, cms_query, get_logger, manifest_add, sha256_file

log = get_logger("07_partd_prescribers")
TITLE = "Medicare Part D Prescribers - by Provider and Drug"
TERMS = ["semaglutide", "tirzepatide", "liraglutide", "dulaglutide", "exenatide", "lixisenatide", "orforglipron", "albiglutide"]
NUM = ["Tot_Clms", "Tot_30day_Fills", "Tot_Day_Suply", "Tot_Drug_Cst", "Tot_Benes", "GE65_Tot_Clms",
       "GE65_Tot_30day_Fills", "GE65_Tot_Drug_Cst", "GE65_Tot_Day_Suply", "GE65_Tot_Benes"]


def main():
    out, raw = INTERIM / "partd_prescribers", RAW / "partd_prescribers"
    out.mkdir(parents=True, exist_ok=True)
    raw.mkdir(parents=True, exist_ok=True)
    ds = [d for d in cms_catalog(log) if d["title"].startswith(TITLE + " :")]
    summary = {}
    for d in sorted(ds, key=lambda d: d["title"][-10:]):
        year = int(d["distribution"][0]["temporal"][0]["startDate"][:4])
        apis = [x["accessURL"] for x in d["distribution"] if x.get("format") == "API"]
        f = out / f"partd_prescribers_{year}.parquet"
        if f.exists():
            summary[year] = len(pd.read_parquet(f)); log.info("skip %s", year); continue
        rows = []
        for t in TERMS:
            rows += cms_query(apis[0], "Gnrc_Name", t, log)
        df = pd.DataFrame(rows).drop_duplicates()
        (raw / f"partd_prescribers_{year}.json").write_text(json.dumps(rows), encoding="utf-8")
        if len(df):
            for c in NUM:
                df[c] = pd.to_numeric(df[c].replace("", None), errors="coerce")   # blank/suppressed -> NULL, never 0
            df["data_year"] = year
            df.to_parquet(f, index=False)
        summary[year] = len(df)
        log.info("%s: %d rows (api %s, catalog modified %s)", year, len(df), apis[0], d.get("modified"))
        if len(df):
            manifest_add(dataset="partd_prescribers", file_name=f.name, source_url=apis[0],
                         release_or_version=f"data.cms.gov catalog modified {d.get('modified')}; {len(apis)} API distribution(s), first used",
                         years_covered=str(year), bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(df),
                         notes="server-side filter Gnrc_Name CONTAINS " + "/".join(TERMS) + "; suppressed -> NULL with CMS flags")
    print(summary)


if __name__ == "__main__":
    main()
