# Module E step 2-3: budget impact model, one-way and probabilistic sensitivity, figures (plan_moduleE.md). Seed 20261004 + 5000; 10,000 draws.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
source(here::here("R", "bia.R"))
suppressPackageStartupMessages({ library(tidyr); library(gt); library(patchwork) })
set.seed(20261004 + 5000L)

# ---- inputs (all traceable) --------------------------------------------------------------------------------------------------------------------------------------
tb <- function(x) readr::read_csv(here::here("outputs", "tables", x), show_col_types = FALSE)
c_dyn <- tb("moduleC_for_budget_model.csv") |> filter(section == "dynamic_att") |> mutate(e = as.integer(sub("e=", "", key))) |> arrange(e)
stopifnot(nrow(c_dyn) == 9)
cost <- tb("moduleE_gross_cost_per_rx_by_quarter.csv")
full_q <- cost |> filter(quarter_label >= "2024Q2", quarter_label <= "2025Q4")                  # full, non-preliminary quarters with 12+ covering states
g25 <- cost |> filter(grepl("^2025", quarter_label)); gross_central <- sum(g25$gross) / sum(g25$rx)
gross_lo <- min(full_q$gross_per_rx); gross_hi <- max(full_q$gross_per_rx)
announced <- 245
rebate_lo <- 0.231; rebate_hi <- 1 - announced / gross_central; rebate_mid <- (rebate_lo + rebate_hi) / 2
mp <- tb("moduleE_meps_purchases_per_user.csv"); fills_obs <- mp$purchases_per_user_weighted[mp$data_year == 2024]; fills_lo <- mp$purchases_per_user_weighted[mp$data_year == 2023]
ash <- tb("moduleE_adult_share_of_medicaid_enrollment.csv"); adult_share <- mean(ash$adult_share)
sv <- tb("moduleB_survey_estimates.csv"); elig_share <- sv$estimate[sv$cycle == "2021_2023" & sv$measure == "Label-eligible (lower bound), without HbA1c: count" & sv$stratum == "Medicaid (HIQ032D)"] /
  sv$estimate[sv$cycle == "2021_2023" & sv$measure == "Adults 18+: count" & sv$stratum == "Medicaid (HIQ032D)"]
inp <- list(att = data.frame(e = c_dyn$e, estimate = c_dyn$estimate, se = c_dyn$se, ci_low = c_dyn$ci_low, ci_high = c_dyn$ci_high),
            gross = list(central = gross_central, low = gross_lo, high = gross_hi), rebate = list(central = rebate_mid, low = rebate_lo, high = rebate_hi), announced = announced,
            fills = list(central = fills_obs, low = fills_lo, high = 12), adult_share = adult_share, eligible_share = elig_share)
assump <- tibble::tribble(
  ~parameter, ~low, ~central, ~high, ~basis, ~source,
  "Module C incremental prescriptions per 1,000 enrollees per quarter, e = 0 to 8", NA, NA, NA, "sourced (estimated): dynamic ATT with SEs, imputation-combined", "outputs/tables/moduleC_for_budget_model.csv",
  "Years 3-5 (quarters 10-20)", NA, NA, NA, "ASSUMPTION: plateau (central), continued linear growth, or decline to half by quarter 20", "this plan",
  "Access policy (prior authorization) multiplier on the effect", 0.5, 1.0, 1.25, "central 1.0 = PA as observed in the 10 covering states (the Module C effect already reflects their PA; 9 of 10 have PA in sourced documents, California's is not found in sourced documents); tight PA 0.5 to 0.75 and loose PA up to 1.25 are ASSUMPTIONS (Module C cannot estimate PA strictness)", "data/reference/medicaid_obesity_coverage.csv; deviations.md item 12",
  "Uptake multiplier (slider; one-way range)", 0.75, 1.0, 1.25, "ASSUMPTION", "plan_moduleE.md",
  "Gross reimbursement per Wegovy/Zepbound prescription (USD)", gross_lo, gross_central, gross_hi, "sourced (measured): SDUD total_amount_reimbursed / prescriptions in states with active coverage; central = 2025 weighted mean, range = quarterly values 2024 Q2 to 2025 Q4; gross of rebates", "outputs/tables/moduleE_gross_cost_per_rx_by_quarter.csv",
  "Cross-check: NADAC per mL x mL per prescription", NA, NA, NA, "sourced (measured); ratio SDUD / NADAC-based about 0.97 in 2025 Q3", "outputs/tables/moduleE_nadac_crosscheck.csv",
  "Rebate share of gross cost", rebate_lo, rebate_mid, rebate_hi, "low = statutory minimum 23.1% (42 U.S.C. 1396r-8, sourced); high = rebate implied by the announced $245 price at the 2025 gross cost; central = midpoint (ASSUMPTION); actual net prices are confidential", "https://www.law.cornell.edu/uscode/text/42/1396r-8",
  "Announced-price scenario: net cost per monthly prescription (USD)", NA, announced, NA, "sourced: White House fact sheet, Nov 2025 (Medicare price $245; state Medicaid 'access at these prices'); one prescription taken as one month (ASSUMPTION, SDUD units per prescription about 2.2 mL)", "docs/sources/whitehouse_fact_sheet_mfn_2025-11.txt",
  "Purchases per user-year (MEPS; for the user count and the per-user cost; high = 12 fills, the continuous-treatment assumption)", fills_lo, fills_obs, 12, "low and central sourced (MEPS 2023, 2024 weighted purchases per adult user of obesity-labeled incretins, partial years included); high = monthly all year (ASSUMPTION)", "outputs/tables/moduleE_meps_purchases_per_user.csv",
  "Adult share of Medicaid enrollment", NA, adult_share, NA, "sourced (measured): warehouse adult enrollment field, 2024 Q3 to 2026 Q1 (not available earlier)", "outputs/tables/moduleE_adult_share_of_medicaid_enrollment.csv",
  "Label-eligible share of adults with Medicaid", NA, elig_share, NA, "sourced (measured, lower bound): NHANES 2021-2023, 17.8 of 34.3 million", "outputs/tables/moduleB_survey_estimates.csv",
  "Medical cost offsets", NA, 0, NA, "none in the base case; no scenario because no published source supporting a five-year offset was retrieved", "plan_moduleE.md",
  "Plan size (enrollees)", NA, 1e6, NA, "set by the question; slider in the app", "plan_moduleE.md") |> mutate(across(c(low, central, high), ~ round(.x, 3)))
save_table(assump, "moduleE_assumptions", gt(assump) |> tab_header(title = "Budget impact model: inputs, ranges and basis", subtitle = "Sourced = measured or retrieved; ASSUMPTION = no source gives the value") |> tab_source_note("Gross and net: SDUD amounts are gross of rebates."))

# ---- central results across scenarios ------------------------------------------------------------------------------------------------------------------------------
base <- bia_defaults(inp)
scen <- expand.grid(y35 = bia_years35, price = c("rebate low (23.1%)", "rebate central", "rebate high (implied by $245)", "announced $245"), stringsAsFactors = FALSE)
res <- lapply(seq_len(nrow(scen)), function(i) { p <- base; p$y35 <- scen$y35[i]
  pr <- scen$price[i]; if (pr == "announced $245") p$price <- "announced" else p$rebate <- switch(pr, "rebate low (23.1%)" = rebate_lo, "rebate central" = rebate_mid, "rebate high (implied by $245)" = rebate_hi)
  r <- bia_run(p); cbind(scen[i, ], as.data.frame(r$total), n_years_exceed_pool = sum(r$annual$exceeds_pool)) }) |> bind_rows()
ann_c <- bia_run(base)$annual
pa_sc <- bind_rows(lapply(c(0.5, 0.75, 1, 1.25), function(m) { p <- base; p$pa_mult <- m; t <- bia_run(p)$total; tibble(pa_multiplier = m, five_year_net = t$five_year_net, five_year_gross = t$five_year_gross, pmpm_net = t$pmpm_net) })) |>
  mutate(label = c("tight PA (assumption)", "tight PA (assumption)", "PA as observed in the 10 covering states (central)", "loose PA (assumption)"))
save_table(pa_sc |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_pa_scenarios")
save_table(res |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_scenario_results")
save_table(ann_c |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_central_annual", gt(ann_c |> transmute(Year = year, `Incremental prescriptions` = round(prescriptions), `Gross cost (USD)` = round(gross), `Net cost (USD)` = round(net), `Net PMPM` = round(pmpm_net, 2), `Users (treated members)` = round(treated_members), `Eligible pool` = round(eligible_pool), `Net cost per user per year (4.3 fills, MEPS)` = round(net_cost_per_user_year), `Net cost per member-year of continuous treatment (12 fills, assumption)` = round(net_cost_per_member_year_continuous))) |>
  tab_header(title = "Central scenario: coverage for a Medicaid program of 1 million enrollees", subtitle = "Years 3-5 plateau; prior authorization as observed in the covering states (multiplier 1.0); central rebate 51.2% (midpoint of 23.1% and 79.3%); incremental to no coverage") |> tab_source_note("PMPM = per enrollee per month. Users = prescriptions / 4.3 purchases per user-year (MEPS 2024). Net of an assumed central rebate of 51.2% (midpoint of 23.1% and 79.3%); SDUD amounts are gross."))

# ---- one-way sensitivity (tornado) ------------------------------------------------------------------------------------------------------------------------------------
five_net <- function(p) bia_run(p)$total$five_year_net
b0 <- five_net(base)
ow <- list()
add <- function(name, lo_p, hi_p, lo_lab, hi_lab) ow[[length(ow) + 1]] <<- tibble(parameter = name, low_label = lo_lab, high_label = hi_lab, net_low = five_net(lo_p), net_high = five_net(hi_p))
mod <- function(...) { p <- base; a <- list(...); for (n in names(a)) p[[n]] <- a[[n]]; p }
add("Coverage effect (95% CI)", mod(att9 = inp$att$ci_low), mod(att9 = inp$att$ci_high), "lower CI", "upper CI")
add("Prior authorization multiplier", mod(pa_mult = 0.5), mod(pa_mult = 1.25), "0.5 (tight)", "1.25 (loose)")
add("Years 3-5 scenario", mod(y35 = "decline"), mod(y35 = "growth"), "decline", "continued growth")
add("Gross cost per prescription", mod(gross = gross_lo), mod(gross = gross_hi), sprintf("$%s", format(round(gross_lo), big.mark = ",")), sprintf("$%s", format(round(gross_hi), big.mark = ",")))
add("Rebate share", mod(rebate = rebate_hi), mod(rebate = rebate_lo), sprintf("%s%% (implied by $245)", fmt1(100 * rebate_hi)), "23.1% (statutory minimum)")
add("Price scenario", mod(price = "announced"), base, "announced $245 net", "central rebate")
add("Uptake multiplier", mod(uptake_mult = 0.75), mod(uptake_mult = 1.25), "0.75", "1.25")
tor <- bind_rows(ow) |> mutate(span = abs(net_high - net_low)) |> arrange(desc(span))
save_table(tor |> mutate(across(where(is.numeric), ~ round(.x, 0))), "moduleE_tornado")

# ---- probabilistic sensitivity ----------------------------------------------------------------------------------------------------------------------------------------------
B <- 10000
psa_run <- function(common) {
  z <- if (common) rep(list(rnorm(B)), 9) else lapply(1:9, function(i) rnorm(B))
  gdraw <- runif(B, gross_lo, gross_hi); u <- runif(B); pa <- { a <- 0.5; b <- 1.25; m <- 1; Fm <- (m - a) / (b - a); ifelse(u < Fm, a + sqrt(u * (b - a) * (m - a)), b - sqrt((1 - u) * (b - a) * (b - m))) };   # triangular, mode 1.0 (as observed)
  y <- sample(bia_years35, B, replace = TRUE)
  out <- lapply(seq_len(B), function(i) { att9 <- pmax(inp$att$estimate + sapply(1:9, function(j) z[[j]][i]) * inp$att$se, 0)
    rb <- runif(1, rebate_lo, max(rebate_lo, 1 - announced / gdraw[i])); p <- base; p$att9 <- att9; p$gross <- gdraw[i]; p$pa_mult <- pa[i]; p$y35 <- y[i]; p$rebate <- rb
    t <- bia_run(p)$total; c(gross = t$five_year_gross, net = t$five_year_net, pmpm = t$pmpm_net) })
  as.data.frame(do.call(rbind, out)) |> mutate(correlation = ifelse(common, "common draw (perfect correlation between event times)", "independent event times"))
}
psa <- bind_rows(psa_run(FALSE), psa_run(TRUE))
q <- function(x) c(median = median(x), p05 = unname(quantile(x, 0.05)), p95 = unname(quantile(x, 0.95)))
psa_sum <- psa |> group_by(correlation) |> summarise(across(c(gross, net, pmpm), list(median = ~ median(.x), p05 = ~ quantile(.x, 0.05), p95 = ~ quantile(.x, 0.95)), .names = "{.col}_{.fn}"), draws = n(), .groups = "drop")
save_table(psa_sum |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleE_psa_summary", gt(psa_sum |> transmute(correlation, `Five-year gross, median` = round(gross_median), `90% interval gross` = sprintf("%s to %s", format(round(gross_p05), big.mark = ","), format(round(gross_p95), big.mark = ",")),
  `Five-year net, median` = round(net_median), `90% interval net` = sprintf("%s to %s", format(round(net_p05), big.mark = ","), format(round(net_p95), big.mark = ",")), `PMPM net, median` = round(pmpm_median, 2), `90% interval PMPM` = sprintf("%.2f to %.2f", pmpm_p05, pmpm_p95))) |>
  tab_header(title = "Probabilistic sensitivity analysis (10,000 draws), 1-million-enrollee Medicaid program", subtitle = "USD; incremental to no coverage; rebate between the statutory minimum and the rebate implied by $245") |> tab_source_note("Event-time correlation: the independent run ignores it; the common-draw run assumes perfect correlation. Gross = SDUD gross of rebates."))

# ---- figures -------------------------------------------------------------------------------------------------------------------------------------------------------------------
cap <- "Source: Module C estimates (CMS State Drug Utilization Data, Medicaid enrollment); SDUD gross reimbursement; statutory rebate floor 42 U.S.C. 1396r-8; White House fact sheet Nov 2025. SDUD amounts are gross of rebates; rebates, prior authorization and years 3-5 are assumptions."
mil <- function(x) x / 1e6
pn <- psa_sum |> filter(grepl("independent", correlation)); c1 <- res |> filter(y35 == "plateau", price == "rebate central")
# tornado
tp <- tor |> mutate(parameter = factor(parameter, levels = rev(parameter))) |> pivot_longer(c(net_low, net_high), names_to = "side", values_to = "net") |> mutate(lab = ifelse(side == "net_low", low_label, high_label)) |> group_by(parameter) |> mutate(is_left = net == min(net)) |> ungroup()
ptor <- ggplot(tp, aes(mil(net), parameter)) + geom_vline(xintercept = mil(b0), colour = col_comparison, linetype = "dashed") +
  geom_line(aes(group = parameter), colour = col_treated, linewidth = 6, alpha = 0.55) + geom_point(aes(colour = side), size = 3) + geom_text(aes(label = lab, hjust = ifelse(is_left, 1.12, -0.12)), size = 3.6, vjust = 0.5) +
  scale_colour_manual(values = c(net_low = col_comparison, net_high = col_treated), guide = "none") + scale_x_continuous(labels = scales::label_dollar(suffix = "M"), expand = expansion(mult = c(1.0, 1.0))) +
  labs(title = stringr::str_wrap(sprintf("Five-year net budget impact for 1 million enrollees is $%sM in the central case; the widest swings are %s ($%sM to $%sM) and %s", fmt1(mil(b0)), tor$parameter[1], fmt1(mil(min(tor$net_low[1], tor$net_high[1]))), fmt1(mil(max(tor$net_low[1], tor$net_high[1]))), tor$parameter[2]), 95),
       subtitle = stringr::str_wrap("One-way sensitivity: each parameter moved across its range with the others at central values (incremental to no coverage; central = plateau, PA as observed, rebate 51.2% = midpoint of 23.1% and 79.3%).", 120), x = "Five-year net budget impact (USD millions)", y = NULL, caption = stringr::str_wrap(cap, 150)) + theme_incretin() + theme(panel.grid.major.y = element_blank())
save_fig(ptor, "40_tornado", width = 11, height = 6, alt = sprintf("Tornado chart of the five-year net budget impact of Medicaid coverage for 1 million enrollees, central %s million dollars, with one bar per parameter: %s.", fmt1(mil(b0)), paste(tor$parameter, collapse = "; ")))
# waterfall (PMPM, five-year average)
g0 <- bia_run(base)$total$pmpm_gross; n_c <- bia_run(base)$total$pmpm_net; n_ann <- bia_run(mod(price = "announced"))$total$pmpm_net
rb_lab <- sprintf("Rebate (%s%%, midpoint of %s%% and %s%%)", fmt1(100 * rebate_mid), fmt1(100 * rebate_lo), fmt1(100 * rebate_hi))
wf <- tibble(step = c("Gross PMPM (effect and PA as observed)", rb_lab, "Net PMPM, central rebate", "Announced $245 price instead", "Net PMPM, announced price"),
             value = c(g0, n_c - g0, n_c, n_ann - n_c, n_ann), type = c("total", "delta", "total", "delta", "total")) |>
  mutate(end = NA_real_, start = NA_real_)
lvl <- 0; st <- numeric(nrow(wf)); en <- numeric(nrow(wf)); for (i in seq_len(nrow(wf))) { if (wf$type[i] == "total") { st[i] <- 0; en[i] <- wf$value[i]; lvl <- wf$value[i] } else { st[i] <- lvl; en[i] <- lvl + wf$value[i]; lvl <- en[i] } }
wf$start <- st; wf$end <- en; wf$step <- factor(wf$step, levels = wf$step)
pw <- ggplot(wf) + geom_rect(aes(xmin = as.numeric(step) - 0.4, xmax = as.numeric(step) + 0.4, ymin = start, ymax = end, fill = type)) +
  geom_text(aes(x = as.numeric(step), y = pmax(start, end), label = sprintf("$%.2f", ifelse(type == "total", value, abs(value)))), vjust = -0.5, size = 3) +
  scale_fill_manual(values = c(total = col_treated, delta = col_comparison), guide = "none") + scale_x_continuous(breaks = seq_len(nrow(wf)), labels = stringr::str_wrap(levels(wf$step), 14)) +
  labs(title = stringr::str_wrap(sprintf("Per enrollee per month, a gross cost of $%.2f falls to a net $%.2f after a rebate of %s%% (midpoint assumption), and to $%.2f at the announced $245 price (five-year average, 1 million enrollees)", g0, n_c, fmt1(100 * rebate_mid), n_ann), 95),
       subtitle = stringr::str_wrap("Waterfall from gross PMPM (effect and prior authorization as observed in the covering states) to net PMPM. The rebate step is an assumption; the $245 price is an announced program price.", 120), x = NULL, y = "USD per enrollee per month", caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(pw, "41_waterfall_pmpm", width = 11, height = 6, alt = sprintf("Waterfall chart from gross cost per enrollee per month of %.2f dollars, down by the rebate to a net %.2f dollars, and to %.2f dollars at the announced price.", g0, n_c, n_ann))
save_table(wf |> mutate(across(where(is.numeric), ~ round(.x, 3))), "moduleE_waterfall_pmpm")
# five-year cost by scenario
sc <- res |> mutate(price = factor(price, levels = c("rebate low (23.1%)", "rebate central", "rebate high (implied by $245)", "announced $245")), y35 = factor(y35, levels = bia_years35, labels = c("Years 3-5 plateau", "Years 3-5 continued growth", "Years 3-5 decline")))
pc <- ggplot(sc, aes(y35, mil(five_year_net), fill = price)) + geom_col(position = position_dodge(width = 0.8), width = 0.75) + geom_text(aes(label = sprintf("$%s M", fmt1(mil(five_year_net)))), position = position_dodge(width = 0.8), angle = 90, hjust = -0.08, vjust = 0.5, size = 3.6) + scale_y_continuous(expand = expansion(mult = c(0.02, 0.32))) +
  scale_fill_manual(values = c("rebate low (23.1%)" = "#BFBFBF", "rebate central" = col_treated, "rebate high (implied by $245)" = "#7A7A7A", "announced $245" = okabe_ito[["blue"]]), name = NULL) + labs(x = NULL, y = "Five-year net budget impact (USD millions)",
  title = stringr::str_wrap(sprintf("Five-year net cost for 1 million enrollees ranges from $%sM to $%sM across years 3-5 scenarios and rebate or price assumptions; central $%sM", fmt1(mil(min(res$five_year_net))), fmt1(mil(max(res$five_year_net))), fmt1(mil(c1$five_year_net))), 95),
  subtitle = stringr::str_wrap("Net cost by years 3-5 scenario and by rebate or price assumption (prior authorization as observed, multiplier 1.0; incremental to no coverage).", 120), caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(pc, "42_cost_by_scenario", width = 11, height = 6, alt = sprintf("Grouped bars of five-year net budget impact for three years 3-5 scenarios and four rebate or price assumptions, from %s to %s million dollars.", fmt1(mil(min(res$five_year_net))), fmt1(mil(max(res$five_year_net)))))
# PSA distribution
pp <- ggplot(psa |> filter(correlation == "independent event times"), aes(mil(net))) + geom_histogram(bins = 60, fill = col_treated, alpha = 0.85) + geom_vline(xintercept = mil(pn$net_median), colour = "#222222") +
  geom_vline(xintercept = mil(c(pn$net_p05, pn$net_p95)), colour = "#222222", linetype = "dashed") + labs(x = "Five-year net budget impact (USD millions)", y = "Draws",
  title = stringr::str_wrap(sprintf("Across 10,000 draws the five-year net budget impact has a median of $%sM (90%% interval $%sM to $%sM); PMPM median $%.2f", fmt1(mil(pn$net_median)), fmt1(mil(pn$net_p05)), fmt1(mil(pn$net_p95)), pn$pmpm_median), 95),
  subtitle = stringr::str_wrap(sprintf("Probabilistic sensitivity analysis: Module C effects drawn from their SEs (independent event times; perfect correlation gives $%sM to $%sM), gross cost, rebate, prior authorization multiplier and years 3-5 scenario drawn from their ranges. 1 million enrollees.",
                                       fmt1(mil(psa_sum$net_p05[grepl("common", psa_sum$correlation)])), fmt1(mil(psa_sum$net_p95[grepl("common", psa_sum$correlation)]))), 140), caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(pp, "43_psa_distribution", width = 10, height = 5.8, alt = sprintf("Histogram of five-year net budget impact across 10,000 draws; median %s million dollars, 90 percent interval %s to %s million.", fmt1(mil(pn$net_median)), fmt1(mil(pn$net_p05)), fmt1(mil(pn$net_p95))))

# ---- files for the app: small CSVs (aggregate numbers already public in the report; each value is checked against key_numbers.csv by scripts/45_check_app_data.R) ------------------------------------
dir.create(here::here("..", "app", "data"), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(inp$att |> transmute(event_quarter = e, estimate = round(estimate, 4), se = round(se, 4), ci_low = round(ci_low, 4), ci_high = round(ci_high, 4)), here::here("..", "app", "data", "moduleC_effects.csv"))
readr::write_csv(tibble::tribble(~parameter, ~low, ~central, ~high, ~unit, ~source,
  "gross_cost_per_prescription", round(inp$gross$low, 2), round(inp$gross$central, 4), round(inp$gross$high, 2), "USD per prescription, gross of rebates", "CMS State Drug Utilization Data, covering states, 2025 (range: quarterly values 2024 Q2 to 2025 Q4)",
  "rebate_share", round(inp$rebate$low, 4), round(inp$rebate$central, 6), round(inp$rebate$high, 6), "share of gross cost", "low = statutory minimum (42 U.S.C. 1396r-8); high = implied by the announced $245 price; central = midpoint (assumption)",
  "announced_net_price", NA, inp$announced, NA, "USD per monthly prescription", "White House fact sheet, November 2025",
  "purchases_per_user_year", inp$fills$low, inp$fills$central, inp$fills$high, "purchases per treated user per year", "MEPS weighted purchases per adult user, 2023 (low) and 2024 (central); 12 = monthly all year (assumption)",
  "adult_share_of_enrollment", NA, round(inp$adult_share, 4), NA, "share of Medicaid enrollees", "Medicaid enrollment, 2024 Q3 to 2026 Q1",
  "eligible_share_of_medicaid_adults", NA, round(inp$eligible_share, 6), NA, "share of Medicaid adults (lower bound)", "NHANES 2021-2023, label-eligible"),
  here::here("..", "app", "data", "model_settings.csv"))
file.copy(here::here("R", "bia.R"), here::here("..", "app", "R", "bia.R"), overwrite = TRUE)
print(inp$att); cat("gross central", round(gross_central), "range", round(gross_lo), round(gross_hi), "rebate", round(rebate_lo, 3), round(rebate_mid, 3), round(rebate_hi, 3), "adult share", round(adult_share, 3), "elig share", round(elig_share, 3), "fills", round(fills_obs, 2), "\n")
print(res |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> select(y35, price, five_year_gross, five_year_net, pmpm_net, net_cost_per_user_year, net_cost_per_member_year_continuous, n_years_exceed_pool), width = 200); print(ann_c |> mutate(across(where(is.numeric), ~ round(.x, 1))), width = 200)
print(tor |> mutate(across(where(is.numeric), ~ round(.x, 0))), width = 200); print(psa_sum |> mutate(across(where(is.numeric), ~ round(.x, 2))), width = 250)
