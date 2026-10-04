# Checks the budget-model app's input files (app/data/*.csv) before publishing: (1) only the expected aggregate columns, no row-level or identifying fields; (2) every value equals the number displayed in
# outputs/key_numbers.csv (same rounding as the report). Stops with an error on any mismatch; writes outputs/tables/app_data_check.csv.
source(here::here("R", "theme.R"))
kn <- read.csv(here::here("outputs", "key_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0))
d <- function(id) { r <- kn[kn$id == id, ]; stopifnot(nrow(r) == 1); r }
num <- function(x) as.numeric(gsub(",", "", x))
eff <- read.csv(here::here("..", "app", "data", "moduleC_effects.csv")); st <- read.csv(here::here("..", "app", "data", "model_settings.csv"), stringsAsFactors = FALSE)
stopifnot(identical(names(eff), c("event_quarter", "estimate", "ci_low", "ci_high")), identical(names(st), c("parameter", "low", "central", "high", "unit", "source")), nrow(eff) == 9, nrow(st) == 6)
rows <- list(); chk <- function(what, app_value, shown, key_id) { ok <- isTRUE(all.equal(num(shown), num(app_value))); rows[[length(rows) + 1]] <<- data.frame(item = what, app_value = app_value, key_numbers_display = shown, key_id = key_id, match = ok) }
for (k in 0:8) { r <- d(paste0("c_es_e", k)); ci <- as.numeric(strsplit(sub("^95% CI ", "", r$ci_or_range), " to ")[[1]]); e <- eff[eff$event_quarter == k, ]
  chk(sprintf("effect e=%d estimate", k), fmt1(e$estimate), r$display, r$id); chk(sprintf("effect e=%d ci_low", k), fmt1(e$ci_low), fmt1(ci[1]), r$id); chk(sprintf("effect e=%d ci_high", k), fmt1(e$ci_high), fmt1(ci[2]), r$id) }
v <- function(p, col) st[[col]][st$parameter == p]
chk("gross cost central", formatC(round(v("gross_cost_per_prescription", "central")), format = "d", big.mark = ","), d("e_gross_rx")$display, "e_gross_rx")
chk("gross cost low", formatC(round(v("gross_cost_per_prescription", "low")), format = "d", big.mark = ","), d("e_gross_rx_low")$display, "e_gross_rx_low"); chk("gross cost high", formatC(round(v("gross_cost_per_prescription", "high")), format = "d", big.mark = ","), d("e_gross_rx_high")$display, "e_gross_rx_high")
chk("rebate central %", fmt1(100 * v("rebate_share", "central")), d("e_rebate_central")$display, "e_rebate_central"); chk("rebate low %", fmt1(100 * v("rebate_share", "low")), d("e_rebate_low")$display, "e_rebate_low"); chk("rebate high %", fmt1(100 * v("rebate_share", "high")), d("e_rebate_high")$display, "e_rebate_high")
chk("announced price", as.character(v("announced_net_price", "central")), d("x_price_245")$display, "x_price_245")
chk("purchases per user-year central", sprintf("%.2f", v("purchases_per_user_year", "central")), d("e_fills_2024")$display, "e_fills_2024"); chk("purchases per user-year low", sprintf("%.2f", v("purchases_per_user_year", "low")), d("e_fills_2023")$display, "e_fills_2023"); chk("purchases per user-year high", as.character(v("purchases_per_user_year", "high")), d("e_fills_continuous")$display, "e_fills_continuous")
chk("adult share %", fmt1(100 * v("adult_share_of_enrollment", "central")), d("e_adult_share")$display, "e_adult_share"); chk("eligible share %", fmt1(100 * v("eligible_share_of_medicaid_adults", "central")), d("b_medicaid_elig_share")$display, "b_medicaid_elig_share")
res <- do.call(rbind, rows); save_table(res, "app_data_check"); print(res, row.names = FALSE)
cat("\nfiles:", paste(c("moduleC_effects.csv", "model_settings.csv"), file.size(here::here("..", "app", "data", c("moduleC_effects.csv", "model_settings.csv"))), "bytes", collapse = "; "), "\n")
stopifnot("app data does not match key_numbers.csv" = all(res$match)); cat("ALL", nrow(res), "VALUES MATCH key_numbers.csv\n")
