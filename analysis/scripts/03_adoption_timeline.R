# Descriptive figure 2: adoption timeline. One row per state with any coverage; each quarter with covered days is a bar segment whose opacity is
# the covered share of the quarter (conservative start). North Carolina's gap shows as missing segments. Primary vs sensitivity by colour.
# The preliminary SDUD quarter (2026 Q1) is shaded; Wegovy and Zepbound approval dates are marked.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))

panel <- get_mart("mart_did_panel")
n_active_2026q1 <- sum(panel$coverage_active[panel$quarter_label == "2026Q1"])
n_withdrew <- panel |> arrange(state_code, quarter_start) |> group_by(state_code) |>
  summarise(w = any(covered_days_share < lag(covered_days_share, default = 0))) |> summarise(n = sum(w)) |> pull(n)
covered <- panel |> filter(analysis_group != "never_treated")
ord <- covered |> group_by(state_code, analysis_group) |>
  summarise(first_active = suppressWarnings(min(quarter_start[coverage_active])), .groups = "drop") |>
  arrange(desc(analysis_group), first_active, state_code)
covered <- covered |> filter(coverage_active) |>
  mutate(state_code = factor(state_code, levels = rev(ord$state_code)), xmin = quarter_start, xmax = as.Date(quarter_start) + 91)

p <- ggplot(covered) +
  annotate("rect", xmin = preliminary_from, xmax = as.Date("2026-04-01"), ymin = -Inf, ymax = Inf, fill = col_context, alpha = 0.5) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = as.numeric(state_code) - 0.38, ymax = as.numeric(state_code) + 0.38,
                fill = analysis_group, alpha = covered_days_share)) +
  geom_vline(xintercept = c(approval_wegovy, approval_zepbound), linetype = "dotted", colour = "#444444") +
  annotate("text", x = approval_wegovy, y = nlevels(covered$state_code) + 0.9, label = "Wegovy approved", hjust = 1.05, size = 3) +
  annotate("text", x = approval_zepbound, y = nlevels(covered$state_code) + 0.9, label = "Zepbound approved", hjust = 1.05, size = 3) +
  scale_y_continuous(breaks = seq_len(nlevels(covered$state_code)), labels = levels(covered$state_code), expand = expansion(add = c(0.6, 1.6))) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = c(as.Date("2021-01-01"), as.Date("2026-04-01"))) +
  scale_fill_manual(values = c(primary = col_treated, sensitivity = "#E7A57A"), labels = c(primary = "Primary", sensitivity = "Sensitivity (start range)"), name = NULL) +
  scale_alpha_continuous(range = c(0.35, 1), limits = c(0, 1), name = "Share of quarter covered") +
  labs(title = sprintf("%d states had Medicaid coverage of Wegovy/Zepbound in 2026 Q1; %d states' coverage had ended or lapsed at some point", n_active_2026q1, n_withdrew) |> stringr::str_wrap(95),
       subtitle = stringr::str_wrap("One bar segment per quarter with any covered day (opacity = share of the quarter covered). Grey band = preliminary SDUD quarter (2026 Q1). Quarterly resolution: starts inside a quarter appear as partial opacity.", 130),
       caption = stringr::str_wrap("Source: warehouse coverage table (state Medicaid documents). Coverage end dates after 2026 Q1 (RI, MA, UT) are future-dated and not shown as ended.", 150),
       x = NULL, y = NULL) +
  theme_incretin() + theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#E6E6E6", linewidth = 0.3))

save_fig(p, "02_adoption_timeline", width = 11, height = 6.5)
