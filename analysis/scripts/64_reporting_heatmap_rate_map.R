# Item 5 of the plan reconciliation: (a) a heatmap of SDUD reporting completeness (state x quarter, fee-for-service FFSU and managed-care MCOU) and of the suppressed share of Wegovy and Zepbound
# rows; (b) a tile-grid map of Wegovy and Zepbound prescriptions per 1,000 Medicaid enrollees in 2025 Q3. Aggregates by state and quarter only (counts under 11 are suppressed by CMS and never shown).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(patchwork); library(geofacet) })
panel <- get_mart("mart_did_panel", cols = c("state_code", "quarter_label", "quarter_start", "is_preliminary", "sdud_reported_ffsu", "sdud_reported_mcou", "n_rows_obesity_wz", "n_suppressed_rows_obesity_wz", "rx_obesity_wz_observed",
                                            "enrollment_medicaid_avg", "rate_obesity_wz_per_1000_medicaid", "coverage_active", "analysis_group"))
panel <- panel |> filter(state_code != "XX", quarter_start >= as.Date("2018-01-01"))
qs <- sort(unique(panel$quarter_label)); lab_q <- ifelse(substr(qs, 6, 6) == "1", substr(qs, 1, 4), "")
# (a) reporting completeness
rep <- panel |> mutate(status = case_when(sdud_reported_ffsu & sdud_reported_mcou ~ "Both FFSU and MCOU rows", sdud_reported_ffsu ~ "FFSU rows only", sdud_reported_mcou ~ "MCOU rows only", TRUE ~ "No SDUD rows"),
                       status = factor(status, levels = c("Both FFSU and MCOU rows", "FFSU rows only", "MCOU rows only", "No SDUD rows")))
ord <- rep |> group_by(state_code) |> summarise(score = sum(status == "Both FFSU and MCOU rows")) |> arrange(score, desc(state_code)) |> pull(state_code)
rep$state_code <- factor(rep$state_code, levels = ord); rep$quarter_label <- factor(rep$quarter_label, levels = qs)
tab_rep <- rep |> count(status) |> mutate(share = n / sum(n)); save_table(tab_rep, "moduleA_sdud_reporting_status_counts")
pa <- ggplot(rep, aes(quarter_label, state_code, fill = status)) + geom_tile(colour = "white", linewidth = 0.1) + scale_fill_manual(values = c("Both FFSU and MCOU rows" = "#BFBFBF", "FFSU rows only" = "#F2B999", "MCOU rows only" = "#9A9A9A", "No SDUD rows" = col_treated), name = NULL) +
  scale_x_discrete(breaks = qs[lab_q != ""], labels = lab_q[lab_q != ""]) + labs(subtitle = "Reporting: does the state-quarter have any SDUD rows (all drugs), by fee-for-service (FFSU) and managed-care (MCOU) utilization type?", x = NULL, y = NULL) +
  theme_incretin(base_size = 8) + theme(panel.grid = element_blank(), legend.position = "top", axis.text.y = element_text(size = 5.5), plot.subtitle = element_text(face = "bold"))
# (b) suppressed share of Wegovy and Zepbound rows
sup <- panel |> filter(n_rows_obesity_wz > 0) |> mutate(supp = n_suppressed_rows_obesity_wz / n_rows_obesity_wz, state_code = factor(state_code, levels = ord), quarter_label = factor(quarter_label, levels = qs))
pb <- ggplot(sup, aes(quarter_label, state_code, fill = supp)) + geom_tile(colour = "white", linewidth = 0.1) + scale_fill_gradient(low = "#FBE3D1", high = "#8E3A00", labels = scales::label_percent(), name = "Suppressed share of rows") +
  scale_x_discrete(breaks = qs[lab_q != ""], labels = lab_q[lab_q != ""], drop = FALSE) + scale_y_discrete(drop = FALSE) + labs(subtitle = "Suppression: share of Wegovy and Zepbound SDUD rows hidden because the count is under 11 (blank = no rows)", x = NULL, y = NULL) +
  theme_incretin(base_size = 8) + theme(panel.grid = element_blank(), legend.position = "top", axis.text.y = element_text(size = 5.5), plot.subtitle = element_text(face = "bold"))
nonrep <- sum(tab_rep$share[tab_rep$status == "No SDUD rows"]); both <- sum(tab_rep$share[tab_rep$status == "Both FFSU and MCOU rows"]); sup_all <- sum(panel$n_suppressed_rows_obesity_wz, na.rm = TRUE) / sum(panel$n_rows_obesity_wz, na.rm = TRUE)
save_table(tibble::tibble(item = c("state_quarters", "state_quarters_no_rows", "share_no_rows_pct", "wz_rows", "wz_rows_suppressed", "wz_suppressed_share_pct"), value = round(c(nrow(panel), sum(rep$status == "No SDUD rows"), 100 * nonrep, sum(panel$n_rows_obesity_wz, na.rm = TRUE), sum(panel$n_suppressed_rows_obesity_wz, na.rm = TRUE), 100 * sup_all), 1)), "moduleA_sdud_reporting_summary")
cap <- "Source: CMS State Drug Utilization Data via the warehouse panel (mart_did_panel flags sdud_reported_ffsu and sdud_reported_mcou; Wegovy and Zepbound row counts). States are ordered by the number of quarters with both utilization types. Counts under 11 are suppressed by CMS; no suppressed value is shown."
ph <- (pa / pb) + plot_annotation(title = sprintf("%s%% of state-quarters report both fee-for-service and managed-care rows, and %s%% of Wegovy and Zepbound SDUD rows are suppressed (counts under 11)", fmt1(100 * both), fmt1(100 * sup_all)), caption = stringr::str_wrap(cap, 170), theme = theme_incretin(base_size = 10))
save_fig(ph, "52_sdud_reporting_suppression", width = 12, height = 12, alt = sprintf("Two heatmaps of state by quarter, 2018 to 2026. Top: whether a state-quarter has SDUD rows for fee-for-service and managed-care utilization; most tiles show both, and the others have fee-for-service rows only (no managed-care rows). Bottom: the suppressed share of Wegovy and Zepbound rows, which varies by state and quarter; overall %s percent of rows are suppressed.", fmt1(100 * sup_all)))

# (b) tile-grid map, 2025 Q3
q <- panel |> filter(quarter_label == "2025Q3") |> mutate(rate = rate_obesity_wz_per_1000_medicaid, cov = coverage_active %in% TRUE)
grid <- tibble::as_tibble(as.data.frame(geofacet::us_state_grid2)) |> filter(code %in% q$state_code) |> left_join(q, by = c("code" = "state_code"))
wrate <- function(x) sum(x$rx_obesity_wz_observed, na.rm = TRUE) / sum(x$enrollment_medicaid_avg[!is.na(x$rx_obesity_wz_observed)], na.rm = TRUE) * 1000
r_cov <- wrate(q[q$cov, ]); r_non <- wrate(q[!q$cov, ])
save_table(tibble::tibble(group = c("states with active coverage", "states without active coverage"), states = c(sum(q$cov), sum(!q$cov)), rx_per_1000_enrollees = round(c(r_cov, r_non), 2)), "moduleA_rate_by_coverage_2025Q3")
save_table(q |> transmute(state_code, rate_per_1000 = round(rate, 2), coverage_active = cov), "moduleA_rate_by_state_2025Q3")
pm <- ggplot(grid, aes(xmin = col, xmax = col + 1, ymin = -row - 1, ymax = -row, fill = rate)) + geom_rect(aes(colour = cov, linewidth = cov)) +
  geom_text(aes(x = col + 0.5, y = -row - 0.35, label = code), size = 3.3, fontface = "bold", colour = "#222222") + geom_text(aes(x = col + 0.5, y = -row - 0.7, label = ifelse(is.na(rate), "n/a", sprintf("%.1f", rate))), size = 2.9, colour = "#222222") +
  scale_fill_gradient(low = "#FBE3D1", high = "#8E3A00", na.value = "#E6E6E6", name = "Prescriptions per 1,000 enrollees") + scale_colour_manual(values = c(`TRUE` = "#222222", `FALSE` = "white"), guide = "none") + scale_linewidth_manual(values = c(`TRUE` = 0.9, `FALSE` = 0.2), guide = "none") +
  coord_equal() + theme_void(base_size = 10) + theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 13), plot.title.position = "plot", plot.caption = element_text(size = 7, colour = "#666666", hjust = 0), plot.caption.position = "plot") +
  labs(title = sprintf("In 2025 Q3 states with active coverage filled %s Wegovy and Zepbound prescriptions per 1,000 Medicaid enrollees against %s elsewhere", fmt1(r_cov), fmt1(r_non)),
       subtitle = "Observed (unsuppressed) prescriptions per 1,000 enrollees; dark outline = active Medicaid coverage; gray = no observed rows.", caption = stringr::str_wrap("Source: CMS State Drug Utilization Data and Medicaid enrollment. Observed counts only: cells under 11 are suppressed, so rates are lower bounds. 2025 Q3 is the last full quarter before the preliminary 2026 Q1 data.", 130))
save_fig(pm, "53_rate_map_2025Q3", width = 11, height = 7.5, alt = sprintf("Tile-grid map of the United States showing Wegovy and Zepbound prescriptions per 1,000 Medicaid enrollees in 2025 Q3 for each state, darker orange for higher rates. States with active Medicaid coverage have a dark outline and average %s per 1,000, against %s in other states.", fmt1(r_cov), fmt1(r_non)))
print(as.data.frame(tab_rep)); cat(r_cov, r_non, sup_all, "\n")
