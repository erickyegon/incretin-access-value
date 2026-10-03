"""Resolve labeler code 66780 and add `labeler_verified` to product_map.csv (run after 02, 06, 23). Idempotent.
66780 is named by the FDA NDC *excluded* products file (LABELERNAME 'Amylin Pharmaceuticals, LLC': Symlin, SymlinPen, Byetta 66780-210);
RxNav lists NDC 66780021904 as OBSOLETE 'exenatide 2 MG Injection [Bydureon]' (RxCUI 1242968).
labeler_verified = true when the labeler name comes from an FDA NDC directory file (current, excluded or unfinished) via the 5-digit labeler code, or from
the Drugs@FDA sponsor check (SDUD-only rows); false when no source names the labeler (none remain)."""
import duckdb
import pandas as pd

from common import RAW, REF, manifest_add, sha256_file

pm = pd.read_csv(REF / "product_map.csv", dtype=str)
exc = duckdb.sql(f"""select distinct split_part(PRODUCTNDC,'-',1) lc, LABELERNAME from read_csv('{(RAW / 'fda_ndc/ndc_excluded/Products_excluded.txt').as_posix()}',
    delim='\t', header=true, all_varchar=true, ignore_errors=true, quote='')""").df()
exc["lc"] = exc.lc.str.zfill(5)
cur = duckdb.sql(f"""select distinct split_part(PRODUCTNDC,'-',1) lc, LABELERNAME from read_csv('{(RAW / 'fda_ndc/ndctext/product.txt').as_posix()}',
    delim='\t', header=true, all_varchar=true, ignore_errors=true, quote='')""").df()
cur["lc"] = cur.lc.str.zfill(5)
unf = duckdb.sql(f"""select distinct split_part(PRODUCTNDC,'-',1) lc, LABELERNAME from read_csv('{(RAW / 'fda_ndc/ndc_unfinished/unfinished_product.txt').as_posix()}',
    delim='	', header=true, all_varchar=true, ignore_errors=true, quote='')""").df()
unf["lc"] = unf.lc.str.zfill(5)
names = {}
for df, src in ((cur, "FDA NDC directory (current)"), (exc, "FDA NDC excluded products file"), (unf, "FDA NDC unfinished products file")):
    for r in df.itertuples():
        names.setdefault(r.lc, (r.LABELERNAME, src))
if "labeler_verified" not in pm:
    pm["labeler_verified"] = ""
if "labeler_source" not in pm:
    pm["labeler_source"] = ""
for i, r in pm.iterrows():
    lc = r.ndc11[:5]
    if pd.isna(r.labeler_name) or r.labeler_name == "":
        if lc in names:
            pm.at[i, "labeler_name"] = names[lc][0]
            pm.at[i, "labeler_verified"] = "true"
            pm.at[i, "labeler_source"] = f"{names[lc][1]}: labeler code {lc} = {names[lc][0]}"
        else:
            pm.at[i, "labeler_verified"] = "false"
            pm.at[i, "labeler_source"] = "no FDA NDC file or Drugs@FDA/RxNav source names this labeler"
    else:
        ok = True
        if r.source == "SDUD_only" and "NOT confirmable" in str(r.label_note):
            ok = False
        pm.at[i, "labeler_verified"] = "true" if ok else "false"
        pm.at[i, "labeler_source"] = ("FDA NDC directory product record / labeler-code lookup" if r.source != "SDUD_only" else "labeler code checked against Drugs@FDA sponsor of the brand's application")
# the former 'not confirmable' SDUD-only row is now resolved through the excluded file
m = pm.ndc11.str.startswith("66780")
pm.loc[m, "labeler_verified"] = "true"
pm.loc[m, "labeler_source"] = "FDA NDC excluded products file names labeler code 66780 = 'Amylin Pharmaceuticals, LLC' (Byetta 66780-210, Symlin); RxNav: NDC 66780021904 = exenatide 2 MG Injection [Bydureon], OBSOLETE"
pm.to_csv(REF / "product_map.csv", index=False, encoding="utf-8")
manifest_add(dataset="reference", file_name="product_map.csv", source_url="derived: FDA NDC Directory + RxNav + openFDA + SDUD-only + Drugs@FDA labels + labeler resolution", release_or_version="after 25_resolve_labeler_66780",
             years_covered="current + historical NDCs", bytes=(REF / "product_map.csv").stat().st_size, sha256=sha256_file(REF / "product_map.csv"), row_count=len(pm),
             notes="labeler_verified and labeler_source added; 66780 = Amylin Pharmaceuticals, LLC")
print(pm.labeler_verified.value_counts().to_dict())
print(pm[m][["ndc11", "ingredient", "brand", "labeler_name", "source", "ndc_status"]].to_string(index=False))
