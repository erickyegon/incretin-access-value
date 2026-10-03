"""Step 5.9: NHANES August 2021-August 2023 (suffix _L) and 2017-March 2020 pre-pandemic (prefix P_), official XPT files.
File links are read from the NCHS data pages (no URL is guessed). Components: DEMO, BMX, BPXO (oscillometric blood pressure),
BPQ, GHB, DIQ, MCQ, RXQ_RX, plus the RXQ_DRUG lookup (1988-2020). The documentation page of each file is saved so the weight to use
can be read from NCHS text (see docs). Also checks whether the 2021-2023 prescription file names semaglutide or tirzepatide."""
import re

import pandas as pd

from common import INTERIM, RAW, download, get_logger, manifest_add, request, sha256_file

log = get_logger("17_nhanes")
PAGE = "https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx"
STEMS = {"DEMO", "BMX", "BPXO", "BPQ", "GHB", "DIQ", "MCQ", "RXQ_RX"}
CYCLES = {"2021-2023": "_L", "2017-2020": "P_"}
COMPONENTS = ["Demographics", "Examination", "Laboratory", "Questionnaire"]


def wanted(stem, cycle):
    if cycle == "2021-2023":
        return stem.endswith("_L") and stem[:-2] in STEMS
    return stem.startswith("P_") and stem[2:] in STEMS or stem == "RXQ_DRUG"


def main():
    out, raw = INTERIM / "nhanes", RAW / "nhanes"
    out.mkdir(parents=True, exist_ok=True)
    found = {}
    for cycle in CYCLES:
        for comp in COMPONENTS:
            h = request("GET", PAGE, log=log, params={"Component": comp, "Cycle": cycle}, timeout=200).text
            for r in re.findall(r"<tr[^>]*>(.*?)</tr>", h, re.S | re.I):
                m = re.search(r'href="([^"]+\.(?:xpt|XPT))"', r)
                if not m:
                    continue
                stem = m.group(1).split("/")[-1][:-4]
                if wanted(stem, cycle):
                    doc = re.search(r'href="([^"]+\.htm)"', r, re.I)
                    found[stem] = dict(cycle=cycle, xpt="https://wwwn.cdc.gov" + m.group(1), doc=("https://wwwn.cdc.gov" + doc.group(1)) if doc else None,
                                       title=re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", r))[:100])
    log.info("files found: %s", sorted(found))
    summary = []
    for stem, v in sorted(found.items()):
        p = download(v["xpt"], raw / f"{stem}.xpt", "nhanes_raw", log, release=f"NCHS NHANES {v['cycle']}", years=v["cycle"], notes=v["title"])
        df = pd.read_sas(p, format="xport", encoding="utf-8")
        df.to_parquet(out / f"{stem}.parquet", index=False)
        manifest_add(dataset="nhanes", file_name=f"{stem}.parquet", source_url=v["xpt"], release_or_version=f"NCHS NHANES {v['cycle']}",
                     years_covered=v["cycle"], bytes=(out / f"{stem}.parquet").stat().st_size, sha256=sha256_file(out / f"{stem}.parquet"),
                     row_count=len(df), notes=v["title"])
        if v["doc"]:
            try:
                d = request("GET", v["doc"], log=log, timeout=200)
                (raw / f"{stem}_doc.htm").write_bytes(d.content)
                manifest_add(dataset="nhanes_doc", file_name=f"{stem}_doc.htm", source_url=v["doc"], release_or_version=f"NCHS NHANES {v['cycle']}",
                             years_covered=v["cycle"], bytes=len(d.content), sha256=sha256_file(raw / f"{stem}_doc.htm"), notes="NCHS documentation page")
            except Exception as e:
                log.warning("doc %s failed: %s", stem, e)
        summary.append((stem, v["cycle"], len(df), df.shape[1]))
    print(pd.DataFrame(summary, columns=["file", "cycle", "rows", "cols"]).to_string(index=False))

    # prescription medicines: does 2021-2023 name semaglutide / tirzepatide?
    for stem in ("RXQ_RX_L", "P_RXQ_RX"):
        if stem not in found:
            print(stem, "NOT FOUND"); continue
        df = pd.read_parquet(out / f"{stem}.parquet")
        txtcols = [c for c in df.columns if df[c].dtype == object]
        print(f"\n{stem}: columns {list(df.columns)[:14]} ... text columns {txtcols}")
        pat = r"semaglut|tirzepat|ozempic|wegovy|rybelsus|mounjaro|zepbound|liraglut|dulaglut|exenat|saxenda|victoza|trulicity"
        for c in txtcols:
            s = df[c].astype(str)
            hit = df[s.str.contains(pat, case=False, na=False)]
            if len(hit):
                print(f"  {c}: {len(hit)} rows; values:", hit[c].astype(str).str.strip().value_counts().head(12).to_dict())
        # drug-name lookup for 2021-2023 (generic names live in RXDDRUG?)
        if "RXDDRUG" in df.columns:
            print("  RXDDRUG distinct:", df.RXDDRUG.nunique(), "| sample:", df.RXDDRUG.astype(str).str.strip().value_counts().head(5).to_dict())
    if "RXQ_DRUG" in found:
        d = pd.read_parquet(out / "RXQ_DRUG.parquet")
        print("\nRXQ_DRUG lookup: rows", len(d), "columns", list(d.columns))
        for c in d.columns:
            if d[c].dtype == object:
                hit = d[d[c].astype(str).str.contains("SEMAGLUT|TIRZEPAT|LIRAGLUT|DULAGLUT|EXENAT", case=False, na=False)]
                if len(hit):
                    print(" ", c, len(hit), hit[c].astype(str).str.strip().value_counts().head(8).to_dict())


if __name__ == "__main__":
    main()
