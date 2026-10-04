# Step 0 report: SDUD reporting completeness, from the panel flags (all-drug rows; see dbt model int_sdud__reporting).
# Lists flagged state-quarters (nothing is dropped or changed) and the internal check that every state has diabetes GLP-1 use every quarter.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)
library(gt)

panel <- get_mart("mart_did_panel")

flags <- panel |>
  transmute(state_code, quarter_label, quarter_start,
            not_reported_ffsu = !sdud_reported_ffsu, not_reported_mcou = !sdud_reported_mcou, anomalous = sdud_anomalous) |>
  pivot_longer(c(not_reported_ffsu, not_reported_mcou, anomalous), names_to = "flag", values_to = "is_flagged") |>
  filter(is_flagged) |> select(-is_flagged) |> arrange(state_code, quarter_start, flag)

# Collapse to runs of consecutive quarters per state and flag
qlist <- sort(unique(panel$quarter_label))
runs <- flags |>
  mutate(qi = match(quarter_label, qlist)) |>
  group_by(state_code, flag) |>
  arrange(qi, .by_group = TRUE) |>
  mutate(run = cumsum(c(TRUE, diff(qi) != 1))) |>
  group_by(state_code, flag, run) |>
  summarise(first_quarter = first(quarter_label), last_quarter = last(quarter_label), n_quarters = n(), .groups = "drop") |>
  mutate(whole_window = n_quarters == length(qlist)) |>
  select(-run)

save_table(flags, "sdud_reporting_flagged_state_quarters")
save_table(runs, "sdud_reporting_flag_runs",
           gt(runs) |> tab_header(title = "SDUD state-quarters flagged in step 0 (not_reported = no SDUD row for any drug; anomalous = under 50% of neighbouring quarters)",
                                  subtitle = "Panel states, 2018 Q1 to 2026 Q1. No row is dropped or changed; the analysis decides how to handle them.") |>
             tab_source_note("Source: full yearly SDUD files (all drugs), aggregated in the warehouse."))

diab_zero <- panel |> filter(n_rows_diabetes_glp1 == 0) |> select(state_code, quarter_label, sdud_reported_ffsu, sdud_reported_mcou)
save_table(diab_zero, "check_diabetes_glp1_zero_rows")

cat("flagged state-quarters (state x quarter x flag):", nrow(flags), "\n")
print(flags |> count(flag))
cat("state-quarters flagged on any flag:", nrow(distinct(flags, state_code, quarter_label)), "of", nrow(panel), "\n")
cat("runs:\n"); print(runs, n = 50)
cat("state-quarters where diabetes_glp1 has zero SDUD rows:", nrow(diab_zero), "\n")
