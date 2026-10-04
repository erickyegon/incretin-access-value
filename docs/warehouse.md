# Warehouse: PostgreSQL `incretin` and the dbt project

The warehouse loads the interim Parquet files into PostgreSQL and builds tested, documented tables with dbt. It contains **no analysis**: no
difference-in-differences, imputation, survey estimates or charts. Counts and reconciliations are validation only.

Lineage: `docs/figures/dbt_lineage.png` (everything) and `docs/figures/dbt_lineage_mart_did_panel.png` (upstream of the panel). Browsable
column documentation: `cd dbt && dbt docs generate && dbt docs serve`.

## Schemas

| Schema | Content | Materialisation |
|---|---|---|
| `raw` | Parquet files loaded unchanged (original column names; `_source_file`, `_loaded_at`, `_sha256` added), plus `raw._load_log` | tables, by `scripts/load/load_raw.py` |
| `seeds` | Reference tables committed as CSV in `dbt/seeds` | dbt seeds |
| `staging` | One `stg_` model per source: snake_case, typed, no filters except exact duplicates | views; large unions are tables (the Open Payments, SDUD, Part D, NPPES and NADAC models) |
| `intermediate` | Grids, quarterly rollups, coverage logic, national residuals | views |
| `marts` | Analysis-ready tables | tables |

## Rebuild from scratch

Credentials are not in the repository. dbt reads the password from `INCRETIN_PG_PASSWORD` (the local server uses trust authentication, so any
value works); the profile is `~/.dbt/profiles.yml`.

```bash
python scripts/load/load_raw.py          # raw schema from data/interim (idempotent: sha256 per table in raw._load_log); writes docs/load_reconciliation.csv
cd dbt
dbt deps                                  # dbt_utils only
dbt seed                                  # 7 reference seeds
dbt build                                 # models + seeds + tests
dbt test                                  # tests alone
python ../scripts/build/gen_dbt_wide_models.py       # only after reloading raw: regenerates sources, NHANES and MEPS staging models
python ../scripts/build/gen_dbt_schema_docs.py       # only after model changes: regenerates intermediate and marts schema.yml
dbt docs generate && python ../scripts/build/render_dbt_lineage.py   # lineage images (Graphviz `dot` on PATH)
```

Seed sources: `scripts/build/prepare_seeds.py` (states, product_map, product_groups, coverage spells, ICD-10 value sets, trial inputs) and
`scripts/build/build_label_events.py` (Drugs@FDA). The product map is built by `scripts/fetch/00` to `26` in that order; `26_fix_combination_flags.py`
corrects `is_combination` for the four RxNorm-derived Soliqua/Xultophy NDCs.

## Models

**Staging (31 models plus `_sources.yml`)**: `stg_sdud__state`, `stg_sdud__national`, `stg_enrollment__monthly`, `stg_enrollment__managed_care`,
`stg_partd__prescriber_drug`, `stg_spending__partd`, `stg_spending__medicaid`, `stg_nadac__weekly`, `stg_open_payments__general`,
`stg_open_payments__record_products`, `stg_open_payments__product_split`, `stg_nppes__provider`, `stg_nucc__taxonomy`, `stg_ctgov__studies`,
`stg_fda__applications`, `stg_fda__supplements`, `stg_nhanes__{demo,bmx,bpxo,bpq,ghb,diq,mcq,rxq_rx,rxq_drug}`,
`stg_meps__fyc_2023`, `stg_meps__fyc_2024`, `stg_meps__cond_{2023,2024}`, `stg_meps__rx_{2023,2024}`.

The NHANES and MEPS models are generated from the raw column lists and documented at model level; their variables are the official names,
lower-cased. Official codebooks: NHANES, https://wwwn.cdc.gov/nchs/nhanes/ (each component page links its documentation and variable list);
MEPS, https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp (HC-248 for 2023, the 2024 Full Year Consolidated file and its codebook).
The managed-care tables `enrollment_managed_care_monthly_by_type` and `enrollment_managed_care_yearly_by_type` are loaded into `raw` but not staged.

**Intermediate (9)**: `quarters`, `int_enrollment__state_month`, `int_enrollment__state_quarter`, `int_enrollment__managed_care_share`,
`int_coverage__state_quarter`, `int_sdud__ndc_group`, `int_sdud__state_quarter_group`, `int_sdud__national_residual`, `int_drug_name__product_group`.

**Marts (10)**: `mart_did_panel`, `mart_sdud_state_quarter_long`, `mart_sdud_cells_for_imputation`, `mart_prescriber_year`,
`mart_open_payments_year_product`, `mart_drug_spending_year`, `mart_nadac_brand_quarter`, `mart_nhanes_adults`, `mart_meps_persons`, `mart_pipeline_trials`.
Every column of every mart and intermediate model is described in its `schema.yml`.

## Decisions built into the models

**Panel.** 50 states plus DC (51) x 33 quarters (2018Q1 to 2026Q1) = 1,683 rows. Territories (AS, GU, MP, PR, UM, VI) are excluded from every
panel-state model; Puerto Rico is the only territory with SDUD rows (348 state rows in staging) and is also excluded from the panel. National residuals
sum all jurisdictions, territories included, because the XX row covers all of them.

**Denominators** (rates are per 1,000, in levels, one named column per denominator):

| Column suffix | Field | Role |
|---|---|---|
| `_per_1000_medicaid` | `total_medicaid_enrollment`, item 8a | primary: SDUD counts Medicaid prescriptions and these drugs are used almost entirely by adults |
| `_per_1000_medicaid_chip` | `total_medicaid_and_chip_enrollment`, items 8a + 8h | sensitivity |
| `_per_1000_adult_medicaid` | `total_adult_medicaid_enrollment`, items 8d + 8g | second sensitivity; **populated only from 2024-07** (2024Q3 to 2026Q1: 7 quarters, all 51 states; 0 quarters before). 357 of 1,683 state-quarters have all three months |
| `_ffs_per_1000_ffs_medicaid` | FFSU prescriptions / (item 8a x (1 - comprehensive managed care share)) | secondary FFS-only; the share is the CMS Managed Care Enrollment Report's comprehensive managed care share, with the **2024 share carried forward to 2025 and 2026 (an assumption, flagged `mc_share_carried_forward`)**. AK, CT, ME, MT, SD and WY have no managed care report row for 2023 to 2024, so their FFS rate is NULL for 2023 on; a state with a 100% share has no FFS enrollment (NULL) |

**Enrollment report status.** For each state-month the "updated" report is used; "preliminary" only where no updated row exists (never needed in
2018-01 to 2026-03: all 5,049 state-months are updated). `report_status_used` carries the choice, `missing` flags an absent state-month (none), and a
test requires every state-month to have one of the three values.

**Footnotes are definition caveats, not missing data.** Values are kept. `definition_caveat` is true when the footnote on the count says it differs
from a clean point-in-time count of people (a footnote beginning "Includes ..." or "Does Not Include ..."); it exists per month and rolls up to the
state-quarter and the panel (any month in the quarter). The footnote "Unable to Provide Data due to System Limitations" (Rhode Island, 2024-12) is a
missing-data note and is `data_unavailable_note`, not a caveat. Rhode Island's zero-reported month stays NULL in every count column.

States and months carrying a definition caveat on total Medicaid enrollment (the primary denominator):

| State | Footnote | Months |
|---|---|---|
| AK | Does Not Include All Full-Benefit Non-MAGI enrollees | 2023-09 to 2024-02 (6) |
| CA | Includes Limited-Benefit Enrollees | 2018-01 to 2025-10 (94) |
| CO | Includes Retroactive Enrollments | 2025-09 (1) |
| CT | Does Not Include All Full-Benefit Medicaid enrollees | 2018-03 to 2018-05 (3) |
| HI | Includes Retroactive Enrollments | 2025-02 to 2026-03 (14) |
| MI | Does Not Include All Full-Benefit Medicaid enrollees | 2021-05 (1) |
| MT | Includes Individuals Enrolled At Any Time in Month (Not a Point-in-Time Count) | 2025-02 to 2026-03 (14) |
| NH | Includes Retroactive Enrollments | 2024-12 to 2026-03 (16) |
| OH | Includes Individuals Enrolled At Any Time in Month (Not a Point-in-Time Count) | 2021-07 to 2026-03 (57) |
| SC | Includes Retroactive Enrollments | 2021-05 to 2026-03 (44) |
| UT | Includes Enrollees in Other Financial Assistance Programs Not Enrolled in Medicaid or CHIP | 2018-02 to 2023-05 (63) |
| WA | Includes Individuals Enrolled At Any Time in Month (Not a Point-in-Time Count) | 2018-01 to 2021-05 (38) |
| WV | Includes Individuals Enrolled At Any Time in Month (Not a Point-in-Time Count) | 2018-01 to 2026-03 (98) |

On the Medicaid + CHIP count alone (`definition_caveat_medicaid_chip`) two more states carry caveats: CT 2018-01 to 2018-02 and VA 2022-02 to
2022-06. In the panel, 162 state-quarters in 13 states have `definition_caveat = true`; three of them (CA, MI, SC) are primary treated states.

**Coverage.** `int_coverage__state_quarter`: `covered_days_share` uses the latest possible start date (conservative); `coverage_active` is any covered
day; `first_full_quarter` is the same quarter only when coverage starts on its first day, otherwise the next quarter (month-only starts, such as
Massachusetts, take the next quarter); sensitivity states whose start range straddles quarters have NULL `first_treated_quarter` and
`first_full_quarter` and carry `start_quarter_earliest` and `start_quarter_latest` instead. Hand-checked by test: Michigan 2022Q1/2022Q2, California
2023Q1/2023Q1, Pennsylvania 2023Q1/2023Q2, Kansas 2021Q3/2021Q4, Massachusetts 2024Q1/2024Q2, North Carolina 2025Q4 partly covered and active again in 2026Q1.
Mississippi and Tennessee carry `category_level_spa = true`; Kansas carries `kansas_flag`.

**Suppression.** SDUD counts of 1 to 10 are NULL. Observed totals skip suppressed rows; `rx_upper_bound` = observed + 10 x suppressed rows. A
state-quarter with no SDUD row has 0 observed and `n_rows` = 0 in the panel (SDUD lists a state-NDC-quarter only when it has utilization). The units
and amount upper bounds assume each suppressed row has 10 prescriptions at the highest units (or amount) per prescription seen for that NDC in
unsuppressed rows; they are NULL where no ratio exists (`units_bound_complete = false`).

**Product groups.** `obesity_wz` (Wegovy injection, Wegovy tablets, Zepbound) is the exposure group; `dosage_form` (tablet, injection, unknown) in
`mart_sdud_state_quarter_long` separates tablets from injections. Combination products (Soliqua, Xultophy) are in no outcome model. Part D and
spending names are matched on the brand's first word; a generic-named row is taken as a diabetes product (`group_basis`).
Wegovy tablets appear in SDUD from 2026Q1 only (113 state rows, 94 suppressed, 937 observed prescriptions, 40 states); Foundayo (approved 2026-04-01)
has no SDUD rows.

## MEPS 2024 Full Year Consolidated file

The file has 1,615 variables and PostgreSQL relations (tables and views) hold at most 1,600 columns. The loader splits it into `raw.meps_fyc_2024_p1`
and `_p2` keyed on `DUPERSID` (19,140 persons in both, tested one-to-one). `stg_meps__fyc_2024` re-joins them but does not expose 23 columns whose
values are identical for all 19,140 persons to an earlier column (the earlier "kept twin" is exposed):

| Dropped | Kept twin | Dropped | Kept twin |
|---|---|---|---|
| FAMID24 | FAMID53 | OPSSTL24 | OPDSTL24 |
| REGION24 | REGION53 | ERFOFD24 | ERTOFD24 |
| ENDRFY42 | BEGRFY42 | ERDOFD24 | OPDOFD24 |
| ENDRFY24 | DATAYEAR | IPFOFD24 | IPTOFD24 |
| ELGRND24 | ELGRND53 | IPDOFD24 | OPDOFD24 |
| IHS24 | IHS53 | HHATRI24 | OPDOFD24 |
| IHSAT31 | IHS31 | HHAPTR24 | HHAPRV24 |
| IHSAT42 | IHS42 | HHNOFD24 | OPDOFD24 |
| IHSAT53 | IHS53 | HHNWCP24 | OPDOFD24 |
| IHSAT24 | IHS53 | VISSTL24 | OPDOFD24 |
| OPFOFD24 | OPTOFD24 | VISWCP24 | OPDOFD24 |
| OPSOFD24 | OPDOFD24 | | |

(`OPDOFD24` and its twins are constant columns.) The list is computed by `gen_dbt_wide_models.py` and repeated in the SQL header of the model.

## Notes

- **Byetta NDCs with unknown labelers** (66029021007, 66029021008, 66914103504, 66914103505; labelers 66029 and 66914, `labeler_verified = false`): none
  appears in SDUD (state or national) or NADAC. Part D has no NDC field, so it cannot be checked by NDC.
- **Labeler 66780** is Amylin Pharmaceuticals, LLC (FDA NDC excluded products file).
- **PostgreSQL access.** The server listens on localhost only (`listen_addresses = localhost`; sockets on 127.0.0.1 and ::1) and `pg_hba.conf` uses
  `trust` for local connections, so any process on this machine can connect as the superuser without a password. That is acceptable for this
  single-user machine; on a shared machine set a password and switch the rules to `scram-sha-256`. No credential is stored in the repository.
- **Open Payments** headline totals count each record once (4,311,738 records, $238,887,019.80, reconciled to the cent). Product-level dollars come two
  ways: `amount_equal_split` (sums to the headline) and `amount_overlapping` (sums to $267,748,355.49; label as overlapping). NPs and PAs enter in 2021:
  use `is_physician` across 2021.
- **NADAC** covers quarters to 2026Q3 (the file runs beyond the SDUD window); everything else stops at 2026Q1.
- **Part D** lists a prescriber-drug row only with at least 11 claims, and excludes drugs used only for weight loss (Wegovy appears only for its 2024
  cardiovascular indication).
