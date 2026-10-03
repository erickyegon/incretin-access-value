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
