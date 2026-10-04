# Module F: discrete choice experiment (DCE) design pack. NO fieldwork, NO respondents: this script generates a design and runs simulations only.
# Run from the analysis folder (renv library):  cd analysis; Rscript ../research_pack/dce_design.R
# Design: two unlabelled alternatives per task (two hypothetical coverage policies), five attributes with three levels, effects coding.
# Efficient design: idefix::Modfed (modified Fedorov), zero prior (D0-error: no prior information on preferences is assumed; none was invented).
# Sample size: (1) Johnson-Orme rule of thumb N >= 500 c / (t a); (2) simulation of power under ILLUSTRATIVE true preference weights (assumptions, labelled).
suppressPackageStartupMessages({ library(idefix); library(survival); library(dplyr) })
out <- "../research_pack/design"; dir.create(out, showWarnings = FALSE, recursive = TRUE)
SEED <- 20261004 + 6000L; set.seed(SEED)

attrs <- list(
  `BMI threshold` = c("27 or more (with a comorbidity)", "30 or more", "35 or more"),
  `Comorbidity requirement` = c("None", "At least 1 weight-related condition", "At least 2 weight-related conditions"),
  `Prior authorization renewal` = c("Every 6 months", "Every 12 months", "No renewal after initial approval"),
  `Step therapy` = c("None", "3-month supervised lifestyle program first", "Trial of a lower-cost agent first"),
  `Patient out-of-pocket cost per month` = c("$0", "$25", "$75"))
# "best-to-worst" order for the coverage-access view, used only to flag dominated tasks (one alternative at least as good on every attribute)
better_is_lower <- c(TRUE, TRUE, FALSE, TRUE, TRUE)   # BMI (lower = broader access), comorbidity (none = broader), renewal (longer = easier), step (none = easier), cost (lower = easier)
lv <- unname(sapply(attrs, length)); n_par <- sum(lv - 1); n_alts <- 2; n_tasks_total <- 24; n_blocks <- 2; t_per_block <- n_tasks_total / n_blocks
cand <- Profiles(lvls = lv, coding = rep("E", length(lv)))
level_idx <- function(des_eff) { # decode effects coding: level 1 = (1,0), level 2 = (0,1), level 3 = (-1,-1), two columns per attribute
  m <- as.matrix(des_eff); sapply(seq_along(lv), function(j) { x <- m[, (2 * j - 1):(2 * j), drop = FALSE]; ifelse(x[, 1] == 1 & x[, 2] == 0, 1L, ifelse(x[, 1] == 0 & x[, 2] == 1, 2L, 3L)) }) }
zero <- matrix(0, nrow = 1, ncol = n_par)

dominated <- function(idx_a, idx_b) { # TRUE when one alternative is at least as good as the other on every attribute (and not identical)
  ord_a <- ifelse(better_is_lower, -idx_a, idx_a); ord_b <- ifelse(better_is_lower, -idx_b, idx_b); (all(ord_a >= ord_b) || all(ord_b >= ord_a)) }

best <- NULL
for (attempt in 1:6) {
  fit <- Modfed(cand.set = cand, n.sets = n_tasks_total, n.alts = n_alts, alt.cte = c(0, 0), par.draws = zero, n.start = 6, parallel = FALSE, no.choice = FALSE)
  des <- fit$BestDesign$design; fit_err <- fit$BestDesign$DB.error; idx <- level_idx(des); task_id <- rep(seq_len(n_tasks_total), each = n_alts)
  dom <- sapply(seq_len(n_tasks_total), function(s) dominated(idx[task_id == s, ][1, ], idx[task_id == s, ][2, ]))
  cat("attempt", attempt, "D0-error", round(fit_err, 4), "dominated tasks", sum(dom), "\n")
  if (is.null(best) || sum(dom) < best$ndom || (sum(dom) == best$ndom && fit_err < best$err)) best <- list(des = des, idx = idx, err = fit_err, ndom = sum(dom), dom = dom)
  if (sum(dom) == 0) break
}
des <- best$des; idx <- best$idx; task_id <- rep(seq_len(n_tasks_total), each = n_alts)
# drop dominated tasks is not possible without losing the design size: report the count; if any remain they are flagged in the table
# blocking: random splits of the 24 tasks into 2 blocks of 12; choose the split with the lowest worst-block D0-error
blk_err <- function(tasks) { rows <- which(task_id %in% tasks); d <- des[rows, , drop = FALSE]; tryCatch(DBerr(par.draws = zero, des = d, n.alts = n_alts), error = function(e) NA_real_) }
bsplit <- NULL
for (b in 1:600) { perm <- sample(seq_len(n_tasks_total)); a <- sort(perm[1:t_per_block]); bb <- sort(perm[-(1:t_per_block)]); e <- c(blk_err(a), blk_err(bb)); if (anyNA(e)) next
  w <- max(e); if (is.null(bsplit) || w < bsplit$worst) bsplit <- list(a = a, b = bb, e = e, worst = w) }
block_of_task <- integer(n_tasks_total); block_of_task[bsplit$a] <- 1; block_of_task[bsplit$b] <- 2

# design table (human-readable levels) and balance
dtab <- do.call(rbind, lapply(seq_len(n_tasks_total), function(s) { r <- which(task_id == s); data.frame(block = block_of_task[s], task = s, alternative = c("Policy A", "Policy B"), idx[r, , drop = FALSE], check.names = FALSE) }))
colnames(dtab)[4:8] <- names(attrs)
for (j in seq_along(attrs)) dtab[[names(attrs)[j]]] <- attrs[[j]][dtab[[names(attrs)[j]]]]
dtab$dominated_task <- rep(best$dom, each = n_alts)
dtab <- dtab[order(dtab$block, dtab$task), ]; dtab$task_in_block <- ave(dtab$task, dtab$block, FUN = function(x) match(x, sort(unique(x))))
write.csv(dtab, file.path(out, "dce_design.csv"), row.names = FALSE)
bal <- do.call(rbind, lapply(seq_along(attrs), function(j) { t <- table(factor(dtab[[names(attrs)[j]]], levels = attrs[[j]])); data.frame(attribute = names(attrs)[j], level = names(t), appearances = as.integer(t), share_pct = round(100 * as.integer(t) / sum(t), 1)) }))
write.csv(bal, file.path(out, "dce_level_balance.csv"), row.names = FALSE)
att_tab <- do.call(rbind, lapply(seq_along(attrs), function(j) data.frame(attribute = names(attrs)[j], level_1 = attrs[[j]][1], level_2 = attrs[[j]][2], level_3 = attrs[[j]][3])))
write.csv(att_tab, file.path(out, "dce_attributes.csv"), row.names = FALSE)

# ---- sample size 1: Johnson-Orme rule of thumb -------------------------------------------------------------------------------------------------------------------
c_max <- max(lv); jo <- 500 * c_max / (t_per_block * n_alts)
# ---- sample size 2: simulation under illustrative true weights (assumptions, labelled; not estimated from any data) -----------------------------------------------------
# true utility steps between adjacent levels of each attribute (logit units): BMI, comorbidity, renewal, step therapy, cost. The smallest step (0.20) is the effect the study must detect.
true_steps <- list(c(0.30, 0.30), c(0.40, 0.40), c(0.20, 0.20), c(0.35, 0.35), c(0.50, 0.50))
partworth <- function(steps) { u <- c(0, cumsum(steps)); u - mean(u) }      # effects-coded part-worths, centred, level 1 lowest utility
pw <- lapply(true_steps, partworth)
# orientation: utilities rise with the "easier access" end; to keep the sign convention simple, level 3 of BMI/comorbidity/step/cost is worst; reverse those so utility falls with level
for (j in c(1, 2, 4, 5)) pw[[j]] <- rev(pw[[j]])
util_of <- function(ix) rowSums(sapply(seq_along(pw), function(j) pw[[j]][ix[, j]]))
sim_power <- function(N, reps = 200) {
  hits <- matrix(FALSE, reps, length(attrs)); se_min <- numeric(reps)
  for (r in seq_len(reps)) {
    blk <- sample(1:2, N, replace = TRUE); rowsets <- lapply(1:N, function(i) which(block_of_task[task_id] == blk[i]))
    d <- do.call(rbind, lapply(seq_len(N), function(i) { rr <- rowsets[[i]]; x <- idx[rr, , drop = FALSE]; data.frame(resp = i, task = rep(seq_len(t_per_block), each = n_alts), alt = rep(1:2, t_per_block), x) }))
    u <- util_of(as.matrix(d[, 4:8])) + (-log(-log(runif(nrow(d))))); d$stratum <- paste(d$resp, d$task)
    d$chosen <- as.integer(ave(u, d$stratum, FUN = function(v) v == max(v)))
    # effects-coded columns: level 1 / level 2 vs level 3 reference sum-to-zero
    X <- do.call(cbind, lapply(seq_along(attrs), function(j) { v <- d[[paste0("X", j)]]; cbind(as.integer(v == 1) - as.integer(v == 3), as.integer(v == 2) - as.integer(v == 3)) })); colnames(X) <- paste0("a", rep(seq_along(attrs), each = 2), "_", rep(1:2, length(attrs)))
    m <- tryCatch(clogit(d$chosen ~ X + strata(d$stratum)), error = function(e) NULL); if (is.null(m)) next
    co <- coef(m); V <- vcov(m)
    for (j in seq_along(attrs)) { ii <- (2 * j - 1):(2 * j); w <- tryCatch(as.numeric(t(co[ii]) %*% solve(V[ii, ii]) %*% co[ii]), error = function(e) 0); hits[r, j] <- pchisq(w, 2, lower.tail = FALSE) < 0.05 }
    # smallest contrast: attribute 3, level 1 vs level 2 (true step 0.20): Wald z
    cvec <- c(1, -1); b <- sum(cvec * co[5:6]); se <- sqrt(as.numeric(t(cvec) %*% V[5:6, 5:6] %*% cvec)); se_min[r] <- se
  }
  data.frame(N = N, t(setNames(colMeans(hits), paste0("power_", gsub("[^A-Za-z]", "", names(attrs))))), mean_se_smallest_contrast = mean(se_min[se_min > 0]))
}
colnames(idx) <- paste0("X", seq_along(attrs));
Ns <- c(30, 50, 75, 100, 150, 200, 300)
power <- do.call(rbind, lapply(Ns, function(N) { cat("simulating N =", N, "\n"); sim_power(N) }))
write.csv(power, file.path(out, "dce_power_simulation.csv"), row.names = FALSE)

summ <- data.frame(item = c("attributes", "levels per attribute", "alternatives per task", "tasks in the design", "blocks", "tasks per respondent", "parameters (effects coding)", "D0-error of the full design (zero prior)",
                            "D0-error, block 1", "D0-error, block 2", "dominated tasks in the final design", "Johnson-Orme minimum respondents", "random seed", "package versions"),
                   value = c(length(attrs), paste(lv, collapse = ","), n_alts, n_tasks_total, n_blocks, t_per_block, n_par, round(best$err, 4), round(bsplit$e[1], 4), round(bsplit$e[2], 4), best$ndom, ceiling(jo), SEED,
                             paste0("idefix ", as.character(packageVersion("idefix")), "; survival ", as.character(packageVersion("survival")))))
write.csv(summ, file.path(out, "dce_design_summary.csv"), row.names = FALSE)
print(summ); print(power)
