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
# figure: dot-and-interval chart of weight change by trial arm (context only)
library(ggplot2)
tp <- tr |> filter(!grepl("^difference", arm)) |> mutate(label = ifelse(grepl("^placebo", arm), paste0(trial, ": placebo"), paste0(trial, ": ", arm, ifelse(grepl("^semaglutide$|^tirzepatide$", arm), " (max. tolerated dose)", ""))),
  kind = ifelse(grepl("^placebo", arm), "Placebo", "Drug")) |> mutate(label = factor(label, levels = rev(label)))
ptr <- ggplot(tp, aes(value, label, colour = kind)) + geom_vline(xintercept = 0, colour = "#999999") + geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.25, linewidth = 0.8, na.rm = TRUE) + geom_point(size = 3) +
  geom_text(aes(label = sprintf("%.1f", value)), nudge_y = 0.38, size = 3.6, show.legend = FALSE) +
  scale_colour_manual(values = c(Drug = col_treated, Placebo = col_comparison), guide = "none") + scale_x_continuous(labels = function(x) paste0(x, "%")) + scale_y_discrete(expand = expansion(add = c(0.6, 0.8))) +
  labs(x = "Mean change in body weight, % (95% CI where the abstract gives one)", y = NULL, title = sprintf("Trials show average weight loss of %.1f%% to %.1f%%, context only", min(abs(tp$value[tp$kind == "Drug"])), max(abs(tp$value[tp$kind == "Drug"]))),
       caption = "Source: published abstracts via PubMed (STEP 1, SURMOUNT-1, SURMOUNT-5, ATTAIN-1). Different populations, durations and doses; no cost-effectiveness claim.") + theme_incretin()
save_fig(ptr, "54_trial_weight_change", width = 10, height = 6.2, alt = "Dot-and-interval chart of mean percent weight change by trial and arm: STEP 1 semaglutide, SURMOUNT-1 tirzepatide 5, 10 and 15 mg, SURMOUNT-5 tirzepatide and semaglutide, and ATTAIN-1 orforglipron 6, 12 and 36 mg, each beside its placebo where reported. Context only; the trials differ in population, duration and dose.")
print(as.data.frame(vc |> select(1:5)))
