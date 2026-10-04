# Module E step 1: cost and population inputs for the budget impact model (plan_moduleE.md).
# Gross reimbursement per Wegovy/Zepbound prescription in states with active coverage (SDUD), NADAC cross-check, adult share of Medicaid enrollment,
# MEPS purchases per user-year and MEPS background spending. Everything here is measured; the rebate, access and years 3-5 assumptions are set in the model script.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(survey); library(gt) })
options(survey.lonely.psu = "adjust")

# ---- gross cost per prescription (covered states) --------------------------------------------------------------------------------------------------------
br <- get_mart("mart_sdud_state_quarter_brand", where = "brand_label in ('Wegovy','Zepbound') and coverage_active")
cost <- br |> group_by(quarter_label, quarter_start) |> summarise(rx = sum(rx_observed), gross = sum(amount_total_observed), medicaid_amount = sum(amount_medicaid_observed), states = n_distinct(state_code), .groups = "drop") |>
  filter(rx > 0) |> mutate(gross_per_rx = gross / rx, medicaid_amount_per_rx = medicaid_amount / rx) |> arrange(quarter_start)
by_brand <- br |> group_by(quarter_label, brand_label) |> summarise(rx = sum(rx_observed), gross = sum(amount_total_observed), .groups = "drop") |> mutate(gross_per_rx = gross / rx)
save_table(cost |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_gross_cost_per_rx_by_quarter")
save_table(by_brand |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_gross_cost_per_rx_by_brand")

# ---- NADAC cross-check: NADAC per unit x units per prescription ----------------------------------------------------------------------------------------------
long <- get_mart("mart_sdud_state_quarter_long", cols = c("state_code", "quarter_label", "quarter_start", "utilization_type", "product_group", "dosage_form", "rx_observed", "units_observed"), where = "product_group = 'obesity_wz' and utilization_type = 'ALL'")
pn <- get_mart("mart_did_panel", cols = c("state_code", "quarter_label", "coverage_active"))
units <- long |> inner_join(pn |> filter(coverage_active), by = c("state_code", "quarter_label")) |> filter(dosage_form == "injection") |> group_by(quarter_label, quarter_start) |>
  summarise(units_per_rx = sum(units_observed) / sum(rx_observed), .groups = "drop")
nad <- get_mart("mart_nadac_brand_quarter", where = "brand_label in ('Wegovy','Zepbound')") |> group_by(quarter_label, quarter_start, brand_label, pricing_unit) |> summarise(nadac_per_unit = mean(nadac_per_unit_mean), .groups = "drop")
nadac_check <- cost |> select(quarter_label, quarter_start, gross_per_rx) |> left_join(units, by = c("quarter_label", "quarter_start")) |> left_join(nad |> group_by(quarter_label) |> summarise(nadac_per_unit = mean(nadac_per_unit), units = paste(unique(pricing_unit), collapse = "/")), by = "quarter_label") |>
  mutate(nadac_x_units_per_rx = nadac_per_unit * units_per_rx, ratio_sdud_to_nadac = gross_per_rx / nadac_x_units_per_rx)
save_table(nadac_check |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_nadac_crosscheck")

# ---- adult share of Medicaid enrollment (warehouse; the adult field exists from 2024 Q3) ---------------------------------------------------------------------------
pe <- get_mart("mart_did_panel", cols = c("state_code", "quarter_label", "quarter_start", "enrollment_medicaid_avg", "enrollment_adult_medicaid_avg", "n_months_present_adult_medicaid")) |> filter(!is.na(enrollment_adult_medicaid_avg))
adult_share <- pe |> group_by(quarter_label) |> summarise(adult_share = sum(enrollment_adult_medicaid_avg) / sum(enrollment_medicaid_avg), states = n(), .groups = "drop")
save_table(adult_share |> mutate(adult_share = round(adult_share, 4)), "moduleE_adult_share_of_medicaid_enrollment")

# ---- MEPS: purchases per user-year and background spending ----------------------------------------------------------------------------------------------------
me <- get_mart("mart_meps_persons") |> filter(age_last >= 18)
users <- me |> mutate(obesity_drug_rx = n_rx_obesity_wz + n_rx_obesity_saxenda + n_rx_obesity_other) |> filter(obesity_drug_rx > 0)
fills <- users |> group_by(data_year) |> summarise(adult_users_unweighted = n(), purchases_per_user_mean_unweighted = mean(obesity_drug_rx), purchases_per_user_weighted = weighted.mean(obesity_drug_rx, person_weight), .groups = "drop")
save_table(fills |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_meps_purchases_per_user")
bg <- bind_rows(lapply(c(2023, 2024), function(y) {
  d <- me |> filter(data_year == y, person_weight > 0)
  des <- svydesign(ids = ~varpsu, strata = ~varstr, weights = ~person_weight, nest = TRUE, data = d)
  bind_rows(lapply(c(obesity = "has_obesity_condition", type2_diabetes = "has_t2d_condition", all_adults = NA), function(v) {
    dd <- if (is.na(v)) des else subset(des, d[[v]] %in% TRUE)
    t <- svymean(~total_expenditure, dd); r <- svymean(~rx_expenditure, dd)
    tibble(data_year = y, group = ifelse(is.na(v), "all adults", names(which(c(obesity = "has_obesity_condition", type2_diabetes = "has_t2d_condition") == v))),
           persons_unweighted = nrow(dd$variables), total_spending_mean = coef(t), total_ci_low = confint(t)[1], total_ci_high = confint(t)[2], rx_spending_mean = coef(r), rx_ci_low = confint(r)[1], rx_ci_high = confint(r)[2]) }))
})) |> mutate(across(where(is.numeric), ~ round(.x, 0)))
save_table(bg, "moduleE_meps_background_spending", gt(bg) |> tab_header(title = "MEPS annual spending per adult (USD), survey-weighted", subtitle = "Adults with an obesity (E66) or type 2 diabetes (E11) condition record; context only") |>
  tab_source_note("MEPS Full Year Consolidated files 2023 and 2024 linked to the conditions file; condition = at least one 3-character ICD-10 condition record E66 or E11; not a measure of the cost of a condition."))
print(cost |> tail(8) |> mutate(across(where(is.numeric), ~ round(.x, 1)))); print(by_brand |> filter(quarter_label %in% c("2025Q3", "2025Q4")) |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(nadac_check |> tail(6) |> mutate(across(where(is.numeric), ~ round(.x, 2)))); print(adult_share); print(fills); print(bg)
