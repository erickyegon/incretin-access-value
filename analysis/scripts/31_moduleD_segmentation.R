# Module D step D2: segmentation of 2024 Part D incretin prescribers (plan_moduleD.md). k-prototypes (mixed data), k chosen by silhouette on a stratified
# 10,000-prescriber subsample, stability by 50 bootstrap resamples (Jaccard). Seed 20261004 + 4000. Aggregate outputs only (profiles of segments, no NPI-level output).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(clustMixType); library(patchwork); library(gt) })
set.seed(20261004 + 4000L)
SIL_N <- as.integer(Sys.getenv("SIL_N", "10000"))   # subsample size for choosing k (plan: 10,000)
cap <- "Source: CMS Medicare Part D Prescribers by Provider and Drug 2023-2024 (rows with at least 11 claims), NPPES. Part D reflects diabetes and other covered uses, not obesity-brand adoption; segments describe prescribers with 11 or more claims for a drug."

d <- get_mart("mart_prescriber_year", cols = c("prescriber_npi", "data_year", "brand_name", "specialty_group", "total_claims", "ge65_total_claims"), where = "data_year in (2023, 2024)")
p24 <- d |> filter(data_year == 2024) |> group_by(prescriber_npi) |> summarise(specialty_group = first(specialty_group), c24 = sum(total_claims), tirz = sum(total_claims[brand_name == "Mounjaro"]),
                                                                             ge65_populated = mean(!is.na(ge65_total_claims)), .groups = "drop")
p23 <- d |> filter(data_year == 2023) |> group_by(prescriber_npi) |> summarise(c23 = sum(total_claims), .groups = "drop")
x <- p24 |> left_join(p23, by = "prescriber_npi") |> mutate(new_2024 = is.na(c23), c23 = coalesce(c23, 0), log_claims = log(c24), growth = log((c24 + 1) / (c23 + 1)), tirz_share = tirz / c24,
                                                           specialty = factor(specialty_group))
# the share of claims for beneficiaries 65+ is used only if populated for at least 80% of prescribers (CMS suppresses it under 11 claims)
share65_populated <- mean(d$data_year == 2024 & !is.na(d$ge65_total_claims)) / mean(d$data_year == 2024)
use65 <- share65_populated >= 0.80
cat("65+ claims populated for", round(100 * share65_populated, 1), "% of prescriber-drug rows -> used in segmentation:", use65, "\n")
feat <- x |> transmute(log_claims = as.numeric(scale(log_claims)), growth = as.numeric(scale(growth)), tirz_share = as.numeric(scale(tirz_share)), new_2024 = as.numeric(scale(as.numeric(new_2024))), specialty = specialty)
feat_df <- as.data.frame(feat)
n <- nrow(feat_df)
# stratified subsample for choosing k
idx <- unlist(lapply(split(seq_len(n), feat_df$specialty), function(i) sample(i, min(length(i), max(100, round(SIL_N * length(i) / n))))))
sub <- feat_df[idx, ]
lam <- lambdaest(sub, verbose = FALSE)
ks <- 2:8
sil <- sapply(ks, function(k) { m <- kproto(sub, k = k, lambda = lam, nstart = 3, verbose = FALSE); mean(validation_kproto(method = "silhouette", object = m)) })
cat("silhouette by k:", paste(ks, round(sil, 3), sep = "=", collapse = " "), "\n")
sel <- tibble(k = ks, silhouette = sil)
if (Sys.getenv("K_FORCE", "0") == "0") readr::write_csv(sel, file.path(out_dir("tables"), "moduleD_segmentation_k_selection.csv"))
k <- ks[which.max(sil)]
K_FORCE <- as.integer(Sys.getenv("K_FORCE", "0")); SUFFIX <- ""
if (K_FORCE > 0) { k <- K_FORCE; SUFFIX <- paste0("_k", k) }   # supplementary run with a chosen k (the plan's selection rule picks the highest silhouette)
cat("k chosen (highest silhouette):", k, "\n")

fit <- kproto(feat_df, k = k, lambda = lam, nstart = 1, iter.max = 25, verbose = FALSE)
x$cluster <- fit$cluster

# stability: bootstrap Jaccard
jacc <- function(a, b) length(intersect(a, b)) / length(union(a, b))
B <- 50
stab <- matrix(NA_real_, B, k)
for (b in seq_len(B)) {
  ii <- sort(unique(sample.int(n, 10000, replace = TRUE)))
  mb <- kproto(feat_df[ii, ], k = k, lambda = lam, nstart = 1, iter.max = 20, verbose = FALSE)
  for (c in seq_len(k)) { orig <- which(x$cluster[ii] == c); stab[b, c] <- max(sapply(seq_len(k), function(j) jacc(orig, which(mb$cluster == j)))) }
}
stability <- tibble(cluster = seq_len(k), mean_jaccard = colMeans(stab, na.rm = TRUE), share_bootstraps_above_0.75 = colMeans(stab > 0.75, na.rm = TRUE))

# profile and descriptive names
prof <- x |> group_by(cluster) |> summarise(prescribers = n(), share_of_prescribers_pct = 100 * n() / nrow(x), claims = sum(c24), share_of_claims_pct = 100 * sum(c24) / sum(x$c24),
  median_claims = median(c24), median_growth_log = median(growth), share_new_2024_pct = 100 * mean(new_2024), mean_tirz_share_pct = 100 * mean(tirz_share), .groups = "drop")
spec <- x |> count(cluster, specialty_group) |> group_by(cluster) |> mutate(pct = 100 * n / sum(n)) |> ungroup()
dom <- spec |> group_by(cluster) |> slice_max(pct, n = 1, with_ties = FALSE) |> select(cluster, dominant_specialty = specialty_group, dominant_pct = pct)
qv <- quantile(x$c24, c(1 / 3, 2 / 3))
prof <- prof |> left_join(dom, by = "cluster") |> left_join(stability, by = "cluster") |>
  mutate(volume = ifelse(median_claims <= qv[1], "lower-volume", ifelse(median_claims <= qv[2], "mid-volume", "high-volume")),
         tirz = ifelse(mean_tirz_share_pct >= 50, "mostly tirzepatide", ifelse(mean_tirz_share_pct >= 10, "some tirzepatide", "little or no tirzepatide")),
         spec_short = recode(dominant_specialty, "Primary care physicians" = "primary care", "Nurse practitioners and physician assistants" = "NP and PA", "Endocrinology" = "endocrinology", "Cardiology" = "cardiology", "Other" = "other specialties"),
         segment = paste0(volume, " ", spec_short, ", ", tirz, ifelse(share_new_2024_pct >= 50, ", new in 2024", ""))) |>
  arrange(desc(share_of_claims_pct)) |> mutate(segment_id = LETTERS[row_number()], segment = paste0(segment_id, ": ", segment))
x <- x |> left_join(prof |> select(cluster, segment), by = "cluster")
save_table(prof |> mutate(across(where(is.numeric), ~ round(.x, 3))), paste0("moduleD_segment_profiles", SUFFIX), gt(prof |> select(segment, prescribers, share_of_prescribers_pct, share_of_claims_pct, median_claims, median_growth_log, share_new_2024_pct, mean_tirz_share_pct, mean_jaccard) |> mutate(across(where(is.numeric), ~ round(.x, 2)))) |>
  tab_header(title = "Segments of 2024 Part D incretin prescribers", subtitle = "k-prototypes on log claims, growth 2023 to 2024, tirzepatide share, new-in-2024 flag and specialty group") |>
  tab_source_note("Mean Jaccard = stability over 50 bootstrap resamples (1 = identical segment each time). Segments are named by profile, never by individual."))
save_table(spec |> mutate(pct = round(pct, 2)) |> left_join(prof |> select(cluster, segment), by = "cluster") |> select(segment, specialty_group, n, pct), paste0("moduleD_segment_specialty_mix", SUFFIX))

# profile figure (aggregate): dot plot of segment medians/means per feature
lv <- rev(prof$segment)
pp <- prof |> transmute(segment = factor(segment, levels = lv), `Median 2024 claims` = median_claims, `Median growth, log(2024+1 / 2023+1)` = median_growth_log, `Tirzepatide share of claims (%)` = mean_tirz_share_pct,
                        `New in 2024 (% of segment)` = share_new_2024_pct, `Share of all prescribers (%)` = share_of_prescribers_pct, `Share of all claims (%)` = share_of_claims_pct) |>
  pivot_longer(-segment, names_to = "feature", values_to = "value") |> mutate(feature = factor(feature, levels = unique(feature)))
pf <- ggplot(pp, aes(value, segment)) + geom_segment(aes(x = 0, xend = value, yend = segment), colour = col_context) + geom_point(colour = col_treated, size = 3) +
  geom_text(aes(label = format(round(value, 1), nsmall = 1)), hjust = -0.35, size = 2.8) + facet_wrap(~feature, nrow = 1, scales = "free_x") + scale_x_continuous(expand = expansion(mult = c(0.05, 0.4))) +
  labs(title = stringr::str_wrap(sprintf("Part D incretin prescribers fall into %d segments; the largest by claims, %s, wrote %s%% of 2024 claims", k, sub("^[A-Z]: ", "", prof$segment[1]), fmt1(prof$share_of_claims_pct[1])), 95),
       subtitle = stringr::str_wrap("Segments of 2024 Part D incretin prescribers (k-prototypes on claims, growth, tirzepatide share, new-in-2024 flag and specialty). Each dot is a segment; segment sizes and stability are in the table.", 140),
       x = NULL, y = NULL, caption = stringr::str_wrap(cap, 150)) + theme_incretin(base_size = 9) + theme(panel.grid.major.y = element_blank())
save_fig(pf, paste0("35_partd_segments", SUFFIX), width = 14, height = 5.5, alt = sprintf("Dot plot of %d prescriber segments across six profile measures: median 2024 claims, median growth, tirzepatide share of claims, share new in 2024, share of all prescribers and share of all claims.", k))

segment_rows <- x |> group_by(segment) |> summarise(n = n(), .groups = "drop"); print(prof |> select(segment, prescribers, share_of_claims_pct, median_claims, median_growth_log, share_new_2024_pct, mean_tirz_share_pct, mean_jaccard) |> mutate(across(where(is.numeric), ~ round(.x, 2))), width = 220)
print(spec |> filter(pct > 10) |> left_join(prof |> select(cluster, segment_id), by = "cluster") |> arrange(segment_id, desc(pct)) |> mutate(pct = round(pct, 1)), n = 40)
