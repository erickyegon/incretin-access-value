"""Merge product-specific start dates / ranges into data/reference/medicaid_obesity_coverage.csv (step 5.3).
Run AFTER build_coverage_table.py. Every bound carries a source and an access date. No SDUD volume is used.

Exposure (decided 2026-10-03) = first covered quarter for Wegovy OR Zepbound for weight management; Saxenda is separate.
Exposure start range = [min of the product earliest bounds, min of the product latest bounds].
'Earliest' = last dated document showing no coverage + 1 day; where no such document exists the FDA approval date is used
(Wegovy 2021-06-04, Zepbound 2023-11-08, Saxenda 2014-12-23) because the product could not be covered earlier.
range_wider_than_1q = (latest - earliest) > 92 days.
analysis_group: primary = exact date or range within one quarter (and a sourced start); sensitivity = otherwise."""
import csv
import datetime as dt
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "fetch"))
from common import manifest_add, sha256_file  # noqa: E402

ACC = dt.date.today().isoformat()
FDA = {"Wegovy": ("2021-06-04", "FDA approval of Wegovy (2021-06-04); product could not be covered earlier"),
       "Zepbound": ("2023-11-08", "FDA approval of Zepbound (2023-11-08); product could not be covered earlier"),
       "Saxenda": ("2014-12-23", "FDA approval of Saxenda (2014-12-23); product could not be covered earlier")}
KFF = "KFF FY2025-26 Medicaid budget survey (files.kff.org ... fy-2025-and-2026.pdf): state did not cover GLP-1s for obesity as of 2024-10-01 (13-state count a year earlier)"
KFFL = "KFF FY2025-26 survey: state covered GLP-1s for obesity as of 2025-10-01 (16 states)"

# state: {product: dict(exact=..., earliest=..., e_src=..., latest=..., l_src=..., note=...)}
P = {}


def put(state, prod, exact=None, earliest=None, e_src=None, latest=None, l_src=None, note=""):
    P.setdefault(state, {})[prod] = dict(exact=exact, earliest=earliest, e_src=e_src, latest=latest, l_src=l_src, note=note)


def both_exact(state, date, src, prods=("Saxenda", "Wegovy"), note=""):
    for p in prods:
        put(state, p, exact=date, l_src=src, note=note)


both_exact("Mississippi", "2023-07-01", "CMS approval of MS SPA 23-0013 effective 2023-07-01 (medicaid.gov MS-23-0013.pdf); MS criteria v1.3 dated 7/1/2023 lists Saxenda and Wegovy Preferred")
put("Mississippi", "Zepbound", earliest="2026-01-02", e_src="MS Select Agents PA criteria dated 1/1/2026 (V8) lists Saxenda/Wegovy only", latest="2026-07-01", l_src="MS criteria dated 7/1/2026 (V11) lists Zepbound Preferred")
both_exact("North Carolina", "2024-08-01", "NC Medicaid prior approval criteria GLP-1s for Weight Management effective 2024-08-01", ("Saxenda", "Wegovy", "Zepbound"), "ended 2025-09-30; reinstated 2025-12-12")
both_exact("Pennsylvania", "2023-01-09", "PA Medical Assistance Bulletin 2022-12-09 effective 2023-01-09 (names Saxenda, Wegovy)")
both_exact("Michigan", "2022-02-01", "MDHHS bulletin MSA 21-49 (attachment lists Saxenda and Wegovy NDCs) and CMS approval of SPA 21-0018 effective 2022-02-01")
both_exact("Rhode Island", "2023-10-03", "RI EOHHS PDL 2024-01-17: Weight Management Agents (Saxenda, Wegovy) status implementation 10/03/2023", note="PDL 2022-07-18 has no such class")
for p in ("Saxenda", "Wegovy"):
    put("Massachusetts", p, earliest="2024-01-01", e_src="MassHealth Pharmacy Facts #235 (2024-11-19): 'began covering anti-obesity medications in January 2024' (month only)", latest="2024-01-31", l_src="same document; month precision", note="Pharmacy Facts read via Wayback copy (mass.gov 403)")
both_exact("South Carolina", "2024-11-01", "Milliman SFY 2026 Capitation Rate Methodology and Data Book for SCDHHS (2025-03-17): 'Effective November 1, 2024, SCDHHS implemented a policy to permit the use of GLP-1 pharmaceutical products Wegovy and Saxenda as weight management agents'; corroborated by SC Daily Gazette 2025-11-17", note="SCDHHS bulletin itself not found (one attempt); end 2025-12-31 from SCDHHS spokesperson via SC Daily Gazette")
put("California", "Saxenda", exact="2023-01-01", l_src="Medi-Cal Rx Contract Drugs List change log: 'Saxenda Added to CDL with restriction. January 1, 2023' (Wayback snapshot 2023-01-29)")
put("California", "Wegovy", exact="2023-01-01", l_src="Medi-Cal Rx CDL change log: 'Semaglutide (Wegovy) Added to CDL with restriction. January 1, 2023'")
put("California", "Zepbound", exact="2024-10-01", l_src="Medi-Cal Rx Monthly Bulletin 2024-10-01: 'Tirzepatide (Zepbound) Added to CDL ... October 1, 2024'")
put("New Hampshire", "Wegovy", earliest=FDA["Wegovy"][0], e_src=FDA["Wegovy"][1], latest="2023-07-01", l_src="NH FFS Medicaid PDL effective 2023-07-01 (Prime Therapeutics portal) lists Wegovy and Saxenda; 2022-08-01 notice (eff. 2022-09-01) adds a Weight Management Agents class but names no drugs",
    note="older PDLs not archived. SPA pass: NH-23-0031 (eff. 2023-03-01; supersedes TN 14-003) lists 'select agents when used for anorexia, weight loss, weight gain' as covered per the state website - category-level, does not narrow the Wegovy range")
put("New Hampshire", "Zepbound", earliest="2024-03-02", e_src="NH PDL effective 2024-03-01 has no Zepbound", latest="2024-08-01", l_src="NH notification 2024-08-01 lists Weight Management - Zepbound among PDL additions")
put("New Hampshire", "Saxenda", earliest=FDA["Saxenda"][0], e_src=FDA["Saxenda"][1], latest="2023-07-01", l_src="NH PDL effective 2023-07-01")
put("Minnesota", "Wegovy", earliest="2021-07-01",
    e_src="CMS-approved MN SPA 21-0022 (approved 2021-12-17) adds weight loss drugs to the prescription drug formulary, effective 2021-07-01; MN SPA 19-0006 (eff. 2019-07-01) excluded weight-loss drugs, so category coverage began 2021-07-01", latest="2022-01-27",
    l_src="MN DHS Anti-Obesity Medications PA criteria (page labelled 'December 2021'; earliest archived capture 2022-01-27): 'Covered drugs with prior authorization' includes Saxenda and Wegovy, with a Wegovy-specific criterion (failed 3-month Saxenda trial)",
    note="SPA pass: MN-21-0022 sets the category start (2021-07-01), so the lower bound moved up from the FDA date; the range still spans Q3 2021-Q1 2022. Counts as coverage under the anti-obesity class (covered list + class criteria). The weight-management PDL section ('added 3-1-2023') and the Drug Formulary Committee vote of 2022-11-16 set preferred status on the PDL, not coverage. Alternative PDL-based start = 2023-03-01 (sensitivity)")
put("Minnesota", "Zepbound", earliest="2024-03-16", e_src="MN Uniform PDL effective 2024-03-15 (section updated 1-1-2024): no Zepbound", latest="2024-12-01", l_src="MN Uniform PDL effective 2026-01-01: weight-management section updated 12-1-2024 lists Zepbound", note="PDL absence may reflect default non-preferred coverage")
put("Minnesota", "Saxenda", earliest=FDA["Saxenda"][0], e_src=FDA["Saxenda"][1], latest="2022-01-27", l_src="MN criteria page labelled December 2021 (capture 2022-01-27)")
put("Wisconsin", "Wegovy", earliest="2021-09-18", e_src="ForwardHealth topic #7837 as archived 2021-09-17 lists Saxenda but not Wegovy", latest="2023-03-31", l_src="ForwardHealth Update 2023-09 (March 2023) criteria name Saxenda, Wegovy, Xenical",
    note="SPA pass: WI-24-0021 (eff. 2024-07-01) only modifies existing weight-loss-drug language; no earlier WI SPA found; no narrowing")
put("Wisconsin", "Zepbound", earliest=FDA["Zepbound"][0], e_src=FDA["Zepbound"][1], latest="2024-06-30", l_src="ForwardHealth Update 2024-16 (June 2024) treats Zepbound as a covered anti-obesity drug")
put("Wisconsin", "Saxenda", earliest=FDA["Saxenda"][0], e_src=FDA["Saxenda"][1], latest="2016-01-31", l_src="Wisconsin Medicaid Pharmacy handbook, published policy through 2016-01-31, lists Saxenda")
put("Virginia", "Wegovy", earliest=FDA["Wegovy"][0], e_src=FDA["Wegovy"][1], latest="2022-06-10", l_src="DMAS Pharmacy Manual App. D (page revision 6/10/2022): Wegovy requires a service authorization, effective immediately",
    note="SPA pass: VA SPAs 20-0018, 21-0014, 23-0006 describe weight-loss drugs covered when preauthorized for severe-disability obesity; VA-25-0004 (eff. 2025-01-01) broadens to select agents listed in the provider manual; SPA text does not date Wegovy; no narrowing")
put("Virginia", "Zepbound", earliest=FDA["Zepbound"][0], e_src=FDA["Zepbound"][1], latest="2024-03-31", l_src="DMAS quarterly report (March 2024): Zepbound approved Q4, non-preferred on PDL, available after trial/failure of preferred")
put("Kansas", "Wegovy", earliest=FDA["Wegovy"][0], e_src=FDA["Wegovy"][1], latest="2021-07-21", l_src="KS DUR Board minutes 2021-07-21 (ArchiveCenter item 2613): revision includes addition of Wegovy to Weight Loss Agents PA criteria",
    note="Board approval date; implementation date not stated")
put("Kansas", "Zepbound", earliest=FDA["Zepbound"][0], e_src=FDA["Zepbound"][1], latest="2024-01-17", l_src="KS DUR Board 2024-01-17 (items 2958/2991): criteria revision adds Zepbound; new Anti-Obesity PDL class approved")
put("Kansas", "Saxenda", earliest=FDA["Saxenda"][0], e_src=FDA["Saxenda"][1], latest="2021-04-21", l_src="KS DUR Board minutes 2021-04-21 (item 2612): Weight Loss Agents criteria updated for Saxenda labeling")
put("Delaware", "Wegovy", earliest=FDA["Wegovy"][0], e_src=FDA["Wegovy"][1], latest="2022-09-23", l_src="DE Pharmacy Provider Policy Manual revision 09/23/2022 (sec. 3.5.6.1): drugs indicated for obesity covered with PA; CMS approved SPA DE-19-0009 on 2022-09-14 (eff. 2019-10-01, 'clarifies' obesity coverage)",
    note="policy-level coverage; Wegovy not named until the 2025 PDL; earlier manual versions not archived. SPA pass: DE-19-0009 (eff. 2019-10-01) is the only obesity SPA found; no narrowing")
put("Delaware", "Zepbound", earliest=FDA["Zepbound"][0], e_src=FDA["Zepbound"][1], latest="2025-11-03", l_src="Delaware Medicaid PDL revised 2025-11-03 lists Zepbound", note="class-level policy may imply earlier coverage")
put("Delaware", "Saxenda", earliest=FDA["Saxenda"][0], e_src=FDA["Saxenda"][1], latest="2022-09-23", l_src="DE Pharmacy Provider Policy Manual revision 09/23/2022")
for p in ("Wegovy", "Zepbound"):
    put("Missouri", p, earliest="2024-10-02", e_src=KFF, latest="2025-02-01", l_src="MO HealthNet PDL effective 2025-02-01 lists GLP-1 Receptor Agonists Indicated for Obesity (Zepbound, Wegovy); DPAC discussed the class edit on 2024-10-15 (implementation date not retrievable)",
        note="KFF: MO covers only Zepbound. SPA pass: no Missouri SPA on weight-loss drugs found (MO-25-0005 concerns biopsychosocial obesity treatment services); no narrowing")
for p in ("Wegovy", "Zepbound"):
    put("Tennessee", p, exact="2025-08-01",
        l_src="CMS-approved TN SPA 25-0006, effective 2025-08-01 (medicaid.gov TN-25-0006.pdf): TennCare will not cover excluded drugs 'except select weight loss drugs when prescribed for treatment of obesity' (new exception); KFF: TN added coverage between 2024-10-01 and 2025-10-01",
        note="CATEGORY-level: the SPA names no drug (weight-loss drugs 'listed on the TennCare preferred drug list'); no TennCare document naming Wegovy/Zepbound found; confidence medium. Earlier TN SPAs 21-0004, 23-0005, 24-0002 contain no weight-loss text")
for p in ("Wegovy", "Zepbound", "Saxenda"):
    put("Utah", p, earliest="2024-10-02", e_src=KFF, latest="2025-10-01", l_src=KFFL,
        note="UNVERIFIED: a snippet of Utah's PA form says 2025-07-01 start and 2026-06-30 pilot end; Utah documents return 403 and the Jan 2025 MIB shows GLP-1 criteria for T2DM only. Confidence stays low")


def d(s):
    return dt.date.fromisoformat(s) if s else None


rows = []
for st, prods in P.items():
    for pr, v in prods.items():
        e, l, x = v["earliest"], v["latest"], v["exact"]
        if x:
            e, l = x, x
        wide = (d(l) - d(e)).days > 92 if (e and l) else ""
        rows.append(dict(state=st, product=pr, start_exact=x or "", start_earliest=e or "", start_earliest_source=("exact: see latest source" if x else v["e_src"] or ""),
                         start_earliest_accessed=ACC, start_latest=l or "", start_latest_source=v["l_src"] or "", start_latest_accessed=ACC,
                         range_wider_than_1q=("N" if not wide else "Y") if wide != "" else "", range_days=(d(l) - d(e)).days if (e and l) else "", notes=v["note"]))
R = pd.DataFrame(rows)
R.to_csv(ROOT / "data" / "reference" / "medicaid_obesity_coverage_by_product.csv", index=False, encoding="utf-8")

# ---- exposure per state = min over Wegovy/Zepbound -------------------------------------------------------------
main = pd.read_csv(ROOT / "data" / "reference" / "medicaid_obesity_coverage.csv", dtype=str).fillna("")
for c in ["start_wegovy_zepbound", "start_saxenda", "start_earliest", "start_latest", "range_wider_than_1q", "start_earliest_source",
          "start_earliest_accessed", "start_latest_source", "start_latest_accessed", "exposure_driving_product", "first_treated_quarter",
          "first_full_quarter", "drop_one_sensitivity", "analysis_group", "analysis_group_reason"]:
    main[c] = ""


def qlabel(date):
    x = d(date)
    return f"{x.year}Q{(x.month - 1) // 3 + 1}"


def next_full_q(date):
    x = d(date)
    if x.day == 1 and (x.month - 1) % 3 == 0:
        return qlabel(date)
    q = (x.month - 1) // 3 + 1
    y = x.year + (1 if q == 4 else 0)
    return f"{y}Q{1 if q == 4 else q + 1}"


first_rows = {}
for i, r in main.iterrows():
    first_rows.setdefault(r.state, i)
for st, i in first_rows.items():
    pr = R[(R.state == st)]
    sax = pr[pr["product"] == "Saxenda"]
    wz = pr[pr["product"].isin(["Wegovy", "Zepbound"])]
    if len(sax):
        s = sax.iloc[0]
        main.at[i, "start_saxenda"] = s.start_exact or f"{s.start_earliest}..{s.start_latest}"
    if not len(wz):
        main.at[i, "analysis_group"] = "sensitivity"
        main.at[i, "analysis_group_reason"] = "no Wegovy/Zepbound start information"
        continue
    e = min(wz.start_earliest); l = min(wz.start_latest)
    drive = ";".join(wz[wz.start_latest == l]["product"])
    exact = (e == l)
    wide = (d(l) - d(e)).days > 92
    ex = wz[(wz.start_latest == l)].iloc[0]
    main.at[i, "start_wegovy_zepbound"] = l if exact else ""
    main.at[i, "start_earliest"], main.at[i, "start_latest"] = e, l
    main.at[i, "range_wider_than_1q"] = "Y" if wide else "N"
    main.at[i, "start_earliest_source"] = ("exact date; see start_latest_source" if exact else
                                           wz[wz.start_earliest == e].iloc[0].start_earliest_source)
    main.at[i, "start_earliest_accessed"] = ACC
    main.at[i, "start_latest_source"] = ex.start_latest_source
    main.at[i, "start_latest_accessed"] = ACC
    main.at[i, "exposure_driving_product"] = drive
    main.at[i, "first_treated_quarter"] = qlabel(l) if exact else f"{qlabel(e)}..{qlabel(l)}"
    main.at[i, "first_full_quarter"] = next_full_q(l) if exact else f"{next_full_q(e)}..{next_full_q(l)}"
    conf = main.at[i, "confidence"]
    same_q = qlabel(e) == qlabel(l)
    if st == "Kansas":   # decision 2026-10-03: primary with start quarter 2021Q3 (2021-07-21 DUR Board decision)
        grp, why = "primary", "decision: start quarter 2021Q3 from the 2021-07-21 DUR Board decision (range 2021-06-04..2021-07-21 straddles Q2/Q3); also flagged for a without-Kansas sensitivity analysis"
        main.at[i, "first_treated_quarter"], main.at[i, "first_full_quarter"] = "2021Q3", "2021Q4"
    elif exact:
        grp, why = "primary", "exact date"
    elif same_q:
        grp, why = "primary", f"range {e}..{l} inside one calendar quarter ({qlabel(e)})"
    else:
        grp, why = "sensitivity", f"range {e}..{l} not inside one calendar quarter ({(d(l) - d(e)).days} days)"
    main.at[i, "drop_one_sensitivity"] = "without-Kansas" if st == "Kansas" else ""
    main.at[i, "analysis_group"], main.at[i, "analysis_group_reason"] = grp, why

# reinstatement row of NC and confidence updates from the new documents
# start-date confidence: exact date from an official document = high; bounded range from dated official documents = medium;
# KFF-only bounds or unreadable documents = low
for s_, c_ in {"California": "high", "Kansas": "medium", "New Hampshire": "medium", "Minnesota": "medium", "Wisconsin": "medium",
               "Virginia": "medium", "Delaware": "medium", "Missouri": "medium", "Tennessee": "medium", "Utah": "low", "South Carolina": "high"}.items():
    main.loc[main.state == s_, "confidence"] = c_
main.loc[(main.state == "Michigan"), "confidence"] = "high"
main.loc[(main.state == "Michigan"), "first_product_covered"] = "Saxenda; Wegovy (NDCs in MSA 21-49 attachment)"
main.loc[(main.state == "Mississippi"), "confidence"] = "medium"
main.loc[(main.state == "Mississippi"), "notes"] = main.loc[(main.state == "Mississippi"), "notes"] + " | SPA 23-0013 approved by CMS with effective date 2023-07-01 (medicaid.gov MS-23-0013.pdf) covers the CATEGORY only ('select obesity drugs ... as listed on the state's website'; no drug named). Wegovy is named by the state criteria v1.3 (dated 7/1/2023) and the 2023-05-09 P&T minutes, but no document confirms a Wegovy claims go-live; confidence medium."
main.loc[(main.state == "Michigan"), "notes"] = main.loc[(main.state == "Michigan"), "notes"] + " | CMS approved SPA 21-0018 with effective date 2022-02-01; MSA 21-49 attachment lists Saxenda and Wegovy."
main.to_csv(ROOT / "data" / "reference" / "medicaid_obesity_coverage.csv", index=False, encoding="utf-8", quoting=csv.QUOTE_MINIMAL)
for f in ("medicaid_obesity_coverage.csv", "medicaid_obesity_coverage_by_product.csv"):
    p = ROOT / "data" / "reference" / f
    manifest_add(dataset="reference", file_name=f, source_url="state Medicaid documents + KFF (see source columns)", release_or_version="third pass " + ACC,
                 years_covered="2014-2026", bytes=p.stat().st_size, sha256=sha256_file(p), row_count=len(pd.read_csv(p)),
                 notes="product-specific starts/ranges with sources and access dates; SDUD not used for dates")
show = main[main.state.map(lambda s: first_rows[s]) .index == main.index][["state", "start_wegovy_zepbound", "start_earliest", "start_latest", "range_wider_than_1q", "coverage_end", "confidence", "analysis_group"]]
print(show.to_string(index=False))
