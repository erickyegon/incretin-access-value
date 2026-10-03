"""Add SDUD-only NDCs (in SDUD under in-scope brand names, absent from FDA directory and RxNorm) to product_map.csv.
Run AFTER 02_build_product_map.py and 03_sdud.py. Idempotent.
Classification is from labeler code + SDUD product name only (not label text):
  Ozempic -> semaglutide, Bydureon -> exenatide, Adlyxin -> lixisenatide, Tanzeum -> albiglutide; all label_group=diabetes.
Confirm labeler codes against Drugs@FDA in phase 5. Also normalises is_combination to TRUE/FALSE.
Merges the matching SDUD rows from *_unmatched_name_candidates.parquet into sdud_YYYY_states / _national_xx."""
import glob
import re

import duckdb
import pandas as pd

from common import INTERIM, REF, get_logger, manifest_add, sha256_file

log = get_logger("06_add_sdud_only_ndcs")
BRANDS = {"OZEMPIC": ("semaglutide", "Ozempic"), "BYDUREON": ("exenatide", "Bydureon"),
          "ADLYXIN": ("lixisenatide", "Adlyxin"), "TANZEUM": ("albiglutide", "Tanzeum")}
LAB = {"00169": "Novo Nordisk", "00310": "AstraZeneca Pharmaceuticals LP", "00024": "Sanofi-Aventis U.S. LLC",
       "00173": "GlaxoSmithKline LLC"}  # names from FDA NDC directory product.txt by labeler code; 66780 not listed -> blank
SD = INTERIM / "sdud"


def main():
    pm = pd.read_csv(REF / "product_map.csv", dtype=str)
    pm["is_combination"] = pm.is_combination.map({"Y": "TRUE", "N": "FALSE", "TRUE": "TRUE", "FALSE": "FALSE"})
    cand = duckdb.sql(f"select ndc, upper(trim(product_name)) pn, year, quarter from "
                      f"read_parquet('{SD.as_posix()}/sdud_*_unmatched_name_candidates.parquet')").df()
    new = []
    for ndc, g in cand.groupby("ndc"):
        if ndc in set(pm.ndc11):
            continue
        key = next(k for k in BRANDS if g.pn.str.startswith(k).any())
        ing, brand = BRANDS[key]
        new.append(dict(ndc11=ndc, ingredient=ing, brand=brand, labeler_name=LAB.get(ndc[:5]),
                        first_seen=f"{g.year.min()}{int(g[g.year == g.year.min()].quarter.min()) * 3 - 2:02d}",
                        last_seen=f"{g.year.max()}{int(g[g.year == g.year.max()].quarter.max()) * 3:02d}",
                        ndc_status="SDUD_ONLY", label_group="diabetes", label_verified="N_sdud_name_inferred",
                        label_note=("classified from labeler code + SDUD product name; confirm labeler code in Drugs@FDA (phase 5)"
                                    + ("; albiglutide (Tanzeum) discontinued, outside the brief's ingredient list, added by instruction"
                                       if ing == "albiglutide" else "")
                                    + ("" if LAB.get(ndc[:5]) else "; labeler code not in FDA directory")),
                        source="SDUD_only", is_combination="FALSE", ingredient_all=ing))
    if new:
        pm = pd.concat([pm, pd.DataFrame(new)], ignore_index=True)
        log.info("added %d SDUD-only NDCs", len(new))
    assert not pm.ndc11.duplicated().any()
    pm = pm.sort_values(["ingredient", "brand", "ndc11"], na_position="last")
    pm.to_csv(REF / "product_map.csv", index=False, encoding="utf-8")
    manifest_add(dataset="reference", file_name="product_map.csv", source_url="derived: FDA NDC Directory + RxNav + openFDA labels + SDUD-only NDCs",
                 release_or_version="rebuilt after 06_add_sdud_only_ndcs", years_covered="current + historical NDCs",
                 bytes=(REF / "product_map.csv").stat().st_size, sha256=sha256_file(REF / "product_map.csv"),
                 row_count=len(pm), notes="source=SDUD_only rows are name/labeler-inferred; see data dictionary")
    # merge candidate rows into main SDUD files
    for cf in sorted(glob.glob(str(SD / "sdud_*_unmatched_name_candidates.parquet"))):
        y = re.search(r"sdud_(\d{4})_", cf).group(1)
        for flag, name in (("<>", f"sdud_{y}_states.parquet"), ("=", f"sdud_{y}_national_xx.parquet")):
            f = SD / name
            df = duckdb.sql(f"select * from read_parquet('{cf}') where state {flag} 'XX'").df()
            base = pd.read_parquet(f)
            add = df[~df.ndc.isin(set(base.ndc))]
            if len(add):
                out = pd.concat([base, add]).sort_values(["state", "quarter", "ndc", "utilization_type"])
                out.to_parquet(f, index=False)
                log.info("%s: +%d rows", name, len(add))
                manifest_add(dataset="sdud", file_name=name, source_url="see sdud_raw rows", release_or_version="incl. SDUD_only NDCs",
                             years_covered=y, bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(out),
                             notes="filtered to product_map NDCs incl. SDUD_only; suppressed NULL; XX separate"
                             + ("; 2026 Q1 PRELIMINARY" if y == "2026" else ""))
    print(pm.groupby(["ingredient", "source"]).size().to_string())


if __name__ == "__main__":
    main()
