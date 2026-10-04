# Item 4 of the plan reconciliation: (a) one timeline of FDA approvals and label indications (label_events seed), primary-state Medicaid coverage starts and ends, the $245 announcement and
# the Medicare GLP-1 Bridge; (b) the ClinicalTrials.gov pipeline summary from mart_pipeline_trials (registered studies of the in-scope ingredients).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(patchwork); library(ggrepel); library(gt) })
cov <- readr::read_csv(here::here("..", "data", "reference", "medicaid_obesity_coverage.csv"), show_col_types = FALSE, progress = FALSE)
ev <- readr::read_csv(here::here("..", "dbt", "seeds", "label_events.csv"), show_col_types = FALSE, progress = FALSE)

# ---- timeline -------------------------------------------------------------------------------------------------------------------------------------------------
xr <- as.Date(c("2021-01-01", "2027-12-31"))
ev <- ev |> filter(event_date >= xr[1]) |> mutate(what = recode(event, original_approval = "approved", indication_cardiovascular = "cardiovascular indication", indication_obstructive_sleep_apnea = "sleep apnea indication"),
                                                  lab = paste0(brand, ": ", what), lane = c("Wegovy" = 1, "Wegovy (tablets)" = 2, "Zepbound" = 3, "Foundayo" = 3)[brand])
p1 <- ggplot(ev, aes(event_date, lane)) + geom_hline(yintercept = c(1, 2, 3), colour = col_context, linewidth = 0.3) + geom_point(colour = col_treated, size = 2.6) +
  geom_text_repel(aes(label = lab), size = 2.8, colour = "#222222", direction = "y", nudge_y = 0.28, segment.size = 0.2, min.segment.length = 0.1, box.padding = 0.25, max.overlaps = Inf, seed = 1) +
  scale_x_date(limits = xr, date_breaks = "1 year", date_labels = "%Y") + scale_y_continuous(limits = c(0.4, 4.0), breaks = NULL) + labs(subtitle = "FDA approvals and label indications (Drugs@FDA)", x = NULL, y = NULL) + theme_incretin(base_size = 10) + theme(panel.grid.major = element_blank(), plot.subtitle = element_text(face = "bold"))
prim <- cov |> filter(analysis_group %in% "primary" | (state == "North Carolina")) |>
  mutate(cs = as.Date(ifelse(!is.na(coverage_start) & nchar(coverage_start) == 7, paste0(coverage_start, "-01"), coverage_start)), start = dplyr::coalesce(cs, as.Date(start_earliest)), end = as.Date(coverage_end), code = state.abb[match(state, state.name)])
spells <- prim |> select(state, code, start, end)
months <- seq(xr[1], as.Date("2026-10-01"), by = "month")
cnt <- tibble::tibble(month = months, n = vapply(months, function(m) length(unique(spells$state[spells$start <= m & (is.na(spells$end) | spells$end >= m)])), integer(1)))
ends <- spells |> filter(!is.na(end)) |> mutate(when = end + 1) |> group_by(when) |> summarise(lab = paste0(paste(code, collapse = ", "), " end"), .groups = "drop")
starts <- spells |> group_by(start) |> summarise(lab = paste0(paste(code, collapse = ", "), " start"), .groups = "drop") |> filter(start >= xr[1])
ann <- bind_rows(starts |> transmute(when = start, lab, kind = "start"), ends |> transmute(when, lab, kind = "end")) |> left_join(cnt |> transmute(when = month, n), by = "when") |> mutate(n = ifelse(is.na(n), approx(as.numeric(cnt$month), cnt$n, as.numeric(when))$y, n))
p2 <- ggplot(cnt, aes(month, n)) + geom_step(colour = col_treated, linewidth = 1) +
  geom_text_repel(data = ann, aes(when, n, label = lab, colour = kind), size = 2.7, direction = "y", nudge_y = 0.6, segment.size = 0.2, min.segment.length = 0.1, box.padding = 0.15, max.overlaps = Inf, seed = 2, show.legend = FALSE) +
  scale_colour_manual(values = c(start = "#222222", end = col_comparison)) + scale_x_date(limits = xr, date_breaks = "1 year", date_labels = "%Y") + scale_y_continuous(breaks = scales::pretty_breaks(4)) +
  labs(subtitle = "Primary-analysis states with active Medicaid coverage of Wegovy or Zepbound (count, with starts and ends)", x = NULL, y = "States") + theme_incretin(base_size = 10) + theme(plot.subtitle = element_text(face = "bold"))
pol <- tibble::tibble(label = c("Announced $245 price (White House fact sheet, 2025-11-06)", "Medicare GLP-1 Bridge (2026-07-01 to 2027-12-31)"), start = as.Date(c("2025-11-06", "2026-07-01")), end = as.Date(c("2025-11-06", "2027-12-31")), y = c(2, 1))
p3 <- ggplot(pol) + geom_segment(aes(x = start, xend = end, y = y, yend = y), colour = col_treated, linewidth = 4, lineend = "butt") + geom_point(aes(start, y), colour = col_treated, size = 3) +
  geom_text(aes(x = start, y = y, label = label), hjust = 1.05, size = 2.9, colour = "#222222") + scale_x_date(limits = xr, date_breaks = "1 year", date_labels = "%Y") + scale_y_continuous(limits = c(0.4, 2.6), breaks = NULL) +
  labs(subtitle = "Federal price and access events", x = NULL, y = NULL) + theme_incretin(base_size = 10) + theme(panel.grid.major = element_blank(), plot.subtitle = element_text(face = "bold"))
nend <- sum(!is.na(spells$end)); nstart <- dplyr::n_distinct(spells$state[!is.na(spells$start) & spells$start >= xr[1]])
ttl <- sprintf("Label expansions, state coverage starts and endings, the $245 announcement and the Medicare Bridge cluster in 2024 to 2026: %d primary states started coverage and %d coverage spells have ended", nstart, nend)
cap <- "Sources: FDA Drugs@FDA labels (dbt seed label_events); state Medicaid documents (data/reference/medicaid_obesity_coverage.csv; primary-analysis states, North Carolina's second spell included); White House fact sheet, November 2025; CMS Medicare GLP-1 Bridge pages. Coverage counts use the first day of the start month and the day after the end date; Saxenda (approved 2014) is outside the window."
pt <- (p1 / p2 / p3) + plot_layout(heights = c(1.2, 1.6, 0.9)) + plot_annotation(title = ttl, caption = stringr::str_wrap(cap, 170), theme = theme_incretin(base_size = 10))
save_fig(pt, "51_timeline", width = 12, height = 8.4, alt = "Three stacked timelines from 2021 to 2027. Top: FDA approvals and indications: Wegovy approved in June 2021 with a cardiovascular indication in March 2024, Zepbound approved in November 2023 with a sleep apnea indication in December 2024, Wegovy tablets approved in December 2025 and Foundayo approved in April 2026. Middle: the number of primary-analysis states with active Medicaid coverage rises from one to about ten in 2025 and falls from late 2025 as coverage ends in several states. Bottom: the announced $245 price in November 2025 and the Medicare GLP-1 Bridge from July 2026 to December 2027.")
save_table(cnt, "moduleA_coverage_count_by_month"); save_table(ev |> select(brand, event, event_date, application_number), "moduleA_label_events_window")

# ---- pipeline summary (ClinicalTrials.gov studies of the in-scope ingredients) ---------------------------------------------------------------------------------
pl <- get_mart("mart_pipeline_trials", cols = c("nct_id", "phase", "status", "start_year", "matched_ingredients", "is_phase3", "condition_mentions_obesity", "last_update"))   # title columns hold bytes the WIN1252 database cannot convert
oral_ids <- get_mart("mart_pipeline_trials", cols = "nct_id", where = "interventions ~* '(^|[^a-z])(oral|tablet|rybelsus)'")$nct_id   # matched inside the database (the intervention text holds bytes the client cannot convert)
ongoing_status <- c("RECRUITING", "NOT_YET_RECRUITING", "ACTIVE_NOT_RECRUITING", "ENROLLING_BY_INVITATION")
grp <- function(ph) ifelse(is.na(ph) | ph %in% c("", "NA"), "Not applicable / not stated", ifelse(grepl("PHASE3|PHASE2;PHASE3", ph), "Phase 3 (including Phase 2/3)", ifelse(grepl("PHASE2|PHASE1;PHASE2", ph), "Phase 2 (including Phase 1/2)", ifelse(grepl("PHASE4", ph), "Phase 4", "Phase 1 (including early Phase 1)"))))
pl <- pl |> mutate(phase_group = grp(phase), ongoing = status %in% ongoing_status, oral = grepl("orforglipron", matched_ingredients) | nct_id %in% oral_ids)
by_phase <- pl |> filter(condition_mentions_obesity) |> group_by(phase_group) |> summarise(studies = n(), ongoing = sum(ongoing), .groups = "drop") |> arrange(match(phase_group, c("Phase 1 (including early Phase 1)", "Phase 2 (including Phase 1/2)", "Phase 3 (including Phase 2/3)", "Phase 4", "Not applicable / not stated")))
by_ing <- pl |> filter(condition_mentions_obesity) |> mutate(ingredient = ifelse(grepl(";", matched_ingredients), "several ingredients", matched_ingredients)) |> group_by(ingredient) |> summarise(studies = n(), phase3 = sum(phase_group == "Phase 3 (including Phase 2/3)"), ongoing_phase3 = sum(phase_group == "Phase 3 (including Phase 2/3)" & ongoing), oral_programme_studies = sum(oral), .groups = "drop") |> arrange(desc(studies))
oral_ob <- pl |> filter(condition_mentions_obesity, oral)
summ <- tibble::tibble(item = c("registered_studies_in_scope", "obesity_studies", "obesity_studies_ongoing", "obesity_phase3_ongoing", "oral_obesity_studies", "oral_obesity_phase3_ongoing", "orforglipron_obesity_studies", "orforglipron_phase3_obesity_studies"),
                       value = c(nrow(pl), sum(pl$condition_mentions_obesity), sum(pl$condition_mentions_obesity & pl$ongoing), sum(pl$condition_mentions_obesity & pl$ongoing & pl$phase_group == "Phase 3 (including Phase 2/3)"), nrow(oral_ob), sum(oral_ob$ongoing & oral_ob$phase_group == "Phase 3 (including Phase 2/3)"),
                                 sum(pl$condition_mentions_obesity & grepl("orforglipron", pl$matched_ingredients)), sum(pl$condition_mentions_obesity & grepl("orforglipron", pl$matched_ingredients) & pl$phase_group == "Phase 3 (including Phase 2/3)")))
save_table(by_phase, "moduleA_pipeline_by_phase"); save_table(by_ing, "moduleA_pipeline_by_ingredient"); save_table(summ, "moduleA_pipeline_summary")
cat("registry last update range:", as.character(min(pl$last_update, na.rm = TRUE)), as.character(max(pl$last_update, na.rm = TRUE)), "\n")
print(as.data.frame(by_phase)); print(as.data.frame(head(by_ing, 8))); print(as.data.frame(summ))
