"""Write the dbt seed CSVs in dbt/seeds from data/reference (and the Census reference files). Idempotent; seeds are small, public-sourced.
Seeds: product_map, product_groups, medicaid_obesity_coverage (one row per coverage spell), icd10_value_sets, trial_inputs, states.
(label_events is written by build_label_events.py; quarters is a dbt model.)"""
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "fetch"))
from common import manifest_add, sha256_file  # noqa: E402

REF = ROOT / "data" / "reference"
SEEDS = ROOT / "dbt" / "seeds"
SEEDS.mkdir(parents=True, exist_ok=True)


def save(df, name, source, note):
    f = SEEDS / f"{name}.csv"
    df.to_csv(f, index=False, encoding="utf-8")
    manifest_add(dataset="seeds", file_name=f"{name}.csv", source_url=source, release_or_version="dbt seed", years_covered="n/a", bytes=f.stat().st_size,
                 sha256=sha256_file(f), row_count=len(df), notes=note)
    print(f"{name}: {len(df)} rows")


# ---- states (Census Bureau reference files) -----------------------------------------------------------------------
g = pd.read_excel(ROOT / "data/raw/census/state-geocodes-v2020.xlsx", header=None, dtype=str, skiprows=6)
g.columns = ["region", "division", "fips", "name"]
regions = {r.region: r.name.replace(" Region", "") for r in g.itertuples() if r.fips == "00" and r.division == "0"}
divs = {(r.region, r.division): r.name.replace(" Division", "") for r in g.itertuples() if r.fips == "00" and r.division != "0"}
g = g[g.fips != "00"].copy()
g["census_region"] = g.region.map(regions)
g["census_division"] = [divs.get((a, b)) for a, b in zip(g.region, g.division)]
n = pd.read_csv(ROOT / "data/raw/census/national_state2020.txt", sep="|", dtype=str)
st = n.merge(g[["fips", "census_region", "census_division"]], left_on="STATEFP", right_on="fips", how="left").drop(columns="fips")
st = st.rename(columns={"STATE": "state_code", "STATEFP": "fips", "STATE_NAME": "state_name"})
st["is_territory"] = ~st.fips.astype(int).isin(list(range(1, 57)))
st["is_dc"] = st.state_code.eq("DC")
st["in_panel"] = ~st.is_territory
save(st[["state_code", "fips", "state_name", "census_region", "census_division", "is_territory", "is_dc", "in_panel"]].sort_values("fips"), "states",
     "https://www2.census.gov/geo/docs/reference/codes2020/national_state2020.txt ; https://www2.census.gov/programs-surveys/popest/geographies/2020/state-geocodes-v2020.xlsx",
     "Census Bureau 2020 state FIPS/ANSI and region/division codes; territories flagged")

# ---- product map (as-is, text-typed in seeds.yml) ---------------------------------------------------------------------
pm = pd.read_csv(REF / "product_map.csv", dtype=str)
save(pm, "product_map", "data/reference/product_map.csv (FDA NDC Directory + RxNav + openFDA + SDUD-only + Drugs@FDA)", "NDC-level map; labeler_verified added 2026-10")

# ---- product groups ---------------------------------------------------------------------------------------------------
def group(r):
    if r.is_combination == "TRUE":
        return "combination_excluded", "insulin/GLP-1 combination product (Soliqua, Xultophy)"
    b = (r.brand or "").lower()
    if r.label_group == "obesity":
        if b in ("wegovy", "zepbound"):
            return "obesity_wz", "Wegovy (every formulation) and Zepbound: the exposure product group"
        if b == "saxenda" or (b == "" and r.ingredient == "liraglutide"):
            return "obesity_saxenda", "Saxenda and Saxenda-type generic liraglutide (obesity-labelled): analysed separately"
        return "obesity_other", "other obesity-labelled brand (e.g. Foundayo)"
    return "diabetes_glp1", "diabetes-labelled incretin, not a combination: negative control and leakage outcome"
pm["brand"] = pm.brand.fillna("")
pg = pm[["brand", "ingredient", "label_group", "is_combination"]].drop_duplicates()
pg[["product_group", "rationale"]] = pg.apply(lambda r: pd.Series(group(r)), axis=1)
pg["product_group_key"] = pg.apply(lambda r: (r.brand if r.brand else "GENERIC") + "|" + r.ingredient + "|" + r.label_group, axis=1)
save(pg.sort_values(["product_group", "brand", "ingredient"]), "product_groups", "rules in docs/warehouse.md (decided 2026-10-03)", "every brand/generic x ingredient x label group mapped to one analysis group")

# ---- reference tables copied as-is --------------------------------------------------------------------------------------
save(pd.read_csv(REF / "icd10_value_sets.csv", dtype=str, keep_default_na=False), "icd10_value_sets", "data/reference/icd10_value_sets.csv (CMS ICD-10-CM FY2027)", "value sets E11, E66, Z68 + placeholder")
save(pd.read_csv(REF / "trial_inputs.csv", dtype=str), "trial_inputs", "data/reference/trial_inputs.csv", "empty template")

# ---- coverage spells --------------------------------------------------------------------------------------------------------
c = pd.read_csv(REF / "medicaid_obesity_coverage.csv", dtype=str).fillna("")
AB = {"Delaware": "DE", "Kansas": "KS", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO", "North Carolina": "NC",
      "Rhode Island": "RI", "Tennessee": "TN", "Utah": "UT", "Virginia": "VA", "Wisconsin": "WI", "California": "CA", "New Hampshire": "NH", "Pennsylvania": "PA", "South Carolina": "SC"}
CATEGORY_SPA = {"Mississippi", "Tennessee"}   # decision 2026-10-03: category-level SPAs
rows = []
for stn, grp in c.groupby("state", sort=False):
    first = grp.iloc[0]
    for k, (_, r) in enumerate(grp.iterrows(), start=1):
        spell_start_low = spell_start_high = r.coverage_start or ""
        precision = "day" if len(r.coverage_start) == 10 else ("month" if len(r.coverage_start) == 7 else "")
        if k == 1:   # first spell carries the exposure start information (Wegovy/Zepbound)
            low, high = first.start_earliest, first.start_latest
            if first.start_wegovy_zepbound:
                low = high = first.start_wegovy_zepbound
                precision = "day"
            elif low and high and low[:7] == high[:7] and low.endswith("-01") and high[8:10] in ("28", "29", "30", "31"):
                precision = "month"
            elif low and high:
                precision = "range"
            if stn == "Kansas":   # decision 2026-10-03: start quarter 2021Q3 from the 2021-07-21 DUR Board decision
                low = high = "2021-07-21"
                precision = "day"
            spell_start_low, spell_start_high = low, high
        else:
            spell_start_low = spell_start_high = r.coverage_start
            precision = "day"
        end = r.coverage_end
        if k == 1 and len(grp) > 1:
            end = r.coverage_end
        rows.append(dict(state_code=AB[stn], state_name=stn, spell_id=f"{AB[stn]}-{k}", spell_no=k, products_covered="Wegovy;Zepbound (obesity indication)" if k else "",
                         coverage_end=end, start_date_low=spell_start_low, start_date_high=spell_start_high, start_precision=precision,
                         analysis_group=first.analysis_group if first.analysis_group else "sensitivity", category_level_spa=str(stn in CATEGORY_SPA).lower(),
                         kansas_flag=str(stn == "Kansas").lower(), confidence=r.confidence, end_confidence=r.end_confidence,
                         first_treated_quarter_documented=first.first_treated_quarter if k == 1 else "", first_full_quarter_documented=first.first_full_quarter if k == 1 else "",
                         source_url=r.source_url, notes=(r.notes or "")[:400]))
cov = pd.DataFrame(rows)
cov.loc[cov.spell_no > 1, "analysis_group"] = cov.loc[cov.spell_no == 1].set_index("state_code").analysis_group.reindex(cov.loc[cov.spell_no > 1].state_code).values
save(cov, "medicaid_obesity_coverage", "data/reference/medicaid_obesity_coverage.csv (restructured to one row per coverage spell)",
     "one row per spell; start_date_low/high equal for dated starts; Kansas start = 2021-07-21 by decision; MA month precision")
print(cov[["state_code", "spell_no", "start_date_low", "start_date_high", "start_precision", "coverage_end", "analysis_group", "category_level_spa"]].to_string(index=False))
print(pg.product_group.value_counts().to_dict())
