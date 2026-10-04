# Pre-specified context tables (Amendment 2): Rhode Island's FFSU/MCOU split of obesity_wz use for 2022 Q4 to 2024 Q1 (use of about 2 per 1,000
# before its 2023 Q4 coverage date), and South Carolina's split from its 2024 Q4 coverage start. Rates per 1,000 total Medicaid enrollees from
# the state-quarter sums (suppressed cells excluded; the number of suppressed cells is shown).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)
library(gt)

long <- get_mart("mart_sdud_state_quarter_long") |> filter(product_group == "obesity_wz", utilization_type %in% c("FFSU", "MCOU"))
panel <- get_mart("mart_did_panel") |> select(state_code, quarter_label, quarter_start, enrollment_medicaid_avg, rate_obesity_wz_per_1000_medicaid)

split <- long |> group_by(state_code, quarter_label, quarter_start, utilization_type) |>
  summarise(rx = sum(rx_observed), n_suppressed_cells = sum(n_suppressed_rows), .groups = "drop") |>
  inner_join(panel, by = c("state_code", "quarter_label", "quarter_start")) |>
  mutate(rate_per_1000 = 1000 * rx / enrollment_medicaid_avg) |>
  select(state_code, quarter_label, quarter_start, utilization_type, rate_per_1000, n_suppressed_cells) |>
  pivot_wider(names_from = utilization_type, values_from = c(rate_per_1000, n_suppressed_cells)) |>
  mutate(rate_total = rate_per_1000_FFSU + rate_per_1000_MCOU, mcou_share_of_observed = rate_per_1000_MCOU / rate_total)

ri <- split |> filter(state_code == "RI", quarter_start >= as.Date("2022-10-01"), quarter_start <= as.Date("2024-01-01"))
sc <- split |> filter(state_code == "SC", quarter_start >= as.Date("2024-10-01"))
out <- bind_rows(ri, sc) |> arrange(state_code, quarter_start) |> select(-quarter_start)
g <- gt(out, groupname_col = "state_code") |>
  tab_header(title = "FFSU/MCOU split of obesity_wz prescriptions: Rhode Island 2022 Q4 to 2024 Q1 and South Carolina from 2024 Q4",
             subtitle = "Observed prescriptions per 1,000 total Medicaid enrollees (suppressed cells excluded)") |>
  fmt_number(c(starts_with("rate_")), decimals = 2) |> fmt_percent(mcou_share_of_observed, decimals = 0) |>
  cols_label(quarter_label = "Quarter", rate_per_1000_FFSU = "FFSU", rate_per_1000_MCOU = "MCOU", n_suppressed_cells_FFSU = "Suppressed cells, FFSU",
             n_suppressed_cells_MCOU = "Suppressed cells, MCOU", rate_total = "Total", mcou_share_of_observed = "MCOU share") |>
  tab_source_note("Gross of rebates; counts under 11 suppressed by CMS. Rhode Island's coverage date is 2023 Q4; South Carolina's is 2024 Q4.")
save_table(out, "ri_sc_ffsu_mcou_split", g)
print(out, n = 40)
