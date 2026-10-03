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

## State Medicaid obesity-drug coverage (`data/reference/medicaid_obesity_coverage.csv`) - phase 1, step 5.3

First pass built only from KFF, "Medicaid Coverage of and Spending on GLP-1s" (published 2026-01-16,
https://www.kff.org/medicaid/medicaid-coverage-of-and-spending-on-glp-1s/). The state list is read from the data
embedded in KFF's map. Delivery system is FFS (KFF covers FFS only).
- 13 states covering GLP-1s for obesity as of Jan 2026: DE, KS, MA, MI, MN, MS, MO, NC, RI, TN, UT, VA, WI. Utah's
  funding was limited to FY 2026 (KFF footnote).
- Withdrawals after Oct 2025: CA, NH, PA, SC. KFF gives no dates, so `coverage_end` is blank.
- North Carolina: dropped beginning Oct 2025, reinstated Dec 2025 (two rows, month precision).
- Prior authorization, BMI threshold, comorbidity, step therapy and all start dates are blank and marked
  "to verify" - KFF does not provide them and nothing was filled from memory. Confidence is `low` throughout.

## SDUD results (as run 2026-10-03)

Years 2018-2025 are complete (Q1-Q4). **The 2026 file (modified 2026-07-10) contains only Q1 2026.**
Kept rows (product-map NDCs): 2018 2,992; 2019 3,120; 2020 3,799; 2021 5,430; 2022 7,402; 2023 9,290; 2024 10,522;
2025 12,832; 2026 3,466 (including `XX` national rows, stored separately). Suppressed share of kept rows is 29-35% per
year (about 50% of all raw rows). No suppressed row has a non-null prescription count.

**Unmatched in-scope NDCs (held back, not added to the product map):** these appear in SDUD under in-scope-looking
names but are in neither the FDA directory nor RxNorm for the map:
- Ozempic: 00169413212, 00169413211, 00169413602, 00169413611 (older Ozempic pens)
- Bydureon: 00310653004, 00310652004, 00310653001, 66780021904 (the map's 3 Bydureon NDCs are different)
- Adlyxin (lixisenatide, in scope): 00024574702, 00024574502
- Tanzeum (albiglutide, candidate only): 00173086735, 00173086635, 00173086601, 00173086701, 00173086602
Full rows are in `data/interim/sdud/sdud_YYYY_unmatched_name_candidates.parquet`, so adding them needs no re-download.
