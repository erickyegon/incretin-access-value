# Data dictionary and analysis conventions

## Product map (`data/reference/product_map.csv`)
| column | meaning |
|---|---|
| ndc11 | 11 digits, no dashes, 5-4-2 |
| ingredient | GLP-1 ingredient (for combination products, the GLP-1 component) |
| brand | brand name; blank for generics |
| dosage_form, route, strength, labeler_name | from the FDA directory; for `RXNORM_ONLY` rows parsed/derived from the RxNorm concept name (route derived) |
| rxcui, first_seen, last_seen, ndc_status | RxNorm concept and history (YYYYMM); `SDUD_ONLY` NDCs use first/last SDUD quarter (month = first/last month of that quarter) |
| label_group | `obesity` or `diabetes`, from the FDA label indications |
| label_verified | `Y_product_label`, `Y_brand_label`, `N_expected_unverified` (Bydureon, from brief), `N_sdud_name_inferred` (SDUD-only NDCs) |
| source | `FDA_NDC_DIRECTORY+RXNORM`, `RXNORM+FDA_PRODUCT_9DIGIT`, `RXNORM_ONLY`, `SDUD_only` |
| is_combination | TRUE/FALSE |

**Combination products (Soliqua, Xultophy; `is_combination = TRUE`)** stay in the map but are **excluded from the main
outcome** and used **only in a sensitivity analysis**.

**SDUD_only NDCs** (older Ozempic pens, Bydureon, Adlyxin, Tanzeum) appear in SDUD but in neither the FDA directory nor
RxNorm. They are classified from labeler code and SDUD product name only, all `label_group = diabetes`. Tanzeum
(albiglutide) is discontinued and outside the original ingredient list; it was added by instruction. Labeler codes
must be confirmed against Drugs@FDA in phase 5. Labeler code 66780 is not in the FDA directory (labeler_name blank).

## SDUD
- Amounts are before rebates. Counts under 11 are suppressed: number_of_prescriptions and amounts are NULL and
  `suppression_used = true`. Suppressed is never 0.
- `XX` national rows are in separate files and are never summed with states.
- Files are revised after release; `date_accessed` in the manifest is the download date for each year.
- **2026 Q1 is preliminary** (the 2026 file contains Q1 only).

## Outcome and denominators (module C)
- **Primary outcome:** all Medicaid prescriptions (FFSU + MCOU) per 1,000 total Medicaid/CHIP enrollees
  (PI dataset, `total_medicaid_and_chip_enrollment`, updated row preferred over preliminary).
- **Secondary outcome (FFS only):** FFSU prescriptions over the FFS share of enrollment, using the managed-care share
  from the Managed Care Enrollment Summary. The summary ends in 2024; the **2024 share is carried forward to 2025 and
  2026 as an ASSUMPTION** (flag any estimate that uses it). No other imputation.
- Suppressed rows are treated as missing, not zero; the handling of that in aggregates is decided in analysis.

## Medicaid obesity coverage (`medicaid_obesity_coverage.csv`)
Exposure = coverage of any GLP-1 for obesity (Saxenda, Wegovy, Zepbound, Foundayo), with `first_product_covered`
recorded separately. Dates are sourced only. `sdud_first_obesity_quarter` and `sdud_discrepancy_flag` are
discrepancy flags computed from SDUD volume; they never set or adjust a date.

## SDUD suppression: decisions for later analysis (recorded 2026-10-03; diagnostics in `sdud_suppression_diagnostics.parquet`)
1. **Imputation range.** A suppressed cell ranges from **0 to 10** prescriptions. Diagnostic (a) found no unsuppressed row
   with fewer than 11, but diagnostic (d) found residual-0 cases (a suppressed state row whose national XX residual is 0),
   so 0 cannot be ruled out. The national-residual constraint (XX total minus observed state rows) is applied **only where
   the XX row is unsuppressed and the residual is positive**. Suppressed XX rows (13% of XX rows) give no constraint.
2. **Analysis sample** = the 50 states plus DC. Territories (PR in the current data) stay in the data and are flagged
   (`is_territory`, `in_analysis_sample`). **Soliqua and Xultophy (`is_combination = TRUE`) are excluded** from the
   diagnostics `c2_*` rows and from the main outcome.
3. **`max_hidden_per_1000`** = 10 x suppressed rows / total Medicaid+CHIP enrollment of the state-quarter x 1,000. Enrollment
   = mean of the months in the quarter that report a value (PI total_medicaid_and_chip_enrollment, updated row preferred over
   preliminary; `months_avail` records how many of 3). A PI value of 0 is a reporting failure, not enrollment: it is set to
   NULL (`enrollment_zero_set_null`; 3 rows, all Rhode Island Dec 2024 - Jan 2025, footnote "Unable to Provide Data due to
   System Limitations").
4. **Outcomes are modelled as rates in levels, not logs.**

## Exposure definition for module C (decided 2026-10-03)
- **Primary exposure** = the first covered quarter for **Wegovy or Zepbound for weight management** (`start_wegovy_zepbound`
  in `medicaid_obesity_coverage.csv`, derived from product-specific dates in the documents). **Saxenda coverage is a separate
  column** (`start_saxenda`) and is not part of the primary exposure.
- Product-specific start dates are recorded wherever a document gives them; otherwise the product column is blank. The
  earlier `coverage_start` / `coverage_end` columns remain the any-GLP-1-for-obesity dates.
- Dates that are not exact are recorded as a range: `start_earliest` = (last dated document showing no coverage) + 1 day and
  `start_latest` = first dated document showing coverage, each with its source. Ranges wider than one quarter are flagged
  (`range_wider_than_1q`). SDUD volumes are never used to set or adjust any date.

## Medicare Part D Prescribers by Provider and Drug
- Rows exist **only for prescriber-drug pairs with at least 11 claims** in the year (CMS omits smaller pairs), so the file is
  left-truncated and totals understate small prescribers.
- **`Tot_Benes` is mostly suppressed** (blank in 72-91% of rows depending on year; `GE65_Bene_Sprsn_Flag` marks it), so
  analyses of prescribers use **claims** (`Tot_Clms`, `Tot_30day_Fills`, `Tot_Drug_Cst`), not beneficiaries.
- Blank values are NULL, never 0. The latest released year is 2024 (2025 not released).
