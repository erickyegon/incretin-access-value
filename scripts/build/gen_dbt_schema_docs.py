"""Write dbt/models/intermediate/schema.yml and dbt/models/marts/schema.yml.
Column lists are read from the built relations (so none can be missed); every column must have a description below or the script stops.
Run after `dbt run` of the intermediate and marts layers. Descriptions are hand-written; the mart_did_panel rate and count columns are
described by pattern because they repeat for the four product groups."""
import re
import sys
from pathlib import Path

import psycopg2
import yaml

ROOT = Path(__file__).resolve().parents[2]
con = psycopg2.connect(host="localhost", dbname="incretin", user="postgres")
cur = con.cursor()


def columns(schema, table):
    cur.execute("""select a.attname from pg_class c join pg_namespace n on n.oid = c.relnamespace join pg_attribute a on a.attrelid = c.oid
                   where n.nspname = %s and c.relname = %s and a.attnum > 0 and not a.attisdropped order by a.attnum""", (schema, table))
    return [r[0] for r in cur.fetchall()]


GROUPS = {"obesity_wz": "Wegovy (injection and tablets) and Zepbound, the exposure group", "obesity_saxenda": "Saxenda and Saxenda-type generic liraglutide",
          "obesity_other": "other obesity-labelled products (Foundayo)", "diabetes_glp1": "diabetes-labelled incretins (not combinations)"}

COMMON = {
    "state_code": "USPS two-letter code of the state (50 states and DC in the panel).",
    "state_name": "State name.",
    "census_region": "Census region of the state.",
    "census_division": "Census division of the state.",
    "year": "Calendar year.",
    "quarter": "Calendar quarter, 1 to 4.",
    "quarter_label": "Quarter as text, for example 2023Q1.",
    "quarter_start": "First day of the quarter.",
    "quarter_end": "Last day of the quarter.",
    "is_preliminary": "True for SDUD quarters CMS still revises (2026 Q1 at the time of the download).",
    "utilization_type": "SDUD utilization type: FFSU (fee-for-service), MCOU (managed care) or ALL (FFSU + MCOU; never add ALL to the other two).",
    "product_group": "Analysis product group: obesity_wz, obesity_saxenda, obesity_other or diabetes_glp1 (combination products are excluded from outcome models).",
    "dosage_form": "Dosage form group of the NDC: tablet, injection or unknown (no dosage form on record).",
    "dosage_form_group": "Dosage form group of the NDC: tablet, injection or unknown (no dosage form on record).",
    "ndc11": "11-digit NDC as text.",
    "brand": "Brand name, empty for brand-less generics.",
    "brand_name": "Brand name as published by the source.",
    "generic_name": "Generic name as published by the source.",
    "brand_label": "Brand name, or 'GENERIC <ingredient>' for brand-less generics.",
    "ingredient": "Active ingredient.",
    "n_rows": "Number of SDUD state-NDC rows behind the cell (suppressed rows included).",
    "n_suppressed_rows": "Number of those rows that CMS suppressed (1 to 10 prescriptions each).",
    "rx_observed": "Prescriptions in the unsuppressed rows only (suppressed rows contribute nothing).",
    "rx_upper_bound": "rx_observed + 10 x n_suppressed_rows: the most the cell could hold.",
    "units_observed": "Units reimbursed in unsuppressed rows.",
    "units_upper_bound": "Units upper bound: observed plus, per suppressed row, 10 prescriptions at the highest units-per-prescription seen for that NDC; NULL when units_bound_complete is false.",
    "units_bound_complete": "True when every suppressed row's NDC has an unsuppressed row to take the per-prescription ratio from.",
    "amount_total_observed": "Total amount reimbursed (Medicaid + non-Medicaid, USD, gross of rebates) in unsuppressed rows.",
    "amount_total_upper_bound": "Upper bound of total amount reimbursed, built like units_upper_bound; NULL when it cannot be bounded.",
    "amount_medicaid_observed": "Medicaid amount reimbursed (USD, gross of rebates) in unsuppressed rows.",
    "amount_medicaid_upper_bound": "Upper bound of the Medicaid amount reimbursed, built like units_upper_bound; NULL when it cannot be bounded.",
    "analysis_group": "primary, sensitivity or never_treated, from the coverage table (primary requires a documented start inside one calendar quarter).",
    "covered_days_share": "Share of the quarter's days inside a coverage spell, using the latest possible start date (conservative).",
    "covered_days_share_max": "Same share using the earliest possible start date (equal for dated starts).",
    "coverage_active": "True when covered_days_share > 0 (any covered day in the quarter).",
    "coverage_full_quarter": "True when every day of the quarter is covered.",
    "first_treated_quarter": "Quarter containing the first coverage start; NULL when a sensitivity state's start range straddles quarters.",
    "first_full_quarter": "First fully covered quarter: the same quarter if coverage starts on its first day, else the next (month-only starts take the next quarter).",
    "start_quarter_earliest": "Quarter of the earliest possible start date.",
    "start_quarter_latest": "Quarter of the latest possible start date.",
    "start_precision": "Precision of the documented start: day, month or range.",
    "post_withdrawal": "True when the quarter has no covered day after a coverage spell has ended.",
    "kansas_flag": "True for Kansas (primary by decision; the analysis also runs without it).",
    "category_level_spa": "True when the state plan amendment covers the drug category, not Wegovy by name (Mississippi, Tennessee).",
    "has_coverage_spell": "True when the state has any documented coverage spell.",
    "enrollment_medicaid_avg": "Quarter average of total Medicaid enrollment (item 8a), the primary denominator; months with no value are skipped.",
    "n_months_present_medicaid": "Months (0 to 3) with a value behind enrollment_medicaid_avg.",
    "enrollment_medicaid_chip_avg": "Quarter average of Medicaid + CHIP enrollment (8a + 8h), sensitivity denominator.",
    "n_months_present_medicaid_chip": "Months (0 to 3) with a value behind enrollment_medicaid_chip_avg.",
    "enrollment_adult_medicaid_avg": "Quarter average of adult Medicaid enrollment (8d + 8g), second sensitivity denominator; reported only from 2024-07.",
    "n_months_present_adult_medicaid": "Months (0 to 3) with a value behind enrollment_adult_medicaid_avg.",
    "n_months_updated": "Months of the quarter taken from the Updated report.",
    "n_months_preliminary": "Months of the quarter taken from the Preliminary report (only where no Updated row exists).",
    "n_months_no_row": "Months with no enrollment row in either report.",
    "definition_caveat": "True when any month of the quarter has a footnote on total Medicaid enrollment that changes the count definition (for example 'not a point-in-time count').",
    "n_months_definition_caveat": "Months of the quarter carrying that footnote.",
    "definition_caveat_medicaid_chip": "Same flag for the Medicaid + CHIP count.",
    "definition_caveat_adult": "Same flag for the adult Medicaid count.",
    "data_unavailable_note": "True when a footnote says the state could not provide data (Rhode Island, 2024-12).",
    "enrollment_zero_set_null": "True when a reported zero was set to NULL (Rhode Island): the value stays missing.",
    "report_status_used": "Which enrollment report supplied the months: updated, preliminary or missing.",
    "product": "In-scope product key from the Open Payments name fields (brand, or ingredient for generic-only names).",
    "is_physician": "True for physician recipients; false for teaching hospitals and non-physician practitioners (NPs and PAs enter in 2021).",
    "is_combination": "True for insulin/GLP-1 combination products (Soliqua, Xultophy).",
    "program_year": "Open Payments program year.",
    "cycle": "NHANES cycle: 2021_2023 or 2017_2020 (pre-pandemic).",
    "group_basis": "How the product group was assigned: brand, or generic_name_diabetes when only a generic name was available.",
    "nct_id": "ClinicalTrials.gov identifier.",
}

PANEL_EXTRA = {
    "rx_all_drugs_observed": "All-drug unsuppressed SDUD prescriptions (FFSU + MCOU, every drug) for the state-quarter: context for judging incomplete preliminary data.",
    "sdud_reported_ffsu": "False when the state has no SDUD row for any drug in the quarter for fee-for-service utilization (a zero would be false).",
    "sdud_reported_mcou": "False when the state has no SDUD row for any drug in the quarter for managed-care utilization.",
    "sdud_anomalous": "True when the state-quarter all-drug prescription count is below 50% of the median of the four nearest other quarters, for FFSU or MCOU.",
    "enrollment_ffs_medicaid_assumed": "Medicaid enrollment x (1 - mc_share): the fee-for-service enrollment used by the FFS-only rates (assumption for 2025-2026, see mc_share_carried_forward).",
    "mc_share": "Share of Medicaid enrollees in comprehensive managed care (CMS Managed Care Enrollment Report).",
    "mc_share_carried_forward": "True when mc_share is the 2024 share carried forward to 2025 and 2026 (an assumption).",
    "rx_obesity_wz_tablet_observed": "Observed prescriptions (all utilization types) for Wegovy tablets within obesity_wz.",
}


def panel_desc(c):
    if c in COMMON:
        return COMMON[c]
    if c in PANEL_EXTRA:
        return PANEL_EXTRA[c]
    for g, gd in GROUPS.items():
        if c == f"rx_{g}_observed":
            return f"Observed prescriptions (FFSU + MCOU, suppressed rows excluded) for {gd}."
        if c == f"rx_{g}_upper_bound":
            return f"Observed prescriptions plus 10 per suppressed row for {gd}."
        if c == f"n_suppressed_rows_{g}":
            return f"Suppressed SDUD state-NDC rows behind the {g} prescriptions."
        if c == f"n_rows_{g}":
            return f"SDUD state-NDC rows behind the {g} prescriptions (0 means no SDUD row for the state-quarter)."
        if c == f"rx_{g}_ffs_observed":
            return f"Observed fee-for-service (FFSU) prescriptions for {gd}."
        if c == f"rate_{g}_per_1000_medicaid":
            return f"{g}: observed prescriptions per 1,000 total Medicaid enrollees (primary denominator, level)."
        if c == f"rate_{g}_upper_bound_per_1000_medicaid":
            return f"{g}: upper-bound prescriptions per 1,000 total Medicaid enrollees (level)."
        if c == f"rate_{g}_per_1000_medicaid_chip":
            return f"{g}: observed prescriptions per 1,000 Medicaid + CHIP enrollees (sensitivity denominator, level)."
        if c == f"rate_{g}_per_1000_adult_medicaid":
            return f"{g}: observed prescriptions per 1,000 adult Medicaid enrollees (second sensitivity denominator; NULL before 2024Q3)."
        if c == f"rate_{g}_ffs_per_1000_ffs_medicaid":
            return f"{g}: FFSU prescriptions per 1,000 assumed fee-for-service Medicaid enrollees (secondary outcome)."
    return None


MODELS = {
    "intermediate": {
        "quarters": ("Calendar quarters 2018Q1 to 2026Q1, one row per quarter (33).", COMMON | {"quarter_id": "Year x 10 + quarter, a sortable integer.", "days_in_quarter": "Number of days in the quarter."},
                     {"unique": ["quarter_label"]}),
        "int_enrollment__state_month": ("Enrollment by panel state and month, 2018-01 to 2026-03 (51 x 99): the Updated report, falling back to Preliminary, with the footnote flags.", COMMON | {
            "month_start": "First day of the month.", "has_enrollment_row": "True when the dataset has a row for the state-month.",
            "total_medicaid_enrollment": "Medicaid-only enrollees at month end (item 8a).",
            "total_medicaid_and_chip_enrollment": "Medicaid + CHIP enrollees at month end (8a + 8h).",
            "total_adult_medicaid_enrollment": "Adult Medicaid enrollees (8d + 8g); NULL before 2024-07.",
            "total_medicaid_enrollment_footnote": "Source footnote on the Medicaid count.",
            "total_medicaid_and_chip_enrollment_footnote": "Source footnote on the Medicaid + CHIP count.",
            "total_adult_medicaid_enrollment_footnote": "Source footnote on the adult Medicaid count.",
            "definition_caveat": "True when the footnote on total Medicaid enrollment changes the count definition (values are kept).",
            "definition_caveat_medicaid_chip": "Same flag for the Medicaid + CHIP count.", "definition_caveat_adult": "Same flag for the adult count.",
            "report_status_used": "updated, preliminary, or missing when the dataset has no row for the state-month."},
         {"unique_combo": ["state_code", "month_start"]}),
        "int_enrollment__state_quarter": ("Enrollment by panel state and quarter (51 x 33): average of the months present, months-present counts, definition-caveat roll-ups and the quarter-on-quarter change.", COMMON | {
            "qoq_change_medicaid": "Quarter-on-quarter relative change of enrollment_medicaid_avg (a warn test flags more than 25%).",
            "qoq_change_medicaid_chip": "Quarter-on-quarter relative change of enrollment_medicaid_chip_avg."},
         {"unique_combo": ["state_code", "year", "quarter"]}),
        "int_enrollment__managed_care_share": ("Share of Medicaid enrollees in comprehensive managed care by panel state and year (2018 to 2026); 2025 and 2026 carry the 2024 share forward.", COMMON | {
            "share_comprehensive_managed_care": "Comprehensive managed care enrollment / total Medicaid enrollees.",
            "is_carried_forward": "True for 2025 and 2026, which use the 2024 share (assumption).",
            "report_total_medicaid_enrollees": "Total Medicaid enrollees in the managed care report.",
            "report_enrollment_comprehensive_managed_care": "Comprehensive managed care enrollment in the managed care report."},
         {"unique_combo": ["state_code", "year"]}),
        "int_coverage__state_quarter": ("State Medicaid obesity-drug coverage by panel state and quarter (51 x 33).", COMMON, {"unique_combo": ["state_code", "year", "quarter"]}),
        "int_sdud__ndc_group": ("Product group and dosage form group of every product_map NDC.", COMMON | {
            "label_group": "Labelled indication group of the product: diabetes or obesity.",
            "labeler_verified": "False when the labeler of the NDC could not be confirmed from an official FDA file."}, {"unique": ["ndc11"]}),
        "int_sdud__state_quarter_group": ("SDUD aggregated to state x quarter x utilization type (FFSU, MCOU, ALL) x product group x dosage form group, with observed and upper-bound measures.", COMMON,
                                          {"unique_combo": ["state_code", "year", "quarter", "utilization_type", "product_group", "dosage_form_group"]}),
        "int_sdud__national_residual": ("National (XX) prescriptions minus the sum of state prescriptions, per NDC, quarter and utilization type (FFSU, MCOU).", COMMON | {
            "has_national_row": "True when SDUD has a national row for the NDC-quarter-type.", "national_suppressed": "True when the national row is suppressed.",
            "national_rx": "National prescriptions (NULL when suppressed).", "n_state_rows": "State rows (all jurisdictions) for the NDC-quarter-type.",
            "n_state_suppressed": "Suppressed state rows for the NDC-quarter-type.", "state_rx_observed": "Sum of unsuppressed state prescriptions (territories included).",
            "residual_rx": "national_rx - state_rx_observed: the volume held in suppressed state rows.",
            "residual_usable": "True when the national row is unsuppressed and residual_rx is positive.",
            "residual_within_bounds": "True when residual_rx lies between 0 and 10 x n_state_suppressed."},
         {"unique_combo": ["ndc11", "year", "quarter", "utilization_type"]}),
        "int_sdud__reporting": ("SDUD reporting completeness over all drugs by panel state, quarter and utilization type (FFSU, MCOU), with not_reported and anomalous flags.", COMMON | {
            "n_rows": "SDUD rows (all drugs) for the state, quarter and utilization type.", "n_suppressed_rows": "Suppressed rows among them.",
            "n_ndcs": "Distinct NDCs (all drugs).", "rx_observed_all_drugs": "Unsuppressed prescriptions summed over all drugs.",
            "neighbour_median_rx": "Median all-drug prescriptions of the four nearest other quarters of the same state and type.",
            "n_neighbours": "Neighbouring quarters used (4 when available).", "not_reported": "True when there are zero rows across all drugs.",
            "anomalous": "True when reported but below 50% of neighbour_median_rx."},
         {"unique_combo": ["state_code", "year", "quarter", "utilization_type"]}),
        "int_drug_name__product_group": ("Product group for each brand/generic name pair in Part D and Medicaid spending and Part D prescriber files.", COMMON, {"unique_combo": ["brand_name", "generic_name"]}),
    },
    "marts": {
        "mart_did_panel": ("Difference-in-differences panel: 51 states (50 + DC) x 33 quarters = 1,683 rows, with coverage timing, three enrollment denominators and prescription rates per 1,000 in levels.", None,
                           {"unique_combo": ["state_code", "year", "quarter"]}),
        "mart_sdud_state_quarter_long": ("SDUD for the panel states, long form: state x quarter x utilization type x product group x dosage form, observed and upper-bound measures.", COMMON,
                                         {"unique_combo": ["state_code", "year", "quarter", "utilization_type", "product_group", "dosage_form"]}),
        "mart_sdud_cells_for_imputation": ("Suppressed SDUD state-NDC cells awaiting imputation, with bounds, national residuals, enrollment and coverage context. Nothing is imputed.", COMMON | {
            "rx_observed": "Always NULL: the count is suppressed.", "rx_lower_bound": "0 (0 to 10 prescriptions treated as possible).", "rx_upper_bound": "10 (the suppression threshold).",
            "has_national_row": "True when the XX national row exists.", "national_suppressed": "True when the national row is suppressed.", "national_rx": "National prescriptions for the NDC-quarter-type.",
            "national_state_rx_observed": "Observed state prescriptions summed for the NDC-quarter-type (territories included).",
            "n_suppressed_rows_same_ndc_quarter": "Suppressed state rows sharing this NDC, quarter and utilization type (all jurisdictions).",
            "residual_rx": "national_rx minus observed state prescriptions.", "residual_usable": "True when the national row is unsuppressed and the residual is positive.",
            "residual_within_bounds": "True when the residual lies between 0 and 10 x the suppressed rows.",
            "enrollment_medicaid_avg": "Quarter average Medicaid enrollment of the state.", "n_months_present_medicaid": "Months behind that average.",
            "coverage_active": "True when the state covered the obesity drugs on any day of the quarter.", "covered_days_share": "Covered share of the quarter (conservative)."},
         {"unique_combo": ["state_code", "ndc11", "year", "quarter", "utilization_type"]}),
        "mart_sdud_state_quarter_brand": ("SDUD obesity-labelled products by state, quarter, brand and dosage form for the panel states (FFSU + MCOU), for the payer-specific brand split.", COMMON | {
            "amount_total_observed": "Total amount reimbursed in unsuppressed rows (USD, gross of rebates).", "amount_medicaid_observed": "Medicaid amount reimbursed in unsuppressed rows (USD, gross of rebates)."},
         {"unique_combo": ["state_code", "year", "quarter", "brand_label", "dosage_form"]}),
        "mart_prescriber_year": ("Medicare Part D prescriber-drug rows (at least 11 claims) with product group, Medicare specialty and NPPES/NUCC taxonomy.", COMMON | {
            "prescriber_npi": "Prescriber NPI.", "data_year": "Part D data year.", "prescriber_type": "CMS Medicare specialty of the prescriber.",
            "entity_type_code": "NPPES entity type: 1 individual, 2 organisation.", "practice_state": "NPPES practice state.", "primary_taxonomy_code": "NPPES primary taxonomy code.",
            "taxonomy_classification": "NUCC classification of the primary taxonomy.", "taxonomy_specialization": "NUCC specialization of the primary taxonomy.",
            "in_nppes": "True when the NPI is in the NPPES extract.", "prescriber_state": "Prescriber state in the Part D file.",
            "total_claims": "Part D claims (at least 11).", "total_30day_fills": "30-day standardized fills.", "total_day_supply": "Total days supply.",
            "total_drug_cost": "Total drug cost, USD.", "total_beneficiaries": "Beneficiaries with a claim."},
         {"unique_combo": ["prescriber_npi", "data_year", "brand_name", "generic_name"]}),
        "mart_open_payments_year_product": ("Open Payments by program year, product and physician flag: equal-split and overlapping dollars.", COMMON | {
            "n_records": "Records naming the product.", "n_distinct_recipients_npi": "Distinct recipient NPIs.",
            "amount_equal_split": "Dollars with each record divided over its in-scope products (sums to the headline total).",
            "amount_overlapping": "Dollars counting the full record for every product named (overlapping; exceeds the headline)."},
         {"unique_combo": ["program_year", "product", "is_physician"]}),
        "mart_drug_spending_year": ("Annual Part D and Medicaid spending by drug (Overall rows).", COMMON | {
            "partd_spending": "Part D total spending, USD.", "partd_claims": "Part D claims.", "partd_beneficiaries": "Part D beneficiaries.", "partd_dosage_units": "Part D dosage units.",
            "partd_avg_spend_per_claim": "Part D average spending per claim.", "partd_outlier_flag": "Part D outlier flag.",
            "medicaid_spending": "Medicaid total spending, USD, gross of rebates.", "medicaid_claims": "Medicaid claims.", "medicaid_dosage_units": "Medicaid dosage units.",
            "medicaid_avg_spend_per_claim": "Medicaid average spending per claim.", "medicaid_outlier_flag": "Medicaid outlier flag."},
         {"unique_combo": ["brand_name", "generic_name", "year"]}),
        "mart_nadac_brand_quarter": ("NADAC acquisition cost per pricing unit by product label and quarter.", COMMON | {
            "pricing_unit": "Pricing unit (EA, ML, GM).", "n_weekly_ndc_rows": "Weekly NDC rows in the quarter.", "n_ndcs": "Distinct NDCs.", "n_weeks": "Distinct survey weeks.",
            "nadac_per_unit_mean": "Mean NADAC per unit over the rows.", "nadac_per_unit_min": "Minimum NADAC per unit.", "nadac_per_unit_max": "Maximum NADAC per unit."},
         {"unique_combo": ["brand_label", "product_group", "pricing_unit", "year", "quarter"]}),
        "mart_nhanes_adults": ("NHANES adults aged 18 and over (the adult label population), two cycles stacked, all kept including missing BMI, with design variables, cycle-specific weights, insurance and the condition variables used for eligibility.", {
            "cycle": COMMON["cycle"], "seqn": "NHANES respondent sequence number.", "ridstatr": "Interview/examination status.", "riagendr": "Sex.", "ridageyr": "Age in years at screening.",
            "ridreth1": "Race/Hispanic origin (older coding).", "ridreth3": "Race/Hispanic origin with Non-Hispanic Asian.", "dmdborn4": "Country of birth.", "dmdeduc2": "Education, adults 20+.",
            "dmdmartz": "Marital status.", "ridexprg": "Pregnancy status at exam.", "indfmpir": "Ratio of family income to poverty.", "sdmvstra": "Masked variance pseudo-stratum.",
            "sdmvpsu": "Masked variance pseudo-PSU.", "wtint2yr": "Interview weight (2021-2023).", "wtmec2yr": "MEC exam weight (2021-2023).", "wtintprp": "Interview weight (2017-2020 pre-pandemic).",
            "wtmecprp": "MEC exam weight (2017-2020 pre-pandemic).", "weight_interview": "Interview weight of whichever cycle applies; not rescaled for combining cycles.",
            "weight_mec": "MEC exam weight of whichever cycle applies; not rescaled for combining cycles.", "wtph2yr": "Fasting subsample weight from the glycohemoglobin file.",
            "bmdstats": "Body measures status.", "bmxwt": "Weight, kg.", "bmxht": "Standing height, cm.", "bmxbmi": "Body mass index, kg/m2.", "bmxwaist": "Waist circumference, cm.",
            "bmxhip": "Hip circumference, cm.", "bmi_missing": "True when BMI is missing.", "bpxosy1": "Systolic blood pressure, reading 1.", "bpxodi1": "Diastolic blood pressure, reading 1.",
            "bpxosy2": "Systolic blood pressure, reading 2.", "bpxodi2": "Diastolic blood pressure, reading 2.", "bpxosy3": "Systolic blood pressure, reading 3.", "bpxodi3": "Diastolic blood pressure, reading 3.",
            "lbxgh": "Glycohemoglobin, %.", "bpq020": "Ever told high blood pressure.", "bpq040a": "Taking prescription for hypertension.", "bpq050a": "Now taking prescribed medicine for hypertension.",
            "diq010": "Doctor told you have diabetes.", "diq050": "Taking insulin now.", "diq070": "Taking diabetic pills to lower blood sugar.",
            "mcq010": "Ever been told you have asthma.", "mcq160a": "Ever told you had arthritis.", "mcq160b": "Ever told you had congestive heart failure.", "mcq160c": "Ever told you had coronary heart disease.",
            "mcq160d": "Ever told you had angina.", "mcq160e": "Ever told you had heart attack.", "mcq160f": "Ever told you had a stroke.", "mcq220": "Ever told you had cancer or malignancy.",
            "bpq080": "Doctor told you high cholesterol level.", "bpq090d": "Told to take prescription for cholesterol (2017-2020 only).", "bpq100d": "Now taking prescribed medicine for cholesterol (2017-2020 only).",
            "bpq101d": "Taking medication to lower blood cholesterol (2021-2023 only).", "bpq150": "Now taking prescribed medication for high blood pressure (2021-2023 only).",
            "diq160": "Ever told you had prediabetes.", "mcq080": "Doctor ever said you were overweight (2017-2020 only; not asked in 2021-2023).",
            "hiq011": "Covered by health insurance.", "hiq032a": "Covered by private insurance.", "hiq032b": "Covered by Medicare.", "hiq032c": "Covered by Medi-Gap.",
            "hiq032d": "Covered by Medicaid.", "hiq032e": "Covered by CHIP.", "hiq032h": "Covered by state-sponsored health plan.", "hiq032i": "Covered by other government insurance."},
         {"unique_combo": ["cycle", "seqn"]}),
        "mart_meps_persons": ("MEPS persons for 2023 and 2024 with survey design, expenditures, T2D/obesity condition flags and incretin prescription counts by product group.", {
            "data_year": "MEPS data year.", "dupersid": "MEPS person identifier.", "panel": "MEPS panel number.", "age_last": "Age at last interview.", "sex": "Sex.", "racethx": "Race/ethnicity.",
            "poverty_category": "Family income as percent of poverty line category.", "insurance_coverage": "Insurance coverage indicator.", "hibpdx": "High blood pressure diagnosis (after age 17).",
            "chddx": "Coronary heart disease diagnosis.", "diabdx_m18": "Diabetes diagnosis (after age 17).", "total_expenditure": "Total health care expenditure, USD.",
            "rx_purchases": "Number of prescribed medicine purchases.", "rx_expenditure": "Prescribed medicine expenditure, USD.", "person_weight": "Person-level analysis weight (perwt23f / perwt24f).",
            "varstr": "Variance estimation stratum.", "varpsu": "Variance estimation PSU.", "has_t2d_condition": "True when the person has an E11 condition record.",
            "has_obesity_condition": "True when the person has an E66 condition record.", "n_rx_obesity_wz": "Purchase records of Wegovy/Zepbound NDCs.",
            "n_rx_obesity_saxenda": "Purchase records of Saxenda-type NDCs.", "n_rx_obesity_other": "Purchase records of other obesity-labelled NDCs.", "n_rx_diabetes_glp1": "Purchase records of diabetes incretin NDCs."},
         {"unique_combo": ["data_year", "dupersid"]}),
        "mart_pipeline_trials": ("ClinicalTrials.gov incretin studies with keyword condition flags.", {
            "nct_id": COMMON["nct_id"], "title": "Brief title.", "official_title": "Official title.", "phase": "Trial phase.", "status": "Overall status.", "study_type": "Study type.",
            "start_date": "Registered start date text.", "start_date_parsed": "Start date as a date (missing day = 01).", "start_year": "Start year, NULL if no start date.",
            "primary_completion_date": "Primary completion date text.", "completion_date": "Completion date text.", "sponsor": "Lead sponsor.", "sponsor_class": "Sponsor class.",
            "enrollment": "Enrollment.", "enrollment_type": "Actual or estimated.", "results_posted": "True when results are posted.", "conditions": "Conditions.", "interventions": "Interventions.",
            "matched_ingredients": "Incretin ingredients matched.", "is_phase3": "True when the phase text contains PHASE3.",
            "condition_mentions_obesity": "True when conditions mention obes, overweight or weight (keyword match).", "condition_mentions_diabetes": "True when conditions mention diabet (keyword match).",
            "last_update": "Last update text."},
         {"unique": ["nct_id"]}),
    },
}

missing = []
for layer, models in MODELS.items():
    out = {"version": 2, "models": []}
    for name, (desc, cdict, tests) in models.items():
        cols = columns(layer, name)
        entries = []
        for c in cols:
            d = panel_desc(c) if name == "mart_did_panel" else cdict.get(c)
            if not d:
                missing.append(f"{layer}.{name}.{c}")
                continue
            entries.append({"name": c, "description": d})
        m = {"name": name, "description": desc, "columns": entries}
        dt = []
        if "unique_combo" in tests:
            dt.append({"dbt_utils.unique_combination_of_columns": {"arguments": {"combination_of_columns": tests["unique_combo"]}}})
        m["data_tests"] = dt
        for c in tests.get("unique", []):
            for e in entries:
                if e["name"] == c:
                    e["data_tests"] = ["unique", "not_null"]
        out["models"].append(m)
    if not missing:
        (ROOT / "dbt" / "models" / layer / "schema.yml").write_text(yaml.safe_dump(out, sort_keys=False, width=200, allow_unicode=True), encoding="utf-8")
if missing:
    sys.exit("columns without a description: " + ", ".join(missing))
print("schema.yml written for intermediate and marts")
