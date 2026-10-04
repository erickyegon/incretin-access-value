"""Correct is_combination in product_map.csv (run after 02, 06, 23, 25). Idempotent.
Found while building the dbt seeds: 02_build_product_map.py marks a product a combination only when it has more than one in-scope GLP-1/GIP ingredient,
so the insulin combinations (Soliqua = insulin glargine + lixisenatide, Xultophy = insulin degludec + liraglutide) were flagged FALSE for the four NDCs that
came from RxNorm (the other three were flagged TRUE from the FDA product file). Rule applied here: a product is a combination when its RxNorm name or
its FDA ingredient list contains insulin, or when its brand is Soliqua or Xultophy. None of the four corrected NDCs appears in SDUD or NADAC, so no
earlier count changes."""
import pandas as pd

from common import REF, manifest_add, sha256_file

f = REF / "product_map.csv"
pm = pd.read_csv(f, dtype=str)
insulin = pm.rx_name.fillna("").str.contains("insulin", case=False) | pm.ingredient_all.fillna("").str.contains("insulin", case=False)
brand = pm.brand.fillna("").isin(["Soliqua", "Xultophy"])
should = insulin | brand
changed = pm[should & (pm.is_combination != "TRUE")]
pm.loc[should, "is_combination"] = "TRUE"
pm.to_csv(f, index=False)
print("corrected to is_combination=TRUE:", changed.ndc11.tolist())
print("combination NDCs now:", int((pm.is_combination == "TRUE").sum()), "| brands:", sorted(pm[pm.is_combination == "TRUE"].brand.dropna().unique()))
manifest_add(dataset="reference", file_name="product_map.csv", source_url="26_fix_combination_flags.py", release_or_version="2026-10", years_covered="n/a",
             bytes=f.stat().st_size, sha256=sha256_file(f), row_count=len(pm), notes="is_combination corrected for 4 RxNorm-derived Soliqua/Xultophy NDCs")
