# Hand-off to the budget model (Module E), approved at Checkpoint B. One tidy CSV with three sections:
#   dynamic_att      imputation-combined dynamic ATT at event times 0..+8 (obesity_wz per 1,000 Medicaid enrollees), pointwise SE and 95% CI,
#                    contributing treated states, and the mean calendar quarter of the contributing cells
#   overall_att      the overall ATT (simple aggregation)
#   never_treated_baseline  mean obesity_wz rate of the never-treated states by calendar quarter (mean of the 20 imputations; the observed-only
#                    mean is alongside), 2018 Q1 to 2026 Q1 (2026 Q1 is preliminary)
source(here::here("R", "prep.R"))
source(here::here("R", "theme.R"))
panel <- get_mart("mart_did_panel")
prim <- readRDS(here::here("outputs", "cache", "primary_fits.rds"))$obesity_wz
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))

dyn <- combine_dynamic(prim) |> filter(e >= 0, e <= 8)
ct <- prim[[1]]$contrib
cells <- prim[[1]]$cells |> filter(kept, e >= 0, e <= 8, is.finite(att))
csize <- panel |> filter(analysis_group == "primary") |> distinct(state_code, first_treated_quarter) |> count(first_treated_quarter, name = "n_states") |> mutate(g = label_to_idx(first_treated_quarter))
mean_cal <- cells |> left_join(csize, by = "g") |> group_by(e) |> summarise(mean_calendar_index = sum(t * n_states) / sum(n_states), .groups = "drop") |>
  mutate(mean_calendar_quarter = idx_to_label(round(mean_calendar_index)))
note_growth <- "The estimated effect grows with event time partly because the national Wegovy/Zepbound market grew over the same period: later event times fall in later calendar quarters (see mean_calendar_quarter), so part of the growth reflects market-wide growth, not time since coverage."
dyn_out <- dyn |> left_join(ct, by = "e") |> left_join(mean_cal |> select(e, mean_calendar_quarter), by = "e") |>
  transmute(section = "dynamic_att", key = paste0("e=", e), estimate, se, ci_low, ci_high, treated_states_contributing = n_states, mean_calendar_quarter,
            value_observed_only = NA_real_, note = ifelse(e == 0, note_growth, ""))
ov <- combine_overall(prim, "simple")
ov_out <- tibble(section = "overall_att", key = "simple aggregation, all post cells", estimate = ov$estimate, se = ov$se, ci_low = ov$ci_low, ci_high = ov$ci_high,
                 treated_states_contributing = prim[[1]]$n_treated_states, mean_calendar_quarter = NA_character_, value_observed_only = NA_real_,
                 note = "Primary run: 10 treated states, 34 never-treated states, 2018 Q1 to 2025 Q3; units are prescriptions per 1,000 Medicaid enrollees (total Medicaid enrollment, item 8a), FFSU + MCOU, gross of rebates.")
per_imp <- lapply(seq_len(M_IMP), function(m) {
  d <- build_data(panel, imp = imps[[m]], window_end = "2026Q1") |> filter(analysis_group == "never_treated") |> group_by(t, quarter_label) |> summarise(mean_rate = mean(y, na.rm = TRUE), .groups = "drop")
  d$m <- m; d })
obs_only <- build_data(panel, bound = "lower", window_end = "2026Q1") |> filter(analysis_group == "never_treated") |> group_by(t) |> summarise(observed_only = mean(y, na.rm = TRUE), .groups = "drop")
base <- bind_rows(per_imp) |> group_by(t, quarter_label) |> summarise(estimate = mean(mean_rate), .groups = "drop") |> left_join(obs_only, by = "t") |> arrange(t)
base_out <- base |> transmute(section = "never_treated_baseline", key = quarter_label, estimate, se = NA_real_, ci_low = NA_real_, ci_high = NA_real_,
                              treated_states_contributing = NA_integer_, mean_calendar_quarter = quarter_label, value_observed_only = observed_only,
                              note = ifelse(quarter_label == "2026Q1", "Preliminary SDUD quarter. Mean over 34 never-treated states.", ifelse(t == 1, "Mean over 34 never-treated states; Wegovy launched 2021 Q2 so values are zero before it.", "")))
out <- bind_rows(dyn_out, ov_out, base_out) |> mutate(across(where(is.numeric), ~ round(.x, 4)))
readr::write_csv(out, file.path(out_dir("tables"), "moduleC_for_budget_model.csv"))
print(out |> filter(section != "never_treated_baseline") |> select(-note), width = 200)
print(base_out |> filter(key %in% c("2021Q2", "2023Q1", "2024Q1", "2025Q1", "2025Q3", "2026Q1")) |> select(key, estimate, value_observed_only))
