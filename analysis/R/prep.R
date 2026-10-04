# Data preparation, suppression imputation, estimation and combination helpers for Module C (pre-specified in analysis_plan_moduleC.md).
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(did)
})
source(here::here("R", "db.R"))

LAUNCH_T <- 14L      # 2021 Q2: first quarter Wegovy exists (index 1 = 2018 Q1)
M_IMP <- 20L
SEED_BASE <- 20261004L

qidx <- function(year, quarter) (as.integer(year) - 2018L) * 4L + as.integer(quarter)
label_to_idx <- function(label) ifelse(is.na(label), NA_integer_, qidx(substr(label, 1, 4), substr(label, 6, 6)))
idx_to_label <- function(i) paste0(2018L + (i - 1L) %/% 4L, "Q", (i - 1L) %% 4L + 1L)

# ---- suppression imputation ---------------------------------------------------------------------------------------------------------
# One imputation of every suppressed cell (state x NDC x quarter x utilization type). Each cell holds 0 to 10 prescriptions.
# residual_usable groups: the group's suppressed cells (all jurisdictions: n_suppressed_rows_same_ndc_quarter of them, of which the panel states'
#   cells are in the mart) are drawn jointly so they sum to the national residual, each capped at 10: multinomial with equal probabilities, redrawn
#   when any cell exceeds the cap; after `max_try` failed redraws a capped sequential allocation (units go to uniformly chosen cells that still have
#   room) is used and counted. A residual above 10 x cells sets every cell to 10 (counted).
# other groups: each cell independent, discrete uniform on 0..10.
draw_group <- function(R, m, max_try = 200L) {
  if (R >= 10 * m) return(list(x = rep(10L, m), mode = "all10"))
  for (i in seq_len(max_try)) {
    x <- as.integer(rmultinom(1, R, rep(1 / m, m)))
    if (max(x) <= 10L) return(list(x = x, mode = "multinomial"))
  }
  x <- integer(m)
  for (u in seq_len(R)) {
    room <- which(x < 10L)
    j <- room[sample.int(length(room), 1)]
    x[j] <- x[j] + 1L
  }
  list(x = x, mode = "sequential")
}

impute_once <- function(cells, seed) {
  set.seed(seed)
  cells <- cells |> mutate(row_id = row_number())
  cells$value <- NA_integer_
  usable <- cells |> filter(residual_usable) |> group_by(ndc11, year, quarter, utilization_type)
  keys <- usable |> group_keys()
  idx <- usable |> group_rows()
  modes <- character(length(idx))
  for (i in seq_along(idx)) {
    rows <- idx[[i]]
    u <- usable[rows, ]
    m <- max(u$n_suppressed_rows_same_ndc_quarter[1], length(rows))
    d <- draw_group(as.integer(round(u$residual_rx[1])), m)
    # the panel cells are a random subset of the m jointly drawn cells (the rest are other jurisdictions' cells)
    pick <- if (m == length(rows)) seq_len(m) else sample.int(m, length(rows))
    cells$value[u$row_id] <- d$x[pick]
    modes[i] <- d$mode
  }
  non <- is.na(cells$value)
  cells$value[non] <- sample.int(11L, sum(non), replace = TRUE) - 1L
  list(cells = cells, modes = table(modes), n_nonusable_cells = sum(non))
}

aggregate_imputed <- function(cells) {
  cells |> group_by(state_code, quarter_label, product_group, utilization_type) |> summarise(imp = sum(value), .groups = "drop")
}

# ---- analysis data ---------------------------------------------------------------------------------------------------------------------
# panel: mart_did_panel; imp: aggregated draws (or NULL); bound: "mi" (use imp), "lower" (suppressed = 0), "upper" (suppressed = 10 each)
build_data <- function(panel, imp = NULL, outcome = "obesity_wz", denominator = "medicaid", util = "ALL", bound = "mi", window_end = "2025Q3",
                       cohort_col = "first_treated_quarter", include_sensitivity = NULL, drop_states = character(), drop_flagged = FALSE,
                       drop_caveat = FALSE, weight = FALSE) {
  # reporting gaps (Amendment 2): MCOU or FFSU not reported although the same state reported it the previous quarter, or flagged anomalous
  d <- panel |> mutate(t = qidx(year, quarter), qd = as.Date(quarter_start)) |> arrange(state_code, t) |> group_by(state_code) |>
    mutate(gap = (!sdud_reported_ffsu & lag(sdud_reported_ffsu, default = FALSE)) | (!sdud_reported_mcou & lag(sdud_reported_mcou, default = FALSE)) | sdud_anomalous) |> ungroup()
  if (is.null(include_sensitivity)) d <- d |> filter(analysis_group != "sensitivity")
  d <- d |> filter(t <= label_to_idx(window_end), !state_code %in% drop_states)
  ffsu_rate <- d[[paste0("rate_", outcome, "_ffs_per_1000_ffs_medicaid")]]
  ffsu_obs <- ifelse(is.na(ffsu_rate) & !is.na(d$enrollment_ffs_medicaid_assumed) & d$enrollment_ffs_medicaid_assumed == 0, 0, ffsu_rate * d$enrollment_ffs_medicaid_assumed / 1000)   # FFSU count rebuilt from the panel rate (0 where the state has no FFS enrollees)
  obs <- if (util == "ALL") d[[paste0("rx_", outcome, "_observed")]] else if (util == "FFSU") ffsu_obs else d[[paste0("rx_", outcome, "_observed")]] - ffsu_obs   # MCOU = all observed minus FFSU (sensitivity 14)
  ub <- d[[paste0("rx_", outcome, "_upper_bound")]]
  if (util != "ALL") ub <- NA_real_   # the upper-bound run is defined for all utilization types only
  extra <- switch(bound, lower = 0,
    upper = if (util == "ALL") ub - obs else NA_real_,
    mi = {
      if (is.null(imp)) stop("imputation needed for bound = 'mi'")
      i <- imp |> filter(product_group == outcome)
      i <- if (util == "ALL") i |> group_by(state_code, quarter_label) |> summarise(imp = sum(imp), .groups = "drop") else i |> filter(utilization_type == util) |> select(state_code, quarter_label, imp)
      d |> select(state_code, quarter_label) |> left_join(i, by = c("state_code", "quarter_label")) |> pull(imp) |> coalesce(0)
    })
  d$rx <- obs + extra
  denom <- switch(denominator, medicaid = d$enrollment_medicaid_avg, medicaid_chip = d$enrollment_medicaid_chip_avg,
                  ffs = d$enrollment_ffs_medicaid_assumed, mc = d$enrollment_medicaid_avg - d$enrollment_ffs_medicaid_assumed)   # mc: managed-care enrollment = total minus the assumed FFS enrollment
  d$y <- 1000 * d$rx / ifelse(denom > 0, denom, NA_real_)
  d$cohort_label <- d[[cohort_col]]
  if (!is.null(include_sensitivity)) {
    sens <- d$analysis_group == "sensitivity"
    d$cohort_label[sens] <- d[[include_sensitivity]][sens]
  }
  d$g <- ifelse(d$analysis_group == "never_treated" | is.na(d$cohort_label), 0L, label_to_idx(d$cohort_label))
  if (drop_flagged) d$y[d$gap] <- NA
  if (drop_caveat) d$y[d$definition_caveat] <- NA
  d <- d |> mutate(id = as.integer(factor(state_code)), w = 1)
  if (weight) {
    w19 <- panel |> filter(year == 2019) |> group_by(state_code) |> summarise(w = mean(enrollment_medicaid_avg, na.rm = TRUE), .groups = "drop")
    d <- d |> select(-w) |> left_join(w19, by = "state_code")
  }
  d |> select(id, state_code, t, g, y, w, analysis_group, quarter_label, definition_caveat, gap, year, quarter) |> arrange(id, t)
}

# ---- estimation ------------------------------------------------------------------------------------------------------------------------
# att_gt per the plan (no covariates, reg, universal base period, clustered by state, multiplier bootstrap with simultaneous bands). Pre-treatment
# cells before the launch quarter (mechanical zeros) are removed from the group-time object before aggregation: the plan allows only post-launch
# calendar quarters as evidence for leads. Post-treatment cells are never before launch (the earliest cohort starts after it).
run_att <- function(dat, control = "notyettreated", weighted = FALSE, seed = 1L, biters = 999L, min_e = -8, max_e = 12, unbalanced = FALSE) {
  set.seed(seed)
  dd <- as.data.frame(dat |> filter(!is.na(y)))
  res <- att_gt(yname = "y", tname = "t", idname = "id", gname = "g", data = dd, xformla = ~1, est_method = "reg", control_group = control,
                base_period = "universal", clustervars = "id", bstrap = TRUE, biters = biters, cband = TRUE, weightsname = if (weighted) "w" else NULL,
                allow_unbalanced_panel = unbalanced, print_details = FALSE, pl = FALSE)
  keep <- !(res$t < LAUNCH_T & res$t < res$group)   # drop pre-treatment cells before launch
  f <- res
  f$group <- res$group[keep]; f$t <- res$t[keep]; f$att <- res$att[keep]
  f$inffunc <- res$inffunc[, keep, drop = FALSE]
  if (!is.null(res$V_analytical)) f$V_analytical <- res$V_analytical[keep, keep, drop = FALSE]
  if (!is.null(res$se)) f$se <- res$se[keep]
  if (!is.null(res$c)) f$c <- res$c
  set.seed(seed + 1L)
  list(raw = res,
       simple = aggte(f, type = "simple", bstrap = TRUE, biters = biters, cband = FALSE, na.rm = TRUE),
       group = aggte(f, type = "group", bstrap = TRUE, biters = biters, cband = FALSE, na.rm = TRUE),
       dynamic = aggte(f, type = "dynamic", bstrap = TRUE, biters = biters, cband = TRUE, min_e = min_e, max_e = max_e, na.rm = TRUE))
}

# ---- Rubin's rules ----------------------------------------------------------------------------------------------------------------------
rubin <- function(est, se) {
  if (anyNA(est) || anyNA(se)) return(tibble(estimate = mean(est), se = NA_real_, ci_low = NA_real_, ci_high = NA_real_, fmi = NA_real_, df = NA_real_))
  m <- length(est); qbar <- mean(est); ubar <- mean(se^2); b <- if (m > 1) var(est) else 0
  tvar <- ubar + (1 + 1 / m) * b
  lam <- if (tvar > 0) (1 + 1 / m) * b / tvar else 0
  df <- if (b > 0) (m - 1) * (1 + ubar / ((1 + 1 / m) * b))^2 else Inf
  tcrit <- qt(0.975, df = max(df, 2))
  tibble(estimate = qbar, se = sqrt(tvar), ci_low = qbar - tcrit * sqrt(tvar), ci_high = qbar + tcrit * sqrt(tvar), fmi = lam, df = df)
}

combine_overall <- function(fits, which = "simple") {
  est <- vapply(fits, function(f) f[[which]]$overall.att, numeric(1)); se <- vapply(fits, function(f) f[[which]]$overall.se, numeric(1))
  rubin(est, se)
}
combine_dynamic <- function(fits) {
  dd <- bind_rows(lapply(seq_along(fits), function(m) {
    a <- fits[[m]]$dynamic
    tibble(m = m, e = a$egt, att = a$att.egt, se = a$se.egt, crit = a$crit.val.egt)
  }))
  dd |> group_by(e) |> group_modify(~ bind_cols(rubin(.x$att, .x$se), tibble(crit_simultaneous = mean(.x$crit), n_imputations = nrow(.x)))) |> ungroup() |>
    mutate(band_low = estimate - crit_simultaneous * se, band_high = estimate + crit_simultaneous * se)
}

# ---- tidy extraction of one fit ------------------------------------------------------------------------------------------------------------
extract_fit <- function(r, dat) {
  raw <- r$raw
  cells <- tibble(g = raw$group, t = raw$t, att = raw$att, se = raw$se) |>
    mutate(e = t - g, kept = !(t < LAUNCH_T & t < g), launch_pre = t < LAUNCH_T & t < g)
  csize <- dat |> filter(g > 0) |> distinct(id, g) |> count(g, name = "n_states")
  contrib <- cells |> filter(kept, e >= -8, e <= 12, is.finite(att)) |> left_join(csize, by = "g") |>
    group_by(e) |> summarise(n_cohorts = n_distinct(g), n_states = sum(n_states[!duplicated(g)]), .groups = "drop")
  a <- r$dynamic
  list(simple = list(overall.att = r$simple$overall.att, overall.se = r$simple$overall.se),
       group = list(overall.att = r$group$overall.att, overall.se = r$group$overall.se, egt = r$group$egt, att.egt = r$group$att.egt, se.egt = r$group$se.egt),
       dynamic = list(egt = a$egt, att.egt = a$att.egt, se.egt = a$se.egt, crit.val.egt = a$crit.val.egt,
                      inf = a$inf.function$dynamic.inf.func.e, n_units = length(unique(dat$id))),
       cells = cells, contrib = contrib,
       n_states = n_distinct(dat$state_code), n_state_quarters = sum(!is.na(dat$y)),
       n_treated_states = n_distinct(dat$state_code[dat$g > 0]), n_never_states = n_distinct(dat$state_code[dat$g == 0]))
}

# Sun-Abraham design: cohort x event-time cells (post-launch leads only, e = -1 reference) for state-quarters of treated states
sa_design <- function(dat) {
  d <- dat |> filter(!is.na(y)) |> mutate(e = ifelse(g > 0, t - g, NA_integer_))
  d$cell <- ifelse(d$g > 0 & d$e >= -8 & d$e <= 12 & d$e != -1 & (d$e >= 0 | d$t >= LAUNCH_T), paste0("g", d$g, "_e", ifelse(d$e < 0, paste0("m", -d$e), d$e)), "ref")
  d
}
