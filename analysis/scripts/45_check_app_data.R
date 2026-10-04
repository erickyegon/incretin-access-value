# Checks the budget-model app's data files (app/data/*.csv) before publishing: (1) only the expected aggregate columns, no row-level or identifying fields; (2) every value equals the number displayed in
# outputs/key_numbers.csv or the output table it is generated from (same rounding as the report). Stops with an error on any mismatch; writes outputs/tables/app_data_check.csv.
source(here::here("R", "theme.R"))
suppressPackageStartupMessages(library(dplyr))
ad <- function(f) readr::read_csv(here::here("..", "app", "data", f), show_col_types = FALSE, progress = FALSE, na = c("", "NA"))
tb <- function(f) readr::read_csv(here::here("outputs", "tables", f), show_col_types = FALSE, progress = FALSE)
kn <- read.csv(here::here("outputs", "key_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0))
d <- function(id) { r <- kn[kn$id == id, ]; stopifnot(nrow(r) == 1); r }
num <- function(x) as.numeric(gsub(",", "", x))
rows <- list(); chk <- function(what, ok, detail = "") rows[[length(rows) + 1]] <<- data.frame(check = what, ok = isTRUE(ok), detail = detail)
cmp <- function(what, app_value, shown, key_id) chk(what, isTRUE(all.equal(num(shown), num(app_value))), sprintf("app %s vs key_numbers %s (%s)", app_value, shown, key_id))

# 1. expected columns (aggregate only)
expect <- list("moduleC_effects.csv" = c("event_quarter", "estimate", "se", "ci_low", "ci_high"), "model_settings.csv" = c("parameter", "low", "central", "high", "unit", "source"), "event_study.csv" = c("event_time", "att", "ci_low", "ci_high", "treated_states", "fewer_than_3_states"),
               "overall_effects.csv" = c("estimate", "att", "ci_low", "ci_high"), "specifications.csv" = c("spec", "specification", "att", "ci_low", "ci_high", "states", "estimable"), "state_quarter_rates.csv" = c("state_code", "quarter_label", "rate", "coverage_active", "is_preliminary"),
               "never_covered_mean.csv" = c("quarter_label", "never_covered_mean_imputed", "never_covered_mean_observed"), "state_enrollment.csv" = c("state_code", "state_name", "quarter_label", "enrollment"), "key_facts.csv" = c("id", "display", "unit", "ci_or_range", "statement"),
               "assumptions.csv" = c("parameter", "value_or_range", "basis_type", "basis", "source_label", "source_url"), "states.csv" = c("state_code", "col", "row", "state_name", "group", "cohort_quarter", "start_earliest", "start_latest", "cohort_year", "coverage_start", "coverage_end", "prior_authorization", "bmi_threshold", "step_therapy", "document", "source_url"))
for (f in names(expect)) chk(paste("columns of", f), identical(names(ad(f)), expect[[f]]), paste(names(ad(f)), collapse = ", "))
chk("no files other than the expected CSVs in app/data", setequal(list.files(here::here("..", "app", "data")), names(expect)), paste(setdiff(list.files(here::here("..", "app", "data")), names(expect)), collapse = ", "))
sz <- sum(file.size(list.files(here::here("..", "app", "data"), full.names = TRUE))); chk("app/data is small (under 200 KB)", sz < 2e5, paste(round(sz / 1024), "KB"))
# 2. state-quarter rates are rates (no counts), with the right shape
r <- ad("state_quarter_rates.csv"); chk("state-quarter rates: 51 states x 33 quarters, one numeric rate column", nrow(r) == 51 * 33 && is.numeric(r$rate), paste(nrow(r), "rows"))
rp <- tb("moduleA_rate_by_state_2025Q3.csv"); m <- merge(r[r$quarter_label == "2025Q3", ], rp, by = "state_code"); chk("2025 Q3 state rates equal moduleA_rate_by_state_2025Q3.csv", all(abs(m$rate - m$rate_per_1000) < 0.006, na.rm = TRUE))
# 3. key facts are exact copies of key_numbers.csv rows
kf <- ad("key_facts.csv") |> as.data.frame(); kk <- kn[match(kf$id, kn$id), ]
chk("key_facts.csv rows are identical to key_numbers.csv", !anyNA(kk$id) && all(kf$display == kk$display) && all(kf$unit == kk$unit) && all(kf$statement == kk$statement) && all(ifelse(is.na(kf$ci_or_range), "", kf$ci_or_range) == kk$ci_or_range), paste(nrow(kf), "rows"))
# 4. Module C effects vs the hand-off table and key numbers
eff <- ad("moduleC_effects.csv"); ho <- tb("moduleC_for_budget_model.csv") |> filter(section == "dynamic_att") |> mutate(e = as.integer(sub("e=", "", key))) |> arrange(e)
chk("effects (estimate, se, CI) equal the Module C hand-off table to 4 decimals", all(abs(eff$estimate - ho$estimate) < 6e-5) && all(abs(eff$se - ho$se) < 6e-5) && all(abs(eff$ci_low - ho$ci_low) < 6e-5) && all(abs(eff$ci_high - ho$ci_high) < 6e-5))
for (k in 0:8) { r1 <- d(paste0("c_es_e", k)); ci <- as.numeric(strsplit(sub("^95% CI ", "", r1$ci_or_range), " to ")[[1]]); e <- eff[eff$event_quarter == k, ]
  cmp(sprintf("effect e=%d estimate", k), fmt1(e$estimate), r1$display, r1$id); cmp(sprintf("effect e=%d ci_low", k), fmt1(e$ci_low), fmt1(ci[1]), r1$id); cmp(sprintf("effect e=%d ci_high", k), fmt1(e$ci_high), fmt1(ci[2]), r1$id) }
# 5. model settings vs key numbers
st <- ad("model_settings.csv") |> as.data.frame(); v <- function(p, col) st[[col]][st$parameter == p]
cmp("gross cost central", formatC(round(v("gross_cost_per_prescription", "central")), format = "d", big.mark = ","), d("e_gross_rx")$display, "e_gross_rx"); cmp("gross cost low", formatC(round(v("gross_cost_per_prescription", "low")), format = "d", big.mark = ","), d("e_gross_rx_low")$display, "e_gross_rx_low")
cmp("gross cost high", formatC(round(v("gross_cost_per_prescription", "high")), format = "d", big.mark = ","), d("e_gross_rx_high")$display, "e_gross_rx_high")
cmp("rebate central %", fmt1(100 * v("rebate_share", "central")), d("e_rebate_central")$display, "e_rebate_central"); cmp("rebate low %", fmt1(100 * v("rebate_share", "low")), d("e_rebate_low")$display, "e_rebate_low"); cmp("rebate high %", fmt1(100 * v("rebate_share", "high")), d("e_rebate_high")$display, "e_rebate_high")
cmp("announced price", as.character(v("announced_net_price", "central")), d("x_price_245")$display, "x_price_245"); cmp("purchases per user-year central", sprintf("%.2f", v("purchases_per_user_year", "central")), d("e_fills_2024")$display, "e_fills_2024")
cmp("purchases per user-year low", sprintf("%.2f", v("purchases_per_user_year", "low")), d("e_fills_2023")$display, "e_fills_2023"); cmp("purchases per user-year high", as.character(v("purchases_per_user_year", "high")), d("e_fills_continuous")$display, "e_fills_continuous")
cmp("adult share %", fmt1(100 * v("adult_share_of_enrollment", "central")), d("e_adult_share")$display, "e_adult_share"); cmp("eligible share %", fmt1(100 * v("eligible_share_of_medicaid_adults", "central")), d("b_medicaid_elig_share")$display, "b_medicaid_elig_share")
# 6. event study, specifications, overall effects, never-covered mean, states
es <- ad("event_study.csv"); eo <- tb("event_study_primary.csv"); chk("event study equals event_study_primary.csv (3 decimals)", nrow(es) == nrow(eo) && all(abs(es$att - eo$att) < 6e-4, na.rm = TRUE) && all(abs(es$ci_low - eo$ci_low) < 6e-4, na.rm = TRUE) && all(abs(es$ci_high - eo$ci_high) < 6e-4, na.rm = TRUE))
sp <- ad("specifications.csv"); so <- tb("specification_table_raw.csv"); ok <- sp$estimable; chk("specifications equal specification_table_raw.csv; specification 12 is flagged not estimable", all(abs(sp$att[ok] - so$att_simple[match(sp$spec[ok], so$spec)]) < 6e-4) && !sp$estimable[sp$spec == "12"] && is.na(sp$att[sp$spec == "12"]))
holds <- sum(sp$estimable & sp$spec != "0" & (sp$ci_low > 0 | sp$ci_high < 0)); chk("'15 of 15 alternative analyses' equals the table", sprintf("%d of %d", holds, sum(sp$estimable & sp$spec != "0")) == d("c_spec_holds")$display, d("c_spec_holds")$display)
ov <- ad("overall_effects.csv"); cmp("overall effect (primary)", fmt1(ov$att[1]), d("c_att_overall")$display, "c_att_overall"); cmp("placebo", fmt1(ov$att[grepl("^Placebo", ov$estimate)]), d("c_placebo")$display, "c_placebo")
nv <- ad("never_covered_mean.csv"); hn <- tb("moduleC_for_budget_model.csv") |> filter(section == "never_treated_baseline"); chk("never-covered mean equals the hand-off table", nrow(nv) == nrow(hn) && all(abs(nv$never_covered_mean_observed - hn$value_observed_only) < 6e-5, na.rm = TRUE))
sts <- ad("states.csv"); chk("51 jurisdictions: 10 primary, 7 sensitivity, 34 never covered (key numbers)", nrow(sts) == 51 && sum(sts$group == "primary") == num(d("c_states_primary")$display) && sum(sts$group == "sensitivity") == num(d("c_states_sens")$display) && sum(sts$group == "never") == num(d("c_states_never")$display))
en <- ad("state_enrollment.csv"); chk("state enrollment: 51 jurisdictions, positive counts", nrow(en) == 51 && all(en$enrollment > 0))
as <- ad("assumptions.csv") |> as.data.frame(); txt <- paste(as$value_or_range, collapse = " | ")
chk("assumptions text carries the key numbers (gross cost, rebates, price, fills, shares)", all(sapply(c(d("e_gross_rx")$display, paste0(d("e_rebate_low")$display, "%"), paste0(d("e_rebate_high")$display, "%"), paste0(d("e_rebate_central")$display, "%"), paste0("$", d("x_price_245")$display), paste0(d("e_adult_share")$display, "%")), function(s) grepl(s, txt, fixed = TRUE))), "")
res <- do.call(rbind, rows); save_table(res |> transmute(check, passed = ok, detail), "app_data_check"); print(res |> filter(!ok)); cat(sum(res$ok), "of", nrow(res), "checks pass\n")
stopifnot("app data does not match key_numbers.csv or its source tables" = all(res$ok))
