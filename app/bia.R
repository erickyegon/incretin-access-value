# Budget impact model for Module E (plan_moduleE.md). Pure functions, used by scripts/41_moduleE_model.R and copied into app/ for the Shiny app.
# Units: ATT = prescriptions per 1,000 enrollees per quarter (Module C, e = 0..8); one prescription is about one month of drug (assumption, checked against SDUD
# units per prescription); money in USD; plan size in enrollees.

bia_years35 <- c("plateau", "growth", "decline")

#' Quarterly incremental prescriptions per 1,000 enrollees for quarters 1..20 given the nine Module C estimates (e = 0..8) and a years 3-5 scenario.
#' plateau: held at the e = 8 level; growth: the linear trend of e = 0..8 extended; decline: falling linearly from the e = 8 level to half of it by quarter 20.
bia_att_path <- function(att9, y35 = "plateau") {
  stopifnot(length(att9) == 9, y35 %in% bia_years35)
  e <- 0:8; slope <- unname(coef(lm(att9 ~ e))[2]); k <- 1:11; e8 <- att9[9]
  tail <- switch(y35, plateau = rep(e8, 11), growth = e8 + slope * k, decline = e8 * (1 - 0.5 * k / 11))
  pmax(c(att9, tail), 0)
}

#' One run of the model. p: plan (enrollees), att9 (nine ATT values), y35, uptake_mult, pa_mult, gross (USD per prescription), rebate (0-1), price ("rebate" or "announced"),
#' announced (USD per prescription), fills (purchases per treated member-year), adult_share, eligible_share.
bia_run <- function(p) {
  a <- bia_att_path(p$att9, p$y35)
  rx <- a * (p$plan / 1000) * p$pa_mult * p$uptake_mult
  gross <- rx * p$gross
  net <- if (identical(p$price, "announced")) rx * p$announced else gross * (1 - p$rebate)
  yr <- rep(1:5, each = 4)
  ann <- data.frame(year = 1:5, prescriptions = tapply(rx, yr, sum), gross = tapply(gross, yr, sum), net = tapply(net, yr, sum))
  ann$pmpm_net <- ann$net / (p$plan * 12); ann$pmpm_gross <- ann$gross / (p$plan * 12)
  ann$treated_member_years <- ann$prescriptions / 12
  ann$net_cost_per_member_year_continuous <- ifelse(ann$treated_member_years > 0, ann$net / ann$treated_member_years, NA_real_)   # 12 fills a year (assumption)
  ann$treated_members <- ann$prescriptions / p$fills
  ann$net_cost_per_user_year <- ifelse(ann$treated_members > 0, ann$net / ann$treated_members, NA_real_)   # observed purchases per user-year (MEPS)
  pool <- p$plan * p$adult_share * p$eligible_share
  ann$eligible_pool <- pool; ann$exceeds_pool <- ann$treated_members > pool
  tot <- list(five_year_gross = sum(gross), five_year_net = sum(net), five_year_prescriptions = sum(rx), pmpm_net = sum(net) / (p$plan * 60), pmpm_gross = sum(gross) / (p$plan * 60),
              net_cost_per_member_year_continuous = sum(net) / (sum(rx) / 12), net_cost_per_user_year = sum(net) / (sum(rx) / p$fills))
  list(quarterly = data.frame(quarter = 1:20, year = yr, att = a, prescriptions = rx, gross = gross, net = net), annual = ann, total = tot)
}

#' Default parameters from the input file (central values).
bia_defaults <- function(inp) {
  list(plan = 1e6, att9 = inp$att$estimate, y35 = "plateau", uptake_mult = 1, pa_mult = 1, gross = inp$gross$central, rebate = inp$rebate$central, price = "rebate",
       announced = inp$announced, fills = inp$fills$central, adult_share = inp$adult_share, eligible_share = inp$eligible_share)
}
