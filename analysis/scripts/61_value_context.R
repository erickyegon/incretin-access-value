# Item 2 of the plan reconciliation: value context. Pivotal-trial weight loss (data/reference/trial_inputs.csv, from PubMed abstracts) next to the Module E net cost per user per year.
# CONTEXT ONLY: the trials, populations, durations and Medicaid fills differ; no cost-effectiveness, cost-per-kg or QALY claim is made or computable from this table.
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(gt); library(dplyr) })
tb <- function(x) readr::read_csv(here::here("outputs", "tables", x), show_col_types = FALSE, progress = FALSE)
tr <- readr::read_csv(here::here("..", "data", "reference", "trial_inputs.csv"), show_col_types = FALSE, progress = FALSE)
res <- tb("moduleE_scenario_results.csv") |> filter(y35 == "plateau", price == "rebate central")
br <- tb("moduleE_gross_cost_per_rx_by_brand.csv") |> filter(grepl("^2025", quarter_label)) |> group_by(brand_label) |> summarise(gross_per_rx_2025 = sum(gross) / sum(rx), .groups = "drop")
brand_of <- c(semaglutide = "Wegovy", tirzepatide = "Zepbound")
vc <- tr |> filter(!grepl("^placebo|difference", arm)) |> mutate(brand = brand_of[drug]) |> left_join(br, by = c("brand" = "brand_label")) |>
  transmute(Trial = trial, Arm = arm, Dose = dose, `Weeks` = duration_weeks, `Weight change, % (95% CI)` = ifelse(is.na(ci_low), sprintf("%.1f (arm CI not in abstract)", value), sprintf("%.1f (%.1f to %.1f)", value, ci_low, ci_high)),
            `Medicaid gross reimbursement per prescription, covering states, 2025, USD` = ifelse(is.na(gross_per_rx_2025), "not a Medicaid-covered obesity product in the SDUD window", format(round(gross_per_rx_2025), big.mark = ",")),
            `Net cost per user per year, USD (4.3 fills, midpoint rebate; blended Wegovy and Zepbound)` = format(round(res$net_cost_per_user_year), big.mark = ","),
            `Net cost per member-year of continuous treatment, USD (12 fills, assumption)` = format(round(res$net_cost_per_member_year_continuous), big.mark = ","), Citation = tr$source_citation[match(paste(Trial, Arm), paste(tr$trial, tr$arm))], DOI = tr$doi[match(paste(Trial, Arm), paste(tr$trial, tr$arm))])
save_table(vc, "moduleE_value_context")
g <- gt(vc |> select(-Citation, -DOI)) |> tab_header(title = "Value context: trial weight loss and Medicaid net cost per user per year", subtitle = "Context only: different populations, durations and fills; no cost-effectiveness claim") |>
  tab_source_note("Trials: published abstracts (PubMed), citations and DOIs in data/reference/trial_inputs.csv. Costs: Module E (SDUD gross reimbursement; net of an assumed rebate of 51.2%, the midpoint of 23.1% and 79.3%). One net cost is shown for every row because it is a blended Wegovy and Zepbound average, not a drug-specific cost.") |>
  tab_options(table.font.size = px(11))
gt::gtsave(theme_gt_incretin(g), file.path(out_dir("tables"), "moduleE_value_context.html"))
print(as.data.frame(vc |> select(1:5)))
