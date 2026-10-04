# Descriptive figure 3: raw trends. obesity_wz prescriptions per 1,000 Medicaid enrollees by quarter (observed counts, suppressed cells excluded),
# small multiples by adoption cohort (accent: individual states thin, cohort mean thick) against the never-treated mean (grey).
# Wegovy and Zepbound approvals are dotted lines; the cohort's first treated quarter is the solid vertical line.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)

panel <- get_mart("mart_did_panel") |> mutate(rate = rate_obesity_wz_per_1000_medicaid, qd = as.Date(quarter_start))
never <- panel |> filter(analysis_group == "never_treated") |> group_by(qd) |> summarise(never_mean = mean(rate, na.rm = TRUE), n_never = n(), .groups = "drop")
prim <- panel |> filter(analysis_group == "primary") |> mutate(cohort = first_treated_quarter)
cohorts <- prim |> distinct(cohort) |> arrange(cohort) |> pull(cohort)
cohort_states <- prim |> distinct(cohort, state_code) |> group_by(cohort) |> summarise(states = paste(sort(state_code), collapse = ", "), .groups = "drop")
lab <- setNames(paste0(cohort_states$cohort, ": ", cohort_states$states), cohort_states$cohort)
prim <- prim |> mutate(cohort_lab = factor(lab[cohort], levels = lab[cohorts]))
cmean <- prim |> group_by(cohort_lab, cohort, qd) |> summarise(cohort_mean = mean(rate, na.rm = TRUE), .groups = "drop")
nv <- tidyr::crossing(cohort_lab = factor(lab[cohorts], levels = lab[cohorts]), never)
starts <- tibble(cohort = cohorts, cohort_lab = factor(lab[cohorts], levels = lab[cohorts]), start = quarter_to_date(cohorts))
window <- c(as.Date("2021-01-01"), as.Date("2026-03-31"))
t_2025q3 <- prim |> filter(qd == as.Date("2025-07-01")) |> summarise(m = mean(rate, na.rm = TRUE)) |> pull(m)
n_2025q3 <- never |> filter(qd == as.Date("2025-07-01")) |> pull(never_mean)

p <- ggplot() +
  annotate("rect", xmin = preliminary_from, xmax = as.Date("2026-03-31"), ymin = -Inf, ymax = Inf, fill = col_context, alpha = 0.4) +
  geom_line(data = nv, aes(qd, never_mean), colour = col_comparison, linewidth = 1) +
  geom_line(data = prim, aes(qd, rate, group = state_code), colour = col_treated, alpha = 0.35, linewidth = 0.4) +
  geom_line(data = cmean, aes(qd, cohort_mean), colour = col_treated, linewidth = 1.1) +
  geom_vline(data = starts, aes(xintercept = start), colour = col_treated, linewidth = 0.6) +
  geom_vline(xintercept = c(approval_wegovy, approval_zepbound), linetype = "dotted", colour = "#444444") +
  facet_wrap(~cohort_lab, ncol = 3, labeller = label_wrap_gen(40)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = window) +
  labs(title = stringr::str_wrap(sprintf("Observed Wegovy/Zepbound prescriptions per 1,000 Medicaid enrollees in 2025 Q3: %.1f in the 10 covering states (mean), %.1f in the %d never-treated states (mean)", t_2025q3, n_2025q3, max(never$n_never)), 90),
       subtitle = stringr::str_wrap("Orange = covering states (thin: each state; thick: cohort mean); grey = mean of never-treated states; solid vertical line = cohort's first treated quarter; dotted = Wegovy approval (2021-06-04) and Zepbound approval (2023-11-08); grey band = preliminary 2026 Q1. Observed counts only (suppressed cells excluded); outcome is mechanically zero before 2021 Q2.", 150),
       x = NULL, y = "Prescriptions per 1,000 Medicaid enrollees (obesity_wz, FFSU + MCOU)", caption = caption_sdud) +
  theme_incretin(base_size = 10)

save_fig(p, "03_raw_trends_by_cohort", width = 12, height = 9)

# Plain-numbers check for the title: share of never-treated and treated rates in the last full quarter vs 2021Q2
chk <- bind_rows(never |> filter(qd %in% as.Date(c("2021-04-01", "2025-07-01"))) |> transmute(group = "never_treated_mean", qd, rate = never_mean),
                 prim |> filter(qd %in% as.Date(c("2021-04-01", "2025-07-01"))) |> group_by(qd) |> summarise(group = "primary_mean", rate = mean(rate, na.rm = TRUE), .groups = "drop"))
print(chk)
save_table(cmean |> select(cohort, qd, cohort_mean) |> left_join(never, by = "qd") |> rename(quarter_start = qd), "raw_trends_cohort_means")
