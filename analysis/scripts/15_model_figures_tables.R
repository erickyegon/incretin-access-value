# Module C step 4.6: figures and tables from the cached model fits (scripts 10-14). Titles state the estimate exactly (one decimal).
source(here::here("R", "prep.R"))
source(here::here("R", "theme.R"))
library(gt)
library(patchwork)

prim <- readRDS(here::here("outputs", "cache", "primary_fits.rds"))
sens <- readr::read_csv(here::here("outputs", "tables", "specification_table_raw.csv"), show_col_types = FALSE)
swp <- readRDS(here::here("outputs", "cache", "sunab_wild_placebo.rds"))
hd <- readRDS(here::here("outputs", "cache", "honestdid.rds"))
panel <- get_mart("mart_did_panel")
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))
f1 <- prim$obesity_wz[[1]]

es_df <- function(fits) {
  d <- combine_dynamic(fits)
  ct <- fits[[1]]$contrib
  d |> left_join(ct, by = "e") |> mutate(few = is.na(n_states) | n_states < 3)
}
fmtci <- function(est, lo, hi) sprintf("%s (95%% CI %s to %s)", fmt1(est), fmt1(lo), fmt1(hi))

# ---- 1. Event-study figure (primary) ---------------------------------------------------------------------------------------------------
es <- es_df(prim$obesity_wz)
ov <- combine_overall(prim$obesity_wz, "simple"); ovg <- combine_overall(prim$obesity_wz, "group")
e0 <- es |> filter(e == 0); e4 <- es |> filter(e == 4); e8 <- es |> filter(e == 8)
pt <- function(e_) es |> filter(e == e_)
ttl <- sprintf("Wegovy/Zepbound prescriptions per 1,000 Medicaid enrollees rose by an estimated %s at coverage start, %s after 4 quarters and %s after 8 quarters",
               fmtci(pt(0)$estimate, pt(0)$ci_low, pt(0)$ci_high), fmtci(pt(4)$estimate, pt(4)$ci_low, pt(4)$ci_high), fmtci(pt(8)$estimate, pt(8)$ci_low, pt(8)$ci_high))
plot_es <- function(d, ylab, title = NULL, subtitle = NULL, caption = NULL, show_counts = TRUE) {
  d <- d |> filter(e >= -8, e <= 12)
  p <- ggplot(d, aes(e, estimate)) +
    geom_hline(yintercept = 0, colour = "#666666") + geom_vline(xintercept = -0.5, linetype = "dashed", colour = "#999999") +
    geom_ribbon(data = filter(d, !few), aes(ymin = ci_low, ymax = ci_high, group = 1), fill = col_treated, alpha = 0.2) +
    geom_ribbon(data = filter(d, few), aes(ymin = ci_low, ymax = ci_high, group = 1), fill = col_comparison, alpha = 0.15) +
    geom_point(aes(colour = few, shape = few), size = 2.6) +
    scale_colour_manual(values = c(`FALSE` = col_treated, `TRUE` = "#B5B5B5"), labels = c(`FALSE` = "3 or more contributing states", `TRUE` = "fewer than 3 contributing states (greyed)"), name = NULL) +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1), labels = c(`FALSE` = "3 or more contributing states", `TRUE` = "fewer than 3 contributing states (greyed)"), name = NULL) +
    scale_x_continuous(breaks = seq(-8, 12, 2)) + labs(x = "Quarters since coverage began (0 = first treated quarter)", y = ylab, title = title, subtitle = subtitle, caption = caption) +
    theme_incretin()
  if (show_counts) p <- p + geom_text(aes(y = -Inf, label = n_states), vjust = -0.6, size = 2.8, colour = "#555555")
  p
}
crit_mean <- mean(es$crit_simultaneous, na.rm = TRUE)
p1 <- plot_es(es, "ATT per 1,000 enrollees", title = stringr::str_wrap(ttl, 95),
              subtitle = stringr::str_wrap("Callaway-Sant'Anna dynamic ATT, 10 primary states vs never- and not-yet-treated states, 2018 Q1 to 2025 Q3; 20 imputations of suppressed cells combined with Rubin's rules. Shaded band and points: pointwise 95% CI; numbers along the bottom: contributing treated states; event times with fewer than 3 contributing states are greyed.", 130),
              caption = stringr::str_wrap(paste(sprintf("Simultaneous confidence bands are not shown: with single-state cohorts the bootstrap critical value is unreliable (did warns of this) and very large (%s on average over the imputations, versus 1.96 pointwise). Leads before 2021 Q2 (before Wegovy existed) are omitted: the outcome is mechanically zero there and they are not evidence of parallel trends.", fmt1(crit_mean)), caption_sdud), 150))
save_fig(p1, "10_event_study_primary", width = 11, height = 6.8)
save_table(es |> transmute(event_time = e, att = estimate, se, ci_low, ci_high, band_low, band_high, fmi, treated_states = n_states, cohorts = n_cohorts, fewer_than_3_states = few), "event_study_primary")

# ---- 2. Overall ATT table -----------------------------------------------------------------------------------------------------------------
sa <- swp$sa_overall; wild <- swp$wild; pl <- swp$placebo
att_tab <- bind_rows(
  tibble(estimate_type = "Overall ATT (simple aggregation), Callaway-Sant'Anna", att = ov$estimate, se = ov$se, ci_low = ov$ci_low, ci_high = ov$ci_high, method = "did multiplier bootstrap, state clusters, 999 draws; Rubin's rules over 20 imputations", fmi = ov$fmi),
  tibble(estimate_type = "Overall ATT (group aggregation: average of cohort ATTs), Callaway-Sant'Anna", att = ovg$estimate, se = ovg$se, ci_low = ovg$ci_low, ci_high = ovg$ci_high, method = "same", fmi = ovg$fmi),
  tibble(estimate_type = "TWFE Sun-Abraham post-period average", att = sa$estimate, se = sa$se, ci_low = sa$ci_low, ci_high = sa$ci_high, method = "fixest, state-clustered; Rubin's rules over 20 imputations", fmi = sa$fmi),
  tibble(estimate_type = "TWFE Sun-Abraham post-period average, wild cluster bootstrap", att = wild$point_estimate, se = NA_real_, ci_low = wild$ci_low, ci_high = wild$ci_high, method = sprintf("fwildclusterboot, Webb weights, 9,999 draws, by state; mean of 20 imputed outcomes; p = %s; interval = symmetric wild bootstrap-t (point +/- CRV1 se x 95th percentile of |t*|, %s)", signif(wild$p_value_wild_webb, 2), fmt1(wild$q95_abs_t_boot)), fmi = NA_real_),
  tibble(estimate_type = "Placebo in time: coverage 4 quarters earlier (post-launch window)", att = pl$estimate, se = pl$se, ci_low = pl$ci_low, ci_high = pl$ci_high, method = sprintf("att_gt, never-treated controls, %d treated states with cohorts that allow it; Rubin's rules", pl$n_treated_states), fmi = pl$fmi))
sec_names <- c(obesity_saxenda = "Saxenda", diabetes_glp1 = "diabetes GLP-1 (spillover outcome, not a clean negative control)")
for (o in names(sec_names)) {
  r <- combine_overall(prim[[o]], "simple")
  att_tab <- bind_rows(att_tab, tibble(estimate_type = paste0("Secondary outcome, overall ATT (simple): ", sec_names[[o]]),
                                       att = r$estimate, se = r$se, ci_low = r$ci_low, ci_high = r$ci_high, method = "same as the primary", fmi = r$fmi))
}
att_tab <- att_tab |> mutate(across(c(att, se, ci_low, ci_high, fmi), ~ round(.x, 3)))
g <- gt(att_tab) |>
  tab_header(title = "Overall effects on obesity_wz prescriptions per 1,000 Medicaid enrollees",
             subtitle = sprintf("Primary run: %d states (%d treated, %d never treated), %d state-quarters, 2018 Q1 to 2025 Q3", f1$n_states, f1$n_treated_states, f1$n_never_states, f1$n_state_quarters)) |>
  fmt_number(c(att, se, ci_low, ci_high, fmi), decimals = 2) |> sub_missing(missing_text = "") |>
  cols_label(estimate_type = "Estimate", att = "ATT", se = "SE", ci_low = "95% CI low", ci_high = "95% CI high", method = "Method", fmi = "Fraction of missing information") |>
  tab_source_note("Gross of rebates; counts under 11 suppressed by CMS (handled by multiple imputation). Estimates are changes in Medicaid-paid prescriptions per 1,000 enrollees, not in total use.")
save_table(att_tab, "overall_att", g)

# ---- 3. Specification chart ---------------------------------------------------------------------------------------------------------------
sp <- sens |> filter(spec != "12") |> mutate(label = paste0(spec, ". ", specification), is_primary = spec == "0") |>
  mutate(label = factor(label, levels = rev(label)))
p3 <- ggplot(sp, aes(att_simple, label, colour = is_primary)) +
  geom_vline(xintercept = 0, colour = "#666666") + geom_vline(xintercept = sp$att_simple[sp$spec == "0"], linetype = "dashed", colour = col_treated, alpha = 0.6) +
  geom_errorbar(aes(xmin = ci_low, xmax = ci_high), width = 0.25, orientation = "y") + geom_point(size = 2.6) +
  scale_colour_manual(values = c(`FALSE` = col_comparison, `TRUE` = col_treated), guide = "none") +
  labs(title = stringr::str_wrap(sprintf("Estimated average effect on obesity_wz prescriptions per 1,000 enrollees: %s in the primary run, from %s to %s across the %d other specifications",
                                         fmt1(sp$att_simple[sp$spec == "0"]), fmt1(min(sp$att_simple[sp$spec != "0"])), fmt1(max(sp$att_simple[sp$spec != "0"])), nrow(sp) - 1), 95),
       subtitle = stringr::str_wrap("Overall ATT (simple aggregation) with 95% CI; orange = primary; each other row changes one thing.", 130),
       x = "Overall ATT (prescriptions per 1,000 enrollees)", y = NULL,
       caption = stringr::str_wrap(paste("Specification 12 (fee-for-service only) is not shown: not estimable reliably (FFS denominators too small; coverage operates mainly through MCOs in SC and RI). It is listed in the specification table.", caption_sdud), 150)) +
  theme_incretin() + theme(panel.grid.major.y = element_blank())
save_fig(p3, "11_specification_chart", width = 11, height = 7)
nr <- "Not estimable reliably: FFS denominators too small; coverage operates mainly through MCOs in SC and RI"
spec_out <- sens |> mutate(across(where(is.numeric), ~ round(.x, 3)))
spec_out[spec_out$spec == "12", c("att_simple", "ci_low", "ci_high", "att_group")] <- NA_real_
spec_out$note[spec_out$spec == "12"] <- paste0(nr, "; ", sens$note[sens$spec == "12"])
gs <- gt(spec_out |> select(spec, specification, att_simple, ci_low, ci_high, att_group, states, treated_states, never_treated_states, state_quarters, imputations, note)) |>
  tab_header(title = "Specification table: overall ATT for obesity_wz under each pre-specified analysis") |>
  fmt_number(c(att_simple, ci_low, ci_high, att_group), decimals = 2) |> sub_missing(missing_text = "") |>
  tab_source_note("Specification 12 is reported as not estimable reliably (FFS denominators too small; coverage operates mainly through MCOs in SC and RI); the raw fit is kept in specification_table_raw.csv. Imputation-combined (Rubin) except 5a and 5b (single fits). Specification 7 equals the primary: the only reporting-gap quarter inside the window (Wisconsin 2020 Q1) belongs to a sensitivity state that the primary run excludes.")
save_table(spec_out, "specification_table", gs)

# ---- 4. HonestDiD figure --------------------------------------------------------------------------------------------------------------------
orig <- tibble(lb = as.numeric(hd$original$lb), ub = as.numeric(hd$original$ub)); grid <- hd$grid |> mutate(lb = as.numeric(lb), ub = as.numeric(ub))
p4 <- ggplot(grid, aes(Mbar)) +
  geom_hline(yintercept = 0, colour = "#666666") +
  geom_ribbon(aes(ymin = lb, ymax = ub), fill = col_treated, alpha = 0.25) + geom_line(aes(y = lb), colour = col_treated) + geom_line(aes(y = ub), colour = col_treated) +
  geom_hline(yintercept = c(orig$lb, orig$ub), linetype = "dashed", colour = col_comparison) +
  labs(title = stringr::str_wrap(sprintf("The 95%% robust CI for the average of the first 4 post-coverage quarters is %s to %s at Mbar = 0 and %s at Mbar = 2; breakdown value %s", fmt1(grid$lb[grid$Mbar == 0]), fmt1(grid$ub[grid$Mbar == 0]),
                                         sprintf("%s to %s", fmt1(grid$lb[grid$Mbar == 2]), fmt1(grid$ub[grid$Mbar == 2])), ifelse(is.na(hd$breakdown_Mbar), "not reached by Mbar = 5", fmt1(hd$breakdown_Mbar))), 95),
       subtitle = stringr::str_wrap("HonestDiD relative-magnitudes bounds on the mean of event times 0 to +3; pre-period event times -8 to -2 (post-launch quarters only). Dashed: conventional CI.", 120),
       x = "Mbar: largest post-period violation of parallel trends as a multiple of the largest pre-period violation", y = "Robust 95% CI for the average ATT, e = 0..3",
       caption = caption_sdud) + theme_incretin()
save_fig(p4, "12_honestdid", width = 9, height = 6)
save_table(bind_rows(tibble(Mbar = NA_real_, lb = orig$lb, ub = orig$ub, method = "conventional"), grid |> transmute(Mbar, lb, ub, method = "relative magnitudes")), "honestdid_bounds")

# ---- 5. Secondary outcomes ------------------------------------------------------------------------------------------------------------------
labs3 <- c(obesity_wz = "Primary: Wegovy/Zepbound (obesity_wz)", obesity_saxenda = "Secondary: Saxenda", diabetes_glp1 = "Secondary: diabetes GLP-1 (spillover outcome)")
ov3_pre <- lapply(names(labs3), function(o) combine_overall(prim[[o]], "simple"))
labs3_strip <- setNames(paste0(labs3, ": overall ATT ", vapply(ov3_pre, function(r) fmtci(r$estimate, r$ci_low, r$ci_high), "")), names(labs3))
es3 <- bind_rows(lapply(names(labs3), function(o) es_df(prim[[o]]) |> mutate(outcome = labs3_strip[[o]]))) |> mutate(outcome = factor(outcome, levels = labs3_strip))
ov3 <- bind_rows(lapply(names(labs3), function(o) combine_overall(prim[[o]], "simple") |> mutate(outcome = labs3[[o]])))
p5 <- ggplot(es3 |> filter(e >= -8, e <= 12), aes(e, estimate)) +
  geom_hline(yintercept = 0, colour = "#666666") + geom_vline(xintercept = -0.5, linetype = "dashed", colour = "#999999") +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high, colour = few), width = 0.25) + geom_point(aes(colour = few), size = 1.8) +
  facet_wrap(~outcome, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(`FALSE` = col_treated, `TRUE` = col_comparison), guide = "none") + scale_x_continuous(breaks = seq(-8, 12, 2)) +
  labs(title = stringr::str_wrap(sprintf("Overall ATT per 1,000 enrollees: %s for Wegovy/Zepbound, %s for Saxenda, %s for diabetes GLP-1 products",
                                         fmtci(ov3$estimate[1], ov3$ci_low[1], ov3$ci_high[1]), fmtci(ov3$estimate[2], ov3$ci_low[2], ov3$ci_high[2]), fmtci(ov3$estimate[3], ov3$ci_low[3], ov3$ci_high[3])), 95),
       subtitle = stringr::str_wrap("Dynamic ATT by quarters since coverage began, same design as the primary; each panel on its own y-scale; bars are pointwise 95% CIs (simultaneous bands omitted: they are very wide with single-state cohorts); grey = fewer than 3 contributing states; leads before 2021 Q2 omitted.", 120),
       x = "Quarters since coverage began", y = "ATT: prescriptions per 1,000 enrollees",
       caption = stringr::str_wrap(paste("The diabetes GLP-1 outcome is a pre-specified spillover outcome, not a clean negative control: a negative estimate is consistent with substitution from off-label diabetes products to covered obesity products, a positive one with spillover in prescribing, and neither can be told apart from a design problem with this data alone.", caption_sdud), 150)) +
  theme_incretin()
save_fig(p5, "13_secondary_outcomes", width = 9, height = 10)
save_table(es3 |> transmute(outcome, event_time = e, att = estimate, se, ci_low, ci_high, treated_states = n_states, fewer_than_3_states = few), "event_study_secondary_outcomes")

# ---- 6. Group-time ATT table (CSV only) ------------------------------------------------------------------------------------------------------
cells <- bind_rows(lapply(seq_along(prim$obesity_wz), function(m) prim$obesity_wz[[m]]$cells |> mutate(m = m))) |>
  group_by(g, t, e, kept) |> summarise(att = mean(att, na.rm = TRUE), se_within = sqrt(mean(se^2, na.rm = TRUE)), .groups = "drop") |>
  mutate(cohort = idx_to_label(g), calendar_quarter = idx_to_label(t), post_launch_cell = kept)
readr::write_csv(cells |> select(cohort, calendar_quarter, event_time = e, att, se_within, post_launch_cell), file.path(out_dir("tables"), "group_time_att.csv"))
cat("done:", nrow(att_tab), "ATT rows;", nrow(sens), "specs\n")
print(att_tab |> select(estimate_type, att, ci_low, ci_high))
print(es |> filter(e %in% c(-2, -1, 0, 1, 4, 8, 12)) |> select(e, estimate, ci_low, ci_high, n_states, n_cohorts))
