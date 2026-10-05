# Descriptive figure 5: how much of obesity_wz prescribing is hidden in suppressed SDUD cells. Each suppressed cell holds 0 to 10 prescriptions,
# so the share of obesity_wz prescriptions (50 states + DC, FFSU + MCOU) sitting in suppressed cells lies between 0 and
# (upper bound - observed) / upper bound. Only aggregated state-quarter sums are used. The y-axis is capped at 10%; clipped early points are labelled.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))

panel <- get_mart("mart_did_panel") |> mutate(qd = as.Date(quarter_start))
q <- panel |> filter(qd >= as.Date("2021-04-01")) |>
  group_by(qd, quarter_label) |>
  summarise(observed = sum(rx_obesity_wz_observed), upper = sum(rx_obesity_wz_upper_bound), n_suppressed_cells = sum(n_suppressed_rows_obesity_wz), .groups = "drop") |>
  mutate(max_hidden_share = (upper - observed) / upper)

cap <- 0.10
clipped <- q |> filter(max_hidden_share > cap)
mx <- q |> filter(qd >= as.Date("2023-01-01")) |> slice_max(max_hidden_share, n = 1)
p <- ggplot(q, aes(qd, pmin(max_hidden_share, !!cap))) +
  geom_ribbon(aes(ymin = 0, ymax = pmin(max_hidden_share, !!cap)), fill = col_treated, alpha = 0.35) +
  geom_line(colour = col_treated, linewidth = 1) +
  geom_point(data = clipped, colour = col_treated, size = 2) +
  ggrepel::geom_text_repel(data = clipped, aes(label = paste0(fmt1(100 * max_hidden_share), "% (", quarter_label, ")")), direction = "y", hjust = 0, nudge_x = 45, nudge_y = -0.011, segment.size = 0.2, box.padding = 0.4, min.segment.length = 0, seed = 6, size = 3.6, max.overlaps = Inf) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, cap), expand = expansion(mult = c(0, 0.02))) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(clip = "off") +
  geom_vline(xintercept = c(approval_zepbound), linetype = "dotted", colour = "#444444") +
  annotate("text", x = approval_zepbound, y = cap, label = "Zepbound approved", hjust = 1.05, vjust = 1.5, size = 3) +
  labs(title = stringr::str_wrap(sprintf("From 2023 Q1 at most %s%% of Wegovy/Zepbound prescriptions sit in suppressed cells in any quarter (peak %s); by 2025 Q3 at most %s%%",
                                         fmt1(100 * mx$max_hidden_share), mx$quarter_label, fmt1(100 * q$max_hidden_share[q$quarter_label == "2025Q3"])), 90),
       subtitle = stringr::str_wrap("Upper bound on the hidden share: each suppressed state-NDC cell holds at most 10 prescriptions; the lower bound is 0. 50 states and DC, FFSU + MCOU, 2021 Q2 to 2026 Q1. Y-axis capped at 10%; the three earlier quarters are above the cap and labeled. Before 2023 Q1 volumes are small (under 10,000 prescriptions a quarter), so the bound is wide.", 100),
       x = NULL, y = "Maximum share of obesity_wz prescriptions hidden", caption = caption_sdud) +
  theme_incretin()
save_fig(p, "04_suppression_share", width = 9, height = 5.5)
save_table(q |> transmute(quarter = quarter_label, observed_rx = observed, upper_bound_rx = upper, n_suppressed_cells, max_hidden_share = round(max_hidden_share, 4)), "suppression_share_by_quarter")
print(q |> select(quarter_label, observed, upper, n_suppressed_cells, max_hidden_share), n = 30)
