# Module B step 3: patient funnel (measured vs modelled) and the payer-specific brand split. plan_moduleB.md.
# Measured: NHANES survey estimates (script 20). Modelled: GLP-1 use from the KFF Health Tracking Poll (docs/sources), propagated with 10,000 draws
# (seed 20261004 + 2000): poll share ~ Normal(12%, margin of error 3 points / 1.96); diagnosed-diabetes users ~ Uniform(35%, 55%) around KFF's 45% (an ASSUMED
# range: KFF says subgroup margins are larger than the full-sample 3 points and does not give the subgroup n in the text retrieved); NHANES counts ~ Normal(estimate, CI/3.92).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(ggpattern); library(gt) })

est <- readr::read_csv(here::here("outputs", "tables", "moduleB_survey_estimates.csv"), show_col_types = FALSE)
g <- function(cyc, measure, stratum = "All") est |> filter(cycle == cyc, measure == !!measure, stratum == !!stratum) |> slice(1)
adults <- g("2021_2023", "Adults 18+: count"); elig <- g("2021_2023", "Label-eligible (lower bound), without HbA1c: count")
dm <- g("2021_2023", "Diagnosed diabetes: count"); dmmed <- g("2021_2023", "Diabetes medication (insulin or pills) among diagnosed diabetes: count")
told <- g("2017_2020", "Label-eligible (lower bound) and told by a doctor overweight: count"); adults17 <- g("2017_2020", "Adults 18+: count"); elig17 <- g("2017_2020", "Label-eligible (lower bound), without HbA1c: count")

set.seed(20261004 + 2000L); B <- 10000
nd <- function(r) rnorm(B, r$estimate, (r$ci_high - r$ci_low) / 3.92)
ad <- nd(adults); dmn <- nd(dm)
p_use <- pmax(rnorm(B, 0.12, 0.03 / 1.96), 0.01); dm_use <- runif(B, 0.35, 0.55)
users_all <- ad * p_use; users_dm <- dmn * dm_use; users_nodm <- pmax(users_all - users_dm, 0)
q <- function(x) c(est = median(x), lo = unname(quantile(x, 0.05)), hi = unname(quantile(x, 0.95)))
qa <- q(users_all); qd <- q(users_dm); qn <- q(users_nodm)

steps <- tibble::tribble(
  ~pathway, ~step, ~label, ~status, ~est, ~lo, ~hi, ~source,
  "Obesity", 1, "U.S. adults 18+", "measured", adults$estimate, adults$ci_low, adults$ci_high, "NHANES 2021-2023 (sum of exam weights; civilian non-institutionalised)",
  "Obesity", 2, "Label-eligible (lower bound)", "measured", elig$estimate, elig$ci_low, elig$ci_high, "NHANES 2021-2023, BMI >= 30 or BMI 27-29.9 with a measurable condition",
  "Obesity", 3, "Eligible and told by a doctor they were overweight", "measured", told$estimate, told$ci_low, told$ci_high, "NHANES 2017-March 2020 (question not asked in 2021-2023)",
  "Obesity", 4, "Currently using a GLP-1 drug, no diagnosed diabetes", "modelled", qn["est"], qn["lo"], qn["hi"], "KFF poll Feb 24-Mar 2, 2026 (12% of adults, +/- 3 points) minus diabetes users; all indications, all GLP-1 drugs",
  "Type 2 diabetes", 1, "U.S. adults 18+", "measured", adults$estimate, adults$ci_low, adults$ci_high, "NHANES 2021-2023",
  "Type 2 diabetes", 2, "Diagnosed diabetes (type not separable)", "measured", dm$estimate, dm$ci_low, dm$ci_high, "NHANES 2021-2023 DIQ010",
  "Type 2 diabetes", 3, "Taking insulin or diabetes pills", "measured", dmmed$estimate, dmmed$ci_low, dmmed$ci_high, "NHANES 2021-2023 DIQ050 / DIQ070",
  "Type 2 diabetes", 4, "Currently using a GLP-1 drug, diagnosed diabetes", "modelled", qd["est"], qd["lo"], qd["hi"], "KFF Nov 2025 poll: 45% of adults with diagnosed diabetes (range 35-55% assumed)",
  "All indications", 5, "Currently using any GLP-1 drug", "modelled", qa["est"], qa["lo"], qa["hi"], "KFF poll Feb 24-Mar 2, 2026: 12% of adults (+/- 3 points)") |>
  mutate(across(c(est, lo, hi), ~ round(as.numeric(.x), 2)), unit = "millions of adults")
save_table(steps, "moduleB_funnel", gt(steps |> select(pathway, step, label, status, est, lo, hi, source)) |>
  tab_header(title = "Patient funnel: measured and modelled steps", subtitle = "Millions of U.S. adults; modelled ranges are 5th-95th percentile of 10,000 draws") |>
  cols_label(est = "Estimate", lo = "Low", hi = "High") |>
  tab_source_note("Measured steps: NHANES survey estimates with 95% CIs. Modelled steps: KFF Health Tracking Poll (docs/sources) with the stated assumptions. Counts of people, not dollars."))

# ---- figure: horizontal funnel, measured solid, modelled hatched -------------------------------------------------------------------------
plot_path <- function(d, title_lab) {
  d <- d |> mutate(y = rev(seq_len(n())), half = est / 2, lab = sprintf("%s  %s M\n%s  (%s)", label, fmt1(est), ifelse(status == "measured", sprintf("95%% CI %s-%s", fmt1(lo), fmt1(hi)), sprintf("range %s-%s", fmt1(lo), fmt1(hi))), status))
  ggplot(d) +
    geom_rect_pattern(aes(xmin = -half, xmax = half, ymin = y - 0.38, ymax = y + 0.38, pattern = status, fill = status), colour = col_treated, pattern_colour = col_treated, pattern_fill = "white", pattern_density = 0.35, pattern_spacing = 0.02, pattern_angle = 45, linewidth = 0.4) +
    geom_text(aes(x = max(est) / 2 + 6, y = y, label = lab), hjust = 0, size = 3.1, lineheight = 0.95, colour = "#222222") +
    scale_pattern_manual(values = c(measured = "none", modelled = "stripe"), name = NULL) + scale_fill_manual(values = c(measured = col_treated, modelled = "#FFFFFF"), name = NULL) +
    scale_x_continuous(limits = c(-max(d$est) / 2 - 3, max(d$est) / 2 + 150)) + labs(subtitle = title_lab, x = NULL, y = NULL) + theme_incretin() +
    theme(axis.text = element_blank(), panel.grid = element_blank(), legend.position = "none", plot.subtitle = element_text(face = "bold", size = 11))
}
ob <- steps |> filter(pathway == "Obesity"); dmp <- steps |> filter(pathway == "Type 2 diabetes")
library(patchwork)
pf <- plot_path(ob, "Obesity pathway") / plot_path(dmp, "Type 2 diabetes pathway") +
  plot_annotation(title = stringr::str_wrap(sprintf("Of %s million U.S. adults, at least %s million (95%% CI %s to %s) meet the labels' weight criteria; an estimated %s million without diagnosed diabetes currently use a GLP-1 drug (range %s to %s)",
                                                     fmt1(adults$estimate), fmt1(elig$estimate), fmt1(elig$ci_low), fmt1(elig$ci_high), fmt1(qn["est"]), fmt1(qn["lo"]), fmt1(qn["hi"])), 95),
                  subtitle = stringr::str_wrap("Solid bars: measured (NHANES 2021-2023 unless stated). Hatched bars: modelled from the KFF Health Tracking Poll (all GLP-1 drugs, all indications). The eligible count is a lower bound: sleep apnea and other label conditions are not measurable in NHANES.", 140),
                  caption = stringr::str_wrap("Sources: NCHS NHANES; KFF Health Tracking Polls (Feb 24-Mar 2, 2026 and Nov 2025); FDA Wegovy and Zepbound labels. Bar widths are proportional to people. Told-overweight step uses the 2017-2020 file (not asked in 2021-2023).", 150),
                  theme = theme_incretin())
save_fig(pf, "20_funnel", width = 12, height = 8, alt = sprintf("Two horizontal funnel charts. Obesity pathway: %s million U.S. adults, at least %s million label-eligible, %s million of those told by a doctor they were overweight (2017-2020 file), and about %s million adults without diagnosed diabetes currently using a GLP-1 drug (modelled, hatched). Type 2 diabetes pathway: %s million adults, %s million with diagnosed diabetes, %s million taking diabetes medication, about %s million with diabetes using a GLP-1 drug (modelled, hatched).", fmt1(adults$estimate), fmt1(elig$estimate), fmt1(told$estimate), fmt1(qn["est"]), fmt1(adults$estimate), fmt1(dm$estimate), fmt1(dmmed$estimate), fmt1(qd["est"])))

# ---- brand split, payer-specific --------------------------------------------------------------------------------------------------------
br <- get_mart("mart_sdud_state_quarter_brand") |> filter(brand_label %in% c("Wegovy", "Zepbound"), coverage_active %in% TRUE) |>
  group_by(quarter_label, quarter_start, brand_label) |> summarise(rx = sum(rx_observed), states = n_distinct(state_code), .groups = "drop") |>
  pivot_wider(id_cols = c(quarter_label, quarter_start), names_from = brand_label, values_from = c(rx, states), values_fill = 0) |> rename(Wegovy = rx_Wegovy, Zepbound = rx_Zepbound) |> mutate(states = pmax(states_Wegovy, states_Zepbound)) |> mutate(wegovy_share_pct = 100 * Wegovy / (Wegovy + Zepbound), zepbound_share_pct = 100 - wegovy_share_pct) |> arrange(quarter_start)
pd <- get_mart("mart_prescriber_year") |> filter(data_year == 2024, brand_name %in% c("Wegovy", "Zepbound")) |> group_by(brand_name) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop") |>
  mutate(share_pct = 100 * claims / sum(claims))
brand <- bind_rows(br |> filter(quarter_label >= "2023Q4") |> transmute(payer = "Medicaid (SDUD), states with coverage_active", period = quarter_label, wegovy_share_pct, zepbound_share_pct, detail = paste0(states, " covering states in the data")),
                   tibble(payer = "Medicare Part D 2024 (claims; Wegovy only for its cardiovascular indication)", period = "2024", wegovy_share_pct = pd$share_pct[pd$brand_name == "Wegovy"], zepbound_share_pct = pd$share_pct[pd$brand_name == "Zepbound"],
                          detail = paste0("Wegovy ", pd$claims[pd$brand_name == "Wegovy"], " claims, Zepbound ", pd$claims[pd$brand_name == "Zepbound"], " claims")))
save_table(brand |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleB_brand_split_by_payer")
print(steps |> select(pathway, label, status, est, lo, hi)); print(brand |> filter(period %in% c("2024Q1", "2025Q1", "2025Q3", "2025Q4", "2026Q1", "2024")))
