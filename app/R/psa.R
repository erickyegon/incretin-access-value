# Probabilistic and one-way sensitivity analysis. The probabilistic run is vectorized (no loop) and reproduces the report's analysis exactly at the default scenario:
# same seed (20261004 + 5000), same draw order, same distributions (analysis/scripts/41_moduleE_model.R). tests/testthat checks it against bia_run() and key_numbers.csv.
PSA_SEED <- 20261004L + 5000L
PSA_DRAWS <- 10000L
# The report's script builds two gt tables before its probabilistic run, and each table draws a random id from the same random-number stream (two sample(letters, 10) calls). The app consumes the same two draws so that
# its stream, and therefore its default result, equals the published one (median $145.4M, 90% interval $58.1M to $319.9M).
PSA_BURN <- 2L

# quarterly path (B x 20) of incremental prescriptions per 1,000 enrollees for B draws of the nine effects; y35 is a vector of years 3-5 scenarios (one per draw). Same rules as bia_att_path().
psa_paths <- function(att9, y35) {
  B <- nrow(att9); e8 <- att9[, 9]; slope <- as.numeric(att9 %*% (0:8 - 4)) / 60; k <- 1:11
  tail <- matrix(0, B, 11)
  i <- y35 == "plateau"; if (any(i)) tail[i, ] <- e8[i]
  i <- y35 == "growth"; if (any(i)) tail[i, ] <- e8[i] + outer(slope[i], k)
  i <- y35 == "decline"; if (any(i)) tail[i, ] <- outer(e8[i], 1 - 0.5 * k / 11)
  pmax(cbind(att9, tail), 0)
}

# One stream of draws in the order of the report's analysis: nine normal effect draws (independent, or one shared draw), gross cost, the triangular prior authorization multiplier, years 3-5 scenario, rebate.
psa_stream <- function(inp, p, B, common, random_y35) {
  z <- if (common) matrix(rep(rnorm(B), 9), B, 9) else sapply(1:9, function(i) rnorm(B))
  g <- runif(B, inp$gross$low, inp$gross$high); u <- runif(B)
  a <- 0.5; b <- 1.25; m <- min(max(p$pa_mult, a), b); Fm <- (m - a) / (b - a)
  pa <- ifelse(u < Fm, a + sqrt(u * (b - a) * (m - a)), b - sqrt((1 - u) * (b - a) * (b - m)))
  y <- if (random_y35) sample(bia_years35, B, replace = TRUE) else rep(p$y35, B)
  ub <- runif(B); lo <- inp$rebate$low; hi <- pmax(lo, 1 - inp$announced / g); rb <- lo + (hi - lo) * ub
  list(z = z, g = g, pa = pa, y = y, rb = rb)
}

#' Probabilistic sensitivity analysis for scenario p. Returns the five-year net cost and the net cost by year for each draw.
psa_draws <- function(inp, p, B = PSA_DRAWS, seed = PSA_SEED, common = FALSE, random_y35 = TRUE) {
  set.seed(seed); for (i in seq_len(PSA_BURN)) invisible(sample(letters, 10, replace = TRUE))
  if (common) invisible(psa_stream(inp, p, B, FALSE, random_y35))   # the report draws the independent stream first, then the shared-draw stream
  s <- psa_stream(inp, p, B, common, random_y35)
  att9 <- pmax(sweep(s$z, 2, inp$att$se, "*") + rep(inp$att$estimate, each = B), 0)
  rx <- psa_paths(att9, s$y) * (p$plan / 1000) * s$pa * p$uptake_mult
  unit <- if (identical(p$price, "announced")) rep(inp$announced, B) else s$g * (1 - s$rb)
  net_q <- rx * unit
  yr <- rep(1:5, each = 4); annual <- sapply(1:5, function(k) rowSums(net_q[, yr == k, drop = FALSE]))
  list(net5 = rowSums(net_q), annual = annual, B = B)
}
psa_summary <- function(d) { q <- stats::quantile(d$net5, c(0.05, 0.5, 0.95)); c(p05 = unname(q[1]), median = unname(q[2]), p95 = unname(q[3])) }
# probability that the cost stays within a budget: five-year total, or the highest single year
psa_prob_within <- function(d, budget, basis = c("five_year", "peak_year")) { basis <- match.arg(basis); x <- if (basis == "five_year") d$net5 else apply(d$annual, 1, max); mean(x <= budget) }

#' One-way sensitivity (tornado) around scenario p: the ranges of the report (moduleE_tornado.csv). Returns net five-year cost at the low and high end of each parameter.
tornado_table <- function(inp, p) {
  five <- function(q) bia_run(q)$total$five_year_net
  mod <- function(...) { q <- p; a <- list(...); for (n in names(a)) q[[n]] <- a[[n]]; q }
  rows <- list(
    list("Module C effect (95% CI of every event time)", mod(att9 = inp$att$ci_low), mod(att9 = inp$att$ci_high), "lower CI", "upper CI"),
    list("Prior authorization multiplier", mod(pa_mult = 0.5), mod(pa_mult = 1.25), "0.5", "1.25"),
    list("Years 3-5 scenario", mod(y35 = "decline"), mod(y35 = "growth"), "decline", "growth"),
    list("Gross cost per prescription", mod(gross = inp$gross$low), mod(gross = inp$gross$high), usd(inp$gross$low), usd(inp$gross$high)),
    list("Rebate share", mod(price = "rebate", rebate = inp$rebate$high), mod(price = "rebate", rebate = inp$rebate$low), paste0(formatC(100 * inp$rebate$high, format = "f", digits = 1), "%"), paste0(formatC(100 * inp$rebate$low, format = "f", digits = 1), "%")),
    list("Price scenario", mod(price = "announced"), p, "$245 net", "current"),
    list("Uptake multiplier", mod(uptake_mult = 0.75), mod(uptake_mult = 1.25), "0.75", "1.25"))
  d <- do.call(rbind, lapply(rows, function(r) data.frame(parameter = r[[1]], net_low = five(r[[2]]), net_high = five(r[[3]]), low_label = r[[4]], high_label = r[[5]], stringsAsFactors = FALSE)))
  d$span <- abs(d$net_high - d$net_low); d[order(-d$span), ]
}
