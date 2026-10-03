# Data sources and provenance

Every number published from this project must trace back to a file in `data/manifest.csv`
(dataset, file, URL, release, years, access date, bytes, sha256, rows). Raw and interim data are gitignored.
Scripts in `scripts/fetch/` are idempotent, retry with backoff, and log to `logs/`.
Repo lives outside OneDrive (a local folder outside any cloud-synced directory) so multi-GB raw files do not sync.

## Product map (`data/reference/product_map.csv`) - phase 1, step 4a

**Scripts:** `00_fda_ndc_rxnorm.py`, `01_openfda_labels.py`, `02_build_product_map.py`.

**Sources**
- FDA National Drug Code Directory text files (`ndctext.zip`: product.txt, package.txt), downloaded 2026-10-03 from
  accessdata.fda.gov. The excluded-drugs file was downloaded and has **no** in-scope rows. The unfinished-drugs file
  was downloaded; its 320 in-scope rows are bulk active-ingredient listings ("drug for further processing"), not
  finished products, so they are **not used**. The compounders file was not downloaded (compounded products carry no
  SDUD NDC).
- RxNorm via NLM RxNav REST (version 08-Sep-2026): ingredient RxCUIs, all SCD/SBD concepts, `allhistoricalndcs`
  (historical and obsolete NDCs with start/end month) and `ndcstatus` per NDC.
- openFDA drug label API (`api.fda.gov/drug/label.json`), looked up by product NDC, used to assign `label_group`.

**ndc11:** 11 digits, no dashes, 5-4-2 (labeler-product-package). FDA 4-4-2 / 5-3-2 / 5-4-1 codes are zero-padded in
the short segment.

**Ingredients in scope:** semaglutide, tirzepatide, liraglutide, dulaglutide, exenatide, lixisenatide, orforglipron
(present as Foundayo in FDA directory and RxNorm). RxNorm ATC class A10BJ also lists **albiglutide** (Tanzeum,
discontinued); RxNorm holds no NDCs for it, so nothing was added. Combination products Soliqua (insulin glargine +
lixisenatide) and Xultophy (insulin degludec + liraglutide) are included under the GLP-1 ingredient with
`is_combination = Y`.

**RxNorm-only NDCs:** RxNorm lists some inner-unit NDCs (e.g. `...-01`) that the FDA package file omits. Where the
first 9 digits match an FDA product, the FDA product attributes are inherited (source `RXNORM+FDA_PRODUCT_9DIGIT`).
For the 29 remaining obsolete NDCs (`RXNORM_ONLY`), dosage form, strength and route are parsed from the RxNorm concept
name and the route is derived (injectables -> SUBCUTANEOUS, "Oral" -> ORAL); treat those three fields as derived.

**label_group** (obesity / diabetes) is read from the FDA label indications text, never from memory:
`obesity` if the indications section (before "Limitations of Use") mentions reducing excess body weight / chronic
weight management, `diabetes` if it mentions glycemic control. A label matching both would be flagged `both`
(none occurred). `label_verified` records the evidence level:
- `Y_product_label`: openFDA label found for that product NDC;
- `Y_brand_label`: no label for that product NDC (e.g. Novo Nordisk's own Wegovy/Ozempic injection labels are absent
  from openFDA, which holds only repackager copies), so the group is inherited from the same brand's labelled products;
- `N_expected_unverified`: **Bydureon (3 NDCs)** has no label in openFDA, DailyMed or the FDA NDC directory
  (discontinued). The group `diabetes` is the one expected in the project brief and is flagged; confirm against the
  Drugs@FDA label archive in phase 5.

Generic liraglutide is split correctly by label: Victoza-type generics -> diabetes; Saxenda-type generics (Teva
0480-7250, Cipla 69097-910, Biocon 70377-095, Orbicular 81607-019, ...) -> obesity. Off-label use cannot be separated
from SDUD; label_group is the labelled indication only.

**Known gap:** SDUD contains NDC 00169413212 (Ozempic) that is in neither the FDA directory nor RxNorm. See the SDUD
section; it is held back, not silently added.

## Medicaid State Drug Utilization Data (SDUD) - phase 1, step 5.1

**Script:** `03_sdud.py`, `05_phase1_report.py`.
Datasets found via the data.medicaid.gov metastore ("State Drug Utilization Data YYYY"), see
`data/raw/sdud/_discovered_datasets.json`. Each yearly CSV was streamed (sha256 recorded), filtered with DuckDB to
product-map NDCs, and then **deleted** to save disk (sha256 and bytes are in the manifest; re-download from the URL
and verify). The parsed row count of every file is checked against its line count.

Fields kept: utilization_type (FFSU / MCOU), state, ndc (lpad to 11), labeler_code, product_code, package_size, year,
quarter, suppression_used (boolean), product_name, units_reimbursed, number_of_prescriptions,
total_amount_reimbursed, medicaid_amount_reimbursed, non_medicaid_amount_reimbursed.

Rules: amounts are **before rebates**; rows with fewer than 11 prescriptions are suppressed and their numeric fields
are NULL (kept NULL, flagged by `suppression_used`, never 0). State `XX` national-total rows are written to separate
files (`sdud_YYYY_national_xx.parquet`) and must never be summed with states. Rows whose product name looks in-scope
but whose NDC is not in the product map are saved in `sdud_YYYY_unmatched_name_candidates.parquet`.

## Medicaid enrollment denominators - phase 1, step 5.2

**Script:** `04_enrollment.py`. All four datasets found by title in the data.medicaid.gov metastore.
- *State Medicaid and CHIP Applications, Eligibility Determinations, and Enrollment Data* (PI dataset, September 2026
  release): monthly total Medicaid+CHIP, Medicaid, CHIP, adult and child enrollment by state, 2013-09 to 2026-06. Each
  state-month can have a preliminary (P) and an updated (U) row; both are kept. Prefer U, fall back to P (2026-06 is
  preliminary only).
- *Managed Care Enrollment Summary* (datastore API): yearly total Medicaid enrollees, any managed care and
  comprehensive managed care enrollment, 2016-2024 (states, territories and a TOTALS row).
- *Managed Care Information for Medicaid and CHIP Beneficiaries by Month / by Year*: managed care enrollment by
  participation type with CMS's data-usability flag (`dunusable`); **ends 2022-12**.

Limits: no managed-care split is available for 2025-2026, so FFS vs managed-care denominators for the latest SDUD
quarters need an assumption (to be decided, not made here). Footnote digits are stripped from state names in the
summary table (`state_clean`).

## State Medicaid obesity-drug coverage (`data/reference/medicaid_obesity_coverage.csv`) - step 5.3, second pass

Built by `scripts/build/build_coverage_table.py` from documents saved under `data/raw/coverage_sources/<STATE>/`
(gitignored; `_sources_log.csv` lists URL, snapshot and access date; `scripts/fetch/covtool.py` fetched them, including
Wayback copies where a state site returns 403). Source order followed: state PDL / bulletins / criteria, Wayback
snapshots, KFF surveys. KFF's January 2026 brief (data embedded in its map) supplies the list of 13 covering states and the
4 withdrawals; the KFF FY2025-26 survey gives product coverage and "added in the last year" statements.

Exposure = coverage of any GLP-1 for obesity (Saxenda, Wegovy, Zepbound, Foundayo); `first_product_covered` is separate.
A date is filled only when a document states it; otherwise it is blank and confidence is `low`. `coverage_end` is the
last covered day (the day before a stated effective-end date). Web-search summaries and aggregator sites were used only as
leads, never as sources.

SDUD columns (`sdud_first_obesity_quarter_*`, `sdud_discrepancy_flag`) are **flags only** and never set or adjust a date.
They use all obesity-labelled product-map NDCs (including generic liraglutide of the Saxenda type). Nearly every state
shows obesity-labelled volume from 2018 (mostly Saxenda, via exceptions, off-label or other pathways), so
`SDUD_EARLIER` is common and says nothing about which date is right.

Results: see the checkpoint report. States with a sourced start: MS, NC, PA, MI, RI, MA, SC, UT (UT low). With a sourced
end: NC, PA, RI, MA, SC, CA, NH, UT (UT low). Unresolved start: CA, NH, MN, WI, VA, KS, DE, MO, TN.

## Medicare Part D Prescribers by Provider and Drug - phase 2, step 5.4

**Script:** `07_partd_prescribers.py`. Yearly datasets found in the data.cms.gov catalog by title; each year queried
through the data API with a server-side `Gnrc_Name CONTAINS` filter for semaglutide, tirzepatide, liraglutide,
dulaglutide, exenatide, lixisenatide, orforglipron and albiglutide (combination generics match more than once and are
de-duplicated). Years 2013 to 2024 are queried; the 2024 dataset (release modified 2026-05-21) has two API distributions
with identical schema and row counts, the first is used. **2025 is not released.** Fields: the Prscrbr_* identity fields,
Brnd_Name, Gnrc_Name, Tot_Clms, Tot_30day_Fills, Tot_Day_Suply, Tot_Drug_Cst, Tot_Benes, and the GE65 fields with CMS
suppression flags (`GE65_Sprsn_Flag`, `GE65_Bene_Sprsn_Flag`). Blank (suppressed) values are NULL, never 0.
Data dictionary: https://data.cms.gov/resources/medicare-part-d-prescribers-by-provider-and-drug-data-dictionary (listed
in the catalog; flag meanings per CMS: counts under 11 are suppressed).

## Spending by drug - phase 2, step 5.5

**Script:** `08_spending_by_drug.py`. "Medicare Part D Spending by Drug" and "Medicaid Spending by Drug" are single wide
tables per release (2026 release, data years 2020-2024, year-suffixed columns). The full CSV is downloaded, filtered to
in-scope generic/brand names, saved wide and long (one row per drug-manufacturer-year) with total spending, dosage units,
claims, beneficiaries (Part D only), average spending per dosage unit (weighted), per claim and per beneficiary, the
outlier flags and the 2023-24 change and 2020-24 CAGR fields. Medicaid spending is before rebates. A separate "Medicare
Quarterly Part D Spending by Drug" dataset (2026 Q1) exists in the catalog and was not downloaded (outside the brief).

## NADAC - phase 2, step 5.6

**Script:** `09_nadac.py`. Yearly NADAC datasets 2018-2026 found in the data.medicaid.gov metastore; each CSV is streamed,
checked against its line count, filtered to product-map NDCs and then deleted (sha256 in the manifest). Fields: ndc,
ndc_description, nadac_per_unit, pricing_unit, effective_date, classification_for_rate_setting, explanation_code,
pharmacy_type_indicator, as_of_date. **NADAC is a pharmacy acquisition-cost survey, not a net price and not a list
price.** NDCs absent from NADAC (not surveyed) simply have no rows.

## SDUD suppression diagnostics (`11_sdud_suppression_diagnostics.py`)

Output `data/interim/sdud_suppression_diagnostics.parquet` (stacked, `diagnostic` column): (a) unsuppressed rows with 0
prescriptions; (b) suppression among national `XX` rows; (c) state x quarter x label_group observed prescriptions,
suppressed-row count and maximum hidden share = 10S / (observed + 10S) (FFSU + MCOU combined; includes combination-product
NDCs); (d) per NDC x quarter x utilization type, XX total minus observed state rows compared with 1x-10x the number of
suppressed state rows. Diagnostics only; no modelling. Results are in the checkpoint report.

## Candidate source for the sensitivity-group states (recorded 2026-10-03, not yet used)
The CMS State Plan Amendment (SPA) database on Medicaid.gov may give systematic, CMS-approved effective dates for when each
state added weight-loss drugs as a covered category. Candidate for every state still in the sensitivity group
(NH, MN, WI, VA, DE, MO, TN, UT). Caveat: a SPA effective date marks coverage of the *category* (it can reflect Saxenda-era or
older-drug coverage) and does not by itself show Wegovy or Zepbound coverage; read the SPA text for product scope before using
it for the primary exposure. Already seen: MS SPA 23-0013 (eff. 2023-07-01), MI SPA 21-0018 (eff. 2022-02-01), DE SPA 19-0009
(eff. 2019-10-01, approved 2022-09-14, "clarifies" obesity drug coverage).

## CMS Open Payments General Payment Data - phase 3, step 5.7

**Script:** `13_open_payments.py`. Program years found in the openpaymentsdata.cms.gov catalog: **2019-2025** (2018 is not in the
current catalog). Deviation from the brief (logged): the datastore API needs 27-65 s per 500 rows (Ozempic alone has ~200k rows in 2024),
so each yearly CSV (3-6 GB) was downloaded, sha256-recorded, filtered with DuckDB and deleted. Rows are kept where **any** of
`Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_1..5` contains an in-scope brand or generic (case-insensitive substring);
`matched_product_name` is the first matching field and the exact strings are in `data/interim/open_payments/_matched_strings_YYYY.csv`
(16 distinct strings). Fields kept: Record_ID, program year, change type, dispute status, recipient type, NPI, primary type and specialty,
state and ZIP, manufacturer, payment amount, date, nature and form of payment, the five product names with their drug/device indicator and
therapeutic-area fields. Limits: non-physician practitioners (NPs, PAs etc.) are covered recipients only from program year 2021
(2019-2020 are 100% physicians); food-and-beverage payments dominate row counts; payments name the product discussed, not the indication.

## NPPES and NUCC - phase 3, step 5.8

**Script:** `14_nppes_nucc.py`. NPPES full monthly file `NPPES_Data_Dissemination_September_2026_V2.zip` (1.16 GB; link found by rendering
the CMS NPI Files page because it is built by JavaScript). **Stream-filtered from the zip without unzipping** (9,798,758 rows read) to the
394,687 NPIs that appear in Part D prescribers (267,678) or Open Payments (266,495); 394,686 found. Kept: NPI, entity type, credential,
enumeration, last-update and deactivation dates, practice state and ZIP, all 15 taxonomy codes with switches, and `primary_taxonomy_code`
(the code whose primary switch is Y, else code 1). 5,996 kept NPIs are deactivated; 4,745 rows have a blank entity type (deactivated
records with blank fields). NUCC taxonomy version 26.1 (883 codes) from nucc.org; 98.8% of primary taxonomy codes are in it. The NPPES zip
is kept in `data/raw/nppes` so the filter can be re-run (sha256 in the manifest).

## NHANES - phase 4, step 5.9 (`17_nhanes.py`)
Official XPT files from the NCHS data pages (links read from the pages, URL of every file in the manifest). **August 2021-August 2023 (suffix _L):**
DEMO_L (11,933), BMX_L, BPXO_L (oscillometric blood pressure), BPQ_L, GHB_L, DIQ_L, MCQ_L, RXQ_RX_L. **2017-March 2020 pre-pandemic (prefix P_):**
P_DEMO (15,560), P_BMX, P_BPXO, P_BPQ, P_GHB, P_DIQ, P_MCQ, P_RXQ_RX, and the RXQ_DRUG lookup (1988-2020). Documentation pages are saved in `data/raw/nhanes/*_doc.htm`.

**Prescription medicines check (the question asked):** `RXQ_RX_L` (2021-2023) **exists but has only 3 columns (SEQN, RXQ033, RXQ050)**: whether any prescription
medicine was taken in the past 30 days and how many. It has **no drug names**, so it cannot identify semaglutide or tirzepatide use, and the RXQ_DRUG
lookup stops at 2020. The 2017-2020 `P_RXQ_RX` does name drugs: 7 semaglutide, 27 dulaglutide, 22 liraglutide and 7 exenatide records, **no tirzepatide**.
Direct GLP-1 use in 2021-2023 therefore cannot be measured in NHANES; use DIQ_L (diabetes medication questions) and BMX_L/GHB_L instead.

**Weights (from NCHS documentation text; analytic-guidelines details to be confirmed at analysis time):** survey design variables SDMVSTRA and SDMVPSU come from DEMO.
2021-2023: `WTINT2YR` (interview) for questionnaire-only analyses (DIQ_L, MCQ_L, BPQ_L, RXQ_RX_L: "interview weights should only be used if questionnaire data are
analyzed by themselves"); `WTMEC2YR` (exam) for BMX_L, BPXO_L ("exam sample weights should be used") and for questionnaire data merged with exam data (MCQ doc);
GHB_L ships its own `WTPH2YR` (phlebotomy weight); DIQ merged with fasting glucose uses the fasting-subsample weight (WTSAF2YR, in the fasting lab file, not downloaded).
2017-March 2020: use the special pre-pandemic weights in P_DEMO: `WTINTPRP` (interview) and `WTMECPRP` (exam); the older 2017-2018 and 2019-2020 cycles are not
separately representative (weights apply to the combined file only). Do not combine the two periods' weights without the NCHS combining guidance.

## MEPS Household Component - phase 4, step 5.10 (`18_meps.py`)
File numbers from AHRQ's PUFID.csv, links from each file's detail page. Latest two years (2024 is the latest released): Full-Year Consolidated HC-256 (2024, 19,140 persons)
and HC-251 (2023, 18,919); Prescribed Medicines event files HC-254A (2024, 204,550) and HC-248A (2023, 192,275); Medical Conditions HC-255 (2024, 67,705) and HC-249 (2023, 63,656).
Full files kept as Parquet; documentation and codebook PDFs saved. **MEPS conditions use 3-character ICD-10-CM codes** (`ICD10CDX`; all 67,705 codes have length 3; `-15` is the
inapplicable/missing code). The prescribed-medicines files name drugs (e.g. Ozempic 1,995 rows and Mounjaro 965 in 2024).

## ICD-10-CM value sets - phase 4, step 5.11 (`19_icd10.py`)
`data/reference/icd10_value_sets.csv` built from the CMS FY2027 code-descriptions tabular-order file (98,403 codes; `icd10cm_order_2027.txt`): type 2 diabetes E11 (117 codes, 87 billable),
obesity E66 (14, 10 billable), BMI Z68 (39, 33 billable) and a comorbidity placeholder row. Codes and descriptions are copied from the CMS file; `code` is dotted, `code_nodot` as in CMS,
`billable` = CMS valid-for-submission flag. Selection is by explicit fiscal year (an earlier run picked the FY2026 April update by mistake and was redone).

## Trials, approvals, labels and policy documents - phase 5, step 5.12
- **ClinicalTrials.gov API v2** (`20_clinicaltrials.py`): one query per ingredient (semaglutide, tirzepatide, orforglipron, liraglutide, dulaglutide, exenatide, lixisenatide, albiglutide)
  with a condition filter (obesity, overweight, type 2 diabetes, weight management); 1,569 distinct studies (430 with results posted; 431 phase 3, 326 phase 4). Fields: NCT ID, titles, phase, status,
  start / primary completion / completion dates, sponsor and class, enrollment, results posted, conditions, interventions, `matched_ingredients`. Raw pages saved.
- **Drugs@FDA data files** (`21_drugsatfda.py`; FDA page dated 2026-10-02): 32 in-scope applications. Original approval dates come from the data (e.g. Wegovy NDA 215256 2021-06-04, Zepbound NDA 217806 2023-11-08,
  Foundayo NDA 220934 2026-04-01, Wegovy tablets NDA 218316 2025-12-22). 265 approved supplements, 64 of them class "Efficacy"; `inscope_efficacy_supplements.csv` lists their dates for the key brands as
  CANDIDATE indication supplements (the data do not say which indication each added; read the label history before using one).
- **Labels** (`22_fda_labels.py`): the latest label PDF per in-scope NDA/BLA from Drugs@FDA is in `data/raw/fda_labels` (this fills the gap left by openFDA, which has no innovator label for Wegovy, Ozempic injection
  or Bydureon); openFDA label JSON per brand from Phase 1 stays in `data/raw/openfda_label`. Indications text confirms: Foundayo, Saxenda, Wegovy (injection and tablets) and Zepbound = weight reduction;
  every other in-scope brand = glycemic control in type 2 diabetes. **Bydureon and Bydureon BCise (2025-06-02 labels) are verified as diabetes-only.**
- **Product map updates** (`23_update_map_after_drugsatfda.py`, run after 02 and 06): Bydureon `label_verified = Y_drugsatfda_label`; SDUD-only brands `Y_brand_label_drugsatfda`; labeler codes of the 15 SDUD-only NDCs
  checked against Drugs@FDA sponsors: 14 confirmed (Novo 00169, AstraZeneca 00310, Sanofi 00024, GlaxoSmithKline 00173), 1 not confirmable (labeler 66780: Drugs@FDA lists sponsors, not NDC labeler codes).
- **Policy documents** (`24_policy_docs.py`, saved in `data/raw/policy_documents` with access date in the manifest): the CMS Medicare GLP-1 Bridge page and prescriber PDF (July 1, 2026 to
  December 31, 2027; $50 copay; Foundayo, Wegovy, Zepbound KwikPen; BMI-tiered criteria), the CMS launch press release, and the KFF Medicaid Coverage of and Spending on GLP-1s page (2026-01-16).
- **Trial efficacy inputs**: `data/reference/trial_inputs.csv` is an empty template (columns trial, drug, dose, population, duration_weeks, outcome, value, uncertainty, source_citation, doi, page_or_table);
  SURMOUNT-1, SURMOUNT-5, STEP-1 and others are to be extracted by hand from the published papers.

Run order for the product map: 00, 01, 02, then 06 (SDUD-only NDCs), then 23 (Drugs@FDA evidence); re-running 02 alone drops the 06 and 23 updates.
