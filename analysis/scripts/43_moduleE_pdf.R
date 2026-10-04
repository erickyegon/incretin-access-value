# Module E static PDF: the main scenarios, central annual table and figures (fallback for the app). Built only from the saved Module E tables and figures.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(grid); library(gridExtra); library(png) })
tb <- function(x) readr::read_csv(here::here("outputs", "tables", x), show_col_types = FALSE)
fig <- function(x) grid.raster(readPNG(here::here("outputs", "figures", x)), width = unit(1, "npc"), height = unit(1, "npc"), interpolate = TRUE)
res <- tb("moduleE_scenario_results.csv"); ann <- tb("moduleE_central_annual.csv"); psa <- tb("moduleE_psa_summary.csv")
f <- here::here("outputs", "budget_impact_scenarios.pdf")
pdf(f, width = 11, height = 8.5, onefile = TRUE)
grid.newpage()
grid.text("Budget impact of Medicaid coverage of Wegovy and Zepbound for obesity", x = 0.05, y = 0.93, just = "left", gp = gpar(fontsize = 20, fontface = "bold"))
pn <- psa[grepl("independent", psa$correlation), ]
txt <- c(sprintf("A state Medicaid program of 1 million enrollees, five years, incremental to no coverage."),
         sprintf("Central case (years 3-5 plateau, prior authorization as observed in the covering states (multiplier 1.0), rebate 51.2%% = midpoint of 23.1%% and 79.3%%): five-year net cost $%.1f million, $%.2f per enrollee per month; gross $%.1f million.",
                 res$five_year_net[res$y35 == "plateau" & res$price == "rebate central"] / 1e6, res$pmpm_net[res$y35 == "plateau" & res$price == "rebate central"], res$five_year_gross[res$y35 == "plateau" & res$price == "rebate central"] / 1e6),
         sprintf("Probabilistic sensitivity (10,000 draws): median $%.1f million, 90%% interval $%.1f to $%.1f million.", pn$net_median / 1e6, pn$net_p05 / 1e6, pn$net_p95 / 1e6),
         sprintf("At the announced $245 per monthly prescription: $%.1f million (PMPM $%.2f) in the plateau scenario.", res$five_year_net[res$y35 == "plateau" & res$price == "announced $245"] / 1e6, res$pmpm_net[res$y35 == "plateau" & res$price == "announced $245"]),
         "", "What is measured: incremental prescriptions per 1,000 enrollees from Module C (observed fills, so discontinuation is already in the uptake); SDUD gross cost per prescription; NHANES eligible share; adult share of enrollment.",
         "What is assumed: rebates (23.1% statutory minimum to the rebate implied by $245), prior authorization multiplier (tight 0.5 to 0.75, loose up to 1.25; central 1.0 = as observed), years 3-5 scenarios, one prescription = one month. SDUD amounts are gross of rebates.",
         "Scenarios, not forecasts; no medical cost offsets are included. Source: CMS SDUD, Medicaid enrollment, NHANES; 42 U.S.C. 1396r-8; White House fact sheet (Nov 2025).")
grid.text(paste(strwrap(txt, 120), collapse = "\n"), x = 0.05, y = 0.80, just = c("left", "top"), gp = gpar(fontsize = 12, lineheight = 1.3))
grid.newpage(); grid.text("Central scenario by year (1 million enrollees)", x = 0.05, y = 0.94, just = "left", gp = gpar(fontsize = 16, fontface = "bold"))
t1 <- data.frame(Year = ann$year, `Incremental prescriptions` = format(round(ann$prescriptions), big.mark = ","), `Gross cost` = paste0("$", format(round(ann$gross), big.mark = ",")), `Net cost` = paste0("$", format(round(ann$net), big.mark = ",")),
                 `Net PMPM` = sprintf("$%.2f", ann$pmpm_net), `Users` = format(round(ann$treated_members), big.mark = ","), `Net cost per user per year (4.3 fills, MEPS)` = paste0("$", format(round(ann$net_cost_per_user_year), big.mark = ",")), `Net cost per member-year of continuous treatment (12 fills, assumption)` = paste0("$", format(round(ann$net_cost_per_member_year_continuous), big.mark = ",")), check.names = FALSE)
grid.draw(tableGrob(t1, rows = NULL, theme = ttheme_minimal(base_size = 11), vp = viewport(y = 0.78, height = 0.3)))
t2 <- data.frame(`Years 3-5` = res$y35, `Price or rebate` = res$price, `Five-year gross` = paste0("$", format(round(res$five_year_gross / 1e6, 1)), "M"), `Five-year net` = paste0("$", format(round(res$five_year_net / 1e6, 1)), "M"), PMPM = sprintf("$%.2f", res$pmpm_net), check.names = FALSE)
grid.draw(tableGrob(t2, rows = NULL, theme = ttheme_minimal(base_size = 10), vp = viewport(y = 0.34, height = 0.5)))
for (x in c("42_cost_by_scenario.png", "41_waterfall_pmpm.png", "40_tornado.png", "43_psa_distribution.png")) { grid.newpage(); fig(x) }
dev.off()
cat("wrote", f, "\n")
