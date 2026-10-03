"""Step 5.5: Medicare Part D Spending by Drug and Medicaid Spending by Drug (data.cms.gov, found in catalog by title).
Each release is one wide table with year-suffixed columns (2020-2024 in the 2026 release). Full CSV downloaded, filtered
locally to in-scope generic/brand names, saved wide plus long (one row per drug-manufacturer-year)."""
import re

import pandas as pd

from common import INTERIM, RAW, cms_catalog, download, get_logger, manifest_add, sha256_file

log = get_logger("08_spending_by_drug")
RX = re.compile(r"semaglutide|tirzepatide|liraglutide|dulaglutide|exenatide|lixisenatide|orforglipron|albiglutide|"
                r"ozempic|wegovy|rybelsus|mounjaro|zepbound|victoza|saxenda|trulicity|byetta|bydureon|adlyxin|"
                r"soliqua|xultophy|foundayo|tanzeum", re.I)
TITLES = {"partd": "Medicare Part D Spending by Drug :", "medicaid": "Medicaid Spending by Drug :"}


def main():
    out, raw = INTERIM / "spending_by_drug", RAW / "spending_by_drug"
    out.mkdir(parents=True, exist_ok=True)
    cat = cms_catalog(log)
    for key, prefix in TITLES.items():
        d = next(x for x in cat if x["title"].startswith(prefix))
        csv = next(x for x in d["distribution"] if x.get("format") == "CSV")["downloadURL"]
        p = download(csv, raw / csv.rsplit("/", 1)[1], f"spending_by_drug_{key}_raw", log,
                     release=f"{d['title']} catalog modified {d.get('modified')}", years="2020-2024")
        df = pd.read_csv(p, dtype=str)
        sel = df[df.Gnrc_Name.fillna("").str.contains(RX) | df.Brnd_Name.fillna("").str.contains(RX)].copy()
        for c in sel.columns:
            if re.search(r"(Spndng|Unts|Clms|Benes|Spnd_Per|Chg_|CAGR|Tot_Mftr)", c):
                sel[c] = pd.to_numeric(sel[c], errors="coerce")
        sel.to_parquet(out / f"{key}_spending_by_drug_wide.parquet", index=False)
        ids = ["Brnd_Name", "Gnrc_Name", "Tot_Mftr", "Mftr_Name"]
        recs = []
        for y in range(2013, 2031):
            cols = {c: c[: -len(str(y)) - 1] for c in sel.columns if c.endswith(f"_{y}")}
            if cols:
                t = sel[ids + list(cols)].rename(columns=cols)
                t["year"] = y
                recs.append(t)
        long = pd.concat(recs)
        long.to_parquet(out / f"{key}_spending_by_drug_long.parquet", index=False)
        for f, n in ((f"{key}_spending_by_drug_wide.parquet", len(sel)), (f"{key}_spending_by_drug_long.parquet", len(long))):
            manifest_add(dataset=f"spending_by_drug_{key}", file_name=f, source_url=csv, release_or_version=f"{d['title']}",
                         years_covered=f"{long.year.min()}-{long.year.max()}", bytes=(out / f).stat().st_size,
                         sha256=sha256_file(out / f), row_count=n, notes="filtered to in-scope generic/brand; NULL for non-numeric")
        log.info("%s: %d drug rows, years %s-%s, outlier flags present: %s", key, len(sel), long.year.min(), long.year.max(),
                 "Outlier_Flag" in long.columns)
        print(key, len(sel), sorted(sel.Brnd_Name.unique()))


if __name__ == "__main__":
    main()
