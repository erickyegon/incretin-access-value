"""Phase 5 follow-up: apply Drugs@FDA evidence to product_map.csv (run after 02 and 06). Idempotent.
 - label_group verification from the Drugs@FDA label PDFs (22_fda_labels.py): Bydureon/Bydureon BCise labels = glycemic control, T2DM only.
 - labeler confirmation for SDUD_only NDCs: Drugs@FDA sponsor of the brand's application vs the labeler code's name in the FDA NDC directory."""
import pandas as pd

from common import INTERIM, REF, manifest_add, sha256_file

pm = pd.read_csv(REF / "product_map.csv", dtype=str)
chk = pd.read_csv(INTERIM / "drugsatfda" / "fda_label_indications_check.csv", dtype=str)
ok = {r.brand.title().replace(" Bcise", "").split()[0] for r in chk.itertuples() if r.mentions_glycemic_control == "True"}
sp = pd.read_csv(INTERIM / "drugsatfda" / "inscope_applications_summary.csv", dtype=str)
SP = {"Bydureon": "ASTRAZENECA AB", "Tanzeum": "GLAXOSMITHKLINE LLC", "Adlyxin": "SANOFI-AVENTIS US", "Ozempic": "NOVO"}
LAB = {"00310": "AstraZeneca", "00173": "GlaxoSmithKline", "00024": "Sanofi", "00169": "Novo"}
m = pm.brand.isin(["Bydureon"]) & (pm.label_verified == "N_expected_unverified")
pm.loc[m, "label_verified"] = "Y_drugsatfda_label"
pm.loc[m, "label_note"] = "VERIFIED from Drugs@FDA labels (Bydureon NDA 022200 and Bydureon BCise NDA 209210, both 2025-06-02): indicated to improve glycemic control in type 2 diabetes only"
for brand in ("Bydureon", "Adlyxin", "Tanzeum", "Ozempic"):
    s = (pm.source == "SDUD_only") & (pm.brand == brand)
    codes = pm[s].ndc11.str[:5]
    for i in pm[s].index:
        lc = pm.at[i, "ndc11"][:5]
        confirmed = lc in LAB and any(LAB[lc].split()[0].upper() in str(x).upper() for x in sp[sp.brands.fillna("").str.upper().str.contains(brand.upper())].SponsorName)
        note = ("labeler code confirmed: " + LAB[lc] + " is the Drugs@FDA sponsor of the brand's application") if confirmed else \
               "labeler code NOT confirmable: Drugs@FDA lists sponsors, not NDC labeler codes (66780 is not in the FDA directory)"
        pm.at[i, "label_note"] = str(pm.at[i, "label_note"]).split(" | labeler")[0] + " | labeler " + note
        pm.at[i, "label_verified"] = "Y_brand_label_drugsatfda" if brand in ("Bydureon", "Adlyxin", "Tanzeum", "Ozempic") else pm.at[i, "label_verified"]
pm.to_csv(REF / "product_map.csv", index=False, encoding="utf-8")
manifest_add(dataset="reference", file_name="product_map.csv", source_url="derived: FDA NDC Directory + RxNav + openFDA + SDUD-only + Drugs@FDA labels", release_or_version="after 23_update_map_after_drugsatfda",
             years_covered="current + historical NDCs", bytes=(REF / "product_map.csv").stat().st_size, sha256=sha256_file(REF / "product_map.csv"), row_count=len(pm),
             notes="Bydureon label_group verified from Drugs@FDA; SDUD_only labeler codes checked against Drugs@FDA sponsors")
print(pm.label_verified.value_counts().to_dict())
print(pm[pm.source == "SDUD_only"].groupby(["brand", "label_verified"]).size().to_string())
print(pm[pm.source == "SDUD_only"].label_note.str.extract(r"(labeler code[^|]*)")[0].value_counts().to_string())
