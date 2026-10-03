"""Builds data/reference/medicaid_obesity_coverage.csv (step 5.3, hand-built from sourced documents).
Every fact comes from a document saved under data/raw/coverage_sources/<STATE>/ (see _sources_log.csv).
Dates are blank unless a source states them. The SDUD columns are discrepancy FLAGS ONLY and never set a date."""
import csv
import datetime as dt
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "fetch"))
from common import manifest_add, sha256_file  # noqa: E402

TODAY = dt.date.today().isoformat()
KFF_SVY = "https://files.kff.org/attachment/report-results-from-an-annual-medicaid-budget-survey-for-state-fiscal-years-2025-and-2026.pdf"
MS = "https://medicaid.ms.gov/wp-content/uploads"

R = []


def add(state, **k):
    k.setdefault("delivery_system", "FFS")
    k["state"] = state
    R.append(k)


def covered(state, notes, **k):
    """Covering GLP-1s for obesity per KFF/state documents, but no sourced start date."""
    add(state, first_product_covered="", confidence="low", notes=notes, **k)


# ---- sourced start and/or end ------------------------------------------------------------------------------------
add("Mississippi", products_covered="Saxenda; Wegovy (Zepbound and Foundayo preferred from criteria dated 2026-07-01)",
    first_product_covered="Saxenda; Wegovy (both Preferred from the start)", coverage_start="2023-07-01",
    prior_authorization="Y", bmi_threshold=">=30",
    comorbidity_requirement="BMI 27-29 requires >=1 weight-related comorbidity (per 7/1/2024 criteria)",
    step_therapy="none stated; only one anti-obesity agent covered at a time",
    other_criteria="age 12+ (Saxenda, Wegovy); initial authorization 6 months (7/1/2024 version)",
    source_url=f"{MS}/2023/04/Anti-obesity-Select-Agents-PA-Criteria-V1.3.pdf; {MS}/2023/05/PTMeetingMinutes050923.pdf; {MS}/2024/07/Anti-obesity-Select-Agents-PA-Criteria-7_1_2024.V4.pdf; {MS}/2026/06/Anti-obesity-Select-Agents-PA-Criteria-07_01_2026-to-Current.V11.pdf",
    source_title="MS Division of Medicaid Select Covered Obesity Medications PA Criteria (v1.3 dated 7/1/2023; V4 7/1/2024; V11 7/1/2026); P&T Committee minutes 2023-05-09",
    source_date="2023-05-09", confidence="medium",
    notes="P&T approved Saxenda and Wegovy as Preferred on 2023-05-09; minutes say SPA 23-0013 to be submitted with a hoped-for 2023-07-01 start; the criteria document is dated 7/1/2023. CMS SPA approval not seen. PDLs of 2017-07-01 and 2019-11-01 contain no anti-obesity class. No end date.")
add("North Carolina", products_covered="Saxenda; Wegovy; Zepbound",
    first_product_covered="Saxenda; Wegovy; Zepbound (all in criteria effective 2024-08-01)",
    coverage_start="2024-08-01", coverage_end="2025-09-30", prior_authorization="Y", bmi_threshold=">=30",
    comorbidity_requirement="BMI >=27 with >=1 weight-related comorbidity (HTN, T2DM, OSA, CVD, dyslipidemia)",
    step_therapy="Y: trial of preferred agent (or documented contraindication) for non-preferred",
    other_criteria="age 12+; baseline weight/BMI within 45 days; titration up to 6 months",
    source_url="https://medicaid.ncdhhs.gov/media/15676/download?attachment=; https://medicaid.ncdhhs.gov/blog/2025/09/05/nc-medicaid-change-coverage-glp-1-weight-management-medications",
    source_title="NC Medicaid Outpatient Pharmacy Prior Approval Criteria GLP-1s for Weight Management (effective 2024-08-01); NC Medicaid bulletin 2025-09-05",
    source_date="2025-09-05", confidence="high", end_confidence="high",
    notes="Coverage discontinued effective 2025-10-01 (last covered day recorded as 2025-09-30). Applies to NC Medicaid Direct and Managed Care. Reinstated in next row.")
add("North Carolina", products_covered="Saxenda; Wegovy; Zepbound", first_product_covered="(reinstatement; see prior row)",
    coverage_start="2025-12-12", prior_authorization="Y",
    other_criteria="reverted to the criteria in place on 2025-09-30 (those effective 2024-08-01)",
    source_url="https://medicaid.ncdhhs.gov/blog/2025/12/19/nc-medicaid-reinstitute-coverage-glp-1s-weight-management",
    source_title="NC Medicaid bulletin: NC Medicaid to Reinstitute Coverage of GLP-1s for Weight Management",
    source_date="2025-12-19", confidence="high",
    notes="Reinstated effective 2025-12-12 under the Governor's directive. Gap 2025-10-01 to 2025-12-11 (no coverage).")
add("Pennsylvania", products_covered="Saxenda; Wegovy (GLP-1 RAs; later Zepbound)",
    first_product_covered="Saxenda; Wegovy (named in bulletin)", coverage_start="2023-01-09", coverage_end="2025-12-31",
    prior_authorization="Y", bmi_threshold=">=30",
    comorbidity_requirement="BMI 27-<30 with prescriber-determined candidacy criteria (2024 guidelines)",
    other_criteria="applies to FFS and managed care; GLP-1 RA PA approved up to 6 months",
    source_url="https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/docs/publications/documents/forms-and-pubs-omap/MAB2022120903.pdf; https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/docs/publications/documents/forms-and-pubs-omap/mab2025112402.pdf; https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/providers/pharmacy-services/documents/clinical-guidelines-non-pdl/obesity-treatment-agents-20240902.pdf",
    source_title="PA Medical Assistance Bulletins 2022-12-09 (eff. 2023-01-09, coverage added), 2024-08-07 (eff. 2024-09-02), 2025-11-24 (eff. 2026-01-01, coverage ends)",
    source_date="2025-11-24", confidence="high", end_confidence="high",
    notes="2022 bulletin: MA 'historically opted not to cover' obesity drugs; adds the Obesity Treatment Agents class. 2025 bulletin: effective 2026-01-01 GLP-1 RAs are not covered for overweight/obesity; Saxenda no longer covered for any indication (last covered day recorded 2025-12-31).")
add("Michigan", products_covered="anti-obesity drug products per the attachment to MSA 21-49 (list not retrieved)",
    first_product_covered="", coverage_start="2022-02-01", prior_authorization="Y",
    other_criteria="FFS pharmacy benefit; copay may apply",
    source_url="https://www.michigan.gov/mdhhs/-/media/Project/Websites/mdhhs/Folder50/Folder2/MSA_21-49-Pharmacy.pdf; https://www.michigan.gov/mdhhs/-/media/Project/Websites/mdhhs/Folder50/Folder2/Anti-Obesity_Drug_Coverage_SPA_21-0018_-_Submission.pdf",
    source_title="MDHHS Bulletin MSA 21-49 (issued 2021-12-01, effective 2022-02-01); State Plan Amendment 21-0018 submission (2021-12-21)",
    source_date="2021-12-01", confidence="medium",
    notes="Bulletin says implementation is contingent on CMS SPA approval and products 'may be covered'; approval not seen. Search summaries (not primary-verified) report a 2026-01-01 restriction to BMI>=40, which narrows but does not end coverage; not recorded as an end date. Which GLP-1 products were in the 2022 list is to verify.")
add("Rhode Island", products_covered="Saxenda; Wegovy (class); Zepbound and Foundayo named in end notice",
    first_product_covered="Saxenda; Wegovy (PA-required class on PDL 2024-01-17)",
    coverage_start="2023-10-03", coverage_end="2026-09-30", prior_authorization="Y",
    other_criteria="clinical PA for the whole class; solely-weight-loss use ends 2026-10-01",
    source_url="https://eohhs.ri.gov/sites/g/files/xkgbur226/files/2024-01/PDL%2001.17.2024.pdf; https://eohhs.ri.gov/sites/g/files/xkgbur226/files/2022-07/PDL%2007.18.2022.pdf; https://eohhs.ri.gov/sites/g/files/xkgbur226/files/2026-08/2026%2008%2013%20GLP-1%20Change%202026%2010%2001.docx.pdf",
    source_title="RI EOHHS PDL 2024-01-17 (Weight Management Agents, status implementation 10/03/2023); PDL 2022-07-18 (no such class); EOHHS memo 2026-08-05",
    source_date="2026-08-05", confidence="medium", end_confidence="high",
    notes="Start taken from the PDL 'Status Implementation: 10/03/2023' for the class; the 2022-07-18 PDL has no weight-management class. End: memo says that beginning 2026-10-01 RI Medicaid no longer covers Foundayo, Saxenda, Wegovy and Zepbound when used solely for weight loss (FY2027 budget). BMI/comorbidity to verify.")
add("Massachusetts", products_covered="Wegovy; Saxenda (2024-01); Zepbound (preferred 2024-10-01; sole covered adult agent from 2025-01-01)",
    first_product_covered="Wegovy; Saxenda", coverage_start="2024-01", coverage_end="2026-06-30", prior_authorization="Y",
    other_criteria="adults 18+ moved Wegovy/Saxenda -> Zepbound on 2025-01-01; ages 12-18 kept Wegovy/Saxenda; obesity use ends 2026-07-01 (CVD, MASH, OSA indications continue)",
    source_url="https://www.mass.gov/doc/pharmacy-facts-235-november-19-2024-0/download; https://www.mass.gov/doc/issue-3-october-2024-0/download; https://www.mass.gov/doc/pharmacy-facts-271-march-12-2026-corrected-0/download",
    source_title="MassHealth Pharmacy Facts #235 (2024-11-19), Prescriber e-Letter Oct 2024, Pharmacy Facts #271 (2026-03-12); read via Wayback copies because mass.gov returns 403",
    source_date="2026-03-12", confidence="medium", end_confidence="high",
    notes="'MassHealth began covering anti-obesity medications in January 2024' (month only; day not stated, so start kept at month precision). Pharmacy Facts #271: effective 2026-07-01 MassHealth no longer covers drugs for obesity/overweight (130 CMR 406.413(B) change); last covered day recorded 2026-06-30. BMI to verify.")
add("South Carolina", products_covered="Wegovy; Saxenda", first_product_covered="Wegovy; Saxenda",
    coverage_start="2024-11-01", coverage_end="2025-12-31", prior_authorization="Y",
    other_criteria="dietary counseling and physical-activity attestation; BMI>=30 (BMI<40 needs a comorbidity) per press reports",
    source_url="https://scdailygazette.com/2025/11/17/sc-medicaid-program-to-stop-covering-expensive-weight-loss-drugs-for-obesity/; " + KFF_SVY,
    source_title="SC Daily Gazette 2025-11-17 quoting an SCDHHS spokesperson; KFF FY2025-26 survey (SC added coverage in the prior year)",
    source_date="2025-11-17", confidence="medium", end_confidence="medium",
    notes="Start (2024-11-01) and end (coverage to treat obesity ends 2026-01-01) come from a news report quoting SCDHHS; the SCDHHS bulletin itself was not retrieved. KFF 2024 survey: SC coverage as of 2024-07-01 was orlistat only.")
add("California", products_covered="Wegovy; Zepbound; Saxenda (removed from the Medi-Cal Rx Contract Drugs List 2026-01-01)",
    first_product_covered="", coverage_end="2025-12-31", prior_authorization="Y",
    other_criteria="weight-loss PAs expired 2025-12-31; EPSDT exception under age 21",
    source_url="https://medi-calrx.dhcs.ca.gov/cms/medicalrx/static-assets/documents/provider/2025/12_A_GLP-1_Coverage_Considerations.pdf; https://medi-calrx.dhcs.ca.gov/cms/medicalrx/static-assets/documents/faq/State_Budget_Policy_Updates_FAQ.pdf",
    source_title="Medi-Cal Rx provider notices (GLP-1 Coverage Considerations; State Budget Policy Updates FAQ)",
    source_date="2025-12-12", confidence="low", end_confidence="high",
    notes="End from official notices (weight-loss coverage ends 2026-01-01; last covered day recorded). Start date NOT located, left blank. KFF lists CA among the 16 covering as of Oct 2025.")
add("New Hampshire", products_covered="Saxenda; Wegovy; Zepbound and generics (when prescribed solely for weight loss)",
    first_product_covered="", coverage_end="2025-12-31",
    other_criteria="coverage continues for T2DM, MACE, severe OSA, MASH",
    source_url="https://nhmmis.nh.gov/portals/wps/wcm/connect/94e54cab-e0c4-4645-b70a-b101315f0c14/Change+in+Medicaid+Coverage+for+GLP-1+Medications.pdf",
    source_title="NH Division of Medicaid Services notice: Change in Medicaid Coverage for GLP-1 Medications",
    source_date="2025-10-09", confidence="low", end_confidence="high",
    notes="End from official notice dated 2025-10-09 (effective 2026-01-01; last covered day recorded). Start date NOT located, left blank. KFF footnote: NH still covers other weight-loss drugs but no GLP-1s.")
add("Utah", products_covered="Wegovy; Saxenda; Zepbound (FFS only; not ACO)", first_product_covered="Wegovy; Saxenda; Zepbound",
    coverage_start="2025-07-01", coverage_end="2026-06-30", prior_authorization="Y", bmi_threshold=">=30 (adults)",
    comorbidity_requirement="BMI 27-29.9 with >=1 weight-related comorbidity; children BMI>=95th percentile",
    other_criteria="legislative pilot (S.B. 3, 2025 session); not covered for ACO-enrolled members",
    source_url=KFF_SVY + "; https://medicaid-documents.dhhs.utah.gov/pharmacy/priorauthorization/pdf/GLP-1+Medications+for+Weight+Loss+and+Other+Indications.pdf",
    source_title="KFF FY2025-26 survey (UT added coverage in the prior year; funding limited to FY2026); Utah Medicaid PA form (seen only as a search snippet; direct fetch returns 403)",
    source_date="2025-11-01", confidence="low", end_confidence="low",
    notes="Start 2025-07-01 and pilot end 2026-06-30 come from a search snippet of Utah's own PA document plus KFF's FY2026 funding footnote. The Utah document could not be opened (403). Whether coverage actually lapsed on 2026-06-30 is not confirmed.")

# ---- covering, start NOT sourced ---------------------------------------------------------------------------------
covered("Minnesota",
        "Start not found. MN Drug Formulary Committee (2022-11-16) recommended adding Contrave, Saxenda and Wegovy to the PDL as Preferred; effective date of that change not located. Criteria page lists Saxenda, Wegovy, Zepbound as covered. Still covered as of 2026-03 (MN House Session Daily, 2026-03-25).",
        products_covered="Saxenda; Wegovy; Zepbound", prior_authorization="Y", bmi_threshold=">=30",
        comorbidity_requirement="BMI >=27 with >=1 weight-related comorbidity",
        other_criteria="diet/dietitian and activity documentation; initial approval 6 months, renewal needs >=5% loss",
        source_url="https://mn.gov/dhs/assets/2022-11-16-dfc-minutes_tcm1053-548911.pdf; https://mn.gov/dhs/partners-and-providers/policies-procedures/minnesota-health-care-programs/provider/types/rx/pa-criteria/anti-obesity-medications.jsp",
        source_title="MN DHS Drug Formulary Committee minutes 2022-11-16; MN DHS Anti-Obesity Medications PA criteria", source_date="2022-11-16")
covered("Wisconsin",
        "Start not found. Saxenda and Wegovy already covered with PA by ForwardHealth Update 2023-09 (form F-00163 04/2023); Update 2025-16 lists Saxenda, Wegovy, Zepbound under PA. KFF 2025: WI considering restrictions.",
        products_covered="Saxenda; Wegovy; Zepbound", prior_authorization="Y", bmi_threshold=">=30",
        source_url="https://www.forwardhealth.wi.gov/kw/pdf/2023-09.pdf; https://www.forwardhealth.wi.gov/kw/pdf/2025-16.pdf",
        source_title="ForwardHealth Updates 2023-09, 2024-16, 2025-16", source_date="2025-06-01")
covered("Virginia",
        "Start not found. Service authorization for Saxenda/Wegovy documented by the DMAS SA form dated 2023-06-23; PDL 'weight management agents (existing closed class)' with Saxenda and Wegovy effective 2024-08-01. VA narrowed criteria in 2024 (not primary-verified).",
        products_covered="Saxenda; Wegovy; Zepbound (non-preferred)", prior_authorization="Y (service authorization)",
        source_url="https://vamedicaid.dmas.virginia.gov/bulletin/virginia-medicaid-preferred-drug-list-common-core-formulary-and-new-drug-utilization; https://townhall.virginia.gov/L/GetFile.cfm?File=C%3A%2FTownHall%2Fdocroot%2FGuidanceDocs_Proposed%2F602%2FGDoc_DMAS_6557_20230623.pdf",
        source_title="Virginia Medicaid PDL bulletin (effective 2024-08-01); DMAS weight-loss SA form 2023-06-23", source_date="2024-08-01")
covered("Kansas",
        "Start not found. KDHE Anti-Obesity Agents PA criteria (initial approval 2007; revised 2015-2024) list Saxenda, Wegovy and Zepbound; KFF 2024: KS broadened existing coverage to Zepbound in FY2024. Product-level dates to verify.",
        products_covered="Saxenda; Wegovy; Zepbound", prior_authorization="Y", bmi_threshold=">=30",
        comorbidity_requirement="BMI >=27 with >=1 weight-related comorbidity (Table 2)",
        source_url="https://www.kdhe.ks.gov/DocumentCenter/View/34035/Anti-Obesity-Agents-PDF",
        source_title="KDHE KanCare Anti-Obesity Agents PA criteria (revised 2024-01-17)", source_date="2024-01-17")
covered("Delaware",
        "Start not found. Delaware Medicaid PDL (revised 2025-11-03) and the 2026 PDL (live 2026-10-05) list an Obesity Treatment Agents class (PA for all agents; Wegovy, Zepbound, Foundayo, Saxenda/liraglutide). Not to be confused with the state employee plan.",
        products_covered="Wegovy; Zepbound; Saxenda; Foundayo (2026 PDL)", prior_authorization="Y",
        source_url="https://medicaidpublications.dhss.delaware.gov/docs/search?Command=Core_Download&EntryId=940",
        source_title="Delaware Medicaid Preferred Drug List", source_date="2025-11-03")
covered("Missouri",
        "Start not found. MO HealthNet PDL effective 2025-02-01 already lists 'GLP-1 Receptor Agonists Indicated for Obesity' (Zepbound, Wegovy); Oct 2025 bulletin: Zepbound is the preferred obesity agent. KFF: MO added coverage between Oct 2024 and Oct 2025 and covers only Zepbound.",
        products_covered="Zepbound (Wegovy listed on PDL)", prior_authorization="Y (may be transparent via ICD-10 on claim)",
        source_url="https://mydss.mo.gov/sites/mydss/files/media/pdf/2025/01/Posting%20PDL%20Static%20Document%202025.02.01.pdf; https://content.govdelivery.com/accounts/MODSS/bulletins/3f4823a",
        source_title="MO HealthNet PDL 2025-02-01; MO DSS Essential Updates Oct 2025", source_date="2025-02-01")
covered("Tennessee",
        "Start not found in a TennCare document. KFF: TN added coverage between Oct 2024 and Oct 2025. A 2025-08-01 start appears only on aggregator sites and is NOT recorded.",
        products_covered="to verify (Wegovy, Zepbound reported)", source_url=KFF_SVY,
        source_title="KFF FY2025-26 Medicaid budget survey", source_date="2025-11-01")

df = pd.DataFrame(R)
df["date_accessed"] = TODAY
COVERING_JAN26 = ["Delaware", "Kansas", "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri", "North Carolina",
                  "Rhode Island", "Tennessee", "Utah", "Virginia", "Wisconsin"]
df["kff_jan2026_status"] = df.state.map(lambda s: "in KFF's 13-state covering list" if s in COVERING_JAN26
                                        else "KFF: eliminated after Oct 2025 (CA, NH, PA, SC)")
# ---- SDUD discrepancy FLAGS (never used to set dates) ----------------------------------------------------------------
AB = {"Delaware": "DE", "Kansas": "KS", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
      "Missouri": "MO", "North Carolina": "NC", "Rhode Island": "RI", "Tennessee": "TN", "Utah": "UT", "Virginia": "VA",
      "Wisconsin": "WI", "California": "CA", "New Hampshire": "NH", "Pennsylvania": "PA", "South Carolina": "SC"}
fq = pd.read_csv(ROOT / "data" / "interim" / "sdud" / "first_obesity_quarter_by_state.csv").set_index("state")


def qstr(v):
    v = int(v)
    return f"{v // 10}Q{v % 10}"


def qidx(v):
    return (int(v) // 10) * 4 + int(v) % 10


def flag(r):
    if not isinstance(r.coverage_start, str) or len(r.coverage_start) < 7:
        return "NO_SOURCED_START"
    sq = int(r.coverage_start[:4]) * 4 + (int(r.coverage_start[5:7]) - 1) // 3 + 1
    d = qidx(fq.loc[AB[r.state], "first_unsuppressed"]) - sq
    return "SDUD_EARLIER" if d <= -1 else "SDUD_LATER" if d >= 2 else "CONSISTENT"


df["sdud_first_obesity_quarter_any_row"] = df.state.map(lambda s: qstr(fq.loc[AB[s], "first_any_row"]))
df["sdud_first_obesity_quarter_unsuppressed"] = df.state.map(lambda s: qstr(fq.loc[AB[s], "first_unsuppressed"]))
df["sdud_discrepancy_flag"] = df.apply(flag, axis=1)
nc2 = df.index[df.state.eq("North Carolina")][1:]
df.loc[nc2, ["sdud_discrepancy_flag", "sdud_first_obesity_quarter_any_row", "sdud_first_obesity_quarter_unsuppressed"]] = ["n/a (reinstatement row)", "", ""]
cols = ["state", "delivery_system", "products_covered", "first_product_covered", "coverage_start", "coverage_end",
        "prior_authorization", "bmi_threshold", "comorbidity_requirement", "step_therapy", "other_criteria", "source_url",
        "source_title", "source_date", "date_accessed", "confidence", "end_confidence", "notes", "kff_jan2026_status",
        "sdud_first_obesity_quarter_any_row", "sdud_first_obesity_quarter_unsuppressed", "sdud_discrepancy_flag"]
df = df.reindex(columns=cols).fillna("")
out = ROOT / "data" / "reference" / "medicaid_obesity_coverage.csv"
df.to_csv(out, index=False, encoding="utf-8", quoting=csv.QUOTE_MINIMAL)
manifest_add(dataset="reference", file_name=out.name, source_url="state Medicaid documents + KFF (see source_url column)",
             release_or_version="second pass " + TODAY, years_covered="2022-2026", bytes=out.stat().st_size,
             sha256=sha256_file(out), row_count=len(df),
             notes="hand-built from sourced documents in data/raw/coverage_sources (gitignored); SDUD columns are discrepancy flags only")
print(df[["state", "coverage_start", "coverage_end", "confidence", "end_confidence",
          "sdud_first_obesity_quarter_unsuppressed", "sdud_discrepancy_flag"]].to_string())
