# The central case, every sensitivity endpoint and the probabilistic analysis reproduce the published numbers (key_numbers.csv, via data/key_facts.csv, and the report's tornado table).
central <- bia_run(BASE)
test_that("the central case reproduces key_numbers.csv", {
  t <- central$total
  expect_equal(m1(t$five_year_net), kf("e_net5")); expect_equal(sprintf("%.2f", t$pmpm_net), kf("e_pmpm")); expect_equal(m1(t$five_year_gross), kf("e_gross5"))
  expect_equal(formatC(round(t$net_cost_per_user_year), format = "d", big.mark = ","), kf("e_per_user_year")); expect_equal(formatC(round(t$net_cost_per_member_year_continuous), format = "d", big.mark = ","), kf("e_per_member_year_cont"))
  expect_equal(formatC(round(central$annual$treated_members[5]), format = "d", big.mark = ","), kf("e_users")); expect_equal(formatC(round(central$annual$eligible_pool[5]), format = "d", big.mark = ","), kf("e_pool"))
  expect_equal(m1(central$annual$net[1:3]), c(kf("e_year1_net"), kf("e_year2_net"), kf("e_year3_net")))
})
test_that("scenario endpoints match key_numbers.csv", {
  net <- function(...) { p <- BASE; a <- list(...); for (n in names(a)) p[[n]] <- a[[n]]; bia_run(p)$total$five_year_net }
  expect_equal(m1(net(pa_mult = 0.5)), kf("e_pa_05")); expect_equal(m1(net(pa_mult = 0.75)), kf("e_pa_075")); expect_equal(m1(net(pa_mult = 1.25)), kf("e_pa_125"))
  expect_equal(m1(net(price = "announced")), kf("e_announced5")); expect_equal(sprintf("%.2f", bia_run(modifyList(BASE, list(price = "announced")))$total$pmpm_net), kf("e_announced_pmpm"))
  expect_equal(m1(net(y35 = "decline", rebate = INP$rebate$high)), kf("e_scen_min")); expect_equal(m1(net(y35 = "growth", rebate = INP$rebate$low)), kf("e_scen_max"))
})
test_that("the tornado equals the report's one-way sensitivity table", {
  tor <- tornado_table(INP, BASE)
  expect_equal(nrow(tor), nrow(tornado_ref)); expect_setequal(tor$parameter, tornado_ref$parameter)
  m <- merge(tor, tornado_ref, by = "parameter", suffixes = c("", "_ref"))
  expect_equal(round(m$net_low), round(m$net_low_ref), tolerance = 1e-6); expect_equal(round(m$net_high), round(m$net_high_ref), tolerance = 1e-6)
  expect_equal(c(m1(min(tor$net_low[1], tor$net_high[1])), m1(max(tor$net_low[1], tor$net_high[1]))), c(kf("e_tornado1_low"), kf("e_tornado1_high")))
})
test_that("the probabilistic analysis reproduces the report and is reproducible", {
  d <- psa_draws(INP, BASE); s <- psa_summary(d)
  expect_equal(m1(s[["median"]]), kf("e_psa_median")); expect_equal(paste(m1(s[["p05"]]), "to", m1(s[["p95"]])), kf_ci("e_psa_median"))
  dc <- psa_draws(INP, BASE, common = TRUE); sc <- psa_summary(dc); expect_equal(paste(m1(sc[["p05"]]), "to", m1(sc[["p95"]])), kf("e_psa_common"))
  expect_identical(psa_draws(INP, BASE)$net5, d$net5)                                   # same seed, same draws
  expect_false(identical(psa_draws(INP, BASE, seed = 1L)$net5, d$net5))
})
test_that("the vectorized draws equal the model run draw by draw", {
  set.seed(PSA_SEED); for (i in seq_len(PSA_BURN)) invisible(sample(letters, 10, replace = TRUE))
  B <- 40L; s <- psa_stream(INP, BASE, B, FALSE, TRUE)
  att9 <- pmax(sweep(s$z, 2, INP$att$se, "*") + rep(INP$att$estimate, each = B), 0)
  net <- vapply(seq_len(B), function(i) { p <- BASE; p$att9 <- att9[i, ]; p$gross <- s$g[i]; p$pa_mult <- s$pa[i]; p$y35 <- s$y[i]; p$rebate <- s$rb[i]; bia_run(p)$total$five_year_net }, numeric(1))
  v <- rowSums(psa_paths(att9, s$y) * (BASE$plan / 1000) * s$pa * BASE$uptake_mult * s$g * (1 - s$rb))
  expect_equal(v, net, tolerance = 1e-9)
})
test_that("plan sizes from a state's enrollment scale the cost linearly", {
  for (code in c("CA", "SC", "WY")) { n <- ENROLL$enrollment[ENROLL$state_code == code]; expect_true(n > 1000)
    expect_equal(bia_run(modifyList(BASE, list(plan = n)))$total$five_year_net, n / 1e6 * central$total$five_year_net, tolerance = 1e-9) }
})
test_that("the app data files hold only aggregates and the expected columns", {
  expect_setequal(names(RATES), c("state_code", "quarter_label", "rate", "coverage_active", "is_preliminary")); expect_equal(nrow(STATES), 51); expect_equal(sum(STATES$group == "primary"), 10); expect_equal(sum(STATES$group == "sensitivity"), 7); expect_equal(sum(STATES$group == "never"), 34)
  expect_true(all(c("event_time", "att", "ci_low", "ci_high") %in% names(ES))); expect_equal(sum(SPECS$estimable), 16)
})
test_that("budget inputs are validated with friendly messages", {
  shiny::testServer(mod_budget_server, {
    session$setInputs(plan_mode = "plan", plan = "1,000,000", state = "CA", adult_share = 57.9, elig_share = 52.0, effect = "est", uptake = 1, y35 = "plateau", pa = 1, price = "rebate", rebate = 51.223, gross = 1186.2097)
    expect_equal(m1(run()$total$five_year_net), kf("e_net5"))
    expect_equal(params()$plan, 1e6); expect_equal(round(params()$plan * params()$adult_share * params()$eligible_share), 300948)  # the boxes show 57.9 and 52.0, the exact defaults are used
    session$setInputs(adult_share = 60); expect_equal(params()$adult_share, 0.6); session$setInputs(adult_share = 57.9)
    session$setInputs(plan = "2,000,000"); expect_equal(params()$plan, 2e6); session$setInputs(plan = "1,000,000")
    session$setInputs(plan = -5); expect_error(params(), class = "shiny.silent.error")
    session$setInputs(plan = 1e6, rebate = 120); expect_error(params(), class = "shiny.silent.error")
    session$setInputs(rebate = 51.223, plan_mode = "state", state = "CA"); expect_equal(params()$plan, ENROLL$enrollment[ENROLL$state_code == "CA"])
  })
})

test_that("evidence selector, sources, wording, tornado labels and the compare preload", {
  ch <- state_selector(); expect_equal(unname(ch[1]), "AVG"); expect_equal(unname(ch[2]), "MI"); expect_equal(length(ch), 52); expect_equal(sum(names(ch) == "Michigan"), 1)
  expect_equal(spec_all(), "all 15 estimable")
  sc <- STATES[STATES$state_code == "SC", ]; expect_match(sc$start_source, "Milliman SFY 2026"); expect_match(sc$start_source, "MB 24-066"); expect_match(sc$criteria_source_type, "news report"); expect_false(identical(sc$start_source, sc$document))
  avg <- stats::aggregate(rate ~ quarter_label, RATES[RATES$state_code %in% STATES$state_code[STATES$group == "primary"], ], mean); expect_equal(nrow(avg), 33)
  tt <- tornado_table(INP, BASE); expect_true(all(c("lower CI", "upper CI", "0.5", "1.25", "decline", "growth") %in% c(tt$low_label, tt$high_label)))
  expect_true(any(grepl("^23.1%$", c(tt$low_label, tt$high_label))) && any(grepl("^79.3%$", c(tt$low_label, tt$high_label))))
  shiny::testServer(mod_compare_server, args = list(scn = list(params = function() BASE)), { expect_equal(nrow(store()), 3); expect_equal(sprintf("%.1f", store()$five_year_net[2] / 1e6), "161.3") })
})
