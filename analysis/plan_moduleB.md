# Module B plan: eligible population, patient funnel and five-year forecast

Written before any Module B result. Changes after results go in `analysis/outputs/deviations.md`.

## Question
How many U.S. adults are eligible for obesity-labelled incretins, how many are diagnosed and treated, and how might treatment grow over five years (2026-2030)?

## Data
`mart_nhanes_adults` (NHANES, adults 18 and over; 2021-2023 primary, 2017-March 2020 pre-pandemic for the trend comparison; the mart was extended for this module to include ages 18-19, the health insurance files HIQ_L and P_HIQ, and the condition variables below). Brand split: `mart_sdud_state_quarter_brand` (Medicaid, covered states) and `mart_prescriber_year` (Part D 2024). Published national GLP-1 use: KFF Health Tracking Polls (saved in `docs/sources/`).

## Survey method
R `survey` package: `svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~weight, nest = TRUE, data = <all adults 18+>)`, then `subset()` on the design object (never filtering rows first). Weights, as the NCHS documentation says:
- 2021-2023: MEC exam weight `WTMEC2YR` for estimates using the exam (BMI, blood pressure) and questionnaire variables. **HbA1c is a blood analyte: NCHS says to use the phlebotomy weight `WTPH2YR` for analyses that use variables derived from blood analytes** (GHB_L documentation, "Phlebotomy Weights"), so every estimate that uses HbA1c (undiagnosed diabetes, and eligibility that includes it) uses the `WTPH2YR` design; the same eligibility estimate without HbA1c uses `WTMEC2YR` and both are reported. (The brief names `WTMEC2YR`; this follows the codebook.)
- 2017-March 2020: `WTMECPRP` (the file has no separate phlebotomy weight).
Weighted counts are in millions with 95% CIs and prevalences in %; the sum of the weights is reported against the U.S. civilian non-institutionalised adult population it represents (NHANES excludes institutionalised people and people in the armed forces).

## Variables (verified against the NCHS codebook pages saved in `data/raw/nhanes/*_doc.htm`; `analysis/outputs/tables/nhanes_variables_used.csv` lists each with its codebook description)
| Concept | 2021-2023 | 2017-2020 | Codebook description |
|---|---|---|---|
| Age, sex | RIDAGEYR, RIAGENDR | same | Age in years at screening; Gender |
| Design | SDMVPSU, SDMVSTRA, WTMEC2YR, WTPH2YR | SDMVPSU, SDMVSTRA, WTMECPRP | pseudo-PSU, pseudo-stratum, exam / phlebotomy weights |
| BMI | BMXBMI | BMXBMI | Body Mass Index (kg/m**2) |
| Told hypertension | BPQ020 | BPQ020 | Ever told you had high blood pressure |
| BP medication | BPQ150 | BPQ040A or BPQ050A | now taking medication prescribed for high blood pressure (2021-2023); taking prescription for hypertension / now taking prescribed medicine for HBP (2017-2020) |
| Measured BP | BPXOSY1-3, BPXODI1-3 | same | oscillometric systolic and diastolic readings; mean of up to three readings, hypertension if mean systolic >= 130 or diastolic >= 80 (NCHS Data Brief 511 definition, also with medication) |
| Told high cholesterol | BPQ080 | BPQ080 | Doctor told you high cholesterol level |
| Cholesterol medication | BPQ101D | BPQ100D (now taking prescribed medicine) | Taking meds to lower blood cholesterol |
| Diagnosed diabetes | DIQ010 (1 = yes) | DIQ010 | Doctor told you have diabetes ("borderline" coded 3 is not diabetes) |
| Insulin / diabetes pills | DIQ050 / DIQ070 | same | Taking insulin now / diabetic pills to lower blood sugar |
| HbA1c | LBXGH | LBXGH | Glycohemoglobin (%) |
| Prediabetes told | DIQ160 | DIQ160 | Ever told you had prediabetes |
| Cardiovascular disease | MCQ160B, C, D, E, F | same | congestive heart failure, coronary heart disease, angina, heart attack, stroke (any yes) |
| Told overweight | not asked (MCQ080 absent from MCQ_L) | MCQ080 | Doctor ever said you were overweight |
| Insurance | HIQ011, HIQ032D (Medicaid), HIQ032E (CHIP), HIQ032B (Medicare) | same | Covered by health insurance / Medicaid / CHIP / Medicare |

## Eligibility rule (FDA labels saved in `data/raw/fda_labels`, not memory)
Wegovy and Zepbound labels, section 1 (Indications and Usage), quoted: *"to reduce excess body weight and maintain weight reduction long term in: Adults and pediatric patients aged 12 years and older with obesity. Adults with overweight in the presence of at least one weight-related comorbid condition"* (Wegovy); *"to reduce excess body weight and maintain weight reduction long term in adults with obesity or adults with overweight in the presence of at least one weight-related comorbid condition"* (Zepbound); Foundayo: same wording for adults. **Section 1 gives no BMI numbers.** The BMI cut points come from the label's Clinical Studies (Zepbound section 14, Study 1): *"adult patients with obesity (BMI >= 30 kg/m2), or with overweight (BMI 27 to <30 kg/m2) and at least one weight-related comorbid condition, such as dyslipidemia, hypertension, obstructive sleep apnea, or CV disease"*. Operational rule used here (adults 18+): **BMI >= 30; or BMI 27 to <30 with at least one condition**. The pediatric 12-17 indication is outside the adult population.

Weight-related conditions NHANES can measure: hypertension (told, on medication, or measured as above), dyslipidemia (told high cholesterol or cholesterol medication; no lipid panel is used, so a lower bound), cardiovascular disease (MCQ160B-F), diabetes (told, or HbA1c >= 6.5%). Not measurable: obstructive sleep apnea (and the label's other conditions). **The BMI 27-29.9 group is therefore a lower bound.** Reported also: obesity classes (30-34.9, 35-39.9, >= 40); diagnosed diabetes and undiagnosed diabetes (HbA1c >= 6.5% without a diagnosis); all by age group (18-39, 40-59, 60-64, 65+) and sex; and eligibility among adults with Medicaid (HIQ032D) and Medicaid adults in total, for Module E. Adults with Medicaid include people also covered by Medicare (dual coverage not separated).

## Funnel (each step marked measured or modelled)
1. U.S. adults (measured: sum of weights).
2. Label-eligible (measured, lower bound).
3. Aware/diagnosed (measured): told overweight by a doctor (MCQ080: 2017-2020 only, because the 2021-2023 file does not ask it; the cycle difference is stated); diagnosed diabetes for type 2 diabetes (NHANES cannot separate type 1; diagnosed diabetes among adults is used and labelled so).
4. Drug-treated (diabetes measured: DIQ050 or DIQ070 among diagnosed diabetes; obesity modelled).
5. GLP-1-treated (modelled): KFF Health Tracking Poll (February 24-March 2, 2026, n = 1,343): 12% currently use a GLP-1 drug (Q9: "Are you currently using or have you ever used one of these drugs to lose weight or treat a chronic condition such as diabetes or heart disease?"), margin of sampling error plus or minus 3 points; November 2025 poll: 45% of adults with diagnosed diabetes and 23% of adults diagnosed overweight or obese in the past five years currently use. The poll counts all indications and all GLP-1 drugs.
6. Brand split (modelled, payer-specific): Wegovy versus Zepbound shares from Medicaid SDUD in covered states and from Part D 2024, each labelled with its payer; never the national share.

## Five-year forecast (2026-2030): scenarios, not a prediction
Target: adults currently using a GLP-1 drug without diagnosed diabetes (a proxy for weight-management use that also includes use for heart disease; KFF-based, modelled), and, separately, all current GLP-1 users.
- **Model:** treated(t) = eligible x uptake(t) with logistic growth to a ceiling K from the 2026 anchor u0 (anchor = KFF 12% of adults, split by the NHANES diagnosed-diabetes prevalence and KFF's 45% diabetes use rate).
- **Growth rate:** calibrated to the national KFF series (6% current use in May 2024, 12% in November 2025 and March 2026) and compared with the observed Medicaid obesity_wz trajectory and Module C's dynamic effect as evidence of how fast use rises when access opens.
- **Ceiling K:** assumption range; the KFF poll's 43% interest among adults diagnosed overweight/obese who do not use these drugs is the source for the upper end.
- **Access events:** Medicare GLP-1 Bridge (July 1, 2026 to December 31, 2027; $50 copay; criteria in `docs/sources/cms_medicare_glp1_bridge_prescribers.txt`), oral options (Wegovy tablets; Foundayo approved 2026-04-01 per `label_events`), state coverage changes. Their sizes are assumptions with stated ranges (no source gives their effect on use). The Bridge-eligible Medicare population is measured from NHANES as a lower bound (BMI >= 35; BMI >= 27 with prediabetes, previous heart attack or stroke; excluding diagnosed diabetes; uncontrolled hypertension and kidney disease are not measurable).
- **Price:** the forecast counts people, so price enters Module E, not this forecast.
- Base, upside and downside scenarios; Monte Carlo of 10,000 draws over the parameter ranges (seed 20261004 + 3000); fan chart with median, 50% and 90% bands, the three scenarios as lines, Bridge window and oral launches annotated.

## What is measured and what is assumed
Measured: weighted adult and eligible counts, conditions, insurance, diagnosed diabetes and diabetes medication use, Medicaid and Part D brand shares (within their payer). Modelled or assumed: GLP-1 use from the KFF poll, brand split beyond its payer, uptake ceiling, access-event effects. Every assumption is in `outputs/tables/moduleB_assumptions.csv` with its source or "assumption".

## Outputs
`outputs/tables/moduleB_eligibility*.csv/html`, `moduleB_funnel.csv/html`, funnel figure, forecast figure and table, `moduleB_assumptions.csv`, `nhanes_variables_used.csv`, `outputs/moduleB_summary.md`.
