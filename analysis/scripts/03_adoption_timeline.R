# Descriptive figure 2: adoption timeline, one row per state with any coverage. Primary states: solid segments for quarters with covered days
# (opacity = covered share of the quarter, conservative start); North Carolina's gap shows as missing segments. Sensitivity states: the start
# range (earliest to latest possible start quarter) is a light dashed-outline segment, then solid coverage after it. The preliminary SDUD
# quarter (2026 Q1) is shaded; Wegovy and Zepbound approval dates are marked.
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
lv <- rev(ord$state_code)
qend <- function(d) as.Date(d) + 91

solid <- covered |> filter(coverage_active) |>
  mutate(range_end = ifelse(analysis_group == "sensitivity", as.character(qend(quarter_to_date(start_quarter_latest)) - 1), NA),
         in_range = analysis_group == "sensitivity" & as.Date(quarter_start) <= as.Date(range_end)) |>
  filter(!in_range) |>
  mutate(state_code = factor(state_code, levels = lv), xmin = as.Date(quarter_start), xmax = qend(quarter_start))
ranges <- covered |> filter(analysis_group == "sensitivity") |> group_by(state_code) |>
  summarise(xmin = quarter_to_date(first(start_quarter_earliest)), xmax = qend(quarter_to_date(first(start_quarter_latest))), .groups = "drop") |>
  mutate(state_code = factor(state_code, levels = lv))

p <- ggplot() +
  annotate("rect", xmin = preliminary_from, xmax = as.Date("2026-04-01"), ymin = -Inf, ymax = Inf, fill = col_context, alpha = 0.5) +
  geom_rect(data = ranges, aes(xmin = xmin, xmax = xmax, ymin = as.numeric(state_code) - 0.38, ymax = as.numeric(state_code) + 0.38),
            fill = "#FFFFFF", colour = col_treated, linetype = "dashed", linewidth = 0.5) +
  geom_rect(data = ranges, aes(xmin = xmin, xmax = xmax, ymin = as.numeric(state_code) - 0.38, ymax = as.numeric(state_code) + 0.38),
            fill = col_treated, alpha = 0.18) +
  geom_rect(data = solid, aes(xmin = xmin, xmax = xmax, ymin = as.numeric(state_code) - 0.38, ymax = as.numeric(state_code) + 0.38,
                              fill = analysis_group, alpha = covered_days_share)) +
  geom_vline(xintercept = c(approval_wegovy, approval_zepbound), linetype = "dotted", colour = "#444444") +
  annotate("text", x = approval_wegovy, y = length(lv) + 0.9, label = "Wegovy approved", hjust = 1.05, size = 3) +
  annotate("text", x = approval_zepbound, y = length(lv) + 0.9, label = "Zepbound approved", hjust = 1.05, size = 3) +
  scale_y_continuous(breaks = seq_along(lv), labels = lv, expand = expansion(add = c(0.6, 1.6))) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = c(as.Date("2021-01-01"), as.Date("2026-04-01"))) +
  scale_fill_manual(values = c(primary = col_treated, sensitivity = "#E7A57A"), labels = c(primary = "Primary: covered", sensitivity = "Sensitivity: covered after the start range"), name = NULL) +
  scale_alpha_continuous(range = c(0.35, 1), limits = c(0, 1), name = "Share of quarter covered") +
  labs(title = stringr::str_wrap(sprintf("%d states had Medicaid coverage of Wegovy/Zepbound in 2026 Q1; %d states' coverage had ended or lapsed at some point", n_active_2026q1, n_withdrew), 95),
       subtitle = stringr::str_wrap("Solid segments: quarters with any covered day (opacity = share of the quarter covered). Light dashed segments: the sensitivity states' possible start range (earliest to latest quarter), coverage solid after it. Gray band = preliminary SDUD quarter (2026 Q1).", 130),
       caption = stringr::str_wrap("Source: warehouse coverage table (state Medicaid documents). Coverage end dates after 2026 Q1 (RI, MA, UT) are future-dated and not shown as ended.", 150),
       x = NULL, y = NULL) +
  theme_incretin() + theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "#E6E6E6", linewidth = 0.3))

save_fig(p, "02_adoption_timeline", width = 11, height = 6.5)
