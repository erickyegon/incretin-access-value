# Module C step 4.4: (a) TWFE Sun-Abraham event study with state and quarter fixed effects (never-treated states as the comparison, cohort-specific
# post-launch cells), post-period average with a wild cluster bootstrap by state (Webb weights, 9,999 draws, fwildclusterboot); (b) placebo in
# time: coverage pretended to begin 4 quarters earlier, post-launch window only.
# Implementation notes (pre-specified choices, see outputs/implementation_notes.md):
#  * The Sun-Abraham estimator is the saturated cohort x event-time interaction regression, with cells restricted to post-launch quarters for
#    leads (plan: no lead before 2021 Q2 counts as evidence) and the e = -1 cell as the reference; interaction-weighted averages use the number
#    of treated state-quarters in each cell (the weights of fixest::aggregate(.., "ATT")). Cluster-robust event-study estimates come from
#    fixest::feols per imputation, combined with Rubin's rules.
#  * The wild bootstrap (9,999 draws) is run once, on the mean of the 20 imputed outcomes, because 20 x 9,999 draws per specification is not needed
#    for a robustness check; seed = SEED_BASE + 9000.
source(here::here("R", "prep.R"))
library(fixest)
panel <- get_mart("mart_did_panel")
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))

sa_fit <- function(dat) {
  d <- sa_design(dat)
  est <- feols(y ~ i(cell, ref = "ref") | id + t, data = d, cluster = ~id)
  cf <- coef(est); V <- vcov(est)
  nm <- sub("^cell::", "", names(cf))
  cells <- tibble(name = nm, est = unname(cf), se = sqrt(diag(V))) |>
    mutate(g = as.integer(sub("^g([0-9]+)_e.*", "\\1", name)), e = ifelse(grepl("_em", name), -as.integer(sub(".*_em", "", name)), as.integer(sub(".*_e", "", name))))
  n_cell <- d |> filter(cell != "ref") |> count(cell, name = "n_obs")
  cells <- cells |> left_join(n_cell, by = c("name" = "cell"))
  # interaction-weighted aggregates (weights = number of treated state-quarters in the cell)
  ev <- cells |> group_by(e) |> summarise(att = sum(n_obs * est) / sum(n_obs), .groups = "drop")
  Vn <- V; rownames(Vn) <- colnames(Vn) <- nm
  se_of <- function(w, names) sqrt(drop(t(w) %*% Vn[names, names, drop = FALSE] %*% w))
  ev$se <- vapply(ev$e, function(ee) { c <- cells |> filter(e == ee); se_of(c$n_obs / sum(c$n_obs), c$name) }, numeric(1))
  post <- cells |> filter(e >= 0)
  w_post <- post$n_obs / sum(post$n_obs)
  list(cells = cells, event = ev, post_att = sum(w_post * post$est), post_se = se_of(w_post, post$name), post_names = post$name, post_w = w_post, design = d)
}

# (a) per imputation
sa <- lapply(seq_len(M_IMP), function(m) sa_fit(build_data(panel, imp = imps[[m]])))
sa_overall <- rubin(vapply(sa, `[[`, 0, "post_att"), vapply(sa, `[[`, 0, "post_se"))
sa_event <- bind_rows(lapply(seq_along(sa), function(m) sa[[m]]$event |> mutate(m = m))) |> group_by(e) |>
  group_modify(~ rubin(.x$att, .x$se)) |> ungroup()

# (wild cluster bootstrap for the post-period average: scripts/13b_wild_bootstrap.R)

# (b) placebo in time
placebo_fit <- function(dat, seed) {
  d <- dat |> filter(t >= LAUNCH_T, !is.na(y)) |>
    mutate(keep_row = g == 0 | t < g) |> filter(keep_row)
  d$g <- ifelse(d$g > 0, d$g - 4L, 0L)
  usable <- d |> filter(g > 0) |> distinct(g) |> filter(g - 1 >= LAUNCH_T) |> pull(g)
  d <- d |> filter(g == 0 | g %in% usable)
  d <- as.data.frame(d)
  set.seed(seed)
  r <- suppressWarnings(att_gt(yname = "y", tname = "t", idname = "id", gname = "g", data = d, xformla = ~1, est_method = "reg", control_group = "nevertreated",
                               base_period = "universal", clustervars = "id", bstrap = TRUE, biters = 999, cband = FALSE, allow_unbalanced_panel = TRUE, print_details = FALSE))
  a <- suppressWarnings(aggte(r, type = "simple", bstrap = TRUE, biters = 999, na.rm = TRUE))
  list(att = a$overall.att, se = a$overall.se, n_states = n_distinct(d$id), cohorts = sort(usable), n_treated = n_distinct(d$id[d$g > 0]))
}
pl <- lapply(seq_len(M_IMP), function(m) placebo_fit(build_data(panel, imp = imps[[m]]), SEED_BASE + 9100L + m))
pl_overall <- rubin(vapply(pl, `[[`, 0, "att"), vapply(pl, `[[`, 0, "se"))
placebo <- pl_overall |> mutate(n_states = pl[[1]]$n_states, n_treated_states = pl[[1]]$n_treated, placebo_cohorts_quarter_index = paste(pl[[1]]$cohorts, collapse = ","))
print(placebo)
saveRDS(list(sa_overall = sa_overall, sa_event = sa_event, wild = NULL, placebo = placebo, sa_cells = bind_rows(lapply(seq_along(sa), function(m) sa[[m]]$cells |> mutate(m = m)))),
        here::here("outputs", "cache", "sunab_wild_placebo.rds"))
print(sa_overall)
