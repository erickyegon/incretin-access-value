# Module D step D3: Open Payments and prescribing, ASSOCIATION ONLY (plan_moduleD.md). Payments in year t-1 against Part D incretin claims in year t.
# Primary pair 2023 payments -> 2024 claims; check 2022 -> 2023. Aggregate outputs only: no NPI-level table or chart; the model results are coefficients.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(MASS); library(sandwich); library(lmtest); library(patchwork); library(gt) })
select <- dplyr::select

cap <- "Source: CMS Medicare Part D Prescribers (rows with at least 11 claims) and CMS Open Payments general payments naming in-scope incretin products (each record counted once, equal split over products). Part D reflects diabetes and other covered uses, not obesity-brand adoption. Association only: payments are not randomly assigned."
d <- get_mart("mart_prescriber_year", cols = c("prescriber_npi", "data_year", "specialty_group", "prescriber_state", "total_claims"), where = "data_year in (2021, 2022, 2023, 2024)")
claims <- d |> group_by(prescriber_npi, data_year) |> summarise(claims = sum(total_claims), specialty_group = first(specialty_group), state = first(prescriber_state), .groups = "drop")
pay <- get_mart("mart_open_payments_npi_year", cols = c("covered_recipient_npi", "program_year", "amount_equal_split", "is_physician"), where = "program_year in (2021, 2022, 2023)")

build <- function(t) {
  base <- claims |> filter(data_year == t) |> select(prescriber_npi, claims, specialty_group, state)
  base <- base |> left_join(pay |> filter(program_year == t - 1) |> select(prescriber_npi = covered_recipient_npi, pay_prev = amount_equal_split), by = "prescriber_npi") |>
    left_join(claims |> filter(data_year == t - 2) |> select(prescriber_npi, claims_t2 = claims), by = "prescriber_npi") |>
    mutate(pay_prev = coalesce(pay_prev, 0), any_pay = pay_prev > 0, no_t2 = is.na(claims_t2), claims_t2 = coalesce(claims_t2, 0), lpay = log1p(pay_prev), lbase = log1p(claims_t2),
           specialty_group = factor(specialty_group), state = factor(coalesce(state, "unknown")))
  base
}
res <- list(); con_tab <- list(); desc_tab <- list(); bin_tab <- list()
for (t in c(2024, 2023)) {
  x <- build(t)
  # descriptive: by claim-volume decile and specialty
  x$decile <- ntile(x$claims, 10)
  desc_tab[[as.character(t)]] <- bind_rows(
    x |> group_by(group = paste("claims decile", decile)) |> summarise(prescribers = n(), share_with_payment_pct = 100 * mean(any_pay), median_payment_among_payees = median(pay_prev[any_pay]), .groups = "drop") |> mutate(by = "claim-volume decile (1 = lowest)"),
    x |> group_by(group = as.character(specialty_group)) |> summarise(prescribers = n(), share_with_payment_pct = 100 * mean(any_pay), median_payment_among_payees = median(pay_prev[any_pay]), .groups = "drop") |> mutate(by = "specialty group"),
    x |> summarise(group = "All prescribers", prescribers = n(), share_with_payment_pct = 100 * mean(any_pay), median_payment_among_payees = median(pay_prev[any_pay])) |> mutate(by = "all")) |> mutate(claims_year = t, payments_year = t - 1)
  # binned scatter: zero-payment bin plus deciles of positive payments
  pos <- x |> filter(any_pay); cut_pts <- unique(quantile(pos$pay_prev, seq(0, 1, 0.1)))
  x$bin <- ifelse(!x$any_pay, "0", as.character(cut(x$pay_prev, cut_pts, include.lowest = TRUE, labels = FALSE)))
  bt <- x |> group_by(bin) |> summarise(prescribers = n(), mean_payment = mean(pay_prev), mean_claims = mean(claims), mean_claims_t2 = mean(claims_t2), .groups = "drop") |> mutate(order = ifelse(bin == "0", 0, as.numeric(bin)), claims_year = t) |> arrange(order)
  bin_tab[[as.character(t)]] <- bt
  # model
  m <- glm.nb(claims ~ lpay + specialty_group + state + lbase + no_t2, data = x, control = glm.control(maxit = 100))
  ct <- coeftest(m, vcov. = vcovHC(m, type = "HC0")); b <- ct["lpay", 1]; se <- ct["lpay", 2]
  # second, two-part form: any payment (indicator) plus log of the amount among payees, centred at the median payee amount, so that "any payment vs none" is a single ratio
  med_pay <- median(x$pay_prev[x$any_pay]); x$lpay_c <- ifelse(x$any_pay, log(x$pay_prev / med_pay), 0)
  m2 <- glm.nb(claims ~ any_pay + lpay_c + specialty_group + state + lbase + no_t2, data = x, control = glm.control(maxit = 100)); ct2 <- coeftest(m2, vcov. = vcovHC(m2, type = "HC0"))
  ci_ratio <- function(est, se, k = 1) c(exp(k * est), exp(k * (est - 1.96 * se)), exp(k * (est + 1.96 * se)))
  r1 <- ci_ratio(ct2["any_payTRUE", 1], ct2["any_payTRUE", 2]); r2 <- ci_ratio(ct2["lpay_c", 1], ct2["lpay_c", 2], log(2)); r3 <- ci_ratio(b, se, log1p(med_pay)); r4 <- ci_ratio(b, se, log1p(1000))
  con_tab[[as.character(t)]] <- tibble(claims_year = t, payments_year = t - 1,
    contrast = c(sprintf("Any payment versus none, at the median payee amount ($%.0f)", med_pay), "Each doubling of the payment amount among payees", sprintf("Median payee amount ($%.0f) versus none", med_pay), "$1,000 versus none (a contrast at $1,000, not a per-$1,000 slope)"),
    model = c("two-part: any payment + log(amount / median) among payees", "two-part: any payment + log(amount / median) among payees", "log(1 + dollars)", "log(1 + dollars)"),
    incidence_rate_ratio = c(r1[1], r2[1], r3[1], r4[1]), ci_low = c(r1[2], r2[2], r3[2], r4[2]), ci_high = c(r1[3], r2[3], r3[3], r4[3]), median_payee_amount = med_pay)
  irr1000 <- exp(b * log1p(1000)); lo <- exp((b - 1.96 * se) * log1p(1000)); hi <- exp((b + 1.96 * se) * log1p(1000))
  res[[as.character(t)]] <- tibble(claims_year = t, payments_year = t - 1, prescribers = nrow(x), prescribers_with_payment = sum(x$any_pay), model = "negative binomial (MASS::glm.nb), HC0 robust CI", functional_form = "log(1 + dollars): predictor is natural log of (1 + prior-year payments in USD); coefficient is per log-unit, not per $1,000",
    coef_log1p_payments = b, ci_low = b - 1.96 * se, ci_high = b + 1.96 * se, ratio_1000_usd_vs_none_contrast = irr1000, ratio_ci_low = lo, ratio_ci_high = hi, theta = m$theta)
  cat("year", t, "n", nrow(x), "payees", sum(x$any_pay), "coef", round(b, 4), "ratio $1000 vs none", round(irr1000, 3), round(lo, 3), round(hi, 3), "\n")
}
mod <- bind_rows(res); con <- bind_rows(con_tab); desc_all <- bind_rows(desc_tab); bins <- bind_rows(bin_tab)
save_table(mod |> mutate(across(where(is.numeric), ~ round(.x, 4))), "moduleD_payments_model", gt(mod |> transmute(claims_year, payments_year, prescribers, prescribers_with_payment, coef = round(coef_log1p_payments, 4), ci = sprintf("%.4f to %.4f", ci_low, ci_high),
  `ratio, $1,000 vs none (contrast, not a slope)` = round(ratio_1000_usd_vs_none_contrast, 3), `95% CI` = sprintf("%.3f to %.3f", ratio_ci_low, ratio_ci_high))) |>
  tab_header(title = "Open Payments in the prior year and Part D incretin claims: negative binomial association", subtitle = "Adjusted for specialty group, state and log(1 + claims two years earlier); robust (HC0) confidence intervals; not a causal effect") |>
  tab_source_note("Functional form: log(1 + dollars), dollars not in thousands. The coefficient is per log-unit of (1 + dollars). The ratio shown is exp(coefficient x log(1 + 1000)): the ratio of expected claims at $1,000 versus $0, not a per-$1,000 slope. Clear contrasts are in moduleD_payments_contrasts.csv."))
save_table(con |> mutate(across(where(is.numeric), ~ round(.x, 3))), "moduleD_payments_contrasts", gt(con |> transmute(claims_year, payments_year, contrast, model, `incidence rate ratio` = round(incidence_rate_ratio, 3), `95% CI` = sprintf("%.3f to %.3f", ci_low, ci_high))) |> tab_header(title = "Open Payments and Part D incretin claims: incidence rate ratios for clear contrasts", subtitle = "Negative binomial, adjusted for specialty group, state and log(1 + claims two years earlier); robust (HC0) CIs; association, not a causal effect"))
save_table(desc_all |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleD_payments_descriptives")
bins <- bins |> group_by(claims_year) |> mutate(claims_ratio_vs_no_payment = mean_claims / mean_claims[order == 0], baseline_claims_ratio_vs_no_payment = mean_claims_t2 / mean_claims_t2[order == 0]) |> ungroup()
save_table(bins |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleD_payments_binned")

b24 <- bins |> filter(claims_year == 2024) |> mutate(label = ifelse(bin == "0", "No payment", paste0("Payee decile ", bin)))
dsc <- desc_all |> filter(claims_year == 2024, by == "all")
m24 <- mod |> filter(claims_year == 2024); c24 <- con |> filter(claims_year == 2024, grepl("^Any payment", contrast))
pb <- ggplot(b24, aes(order, mean_claims)) + geom_line(colour = col_treated, linewidth = 1) + geom_point(colour = col_treated, size = 3) +
  geom_line(aes(y = mean_claims_t2), colour = col_comparison, linewidth = 0.9, linetype = "dashed") + geom_point(aes(y = mean_claims_t2), colour = col_comparison, size = 2) +
  scale_x_continuous(breaks = 0:10, labels = c("none", paste0("D", 1:10))) +
  annotate("text", x = 10, y = max(b24$mean_claims) * 0.98, label = "2024 claims", colour = col_treated, hjust = 1, size = 3.3) + annotate("text", x = 10, y = b24$mean_claims_t2[b24$order == 10] * 0.8, label = "2022 claims (baseline)", colour = col_comparison, hjust = 1, size = 3.3) +
  labs(title = stringr::str_wrap(sprintf("Prescribers with in-scope payments in 2023 had more incretin claims in 2024 (%s%% of the %s prescribers had a payment); adjusted for baseline volume, any payment goes with a claims rate ratio of %s (95%% CI %s to %s) at the median payee amount",
        fmt1(dsc$share_with_payment_pct), format(dsc$prescribers, big.mark = ","), sprintf("%.2f", c24$incidence_rate_ratio), sprintf("%.2f", c24$ci_low), sprintf("%.2f", c24$ci_high)), 100),
       subtitle = "Mean 2024 Part D incretin claims (solid) and mean 2022 claims (dashed) by 2023 payment bin: no payment, then deciles of positive payment amounts (D1 lowest, D10 highest). Binned and aggregate; an association, not an effect of payments.",
       x = "Prior-year (2023) payments, binned", y = "Mean claims per prescriber", caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(pb, "36_payments_binned", width = 10, height = 6.2, alt = sprintf("Binned scatter of mean Part D incretin claims in 2024 (solid) and in 2022 (dashed) against 2023 Open Payments bins: no payment and ten deciles of positive amounts. Claims rise with payment size in both years. Negative binomial incidence rate ratio for any payment versus none at the median payee amount, adjusted for baseline volume, specialty and state: %s (95 percent CI %s to %s).",
     sprintf("%.2f", c24$incidence_rate_ratio), sprintf("%.2f", c24$ci_low), sprintf("%.2f", c24$ci_high)))
print(mod |> mutate(across(where(is.numeric), ~ round(.x, 4))), width = 200); print(desc_all |> filter(claims_year == 2024) |> mutate(across(where(is.numeric), ~ round(.x, 1))), n = 40); print(b24 |> mutate(across(where(is.numeric), ~ round(.x, 1))))
