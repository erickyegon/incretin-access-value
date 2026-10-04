"""NHANES health insurance files for Module B/E: HIQ_L (August 2021-August 2023) and P_HIQ (2017-March 2020), official XPT files.
Links are read from the NCHS data pages (nothing is guessed); each file and its documentation page are saved, converted to interim Parquet and
recorded in the manifest. Run scripts/load/load_raw.py afterwards to load them (stem lower-cased: nhanes_hiq_l, nhanes_p_hiq)."""
import re

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, request, sha256_file

log = get_logger("28_nhanes_hiq")
PAGE = "https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx"
CYCLES = {"2021-2023": "HIQ_L", "2017-2020": "P_HIQ"}


def main():
    out, raw = INTERIM / "nhanes", RAW / "nhanes"
    out.mkdir(parents=True, exist_ok=True)
    for cycle, stem in CYCLES.items():
        h = request("GET", PAGE, log=log, params={"Component": "Questionnaire", "Cycle": cycle}, timeout=200).text
        found = None
        for r in re.findall(r"<tr[^>]*>(.*?)</tr>", h, re.S | re.I):
            m = re.search(r'href="([^"]+\.(?:xpt|XPT))"', r)
            if m and m.group(1).split("/")[-1][:-4] == stem:
                doc = re.search(r'href="([^"]+\.htm)"', r, re.I)
                found = ("https://wwwn.cdc.gov" + m.group(1), ("https://wwwn.cdc.gov" + doc.group(1)) if doc else None,
                         re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", r))[:100])
        if not found:
            print(f"{stem}: NOT RELEASED / NOT FOUND on the NCHS {cycle} questionnaire page")
            continue
        url, doc, title = found
        p = download(url, raw / f"{stem}.xpt", "nhanes_raw", log, release=f"NCHS NHANES {cycle}", years=cycle, notes=title)
        df = pd.read_sas(p, format="xport", encoding="utf-8")
        df.to_parquet(out / f"{stem}.parquet", index=False)
        manifest_add(dataset="nhanes", file_name=f"{stem}.parquet", source_url=url, release_or_version=f"NCHS NHANES {cycle}", years_covered=cycle,
                     bytes=(out / f"{stem}.parquet").stat().st_size, sha256=sha256_file(out / f"{stem}.parquet"), row_count=len(df), notes=title)
        if doc:
            d = request("GET", doc, log=log, timeout=200)
            (raw / f"{stem}_doc.htm").write_bytes(d.content)
            manifest_add(dataset="nhanes_doc", file_name=f"{stem}_doc.htm", source_url=doc, release_or_version=f"NCHS NHANES {cycle}", years_covered=cycle,
                         bytes=len(d.content), sha256=sha256_file(raw / f"{stem}_doc.htm"), notes="NCHS documentation page")
        print(f"{stem}: {len(df)} rows, columns {list(df.columns)}")


if __name__ == "__main__":
    main()
