# Module B step 4: five-year forecast (2026-2030) of adults currently using a GLP-1 drug without diagnosed diabetes (a proxy for weight-management use; it also
# includes use for heart disease) and of all current GLP-1 users. SCENARIOS, NOT A PREDICTION. plan_moduleB.md. Seed 20261004 + 3000; 10,000 draws.
# Model (quarterly, anchor 2026 Q1):
#   organic users N: N[t+1] = N[t] + dt * r * (1 + o * oral[t]) * N[t] * (1 - N[t] / (K * E))   (logistic growth to a ceiling K x eligible adults E)
#   Medicare GLP-1 Bridge users B[t]: a share f of the NHANES-measured Bridge-eligible adults enrolled linearly from 2026 Q3 to 2027 Q4, a share (1 - ret) lost in 2028 Q1
#   Medicaid coverage change M[t]: net additional users reached linearly from 2026 Q2 to 2030 Q4
#   total = N + B + M. All-GLP-1 users add the diagnosed-diabetes users (held at their 2026 anchor).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(gt) })

est <- readr::read_csv(here::here("outputs", "tables", "moduleB_survey_estimates.csv"), show_col_types = FALSE)
g <- function(measure, stratum = "All", cyc = "2021_2023") est |> filter(cycle == cyc, measure == !!measure, stratum == !!stratum) |> slice(1)
adults <- g("Adults 18+: count"); elig <- g("Label-eligible (lower bound), without HbA1c: count"); dm <- g("Diagnosed diabetes: count")
bridge <- g("Medicare GLP-1 Bridge criteria met (measurable part, 65+): count")

set.seed(20261004 + 3000L); B <- 10000
nd <- function(r) rnorm(B, r$estimate, (r$ci_high - r$ci_low) / 3.92)
ad <- nd(adults); E <- nd(elig); dmn <- nd(dm); brg <- nd(bridge)
p_use <- pmax(rnorm(B, 0.12, 0.03 / 1.96), 0.01); dm_use <- runif(B, 0.35, 0.55)
N0 <- pmax(ad * p_use - dmn * dm_use, 0.1); DM0 <- dmn * dm_use
par <- tibble(r = runif(B, 0, log(2) / 1.5), K = runif(B, 0.30, 0.56), f = runif(B, 0.05, 0.40), ret = runif(B, 0, 1), o = runif(B, 0, 0.25), dM = runif(B, -1, 1))
quarters <- seq(as.Date("2026-01-01"), by = "quarter", length.out = 20)      # 2026 Q1 .. 2030 Q4
dt <- 0.25
oral_on <- quarters >= as.Date("2026-04-01")                                   # Foundayo approved 2026-04-01; Wegovy tablets approved 2025-12-22 (label_events)
bridge_on <- quarters >= as.Date("2026-07-01") & quarters <= as.Date("2027-10-01")
nb <- sum(bridge_on)

sim <- function(N0, E, brg, par, DM0) {
  n <- length(N0); N <- matrix(0, n, 20); N[, 1] <- N0
  for (t in 2:20) {
    rr <- par$r * (1 + par$o * oral_on[t])
    N[, t] <- pmin(N[, t - 1] + dt * rr * N[, t - 1] * (1 - N[, t - 1] / (par$K * E)), par$K * E)
  }
  Bm <- matrix(0, n, 20); for (t in 1:20) { k <- sum(quarters[1:t] %in% quarters[bridge_on]); Bm[, t] <- par$f * brg * k / nb; if (quarters[t] >= as.Date("2028-01-01")) Bm[, t] <- par$f * brg * par$ret }
  Mm <- matrix(0, n, 20); for (t in 1:20) { if (quarters[t] >= as.Date("2026-04-01")) Mm[, t] <- par$dM * (sum(quarters[1:t] >= as.Date("2026-04-01"))) / sum(quarters >= as.Date("2026-04-01")) }
  tot <- N + Bm + Mm
  list(noDM = tot, all = tot + DM0)
}
S <- sim(N0, E, brg, par, DM0)
qs <- function(m) t(apply(m, 2, quantile, probs = c(0.05, 0.25, 0.5, 0.75, 0.95)))
fan <- function(m, label) { q <- qs(m); tibble(target = label, quarter_start = quarters, p05 = q[, 1], p25 = q[, 2], p50 = q[, 3], p75 = q[, 4], p95 = q[, 5]) }
fans <- bind_rows(fan(S$noDM, "GLP-1 users without diagnosed diabetes (weight-management proxy)"), fan(S$all, "All current GLP-1 users"))

# scenario lines: fixed parameter sets at the ends and the middle of each range, anchored at the median anchor
sc <- tibble(scenario = c("Downside", "Base", "Upside"), r = c(0, log(2) / 3, log(2) / 1.5), K = c(0.30, 0.43, 0.56), f = c(0.05, 0.225, 0.40), ret = c(0, 0.5, 1), o = c(0, 0.125, 0.25), dM = c(-1, 0, 1))
sc_run <- lapply(seq_len(nrow(sc)), function(i) { s <- sc[i, ]; p <- tibble(r = s$r, K = s$K, f = s$f, ret = s$ret, o = s$o, dM = s$dM)
  o <- sim(median(N0), median(E), median(brg), p, median(DM0)); tibble(scenario = s$scenario, quarter_start = quarters, no_diabetes = o$noDM[1, ], all_glp1 = o$all[1, ]) }) |> bind_rows()

# ---- outputs ----------------------------------------------------------------------------------------------------------------------------
yr_end <- fans |> filter(format(quarter_start, "%m") == "10") |> mutate(year = as.integer(format(quarter_start, "%Y"))) |> select(target, year, p05, p25, p50, p75, p95)
sc_year <- sc_run |> filter(format(quarter_start, "%m") == "10") |> mutate(year = as.integer(format(quarter_start, "%Y")))
save_table(yr_end |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleB_forecast_year_end", gt(yr_end |> mutate(across(where(is.numeric), ~ round(.x, 1)))) |>
  tab_header(title = "Forecast: current GLP-1 users, millions of U.S. adults (year-end, 10,000-draw scenario simulation)", subtitle = "Scenarios, not a prediction; 5th-95th and 25th-75th percentiles") |> tab_source_note("Assumptions: outputs/tables/moduleB_assumptions.csv."))
save_table(sc_year |> mutate(across(where(is.numeric), ~ round(.x, 3))), "moduleB_forecast_scenarios")

assump <- tibble::tribble(
  ~parameter, ~role, ~low, ~central, ~high, ~distribution, ~basis, ~source_file,
  "U.S. adults 18+ (millions)", "population", adults$ci_low, adults$estimate, adults$ci_high, "Normal from the NHANES 95% CI", "sourced (measured)", "outputs/tables/moduleB_survey_estimates.csv",
  "Label-eligible adults, lower bound (millions)", "eligible population E; held constant over 2026-2030", elig$ci_low, elig$estimate, elig$ci_high, "Normal from the NHANES 95% CI", "sourced (measured); no demographic projection used (assumption: constant)", "outputs/tables/moduleB_survey_estimates.csv",
  "Current GLP-1 use among adults (all indications)", "anchor", 0.09, 0.12, 0.15, "Normal(12%, 3 points / 1.96)", "sourced: KFF Health Tracking Poll Feb 24-Mar 2, 2026, n = 1,343, +/- 3 points", "https://files.kff.org/attachment/topline-kff-health-tracking-poll-march-2026.pdf",
  "Share of adults with diagnosed diabetes currently using GLP-1", "anchor split", 0.35, 0.45, 0.55, "Uniform(35%, 55%)", "central sourced (KFF Nov 2025, 45%); range ASSUMED (subgroup margin larger than 3 points)", "https://www.kff.org/public-opinion/poll-1-in-8-adults-say-they-are-currently-taking-a-glp-1-drug-for-weight-loss-diabetes-or-another-condition-even-as-half-say-the-drugs-are-difficult-to-afford/",
  "Anchor: users without diagnosed diabetes, 2026 Q1 (millions)", "N0", unname(quantile(N0, 0.05)), median(N0), unname(quantile(N0, 0.95)), "derived from the three rows above", "modeled", "outputs/tables/moduleB_funnel.csv",
  "Organic annual growth rate r", "logistic growth rate", 0, round(log(2) / 3, 3), round(log(2) / 1.5, 3), "Uniform(0, ln2/1.5)", "endpoints sourced: KFF current use 12% in Nov 2025 and Mar 2026 (no change: 0) and 6% in May 2024 to 12% in Nov 2025 (ln2/1.5 years = 0.462); applying an all-indication rate to this group is an assumption", "https://files.kff.org/attachment/topline-kff-health-tracking-poll-march-2026.pdf",
  "Ceiling K (share of eligible adults)", "logistic ceiling", 0.30, 0.43, 0.56, "Uniform(0.30, 0.56)", "upper end sourced from KFF (23% now using + 43% of non-users interested among adults diagnosed overweight/obese = 56%); lower end ASSUMED", "https://www.kff.org/public-opinion/poll-1-in-8-adults-say-they-are-currently-taking-a-glp-1-drug-for-weight-loss-diabetes-or-another-condition-even-as-half-say-the-drugs-are-difficult-to-afford/",
  "Medicare GLP-1 Bridge-eligible adults, measurable part (millions)", "Bridge population", bridge$ci_low, bridge$estimate, bridge$ci_high, "Normal from the NHANES 95% CI", "sourced (NHANES, criteria from the CMS prescriber page); lower bound: uncontrolled hypertension and kidney disease are not measurable", "docs/sources/cms_medicare_glp1_bridge_prescribers.txt",
  "Bridge uptake by 2027 Q4 (share of Bridge-eligible)", "Bridge scenario", 0.05, 0.225, 0.40, "Uniform(5%, 40%)", "ASSUMPTION (no source gives uptake); window July 1 2026 to December 31 2027 and $50 copay sourced", "docs/sources/cms_medicare_glp1_bridge_page.txt",
  "Share of Bridge users retained after the demonstration ends", "Bridge scenario", 0, 0.5, 1, "Uniform(0, 1)", "ASSUMPTION (CMS page mentions possible BALANCE implementation in Part D, no terms)", "docs/sources/cms_medicare_glp1_bridge_page.txt",
  "Oral options: extra growth from 2026 Q2", "access event", 0, 0.125, 0.25, "Uniform(0, 25%) multiplier on r", "ASSUMPTION; launch dates sourced (Foundayo approved 2026-04-01, Wegovy tablets 2025-12-22 in label_events)", "dbt seed label_events",
  "Net additional users from Medicaid coverage changes by 2030 (millions)", "access event", -1, 0, 1, "Uniform(-1, +1)", "ASSUMPTION (symmetric; states may add or drop coverage)", "analysis/outputs/moduleC_summary.md",
  "Diagnosed-diabetes GLP-1 users", "added to the all-GLP-1 series", unname(quantile(DM0, 0.05)), median(DM0), unname(quantile(DM0, 0.95)), "held at the 2026 anchor", "ASSUMPTION (constant)", "outputs/tables/moduleB_funnel.csv") |>
  mutate(across(c(low, central, high), ~ round(as.numeric(.x), 3)))
save_table(assump, "moduleB_assumptions")

# ---- fan chart ---------------------------------------------------------------------------------------------------------------------------
fa <- fans |> filter(grepl("without", target)); l30 <- fa |> filter(quarter_start == as.Date("2030-10-01"))
sb <- sc_run |> filter(quarter_start == as.Date("2030-10-01"))
cols <- c(Downside = okabe_ito[["purple"]], Base = okabe_ito[["blue"]], Upside = okabe_ito[["green"]])
pf <- ggplot(fa, aes(quarter_start)) +
  annotate("rect", xmin = as.Date("2026-07-01"), xmax = as.Date("2027-12-31"), ymin = -Inf, ymax = Inf, fill = col_context, alpha = 0.3) +
  geom_ribbon(aes(ymin = p05, ymax = p95), fill = col_treated, alpha = 0.18) + geom_ribbon(aes(ymin = p25, ymax = p75), fill = col_treated, alpha = 0.32) +
  geom_line(aes(y = p50), colour = col_treated, linewidth = 1.2) +
  geom_line(data = sc_run, aes(y = no_diabetes, colour = scenario), linetype = "dashed", linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2026-04-01"), linetype = "dotted") +
  annotate("text", x = as.Date("2026-07-15"), y = max(fa$p95) * 0.97, label = "Medicare GLP-1 Bridge\nJul 2026 - Dec 2027", hjust = 0, size = 3, colour = "#444444") +
  annotate("text", x = as.Date("2026-03-20"), y = max(fa$p95) * 0.80, label = "Foundayo approved\n2026-04-01", hjust = 1, size = 3, colour = "#444444") +
  scale_colour_manual(values = cols, name = "Scenario (parameter set)") + scale_x_date(date_breaks = "1 year", date_labels = "%Y") + scale_y_continuous(labels = scales::label_number(suffix = " M")) +
  labs(title = stringr::str_wrap(sprintf("Scenarios put adults using a GLP-1 drug without diagnosed diabetes at %s million by end-2030 (median; 90%% interval %s to %s), from %s million in early 2026",
                                         fmt1(l30$p50), fmt1(l30$p05), fmt1(l30$p95), fmt1(fa$p50[1])), 95),
       subtitle = stringr::str_wrap("Fan: median, 50% and 90% bands of 10,000 draws over the assumed parameter ranges; dashed lines: downside, base and upside parameter sets. A scenario simulation, not a prediction. The group includes use for heart disease and is a proxy for weight-management use.", 140),
       x = NULL, y = "Adults currently using a GLP-1 drug (millions)",
       caption = stringr::str_wrap("Sources: KFF Health Tracking Polls (all GLP-1 drugs, all indications); NCHS NHANES 2021-2023 (eligible adults, Bridge-eligible adults); CMS Medicare GLP-1 Bridge; FDA label events. Growth, ceiling and access-event sizes are assumptions listed in moduleB_assumptions.csv.", 150)) +
  theme_incretin()
save_fig(pf, "21_forecast_fan", width = 11, height = 6.5, alt = sprintf("Fan chart of adults currently using a GLP-1 drug without diagnosed diabetes, 2026 to 2030. The median rises from %s million in early 2026 to %s million at the end of 2030, with a 90 percent interval from %s to %s million. Three dashed scenario lines (downside %s, base %s, upside %s million in 2030) and the shaded Medicare GLP-1 Bridge window from July 2026 to December 2027.",
                                                                  fmt1(fa$p50[1]), fmt1(l30$p50), fmt1(l30$p05), fmt1(l30$p95), fmt1(sb$no_diabetes[sb$scenario == "Downside"]), fmt1(sb$no_diabetes[sb$scenario == "Base"]), fmt1(sb$no_diabetes[sb$scenario == "Upside"])))
print(yr_end |> filter(target != "All current GLP-1 users") |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(sc_year |> filter(year == 2030) |> select(scenario, no_diabetes, all_glp1))
