# Estimator reconciliation (Checkpoint B request 1): why the Callaway-Sant'Anna simple ATT (12.2) differs from the Sun-Abraham post-period average (9.3).
# (a) CS simple, all post cells; (b) CS dynamic averaged over e = 0..12 with equal weights; (c) CS dynamic averaged over e = 0..12 with the
# Sun-Abraham cell weights (event time weighted by the number of treated state-quarters in the cell); (d) Sun-Abraham. All imputation-combined.
# Also: the maximum event time each cohort reaches inside the window (2025 Q3).
source(here::here("R", "prep.R"))
source(here::here("R", "theme.R"))
panel <- get_mart("mart_did_panel")
prim <- readRDS(here::here("outputs", "cache", "primary_fits.rds"))$obesity_wz
swp <- readRDS(here::here("outputs", "cache", "sunab_wild_placebo.rds"))
E <- 0:12

avg_dyn <- function(f, w_fun) {
  a <- f$dynamic; idx <- match(E, a$egt)
  ct <- f$contrib; n_e <- ct$n_states[match(E, ct$e)]
  w <- w_fun(n_e); w <- w / sum(w)
  S <- crossprod(a$inf[, idx, drop = FALSE]) / a$n_units^2
  c(att = sum(w * a$att.egt[idx]), se = sqrt(drop(t(w) %*% S %*% w)))
}
comb <- function(w_fun) {
  r <- sapply(prim, avg_dyn, w_fun = w_fun)
  rubin(r["att", ], r["se", ])
}
tab <- bind_rows(
  combine_overall(prim, "simple") |> mutate(estimator = "(a) Callaway-Sant'Anna simple aggregation, all post cells"),
  comb(function(n) rep(1, length(n))) |> mutate(estimator = "(b) CS dynamic, mean of e = 0..12, equal weights"),
  comb(function(n) n) |> mutate(estimator = "(c) CS dynamic, mean of e = 0..12, Sun-Abraham cell weights (treated state-quarters per event time)"),
  swp$sa_overall |> mutate(estimator = "(d) TWFE Sun-Abraham post-period average")) |>
  select(estimator, estimate, se, ci_low, ci_high) |> mutate(across(where(is.numeric), ~ round(.x, 3)))

# (c2) CS group-time estimates weighted exactly like the Sun-Abraham cells (treated state-quarters per cohort x event-time cell), point estimate only
cs_cells <- bind_rows(lapply(prim, function(f) f$cells |> filter(kept, e >= 0, e <= 12, is.finite(att)) |> select(g, e, att))) |> group_by(g, e) |> summarise(att = mean(att), .groups = "drop")
sa_n <- swp$sa_cells |> filter(m == 1, e >= 0, e <= 12) |> select(g, e, n_obs)
c2 <- cs_cells |> inner_join(sa_n, by = c("g", "e")) |> summarise(estimate = sum(n_obs * att) / sum(n_obs)) |> pull(estimate)
tab <- bind_rows(tab, tibble(estimator = "(c2) CS group-time estimates, e = 0..12, weighted like the Sun-Abraham cells (point estimate)", estimate = round(c2, 3), se = NA_real_, ci_low = NA_real_, ci_high = NA_real_)) |>
  arrange(estimator)
csize <- panel |> filter(analysis_group == "primary") |> group_by(first_treated_quarter) |> summarise(states = paste(sort(unique(state_code)), collapse = ", "), n_states = n_distinct(state_code), .groups = "drop") |>
  mutate(g = label_to_idx(first_treated_quarter), max_event_time_in_window = label_to_idx("2025Q3") - g, post_quarters = max_event_time_in_window + 1L) |> arrange(g)
save_table(tab, "estimator_reconciliation")
save_table(csize |> select(cohort = first_treated_quarter, states, n_states, max_event_time_in_window, post_quarters), "max_event_time_by_cohort")
print(tab, width = 200); print(csize |> select(first_treated_quarter, states, max_event_time_in_window))

# weight of each cohort: CS simple ATT = every post group-time cell weighted by its cohort size (so a cohort counts n_states x post quarters);
# Sun-Abraham post average = every treated state-quarter once (the same thing at the level of event-time cells, but with the cells of the regression)
sa_cells <- swp$sa_cells |> filter(m == 1, e >= 0) |> group_by(g) |> summarise(sa_weight = sum(n_obs), .groups = "drop") |> mutate(sa_weight = sa_weight / sum(sa_weight))
cs_cells <- prim[[1]]$cells |> filter(kept, t >= g, is.finite(att)) |> left_join(csize |> select(g, n_states), by = "g") |> group_by(g) |> summarise(post_cells = n(), n_states = first(n_states), .groups = "drop") |>
  mutate(cs_simple_weight = n_states * post_cells / sum(n_states * post_cells))
wt <- csize |> select(g, cohort = first_treated_quarter, states) |> left_join(cs_cells |> select(g, cs_simple_weight), by = "g") |> left_join(sa_cells, by = "g") |>
  left_join(prim[[1]]$cells |> filter(kept, t >= g, is.finite(att)) |> group_by(g) |> summarise(cohort_mean_post_att = mean(att), .groups = "drop"), by = "g") |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))
save_table(wt, "estimator_cohort_weights")
print(wt)
