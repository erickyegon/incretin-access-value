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
