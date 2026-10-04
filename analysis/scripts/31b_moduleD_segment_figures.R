# Module D step D2 figures: dot-plot profile of the segments, drawn from the saved profile tables (aggregate only), for the pre-specified solution (k chosen by
# silhouette) and the supplementary five-segment solution. Alt text is recorded in outputs/figures/alt_text.csv.
source(here::here("R", "theme.R"))
suppressPackageStartupMessages(library(tidyr))
cap <- "Source: CMS Medicare Part D Prescribers by Provider and Drug 2023-2024 (rows with at least 11 claims), NPPES. Part D reflects diabetes and other covered uses, not obesity-brand adoption; segments describe prescribers with 11 or more claims for a drug. Stability: mean Jaccard over 50 bootstrap resamples."
for (suffix in c("", "_k5")) {
  f <- file.path(out_dir("tables"), paste0("moduleD_segment_profiles", suffix, ".csv"))
  if (!file.exists(f)) next
  prof <- readr::read_csv(f, show_col_types = FALSE); k <- nrow(prof)
  lv <- rev(prof$segment)
  pp <- prof |> transmute(segment = factor(segment, levels = lv), `Median 2024 claims` = median_claims, `Median growth (log ratio 2024 to 2023)` = median_growth_log, `Tirzepatide share of claims (%)` = mean_tirz_share_pct,
                          `New in 2024 (% of segment)` = share_new_2024_pct, `Share of all prescribers (%)` = share_of_prescribers_pct, `Share of all claims (%)` = share_of_claims_pct, `Stability (mean Jaccard)` = mean_jaccard) |>
    pivot_longer(-segment, names_to = "feature", values_to = "value") |> mutate(feature = factor(feature, levels = unique(feature)))
  ttl <- sprintf("Part D incretin prescribers fall into %d segments; the largest by claims, %s, wrote %s%% of 2024 claims", k, sub("^[A-Z]: ", "", prof$segment[which.max(prof$share_of_claims_pct)]), fmt1(max(prof$share_of_claims_pct)))
  p <- ggplot(pp, aes(value, segment)) + geom_segment(aes(x = 0, xend = value, yend = segment), colour = col_context) + geom_point(colour = col_treated, size = 3) +
    geom_text(aes(label = format(round(value, 2), nsmall = 1, trim = TRUE)), hjust = -0.3, size = 2.7) +
    facet_wrap(~feature, nrow = 1, scales = "free_x", labeller = label_wrap_gen(16)) + scale_x_continuous(expand = expansion(mult = c(0.05, 0.45))) +
    labs(title = ttl, subtitle = if (k == 2) "Pre-specified solution (highest silhouette): the two segments separate prescribers new in 2024 from continuing prescribers. Each dot is a segment." else
           "Supplementary five-segment solution (the next silhouette maximum). Each dot is a segment; segment sizes and stability are in the table.", x = NULL, y = NULL, caption = cap) + theme_incretin(base_size = 9) + theme(panel.grid.major.y = element_blank())
  save_fig(p, paste0("35_partd_segments", suffix), width = 15, height = ifelse(k == 2, 3.8, 5.5),
           alt = sprintf("Dot plot of %d prescriber segments across seven profile measures: median 2024 claims, median growth, tirzepatide share of claims, share new in 2024, share of all prescribers, share of all claims and stability. %s", k, paste(sprintf("%s wrote %s percent of claims", prof$segment, round(prof$share_of_claims_pct, 1)), collapse = "; ")))
}
cat("segment figures written\n")
