# Descriptive table 4: group composition. States per group, mean 2019 Medicaid enrollment (the weight used in the weighted sensitivity), and
# pre-period outcome means. Pre-period = 2021 Q2 (first Wegovy quarter) to the quarter before the state's first treated quarter
# (primary) or before start_quarter_earliest (sensitivity). Never-treated states have no start: their row uses, for each treated state, that
# state's own pre-period window (matched windows), averaged over the treated states of the group.
# Outcomes are observed prescriptions per 1,000 enrollees (primary denominator), suppressed cells excluded.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)
library(gt)

panel <- get_mart("mart_did_panel") |> mutate(qd = as.Date(quarter_start))
outs <- c(wz = "rate_obesity_wz_per_1000_medicaid", saxenda = "rate_obesity_saxenda_per_1000_medicaid", diab = "rate_diabetes_glp1_per_1000_medicaid")

enr2019 <- panel |> filter(year == 2019) |> group_by(state_code) |> summarise(enrollment_2019 = mean(enrollment_medicaid_avg, na.rm = TRUE), .groups = "drop")
states <- panel |> group_by(state_code) |>
  summarise(group = first(analysis_group), start_q = first(coalesce(first_treated_quarter, start_quarter_earliest)), .groups = "drop") |>
  left_join(enr2019, by = "state_code") |>
  mutate(pre_end = as.Date(ifelse(is.na(start_q), NA_real_, as.numeric(quarter_to_date(coalesce(start_q, "2000Q1"))) - 1), origin = "1970-01-01"))

pre_mean <- function(df, from, to) {
  d <- df |> filter(qd >= from, qd <= to)
  tibble(n_pre_quarters = n_distinct(d$qd), wz = mean(d[[outs["wz"]]], na.rm = TRUE), saxenda = mean(d[[outs["saxenda"]]], na.rm = TRUE), diab = mean(d[[outs["diab"]]], na.rm = TRUE))
}
launch <- as.Date("2021-04-01")
treated_states <- states |> filter(group != "never_treated")
per_state <- bind_rows(lapply(seq_len(nrow(treated_states)), function(i) {
  r <- treated_states[i, ]
  bind_cols(r |> select(state_code, group, start_q, enrollment_2019), pre_mean(panel |> filter(state_code == r$state_code), launch, r$pre_end))
}))
never_states <- states |> filter(group == "never_treated") |> pull(state_code)
never_matched <- bind_rows(lapply(seq_len(nrow(treated_states)), function(i) {
  r <- treated_states[i, ]
  bind_cols(r |> select(group, start_q), pre_mean(panel |> filter(state_code %in% never_states), launch, r$pre_end))
}))

grp <- per_state |> group_by(group) |>
  summarise(states = n(), mean_enrollment_2019 = mean(enrollment_2019), pre_quarters_mean = mean(n_pre_quarters),
            pre_mean_wz = mean(wz, na.rm = TRUE), pre_mean_saxenda = mean(saxenda, na.rm = TRUE), pre_mean_diabetes_glp1 = mean(diab, na.rm = TRUE), .groups = "drop")
nev <- states |> filter(group == "never_treated") |>
  summarise(group = "never_treated", states = n(), mean_enrollment_2019 = mean(enrollment_2019))
nev_pre <- never_matched |> group_by(group) |> summarise(pre_quarters_mean = mean(n_pre_quarters), pre_mean_wz = mean(wz, na.rm = TRUE), pre_mean_saxenda = mean(saxenda, na.rm = TRUE),
                                                          pre_mean_diabetes_glp1 = mean(diab, na.rm = TRUE), .groups = "drop")
tab <- bind_rows(grp, nev |> bind_cols(nev_pre |> filter(group == "primary") |> select(-group)) |> mutate(group = "never_treated (matched to primary windows)"),
                 nev |> bind_cols(nev_pre |> filter(group == "sensitivity") |> select(-group)) |> mutate(group = "never_treated (matched to sensitivity windows)")) |>
  mutate(group = recode(group, primary = "primary treated", sensitivity = "sensitivity treated"))

g <- gt(tab) |>
  tab_header(title = "Group composition and pre-period outcome means",
             subtitle = "Observed prescriptions per 1,000 Medicaid enrollees; pre-period = 2021 Q2 to the quarter before coverage began") |>
  fmt_number(c(mean_enrollment_2019), decimals = 0) |> fmt_number(c(pre_quarters_mean, pre_mean_wz, pre_mean_saxenda, pre_mean_diabetes_glp1), decimals = 2) |>
  cols_label(group = "Group", states = "States", mean_enrollment_2019 = "Mean 2019 Medicaid enrollment", pre_quarters_mean = "Mean pre-period quarters",
             pre_mean_wz = "Wegovy/Zepbound", pre_mean_saxenda = "Saxenda", pre_mean_diabetes_glp1 = "Diabetes GLP-1") |>
  tab_spanner("Pre-period mean per 1,000", c(pre_mean_wz, pre_mean_saxenda, pre_mean_diabetes_glp1)) |>
  tab_source_note("State-level means averaged over states (states with no pre-launch pre-period quarters, such as sensitivity states starting in 2021 Q2, drop out of the outcome means). Never-treated rows use each treated state's own pre-period window, then average. Gross of rebates; counts under 11 suppressed by CMS. Kansas has one pre-period quarter (2021 Q2).")
save_table(tab, "group_composition", g)
save_table(per_state |> arrange(group, start_q, state_code), "group_composition_by_state")
print(tab, width = 200)
