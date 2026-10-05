# Withdrawal figure (DESCRIPTIVE ONLY, PRELIMINARY: no model, no p-values). 2026 Q1 is preliminary SDUD data and only one post-withdrawal quarter exists
# for most states.
# Panel A: for CA, PA, SC, NC (primary) and NH (sensitivity), obesity_wz prescriptions per 1,000 Medicaid enrollees for the four quarters before
#   coverage ended (or lapsed) and all quarters after, through 2026 Q1, against two references over the same calendar quarters: the states
#   continuously covered through 2026 Q1 (KS, MI, MS, RI, MA, TN) and the never-treated states.
# Panel B: each state's 2025 Q4 -> 2026 Q1 change in obesity_wz prescriptions beside its change in ALL-drug SDUD prescriptions for the same quarters,
#   so incomplete preliminary data is visible.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(tidyr)
library(patchwork)

panel <- get_mart("mart_did_panel") |> mutate(qd = as.Date(quarter_start), rate = rate_obesity_wz_per_1000_medicaid)
qlist <- panel |> distinct(quarter_label, qd) |> arrange(qd) |> pull(quarter_label)
wd_states <- c("CA", "PA", "SC", "NC", "NH")
cont_states <- c("KS", "MI", "MS", "RI", "MA", "TN")
stopifnot(all(panel$coverage_active[panel$state_code %in% cont_states & panel$quarter_label == "2026Q1"]))
never_states <- unique(panel$state_code[panel$analysis_group == "never_treated"])

t0 <- panel |> filter(state_code %in% wd_states) |> arrange(state_code, qd) |> group_by(state_code) |>
  mutate(fell = covered_days_share < lag(covered_days_share, default = 0)) |> filter(fell) |> summarise(t0 = first(quarter_label), .groups = "drop")
ref <- bind_rows(
  panel |> filter(state_code %in% cont_states) |> group_by(quarter_label, qd) |> summarise(rate = mean(rate), .groups = "drop") |> mutate(series = "Continuously covered (KS, MI, MS, RI, MA, TN), mean"),
  panel |> filter(state_code %in% never_states) |> group_by(quarter_label, qd) |> summarise(rate = mean(rate), .groups = "drop") |> mutate(series = "Never-treated states, mean"))
dat <- bind_rows(lapply(seq_len(nrow(t0)), function(i) {
  s <- t0$state_code[i]; k <- match(t0$t0[i], qlist); keep <- qlist[(k - 4):length(qlist)]
  bind_rows(panel |> filter(state_code == s, quarter_label %in% keep) |> transmute(state = s, quarter_label, qd, rate, series = paste0(s, " (", panel$analysis_group[panel$state_code == s][1], ")")),
            ref |> filter(quarter_label %in% keep) |> mutate(state = s)) |>
    mutate(rel = match(quarter_label, qlist) - k)
})) |> mutate(state = factor(state, levels = wd_states),
              series2 = case_when(grepl("^Cont", series) ~ "Continuously covered", grepl("^Never", series) ~ "Never treated", TRUE ~ "Withdrawing / lapsed state"))
facet_lab <- setNames(paste0(t0$state_code, " (from ", t0$t0, ")"), t0$state_code)

pa <- ggplot(dat, aes(rel, rate, colour = series2, linewidth = series2, group = series)) +
  geom_vline(xintercept = -0.5, linetype = "dashed", colour = col_treated) +
  geom_line() + geom_point(size = 1.4) +
  facet_wrap(~state, nrow = 1, labeller = labeller(state = facet_lab)) +
  scale_colour_manual(values = c("Withdrawing / lapsed state" = col_treated, "Continuously covered" = "#4D4D4D", "Never treated" = col_comparison), name = NULL) +
  scale_linewidth_manual(values = c("Withdrawing / lapsed state" = 1.2, "Continuously covered" = 0.8, "Never treated" = 0.8), guide = "none") +
  scale_x_continuous(breaks = -4:1, labels = function(x) ifelse(x < 0, paste0(x), ifelse(x == 0, "end", paste0("+", x)))) +
  labs(x = "Quarters relative to the first quarter after coverage ended or lapsed (dashed line)", y = "Prescriptions per 1,000 enrollees") +
  theme_incretin(base_size = 10)

chg <- function(df, v) { a <- df[df$quarter_label == "2025Q4", ]; b <- df[df$quarter_label == "2026Q1", ]; sum(b[[v]]) / sum(a[[v]]) - 1 }
state_chg <- bind_rows(lapply(c(wd_states, cont_states), function(s) {
  d <- panel |> filter(state_code == s)
  tibble(unit = s, group = ifelse(s %in% wd_states, "Withdrawing / lapsed", "Continuously covered"),
         obesity_wz = chg(d, "rx_obesity_wz_observed"), all_drugs = chg(d, "rx_all_drugs_observed"))
}))
nv <- panel |> filter(state_code %in% never_states)
state_chg <- bind_rows(state_chg, tibble(unit = "Never-treated (pooled)", group = "Never treated", obesity_wz = chg(nv, "rx_obesity_wz_observed"), all_drugs = chg(nv, "rx_all_drugs_observed")))
# normalised change: obesity_wz change relative to the state's all-drug change over the same two quarters = (1 + obesity change) / (1 + all-drug change) - 1
state_chg <- state_chg |> mutate(normalised = (1 + obesity_wz) / (1 + all_drugs) - 1)
save_table(state_chg |> mutate(across(c(obesity_wz, all_drugs, normalised), ~ round(.x, 4))), "withdrawal_change_2025Q4_to_2026Q1")
state_chg <- state_chg |> mutate(unit = factor(unit, levels = rev(unit)))
cap <- 1
pb <- ggplot(state_chg, aes(pmin(normalised, !!cap), unit, colour = group)) +
  geom_vline(xintercept = 0, colour = "#999999") +
  geom_segment(aes(x = 0, xend = pmin(normalised, !!cap), yend = unit), linewidth = 0.8) + geom_point(size = 3.2) +
  geom_text(data = filter(state_chg, normalised > cap), aes(x = !!cap, label = paste0("+", round(100 * normalised), "% (axis capped)")), hjust = 1.05, vjust = -0.9, size = 3, show.legend = FALSE) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(-1, cap)) +
  scale_colour_manual(values = c("Withdrawing / lapsed" = col_treated, "Continuously covered" = "#4D4D4D", "Never treated" = col_comparison), name = NULL, guide = "none") +
  labs(x = "Normalized change, 2025 Q4 to 2026 Q1: change in obesity_wz prescriptions relative to the state's all-drug change (preliminary)", y = NULL) + theme_incretin(base_size = 10)

cont_med <- median(state_chg$normalised[state_chg$group == "Continuously covered"])
g <- function(u, v) state_chg[[v]][state_chg$unit == u]
title <- sprintf("Preliminary: relative to their all-drug change, Wegovy/Zepbound prescriptions changed %s in CA and %s in PA after coverage ended, versus a median of %s in the 6 continuously covered states",
                 fmt_pct1(g("CA", "normalised")), fmt_pct1(g("PA", "normalised")), fmt_pct1(cont_med))
sub <- sprintf("Descriptive only: no model, no p-values; 2026 Q1 is preliminary SDUD data. Normalized change = (1 + obesity_wz change) / (1 + all-drug SDUD change) - 1 for 2025 Q4 to 2026 Q1; raw changes are in the table (obesity_wz: CA %s, PA %s, continuously covered median %s; all drugs: CA %s, PA %s, median %s).",
               fmt_pct1(g("CA", "obesity_wz")), fmt_pct1(g("PA", "obesity_wz")), fmt_pct1(median(state_chg$obesity_wz[state_chg$group == "Continuously covered"])),
               fmt_pct1(g("CA", "all_drugs")), fmt_pct1(g("PA", "all_drugs")), fmt_pct1(median(state_chg$all_drugs[state_chg$group == "Continuously covered"])))
p <- (pa / pb) + plot_layout(heights = c(1, 1.15), guides = "collect") +
  plot_annotation(title = stringr::str_wrap(title, 100), subtitle = stringr::str_wrap(sub, 130),
                  caption = stringr::str_wrap(paste(caption_sdud, "PRELIMINARY: 2026 Q1 is preliminary SDUD data; only one post-withdrawal quarter exists for most states (North Carolina lapsed 2025-10-01 to 2025-12-11 and resumed). New Hampshire is a sensitivity state."), 150),
                  theme = theme_incretin()) & theme(legend.position = "bottom")
save_fig(p, "05_withdrawal_descriptive", width = 12, height = 9)
# the normalized-change panel on its own (used on the deck slide on first withdrawals)
pb_only <- pb + labs(title = stringr::str_wrap(title, 100), caption = caption_sdud)
save_fig(pb_only, "05b_withdrawal_change", width = 9, height = 5.5, alt = sprintf("Dot plot of the normalized change in Wegovy and Zepbound prescriptions from 2025 Q4 to 2026 Q1 by state, relative to each state's all-drug change (preliminary, descriptive). California %s and Pennsylvania %s fell most; the continuously covered states have a median of %s.", fmt_pct1(g("CA", "normalised")), fmt_pct1(g("PA", "normalised")), fmt_pct1(cont_med)))
print(state_chg |> mutate(across(c(obesity_wz, all_drugs), ~ round(.x, 3))))
