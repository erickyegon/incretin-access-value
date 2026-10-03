"""Step 5.10: MEPS Household Component - latest two years (2023, 2024): Full-Year Consolidated, Prescribed Medicines event file,
Medical Conditions. File numbers (HC-xxx) come from AHRQ's PUFID.csv and download links from each file's detail page (no guessing).
Stata (.dta) zips are downloaded, converted to Parquet (full files kept), documentation and codebook PDFs saved.
MEPS conditions carry 3-character ICD-10-CM codes (ICD10CDX), not full codes."""
import io
import re
import zipfile
from urllib.parse import urljoin

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, request, sha256_file

log = get_logger("18_meps")
BASE = "https://meps.ahrq.gov/mepsweb/data_stats/"


def main():
    out, raw = INTERIM / "meps", RAW / "meps"
    out.mkdir(parents=True, exist_ok=True)
    cat = download("https://meps.ahrq.gov/mepsweb/data_stats/download_data/pufs/PUFID.csv", raw / "PUFID.csv", "meps_catalog", log,
                   release="AHRQ PUFID.csv", years="1996-2024")
    d = pd.read_csv(cat, dtype=str, encoding="utf-8-sig")
    d.columns = [c.strip() for c in d.columns]
    d = d[d.YEAR.isin(["2023", "2024"]) & d.ABBREV.isin(["FYC", "RX", "COND"])]
    rows = []
    for _, r in d.iterrows():
        h = request("GET", r.URL, log=log, timeout=200).text
        links = sorted(set(re.findall(r'href="([^"]+\.(?:zip|pdf))"', h)))
        def pick(pat):
            m = [l for l in links if re.search(pat, l)]
            return urljoin(r.URL, m[0]) if m else None
        puf = r.PUFID.lower().replace("hc-", "h")
        zurl = pick(rf"{puf}dta\.zip")
        z = download(zurl, raw / f"{puf}dta.zip", "meps_raw", log, release=f"MEPS {r.PUFID} {r.DATA}", years=r.YEAR, notes=r.DATA)
        with zipfile.ZipFile(z) as zf:
            name = next(n for n in zf.namelist() if n.lower().endswith(".dta"))
            df = pd.read_stata(io.BytesIO(zf.read(name)), convert_categoricals=False)
        df.columns = [c.upper() for c in df.columns]
        pq = out / f"meps_{r.ABBREV.lower()}_{r.YEAR}_{puf}.parquet"
        df.to_parquet(pq, index=False)
        manifest_add(dataset="meps", file_name=pq.name, source_url=zurl, release_or_version=f"MEPS {r.PUFID} {r.DATA}", years_covered=r.YEAR,
                     bytes=pq.stat().st_size, sha256=sha256_file(pq), row_count=len(df), notes=f"{r.DATA}; full file kept")
        for kind in ("doc", "cb"):
            u = pick(rf"{puf}{kind}\.pdf")
            if u:
                download(u, raw / f"{puf}{kind}.pdf", "meps_doc", log, release=f"MEPS {r.PUFID}", years=r.YEAR, notes=f"{kind} pdf")
        rows.append((r.ABBREV, r.YEAR, r.PUFID, len(df), df.shape[1]))
        if r.ABBREV == "COND":
            c = [x for x in df.columns if "ICD" in x]
            print(r.YEAR, "COND ICD columns:", c, "| distinct ICD10CDX:", df["ICD10CDX"].nunique(), "| sample:", df["ICD10CDX"].astype(str).str.strip().value_counts().head(5).to_dict())
            print("   length of codes:", df["ICD10CDX"].astype(str).str.strip().str.len().value_counts().to_dict())
        if r.ABBREV == "RX":
            nm = [x for x in df.columns if x in ("RXNAME", "RXDRGNAM")]
            col = nm[0] if nm else None
            if col:
                s = df[col].astype(str)
                hit = df[s.str.contains("OZEMPIC|WEGOVY|RYBELSUS|MOUNJARO|ZEPBOUND|TRULICITY|VICTOZA|SAXENDA|BYETTA|SEMAGLUT|TIRZEP", case=False, na=False)]
                print(r.YEAR, "RX in-scope name rows:", len(hit), hit[col].astype(str).str.strip().value_counts().head(8).to_dict())
    print(pd.DataFrame(rows, columns=["file", "year", "HC", "rows", "cols"]).to_string(index=False))


if __name__ == "__main__":
    main()
