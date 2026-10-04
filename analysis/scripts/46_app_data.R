# Data files for the budget-model app (app/data/*.csv): small aggregate tables only, all generated from the project's output files (or aggregated warehouse marts) and checked against key_numbers.csv by
# scripts/45_check_app_data.R. Nothing row-level: state-quarter rates are observed (unsuppressed) prescriptions per 1,000 Medicaid enrollees, counts under 11 are never shown.
# Run after scripts 41 (model inputs), 50 (key numbers) and 60 (criteria table).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(geofacet) })
out <- function(x, f) readr::write_csv(x, here::here("..", "app", "data", f), na = "")
tb <- function(f) readr::read_csv(here::here("outputs", "tables", f), show_col_types = FALSE, progress = FALSE)
panel <- get_mart("mart_did_panel", cols = c("state_code", "state_name", "quarter_label", "quarter_start", "analysis_group", "first_treated_quarter", "start_quarter_earliest", "start_quarter_latest", "coverage_active",
                                             "is_preliminary", "enrollment_medicaid_avg", "n_months_present_medicaid", "rate_obesity_wz_per_1000_medicaid")) |> filter(state_code != "XX")
cov <- readr::read_csv(here::here("..", "data", "reference", "medicaid_obesity_coverage.csv"), show_col_types = FALSE, progress = FALSE)
um <- readr::read_csv(here::here("outputs", "tables", "coverage_um_criteria.csv"), show_col_types = FALSE, progress = FALSE)

# 1. event study (all event times; event times with fewer than 3 contributing states are greyed in the app)
es <- tb("event_study_primary.csv") |> transmute(event_time, att = round(att, 3), ci_low = round(ci_low, 3), ci_high = round(ci_high, 3), treated_states, fewer_than_3_states)
out(es, "event_study.csv")
# 2. overall effects and the specification table
oa <- tb("overall_att.csv")
out(oa |> transmute(estimate = estimate_type, att = round(att, 3), ci_low = round(ci_low, 3), ci_high = round(ci_high, 3)), "overall_effects.csv")
sp <- tb("specification_table_raw.csv")
out(sp |> transmute(spec, specification, att = round(att_simple, 3), ci_low = round(ci_low, 3), ci_high = round(ci_high, 3), states, estimable = spec != "12") |> mutate(att = ifelse(estimable, att, NA), ci_low = ifelse(estimable, ci_low, NA), ci_high = ifelse(estimable, ci_high, NA)), "specifications.csv")
# 3. states: tile-grid position, coverage group and cohort, dates, prior authorization and the sourced document
grid <- tibble::as_tibble(as.data.frame(geofacet::us_state_grid2)) |> select(state_code = code, col, row)
st <- panel |> arrange(state_code, quarter_start) |> group_by(state_code) |> summarise(state_name = first(state_name), group = first(analysis_group), cohort_quarter = first(first_treated_quarter), start_earliest = first(start_quarter_earliest), start_latest = first(start_quarter_latest), .groups = "drop") |>
  mutate(group = recode(group, never_treated = "never"), cohort_year = ifelse(group == "primary", substr(cohort_quarter, 1, 4), NA_character_))
covd <- cov |> filter(!is.na(coverage_start) | !is.na(coverage_end) | analysis_group %in% c("primary", "sensitivity")) |> mutate(abbr = state.abb[match(state, state.name)]) |> group_by(abbr) |>
  summarise(coverage_start = paste(na.omit(unique(coalesce(as.character(coverage_start), paste0(start_earliest, " to ", start_latest)))), collapse = "; "), coverage_end = paste(na.omit(unique(as.character(coverage_end))), collapse = "; "), .groups = "drop")
umd <- um |> mutate(abbr = state.abb[match(State, state.name)]) |> transmute(abbr, prior_authorization = `Prior authorization`, bmi_threshold = `BMI threshold`, step_therapy = `Step therapy`, document = `Criteria version (document)`, source_url = `Source URL`)
states <- grid |> left_join(st, by = "state_code") |> left_join(covd, by = c("state_code" = "abbr")) |> left_join(umd, by = c("state_code" = "abbr")) |> mutate(across(c(coverage_start, coverage_end), ~ ifelse(.x == "", NA, .x)))
stopifnot(nrow(states) == 51, !anyNA(states$group))
out(states, "states.csv")
# 4. state-quarter observed rates and the observed-only never-covered mean (comparison line)
out(panel |> transmute(state_code, quarter_label, rate = round(rate_obesity_wz_per_1000_medicaid, 3), coverage_active = coverage_active %in% TRUE, is_preliminary), "state_quarter_rates.csv")
hand <- tb("moduleC_for_budget_model.csv") |> filter(section == "never_treated_baseline") |> transmute(quarter_label = key, never_covered_mean_imputed = round(estimate, 4), never_covered_mean_observed = round(value_observed_only, 4))
out(hand, "never_covered_mean.csv")
# 5. plan sizes from a state's Medicaid enrollment: the latest quarter with all three months of data
en <- panel |> filter(!is.na(enrollment_medicaid_avg), enrollment_medicaid_avg > 0, n_months_present_medicaid == 3) |> group_by(state_code) |> slice_max(quarter_start, n = 1, with_ties = FALSE) |> ungroup() |>
  transmute(state_code, state_name, quarter_label, enrollment = round(enrollment_medicaid_avg))
out(en, "state_enrollment.csv")
# 6. effects with standard errors for the probabilistic analysis (Module C hand-off; same file as the report)
dyn <- tb("moduleC_for_budget_model.csv") |> filter(section == "dynamic_att") |> mutate(event_quarter = as.integer(sub("e=", "", key))) |> arrange(event_quarter)
out(dyn |> transmute(event_quarter, estimate = round(estimate, 4), se = round(se, 4), ci_low = round(ci_low, 4), ci_high = round(ci_high, 4)), "moduleC_effects.csv")
# 7. key facts: exact copies of key_numbers.csv rows used in the app text
ids <- c("c_att_overall", "c_es_e0", "c_es_e4", "c_es_e8", "c_placebo", "c_sa", "c_wild", "c_spec_holds", "c_spec_range", "c_spec14", "c_saxenda", "c_diab_glp1", "c_withdraw_ca", "c_withdraw_pa", "m_sc_mcou_share", "m_ri_mcou_share",
         "c_states_primary", "c_states_sens", "c_states_never", "c_pa_states", "um_pa", "um_bmi", "um_comorb", "um_step", "x_price_245", "e_net5", "e_pmpm", "e_gross5", "e_per_user_year", "e_per_member_year_cont", "e_psa_median", "e_psa_common", "e_scen_min", "e_scen_max",
         "e_rebate_central", "e_rebate_low", "e_rebate_high", "e_gross_rx", "e_gross_rx_low", "e_gross_rx_high", "e_users", "e_pool", "b_eligible", "b_medicaid_elig", "b_medicaid_elig_share", "e_adult_share", "e_fills_2024", "e_fills_2023", "e_fills_continuous", "e_year1_net", "e_year2_net", "e_year3_net", "e_pa_05", "e_pa_075", "e_pa_125", "e_announced5", "e_announced_pmpm", "e_tornado1_low", "e_tornado1_high", "e_tornado2_low", "e_tornado2_high", "e_gross_pmpm")
kn <- read.csv(here::here("outputs", "key_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0))
stopifnot(all(ids %in% kn$id)); out(kn[match(ids, kn$id), c("id", "display", "unit", "ci_or_range", "statement")], "key_facts.csv")
# 8. assumptions with a basis badge (Measured, Sourced, Assumed) and a source link
repo <- "https://github.com/erickyegon/incretin-access-value/blob/main/"
A <- tibble::tribble(~parameter, ~value_or_range, ~basis_type, ~basis, ~source_label, ~source_url,
  "Coverage effect by quarter since coverage began (quarters 1 to 9)", "1.3 to 17.2 per 1,000 enrollees per quarter (95% CIs in the Evidence tab)", "Measured", "Callaway and Sant'Anna difference-in-differences on State Drug Utilization Data and Medicaid enrollment, 10 covering and 34 never-covering jurisdictions; suppressed cells imputed (20 imputations)", "Module C summary", paste0(repo, "analysis/outputs/moduleC_summary.md"),
  "Gross cost per prescription", "$1,186 (range $1,164 to $1,252)", "Measured", "State Drug Utilization Data total amount reimbursed per Wegovy or Zepbound prescription in covering states (2025; range = quarters 2024 Q2 to 2025 Q4); gross of rebates; cross-checked with NADAC (within 3%)", "Module E assumptions table", paste0(repo, "analysis/outputs/tables/moduleE_assumptions.csv"),
  "Rebate share of gross cost, low", "23.1%", "Sourced", "Statutory minimum Medicaid rebate for brand drugs, 42 U.S.C. 1396r-8", "42 U.S.C. 1396r-8 (Cornell LII)", "https://www.law.cornell.edu/uscode/text/42/1396r-8",
  "Rebate share of gross cost, high", "79.3%", "Sourced", "Rebate implied by the announced $245 price at the 2025 gross cost", "White House fact sheet, November 2025", "https://www.whitehouse.gov/fact-sheets/2025/11/fact-sheet-president-donald-j-trump-announces-major-developments-in-bringing-most-favored-nation-pricing-to-americans/",
  "Rebate share of gross cost, central", "51.2%", "Assumed", "Midpoint of 23.1% and 79.3%; actual net prices are confidential", "Module E summary", paste0(repo, "analysis/outputs/moduleE_summary.md"),
  "Announced net price", "$245 per monthly prescription", "Sourced", "Announced Medicare price; the fact sheet says state Medicaid programs will have access at these prices", "White House fact sheet, November 2025", "https://www.whitehouse.gov/fact-sheets/2025/11/fact-sheet-president-donald-j-trump-announces-major-developments-in-bringing-most-favored-nation-pricing-to-americans/",
  "Prior authorization multiplier", "1.0 as observed (tight 0.5 to 0.75; loose up to 1.25)", "Assumed", "The Module C effect already reflects the prior authorization rules of the 10 covering states (documented in 9 of 10); tight and loose scenarios are assumptions", "Coverage criteria table", paste0(repo, "analysis/outputs/tables/coverage_um_criteria.csv"),
  "Years 3 to 5 path", "Plateau (central), continued growth, or decline to half by quarter 20", "Assumed", "No data after quarter 9 of coverage; scenarios only", "Module E summary", paste0(repo, "analysis/outputs/moduleE_summary.md"),
  "Purchases per user per year", "4.3 (2.9 to 12)", "Measured", "MEPS weighted purchases per adult user, 2024 (central) and 2023 (low); 12 = monthly all year (assumption)", "Module E assumptions table", paste0(repo, "analysis/outputs/tables/moduleE_assumptions.csv"),
  "Adult share of Medicaid enrollment", "57.9%", "Measured", "Medicaid enrollment, adult enrollment field, 2024 Q3 to 2026 Q1", "Module E assumptions table", paste0(repo, "analysis/outputs/tables/moduleE_assumptions.csv"),
  "Eligible share of Medicaid adults", "52.0% (lower bound)", "Measured", "NHANES 2021-2023 label-eligible adults with Medicaid (BMI 30, or 27 with a measurable condition)", "Module B summary", paste0(repo, "analysis/outputs/moduleB_summary.md"),
  "Uptake multiplier", "1.0 (0.75 to 1.25 in the sensitivity analysis)", "Assumed", "Scenario lever for faster or slower uptake than observed", "Module E plan", paste0(repo, "analysis/plan_moduleE.md"),
  "Medical cost offsets", "None in the base case", "Assumed", "No published source supporting a five-year offset was retrieved", "Module E plan", paste0(repo, "analysis/plan_moduleE.md"))
out(A, "assumptions.csv")
cat("app data written:", paste(list.files(here::here("..", "app", "data")), collapse = ", "), "\n")
# 9. test fixture: the report's one-way sensitivity table (app/tests/testthat compares the app's tornado with it)
dir.create(here::here("..", "app", "tests", "testthat", "fixtures"), recursive = TRUE, showWarnings = FALSE)
file.copy(here::here("outputs", "tables", "moduleE_tornado.csv"), here::here("..", "app", "tests", "testthat", "fixtures", "moduleE_tornado.csv"), overwrite = TRUE)
