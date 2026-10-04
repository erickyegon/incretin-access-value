"""Utilization-management (UM) criteria for the 17 states in the coverage study, from the state documents saved under data/raw/coverage_sources (see
scripts/fetch/30_state_um_docs.py and _sources_log.csv). Every cell is either read from a cited document or the exact phrase NF = "not found in sourced documents";
nothing is guessed. Writes:
  data/reference/medicaid_obesity_um_criteria.csv  (clean table, one row per state)
and refreshes the four UM columns (prior_authorization, bmi_threshold, comorbidity_requirement, step_therapy) of data/reference/medicaid_obesity_coverage.csv.
Run: python scripts/build/build_um_table.py"""
import csv, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
NF = "not found in sourced documents"
ACC = "2026-10-03 to 2026-10-04"
S = {  # state -> dict (primary document, version, field values)
 "Mississippi": dict(pa="Y", bmi=">=30; BMI 27-29.9 with >=1 weight-related comorbidity", comorb="BMI 27-29 requires >=1 weight-related comorbidity (7/1/2024 criteria)",
    step="none stated in the criteria; only one anti-obesity agent covered at a time", other="age 12+ (Saxenda, Wegovy); initial authorization 6 months",
    ver="MS Division of Medicaid Select Covered Obesity Medications PA Criteria V4 (7/1/2024); later versions (V7 to V11) add Zepbound and Foundayo", typ="state agency document",
    url="https://medicaid.ms.gov/wp-content/uploads/2024/07/Anti-obesity-Select-Agents-PA-Criteria-7_1_2024.V4.pdf"),
 "North Carolina": dict(pa="Y", bmi=">=30; BMI >=27 with >=1 weight-related comorbidity", comorb=">=27 with >=1 weight-related comorbidity (HTN, T2DM, OSA, CVD, dyslipidemia)",
    step="Y for non-preferred agents: trial of a preferred agent (or documented contraindication)", other="age 12+; baseline weight/BMI within 45 days; titration up to 6 months; coverage ended 2025-10-01 and was reinstated (see coverage table)",
    ver="NC Medicaid Outpatient Pharmacy Prior Approval Criteria, GLP-1s for Weight Management (effective 2024-08-01)", typ="state agency document",
    url="https://medicaid.ncdhhs.gov/media/15676/download?attachment=", url2="https://medicaid.ncdhhs.gov/blog/2025/12/19/nc-medicaid-reinstitute-coverage-glp-1s-weight-management"),
 "Pennsylvania": dict(pa="Y", bmi=">=30 (adults)", comorb="BMI 27 to <30 with prescriber-determined candidacy criteria (2024 guidelines)",
    step="Y for non-preferred obesity agents: history of therapeutic failure of, contraindication or intolerance to the preferred Obesity Treatment Agents", other="see the criteria document for dose, age and documentation requirements",
    ver="PA Medical Assistance Bulletin MAB 2025-11-24 (criteria effective 2026-01-01, replacing 2024); earlier MAB 2022-12-09", typ="state agency document",
    url="https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/docs/publications/documents/forms-and-pubs-omap/mab2025112402.pdf", url2="https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/docs/publications/documents/forms-and-pubs-omap/MAB2022120903.pdf"),
 "Michigan": dict(pa="Y", bmi="GLP-1 weight-loss agents: BMI classified as morbidly obese (e.g. >=40) in the 10/01/2026 criteria; earlier criteria " + NF, comorb="not required in the 10/01/2026 GLP-1 criteria (BMI >=40 route); earlier criteria " + NF,
    step="Y (10/01/2026 criteria): GLP-1s are non-preferred; trial and failure (or allergy, contraindication, side effects) of all five preferred non-GLP-1 types, failure of other weight-loss interventions, and use only to avert bariatric surgery",
    other="PA applies under current FFS pharmacy policy (MSA 21-49, effective 2022-02-01)", ver="MDHHS MHP Common Formulary Prior Authorization Criteria, anti-obesity section (effective 10/01/2026); MSA 21-49 (2021-12-01) for PA and start", typ="state agency document",
    url="https://www.michigan.gov/mdhhs/-/media/Project/Websites/mdhhs/Assistance-Programs/Medicaid-BPHASA/MHP-Common-Formulary-PDL-PA-Criteria.pdf"),
 "Rhode Island": dict(pa="Y for some products (EOHHS memo: 'some medications may require prior authorization')", bmi=NF, comorb=NF, step=NF, other="coverage for weight loss ends 2026-10-01 (EOHHS memo 2026-08-05); the DUR Board minutes (2024-06-04) say the weight loss policy and PA criteria 'needs to be revisited'",
    ver="RI EOHHS memo GLP-1 State Budget Guidance (2026-08-05); DUR Board minutes 2024-06-04", typ="state agency document",
    url="https://eohhs.ri.gov/sites/g/files/xkgbur226/files/2024-06/dur_jun_24.pdf"),
 "Massachusetts": dict(pa="Y", bmi=">=30; or >=27 with a listed weight-related comorbidity", comorb="BMI >=27 plus one of: coronary heart disease or other atherosclerotic disease, dyslipidemia, hypertension, NASH, obstructive sleep apnea, PCOS, prediabetes, systemic osteoarthritis, type 2 diabetes",
    step="Y: inadequate response to, adverse reaction to, or contraindication to phentermine (and related agents) per the criteria; preferred-drug trial rules for non-preferred agents", other="continues reduced-calorie diet and increased physical activity (attestation accepted); quantity <=3 units/day",
    ver="MassHealth Anti-Obesity Agents PA criteria, effective 2025-01-01 (published by Mass General Brigham Health Plan for MassHealth)", typ="state-program criteria published by a MassHealth plan",
    url="https://resources.massgeneralbrighamhealthplan.org/pharmacy/PharmacyPolicies/Medicaid/AntiObesity_PA_MH_Rx_01.01.25.pdf"),
 "South Carolina": dict(pa="Y", bmi=">=30; BMI 30-34 needs >=1 very high-risk factor or >=2 other risk factors; BMI 35-39 needs >=1 risk factor; BMI >=40 needs none", comorb="very high-risk: type 2 diabetes, coronary heart disease, sleep apnea; other risk factors: hypertension, cigarette smoking, family history of premature heart disease, osteoarthritis (as reported)",
    step=NF, other="dietary counseling and prescriber attestation of increased physical activity (as reported by SC Daily Gazette quoting SCDHHS); managed care program", ver="SC Daily Gazette reports 2025-01-07 and 2025-11-17 quoting SCDHHS; no SCDHHS criteria document was retrieved", typ="news report quoting the state agency",
    url="https://scdailygazette.com/2025/01/07/as-demand-for-weight-loss-drugs-rises-states-grapple-with-medicaid-coverage/", url2="https://scdailygazette.com/2025/11/17/sc-medicaid-program-to-stop-covering-expensive-weight-loss-drugs-for-obesity/"),
 "California": dict(pa=NF + " for the covered period (Zepbound was added to the Contract Drugs List with diagnosis, quantity and labeler restrictions, 2024-10-01); from 2026-01-01 weight-loss use is no longer covered", bmi=NF + " (the 2026 FAQ says no BMI range qualifies for weight-loss coverage after 2026-01-01)", comorb=NF, step=NF, other="claims need an accepted ICD-10-CM diagnosis code (2026 policy for non-weight-loss use)",
    ver="Medi-Cal Rx Monthly Bulletin 2024-10 and State Budget Policy Updates FAQ (2026)", typ="state agency document",
    url="https://medi-calrx.dhcs.ca.gov/cms/medicalrx/static-assets/documents/provider/pharmacy-news/2024.10_B_Monthly_Bulletin.pdf", url2="https://medi-calrx.dhcs.ca.gov/cms/medicalrx/static-assets/documents/faq/State_Budget_Policy_Updates_FAQ.pdf"),
 "New Hampshire": dict(pa="Y (the PDL notes additional prior approval for the weight management class)", bmi=NF, comorb=NF, step="Y: trial and failure of 2 preferred products (orlistat, phentermine/topiramate) required before non-preferred products (Saxenda, Wegovy, Zepbound)",
    other="coverage for weight loss ended in January 2026 (NH Prime Therapeutics notification 2025-10-09)", ver="NH DHHS Fee-for-Service Medicaid PDL effective 2025-10-01", typ="state agency document",
    url="https://nh.primetherapeutics.com/documents/51139/51630/Notification%2010.09.2025%20-%20GLP-1%20Coverage%20Change/218c7285-7968-9484-a244-859e0741eeba"),
 "Utah": dict(pa="Y", bmi=">=30 (adults)", comorb="BMI 27-29.9 with >=1 weight-related comorbidity; children BMI >=95th percentile", step=NF, other="FFS only; not ACO", ver="Utah Medicaid Information Bulletins (January and July 2025)", typ="state agency document",
    url="https://medicaid-documents.dhhs.utah.gov/Documents/manuals/pdfs/Medicaid+Information+Bulletins/Traditional+Medicaid+Program/2025/July2025-MIB.pdf"),
 "Minnesota": dict(pa="Y", bmi=">=30 with no risk factors (age 18+)", comorb="BMI >=27 with >=1 weight-related comorbid condition (e.g. hypertension, type 2 diabetes, dyslipidemia)", step="none stated; documentation of a reduced-calorie diet or dietitian care and increased physical activity is required",
    other="initial approval 6 months for Saxenda, Wegovy, Contrave, Xenical; renewal needs >=5% weight loss", ver="MN DHS Anti-Obesity Medications PA criteria (August 2026 page)", typ="state agency document",
    url="https://mn.gov/dhs/partners-and-providers/policies-procedures/minnesota-health-care-programs/provider/types/rx/pa-criteria/anti-obesity-medications.jsp"),
 "Wisconsin": dict(pa="Y", bmi=">=30 (age 18+)", comorb="BMI 27 to <30 with >=2 risk factors (treated dyslipidemia, hypertension, sleep apnea, type 2 diabetes, or cardiovascular disease)", step="none stated; the member must have participated in a weight loss treatment plan in the past six months and continue it",
    other="one anti-obesity drug per member; no renewal if BMI <24 (as reported in the criteria search results is not used; see form)", ver="ForwardHealth PA Drug Attachment for Anti-Obesity Drugs, F-00163 (11/2025); ForwardHealth Update 2025-16", typ="state agency document",
    url="https://www.dhs.wisconsin.gov/forms/f00163-1125.pdf", url2="https://www.forwardhealth.wi.gov/kw/pdf/2025-16.pdf"),
 "Virginia": dict(pa="Y (service authorization)", bmi="2022 form: >=30 (>=27 with two or more risk factors); form effective 2026-07-01: GLP-1 weight-loss agents BMI >40, or >37 with dyslipidemia, hypertension or type 2 diabetes", comorb="2022 form: >=27 with two or more of coronary heart disease, dyslipidemia, hypertension, sleep apnea, type 2 diabetes; 2026 form: >37 with one or more of dyslipidemia, hypertension, type 2 diabetes",
    step="Y (form effective 2026-07-01): tried and failed one non-GLP-1 weight-loss medication (or intolerant to all), and tried and failed the PDL-selected product; 2022 form: previous failure of a weight loss treatment plan in the past 6 months",
    other="nutritional counseling and a physical activity program required; renewals stop at BMI <25", ver="DMAS Service Authorization forms: Anti-Obesity Drugs (effective 2022-01-20) and Weight-Loss Management (effective 2026-07-01)", typ="state agency document (contractor-hosted)",
    url="https://www.virginiamedicaidpharmacyservices.com/provider/external/medicaid/vamps/doc/en-us/VAMPS_SAform_Weight_Loss_Management.pdf", url2="https://www.virginiamedicaidpharmacyservices.com/provider/external/medicaid/vamps/doc/en-us/VAMPS_SAform_Anti_Obesity.pdf"),
 "Kansas": dict(pa="Y", bmi=">=30 (adults); 'high-cost' agents (Table 4, includes Saxenda and Wegovy): severe obesity BMI >=40, or for Wegovy BMI >=27 with established cardiovascular disease", comorb="BMI >=27 with >=1 weight-related comorbidity (Table 2)",
    step="Y: the preferred PDL drug is required unless the patient meets non-preferred PDL criteria; 'high-cost' agents need >=3% weight loss after >=3 months of lifestyle modification", other="comprehensive lifestyle interventions; approval 12 weeks (8 weeks for high-cost agents)",
    ver="KDHE/KMAP Anti-Obesity Medications PA criteria (revised 2024-01-17)", typ="state agency document", url="https://www.kdhe.ks.gov/DocumentCenter/View/34035/Anti-Obesity-Agents-PDF"),
 "Delaware": dict(pa="Y (the 2026 PDL: all obesity treatment agents require prior authorization)", bmi=NF, comorb="coverage is for obesity drugs 'to address weight loss with co-morbid conditions with prior authorization' (State Plan DE 19-0009)", step="Y: two preferred products are required before a non-preferred product (2026 PDL)",
    other="criteria apply to fee-for-service members; MCO members go through the MCO", ver="Delaware Medicaid PDL (live 10/05/2026); State Plan Amendment DE 19-0009 (effective 2019-10-01)", typ="state agency document",
    url="https://medicaidpublications.dhss.delaware.gov/docs/search?Command=Core_Download&EntryId=940", url2="https://www.medicaid.gov/sites/default/files/2022-09/DE-19-0009.pdf"),
 "Missouri": dict(pa="Y (may be transparent: a billable ICD-10 obesity code on the claim can approve without PA)", bmi=">=30 (adults)", comorb="BMI >=27 with one of: hypertension, dyslipidemia, obstructive sleep apnea, prediabetes, previous myocardial infarction, previous stroke, symptomatic peripheral arterial disease; MASH with F2-F3 fibrosis alternative",
    step="Y: preferred agents (Zepbound, Foundayo) first; Wegovy is non-preferred and needs medical necessity for not using a preferred agent", other="age 12+ (Foundayo 18+); BMI >=95th percentile for under 18", ver="MO HealthNet SmartPA Criteria, GLP-1 Receptor Agonists Indicated for Obesity PDL Edit (revised 2026-04-23)", typ="state agency document",
    url="https://dss.mo.gov/media/file/glucagon-peptide-1-glp-1-receptor-agonists-indicated-obesity-pdl-edit"),
 "Tennessee": dict(pa="Y (interim PA criteria from 2025-08-01; Wegovy and Zepbound preferred with PA and quantity limits)", bmi=">=30 (adults)", comorb="BMI >=27 with a weight-related comorbidity (e.g. hypertension, dyslipidemia, diabetes, coronary heart disease, MASH/NASH, obstructive sleep apnea)",
    step="none for the preferred agents (Wegovy, Zepbound); Y for non-preferred agents (Saxenda, liraglutide): trial and failure, contraindication or intolerance of two preferred agents", other="prescriber attests to nutritional and lifestyle changes; initial authorization 3 months from 2026-01-01; renewal needs >=5% weight loss",
    ver="TennCare Provider Notice, Obesity Management Agents (2025-08-01) and Provider Notice 2025-12-01", typ="state agency document",
    url="https://contenthub-aem.optumrx.com/content/dam/contenthub/onboarding/assets/Tenncare/Provider-Notice-Obesity-Management-Agents-08-01-25.pdf", url2="https://contenthub-aem.optumrx.com/content/dam/contenthub/onboarding/assets/Tenncare/Provider-Notice-Weight-Management-Updates-12-01-25.pdf"),
}
S["Wisconsin"]["other"] = "one anti-obesity drug per member; Wegovy and Zepbound are among the drugs on the F-00163 attachment"
ref = root / "data" / "reference"
rows = list(csv.DictReader(open(ref / "medicaid_obesity_coverage.csv", encoding="utf-8")))
fieldnames = list(rows[0].keys())
first = {}
for r in rows: first.setdefault(r["state"], r)
assert set(S) == set(first), set(S) ^ set(first)
for r in rows:
    d = S[r["state"]]
    r["prior_authorization"], r["bmi_threshold"], r["comorbidity_requirement"], r["step_therapy"] = d["pa"], d["bmi"], d["comorb"], d["step"]
with open(ref / "medicaid_obesity_coverage.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames); w.writeheader(); w.writerows(rows)
out = []
for st, d in S.items():
    f = first[st]
    out.append(dict(state=st, analysis_group=f["analysis_group"], delivery_system=f["delivery_system"], products_covered=f["products_covered"], prior_authorization=d["pa"], bmi_threshold=d["bmi"],
                    comorbidity_requirement=d["comorb"], step_therapy=d["step"], other_requirements=d["other"], criteria_version=d["ver"], source_type=d["typ"], source_url=d["url"], supporting_source_url=d.get("url2", ""),
                    date_accessed=ACC, note="a cell reading 'not found in sourced documents' means no saved or retrieved state document states it; criteria can differ by period (see criteria_version)"))
with open(ref / "medicaid_obesity_um_criteria.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out), "states;", sum(NF in " ".join(str(v) for k, v in o.items() if k in ("prior_authorization", "bmi_threshold", "comorbidity_requirement", "step_therapy")) for o in out), "with at least one 'not found' cell")
