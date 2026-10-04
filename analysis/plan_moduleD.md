# Module D plan: prescribers, concentration, segmentation and Open Payments

Written before any Module D result. Changes after results go in `analysis/outputs/deviations.md`.

## Question
Who prescribes incretins in Medicare Part D, how concentrated is prescribing, how did tirzepatide and Wegovy adoption spread, and how do industry payments relate to prescribing?

## Rules for every output
- Part D reflects diabetes and other covered uses, not obesity-brand adoption: this sentence is on every figure.
- A prescriber-drug row exists only with at least 11 claims, so every concentration and adoption measure describes those prescribers; claims, not beneficiaries (mostly suppressed).
- Aggregate outputs only: no named clinician, no NPI-level table or chart published, no manufacturer in a figure title. Payments results are associations, in observational language.

## Data
`mart_prescriber_year` (Part D prescriber-drug rows 2013-2024; used 2018-2024; combination products excluded), `mart_open_payments_npi_year` (in-scope Open Payments by NPI and program year 2019-2025, built for this module), seeds `prescriber_specialty_map` and `nppes_specialty_map` (committed).

## D1 Descriptives (2018-2024)
- Claims and prescribers per year by ingredient and brand (ingredient from the generic name).
- **Specialty mix.** CMS `Prscrbr_Type` grouped by `prescriber_specialty_map`: primary care physicians (Family Practice, Family Medicine, Internal Medicine, General Practice, Geriatric Medicine); nurse practitioners and physician assistants (one group); endocrinology; cardiology (Cardiology, Interventional Cardiology, Advanced Heart Failure and Transplant Cardiology, Clinical Cardiac Electrophysiology, Cardiovascular Disease (Cardiology), Adult Congenital Heart Disease); other (every unlisted type). Cross-check: the same grouping from the NPPES taxonomy (`nppes_specialty_map`), reported as an agreement table.
- **Concentration** per year: Lorenz curve and Gini of claims across prescribers (prescriber totals over all in-scope incretin brands), top 10% and top 1% claim shares.
- **Tirzepatide adoption 2022-2024:** share of incretin prescribers (rows with at least 11 claims) with any Mounjaro row, by specialty group and year.
- **Wegovy in Part D after its cardiovascular indication (2024-03-08):** 2024 Wegovy claims and prescribers by specialty group against Ozempic's 2024 specialty mix; cardiology's share for each. One year: descriptive only.

## D2 Segmentation (2024 prescribers with incretin claims)
Features: log total incretin claims; growth 2023 to 2024 as log((claims 2024 + 1) / (claims 2023 + 1)) with prescribers absent in 2023 flagged `new_2024` (a separate binary feature) and their 2023 claims taken as 0; tirzepatide share of claims; specialty group; and the share of claims for beneficiaries aged 65 and over only if it is populated for at least 80% of prescribers (CMS suppresses it under 11 claims). Method: k-prototypes (`clustMixType`, mixed data), number of segments chosen over k = 2 to 8 on a stratified subsample of 10,000 prescribers by silhouette, with interpretability as the tie-break; stability by 50 bootstrap resamples of 10,000 prescribers (Jaccard similarity of each segment with its best-matching bootstrap segment). Segments are named by profile, never by individual. Output: profile table and dot-plot profile figure. Seed 20261004 + 4000.

## D3 Open Payments and prescribing (association only)
- Link in-scope payments to prescribers by NPI. Payments in year t-1 against incretin claims in year t: primary pair 2023 payments with 2024 claims; repeated as a check with 2022 payments and 2023 claims.
- Descriptive: share of prescribers with any in-scope payment in t-1, and median amount among payees, by claim-volume decile and specialty group (`amount_equal_split`, record counted once).
- Model: negative binomial regression (`MASS::glm.nb`) of claims in t on log(1 + payments in t-1), adjusted for specialty group, state and log(1 + claims in t-2) (baseline volume; prescribers without a row in t-2 get 0 and an indicator). Population: prescribers with incretin claims in t (rows with at least 11 claims). Heteroskedasticity-robust (HC0) confidence intervals (`sandwich`), the number of prescribers reported. This does not identify an effect of payments: payments are not randomly assigned and likely target high-volume prescribers.
- Figure: binned scatter (payment deciles among payees plus a zero-payment bin against mean claims), aggregate only.

## Outputs
`outputs/tables/moduleD_*.csv/html`, figures `30_*` to `35_*`, `outputs/moduleD_summary.md`.
