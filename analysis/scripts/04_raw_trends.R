# Descriptive figure 3: raw trends. obesity_wz prescriptions per 1,000 Medicaid enrollees by quarter (observed counts, suppressed cells excluded),
# small multiples by adoption cohort (orange: individual states thin, cohort mean thick) against the never-treated mean (grey).
# Solid vertical line = the cohort's first treated quarter; dashed = coverage end (CA, PA, SC); shaded = North Carolina's coverage gap;
# dotted = approvals (Wegovy 2021-06-04, Zepbound 2023-11-08) and label events (Wegovy cardiovascular indication 2024-03-08, Zepbound sleep apnea 2024-12-20).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)

panel <- get_mart("mart_did_panel") |> mutate(rate = rate_obesity_wz_per_1000_medicaid, qd = as.Date(quarter_start))
never <- panel |> filter(analysis_group == "never_treated") |> group_by(qd) |> summarise(never_mean = mean(rate, na.rm = TRUE), n_never = n(), .groups = "drop")
prim <- panel |> filter(analysis_group == "primary") |> mutate(cohort = first_treated_quarter)
cohorts <- prim |> distinct(cohort) |> arrange(cohort) |> pull(cohort)
cohort_states <- prim |> distinct(cohort, state_code) |> group_by(cohort) |> summarise(states = paste(sort(state_code), collapse = ", "), .groups = "drop")
lab <- setNames(paste0(cohort_states$cohort, ": ", cohort_states$states), cohort_states$cohort)
lvl <- lab[cohorts]
prim <- prim |> mutate(cohort_lab = factor(lab[cohort], levels = lvl))
cmean <- prim |> group_by(cohort_lab, cohort, qd) |> summarise(cohort_mean = mean(rate, na.rm = TRUE), .groups = "drop")
nv <- tidyr::crossing(cohort_lab = factor(lvl, levels = lvl), never)
starts <- tibble(cohort = cohorts, cohort_lab = factor(lvl, levels = lvl), start = quarter_to_date(cohorts))

# Coverage end: first quarter in which a state's covered share falls (CA, PA, SC at 2026 Q1; NC's drop is a gap, shaded instead).
drops <- prim |> arrange(state_code, qd) |> group_by(state_code, cohort_lab) |>
  mutate(fell = covered_days_share < lag(covered_days_share, default = 0)) |> filter(fell) |> ungroup()
ends <- drops |> filter(state_code != "NC") |> distinct(cohort_lab, qd) |> rename(end_line = qd)
# North Carolina's gap (coverage table): spell 1 ended 2025-09-30, spell 2 began 2025-12-12 (days 2025-10-01 to 2025-12-11 uncovered)
nc_gap <- tibble(cohort_lab = factor(lab[prim$cohort[prim$state_code == "NC"][1]], levels = lvl), xmin = as.Date("2025-10-01"), xmax = as.Date("2025-12-11"))
window <- c(as.Date("2021-01-01"), as.Date("2026-03-31"))
t_2025q3 <- prim |> filter(qd == as.Date("2025-07-01")) |> summarise(m = mean(rate, na.rm = TRUE)) |> pull(m)
n_2025q3 <- never |> filter(qd == as.Date("2025-07-01")) |> pull(never_mean)

p <- ggplot() +
  annotate("rect", xmin = preliminary_from, xmax = as.Date("2026-03-31"), ymin = -Inf, ymax = Inf, fill = col_context, alpha = 0.4) +
  geom_rect(data = nc_gap, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = col_treated, alpha = 0.25) +
  geom_line(data = nv, aes(qd, never_mean), colour = col_comparison, linewidth = 1) +
  geom_line(data = prim, aes(qd, rate, group = state_code), colour = col_treated, alpha = 0.35, linewidth = 0.4) +
  geom_line(data = cmean, aes(qd, cohort_mean), colour = col_treated, linewidth = 1.1) +
  geom_vline(data = starts, aes(xintercept = start), colour = col_treated, linewidth = 0.6) +
  geom_vline(data = ends, aes(xintercept = end_line), colour = col_treated, linetype = "dashed", linewidth = 0.7) +
  geom_vline(xintercept = c(approval_wegovy, approval_zepbound, label_wegovy_cv, label_zepbound_osa), linetype = "dotted", colour = "#444444") +
  facet_wrap(~cohort_lab, ncol = 3, labeller = label_wrap_gen(40)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = window) +
  labs(title = stringr::str_wrap(sprintf("Observed Wegovy/Zepbound prescriptions per 1,000 Medicaid enrollees in 2025 Q3: %s in the 10 covering states (mean), %s in the %d never-treated states (mean)", fmt1(t_2025q3), fmt1(n_2025q3), max(never$n_never)), 90),
       subtitle = stringr::str_wrap("Orange = covering states (thin: each state; thick: cohort mean); gray = mean of never-treated states. Solid vertical line = cohort's first treated quarter; dashed = coverage end; shaded = North Carolina's coverage gap. Dotted lines, left to right: Wegovy approval (2021-06-04), Zepbound approval (2023-11-08), Wegovy cardiovascular indication (2024-03-08), Zepbound sleep apnea indication (2024-12-20). Gray band = preliminary 2026 Q1. Observed counts only (suppressed cells excluded); the outcome is mechanically zero before 2021 Q2.", 150),
       x = NULL, y = "Prescriptions per 1,000 Medicaid enrollees (obesity_wz, FFSU + MCOU)", caption = caption_sdud) +
  theme_incretin(base_size = 10)

save_fig(p, "03_raw_trends_by_cohort", width = 12, height = 9.5)
save_table(cmean |> select(cohort, qd, cohort_mean) |> left_join(never, by = "qd") |> rename(quarter_start = qd), "raw_trends_cohort_means")
cat(sprintf("2025Q3 mean: covering %s (%.3f), never-treated %s (%.3f)\n", fmt1(t_2025q3), t_2025q3, fmt1(n_2025q3), n_2025q3))
