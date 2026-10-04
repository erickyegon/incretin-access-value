# Descriptive table 6: data-quality flags by state and period: SDUD reporting flags (step 0) and the enrollment definition caveat.
# definition_caveat = a footnote on total Medicaid enrollment says the count is not a clean point-in-time count (values are kept).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)
library(gt)

panel <- get_mart("mart_did_panel")
qlist <- sort(unique(panel$quarter_label))

runs_of <- function(df, flag_col, label) {
  df |> filter(.data[[flag_col]]) |> mutate(qi = match(quarter_label, qlist)) |> group_by(state_code) |> arrange(qi, .by_group = TRUE) |>
    mutate(run = cumsum(c(TRUE, diff(qi) != 1))) |> group_by(state_code, run) |>
    summarise(flag = label, first_quarter = first(quarter_label), last_quarter = last(quarter_label), n_quarters = n(), .groups = "drop") |> select(-run)
}
t1 <- runs_of(panel |> mutate(f = !sdud_reported_ffsu), "f", "SDUD not reported: FFSU")
t2 <- runs_of(panel |> mutate(f = !sdud_reported_mcou), "f", "SDUD not reported: MCOU")
t3 <- runs_of(panel |> mutate(f = sdud_anomalous), "f", "SDUD anomalous (under 50% of neighbouring quarters)")
t4 <- runs_of(panel |> mutate(f = definition_caveat), "f", "Enrollment definition caveat (any month in quarter)")
t5 <- runs_of(panel |> mutate(f = coalesce(data_unavailable_note, FALSE)), "f", "Enrollment: state unable to provide data (month NULL)")
t <- bind_rows(t1, t2, t3, t4, t5) |> left_join(panel |> distinct(state_code, analysis_group), by = "state_code") |>
  select(state_code, analysis_group, flag, first_quarter, last_quarter, n_quarters) |> arrange(flag, state_code, first_quarter)

g <- gt(t, groupname_col = "flag") |>
  tab_header(title = "Data-quality flags by state and period", subtitle = "Panel states, 2018 Q1 to 2026 Q1. No row is dropped from the primary analysis; sensitivity analyses 7 and 8 set flagged state-quarters to missing.") |>
  cols_label(state_code = "State", analysis_group = "Group", first_quarter = "From", last_quarter = "To", n_quarters = "Quarters") |>
  tab_source_note("MCOU = managed-care utilization, FFSU = fee-for-service. A state with no managed-care pharmacy data shows MCOU not reported for structural reasons (see report). Source: SDUD full yearly files; CMS Performance Indicator enrollment footnotes.")
save_table(t, "data_quality_flags_by_state_period", g)
print(t |> count(flag), n = 10)
print(t |> filter(grepl("caveat", flag)) |> arrange(state_code), n = 40)
