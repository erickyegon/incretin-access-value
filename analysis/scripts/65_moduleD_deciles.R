# Plan gap 1: prescriber volume deciles. Prescribers with at least one 11-claim incretin row in 2024 are ranked by their total Part D incretin claims and cut into ten equal-sized groups
# (decile 10 = highest volume). Table and figure: prescribers and share of claims per decile. Aggregates only; no NPI-level output.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
d <- get_mart("mart_prescriber_year", cols = c("prescriber_npi", "data_year", "total_claims"), where = "data_year = 2024")
tot <- d |> group_by(prescriber_npi) |> summarise(claims = sum(total_claims), .groups = "drop") |> arrange(claims) |> mutate(rank = row_number(), decile = ceiling(10 * rank / n()))
dec <- tot |> group_by(decile) |> summarise(prescribers = n(), claims = sum(claims), min_claims = min(claims), median_claims = median(claims), max_claims = max(claims), .groups = "drop") |>
  mutate(share_of_prescribers_pct = 100 * prescribers / sum(prescribers), share_of_claims_pct = 100 * claims / sum(claims), cumulative_share_from_top_pct = cumsum(rev(share_of_claims_pct))[11 - decile])
save_table(dec |> mutate(across(c(share_of_prescribers_pct, share_of_claims_pct, cumulative_share_from_top_pct, median_claims), ~ round(.x, 2))), "moduleD_volume_deciles_2024",
  gt::gt(dec |> transmute(Decile = decile, Prescribers = prescribers, `Claims` = claims, `Median claims` = median_claims, `Share of claims, %` = round(share_of_claims_pct, 1), `Cumulative share from the top, %` = round(cumulative_share_from_top_pct, 1))) |>
    gt::tab_header(title = "Part D incretin claims by prescriber volume decile, 2024", subtitle = "Decile 10 = highest-volume tenth of prescribers") |> gt::tab_source_note("Prescribers with at least one 11-claim row; claims summed over all in-scope incretin brands. Part D reflects diabetes and other covered uses."))
top <- dec$share_of_claims_pct[dec$decile == 10]; bot <- sum(dec$share_of_claims_pct[dec$decile <= 5])
dec$grp <- ifelse(dec$decile == 10, "Top decile", "Other deciles")
p <- ggplot(dec, aes(factor(decile), share_of_claims_pct, fill = grp)) + geom_hline(yintercept = 10, linetype = "dashed", colour = col_comparison) + geom_col(width = 0.75) +
  geom_label(aes(label = sprintf("%s%%", fmt1(share_of_claims_pct))), vjust = -0.15, size = 3.6, colour = "#222222", fill = "white", label.size = 0, label.padding = unit(0.12, "lines")) +
  annotate("text", x = 1, y = 11.2, label = "equal share (10%)", hjust = 0, size = 3.6, colour = col_comparison) +
  scale_fill_manual(values = c("Top decile" = col_treated, "Other deciles" = col_context), guide = "none") + scale_y_continuous(limits = c(0, max(dec$share_of_claims_pct) * 1.15), expand = expansion(mult = c(0, 0))) +
  labs(x = "Prescriber volume decile (10 = highest volume)", y = "Share of 2024 Part D incretin claims (%)",
       title = sprintf("The top tenth of prescribers wrote %s%% of 2024 Part D incretin claims; the bottom half wrote %s%%", fmt1(top), fmt1(bot)),
       subtitle = "Each bar is one tenth of prescribers, ranked by their total claims.", caption = "Source: CMS Medicare Part D Prescribers (rows with at least 11 claims). Part D reflects diabetes and other covered uses, not obesity-brand adoption. Aggregates only.") + theme_incretin()
save_fig(p, "37_partd_volume_deciles", width = 9, height = 5.6, alt = sprintf("Bar chart of the share of 2024 Part D incretin claims written by each tenth of prescribers ranked by volume. The top decile wrote %s percent of claims and the bottom five deciles together %s percent, against 10 percent each if volume were equal.", fmt1(top), fmt1(bot)))
print(as.data.frame(dec |> select(decile, prescribers, claims, share_of_claims_pct)))
