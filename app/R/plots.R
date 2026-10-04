# Interactive charts (plotly), house style: grey plus one accent, hover values, no clutter. Titles live in the card headers (finding-as-title) and sources in the card footers.
yr_lab <- function(y) paste("Year", y)

plot_annual <- function(run) {
  a <- run$annual
  plotly::plot_ly(x = yr_lab(a$year)) |>
    plotly::add_bars(y = a$gross / 1e6, name = "Gross (before rebate)", marker = list(color = LIGHT), hovertemplate = "%{x}<br>Gross $%{y:,.1f}M<extra></extra>") |>
    plotly::add_bars(y = a$net / 1e6, name = "Net", marker = list(color = ACCENT), hovertemplate = "%{x}<br>Net $%{y:,.1f}M<extra></extra>") |>
    plotly::layout(barmode = "overlay") |> style_plot(NULL, "USD millions")
}

plot_quarterly_rx <- function(run) {
  q <- run$quarterly; obs <- q$quarter <= 9
  plotly::plot_ly() |>
    plotly::add_bars(x = q$quarter[obs], y = q$prescriptions[obs], name = "Estimated effect (quarters 1 to 9)", marker = list(color = ACCENT), hovertemplate = "Quarter %{x}<br>%{y:,.0f} prescriptions<extra></extra>") |>
    plotly::add_bars(x = q$quarter[!obs], y = q$prescriptions[!obs], name = "Scenario (years 3 to 5)", marker = list(color = LIGHT), hovertemplate = "Quarter %{x}<br>%{y:,.0f} prescriptions<extra></extra>") |>
    style_plot("Quarter since coverage began", "Incremental prescriptions")
}

plot_members <- function(run, p) {
  q <- run$quarterly; users <- q$prescriptions * 4 / p$fills; pool <- p$plan * p$adult_share * p$eligible_share
  plotly::plot_ly() |>
    plotly::add_lines(x = q$quarter, y = users, name = "Members treated (annualized)", line = list(color = ACCENT, width = 3), hovertemplate = "Quarter %{x}<br>%{y:,.0f} members<extra></extra>") |>
    plotly::add_lines(x = q$quarter, y = rep(pool, nrow(q)), name = "Eligible pool (ceiling)", line = list(color = GREY, dash = "dash"), hovertemplate = "Eligible pool %{y:,.0f}<extra></extra>") |>
    style_plot("Quarter since coverage began", "Members")
}

plot_waterfall <- function(p) {
  r <- function(q) bia_run(q)$total
  g0 <- r(modifyList(p, list(pa_mult = 1, uptake_mult = 1)))$pmpm_gross; g1 <- r(modifyList(p, list(uptake_mult = 1)))$pmpm_gross; tot <- r(p)
  lab <- c("Gross PMPM"); meas <- "absolute"; y <- g0
  if (abs(g1 - g0) > 1e-9) { lab <- c(lab, sprintf("Prior auth. x%.2f", p$pa_mult)); meas <- c(meas, "relative"); y <- c(y, g1 - g0) }
  if (abs(tot$pmpm_gross - g1) > 1e-9) { lab <- c(lab, sprintf("Uptake x%.2f", p$uptake_mult)); meas <- c(meas, "relative"); y <- c(y, tot$pmpm_gross - g1) }
  step <- if (identical(p$price, "announced")) "$245 price" else sprintf("Rebate %.1f%%", 100 * p$rebate)
  lab <- c(lab, step, "Net PMPM"); meas <- c(meas, "relative", "total"); y <- c(y, tot$pmpm_net - tot$pmpm_gross, tot$pmpm_net)
  plotly::plot_ly(type = "waterfall", x = factor(lab, levels = lab), y = y, measure = meas, text = sprintf("$%.2f", abs(y)), textposition = "outside", hovertemplate = "%{x}<br>$%{y:.2f} per member per month<extra></extra>",
                  connector = list(line = list(color = LIGHT)), increasing = list(marker = list(color = GREY)), decreasing = list(marker = list(color = LIGHT)), totals = list(marker = list(color = ACCENT))) |>
    plotly::layout(xaxis = list(tickangle = 0)) |> style_plot(NULL, "USD per member per month", legend = FALSE, margin = list(l = 60, r = 20, t = 40, b = 40))
}

plot_event_study <- function() {
  d <- ES[ES$event_time >= -8 & ES$event_time <= 12, ]; ok <- !d$fewer_than_3_states
  plotly::plot_ly() |>
    plotly::add_trace(data = d[ok, ], x = ~event_time, y = ~att, type = "scatter", mode = "markers", marker = list(color = ACCENT, size = 8), error_y = list(type = "data", symmetric = FALSE, array = d$ci_high[ok] - d$att[ok], arrayminus = d$att[ok] - d$ci_low[ok], color = PALE, thickness = 2),
                      name = "Estimate and 95% CI (3 or more states)", text = sprintf("Quarter %d: %.1f (95%% CI %.1f to %.1f); %d treated states", d$event_time[ok], d$att[ok], d$ci_low[ok], d$ci_high[ok], d$treated_states[ok]), hoverinfo = "text") |>
    plotly::add_trace(data = d[!ok, ], x = ~event_time, y = ~att, type = "scatter", mode = "markers", marker = list(color = "#FFFFFF", size = 8, line = list(color = LIGHT, width = 2)), error_y = list(type = "data", symmetric = FALSE, array = d$ci_high[!ok] - d$att[!ok], arrayminus = d$att[!ok] - d$ci_low[!ok], color = LIGHT, thickness = 1.5),
                      name = "Fewer than 3 states (greyed)", text = sprintf("Quarter %d: %.1f (95%% CI %.1f to %.1f); %d treated states", d$event_time[!ok], d$att[!ok], d$ci_low[!ok], d$ci_high[!ok], d$treated_states[!ok]), hoverinfo = "text") |>
    plotly::layout(shapes = list(list(type = "line", x0 = -0.5, x1 = -0.5, y0 = 0, y1 = 1, yref = "paper", line = list(color = GREY, dash = "dash", width = 1)), list(type = "line", x0 = -8.5, x1 = 12.5, y0 = 0, y1 = 0, line = list(color = LIGHT, width = 1)))) |>
    style_plot("Quarters since coverage began (0 = first treated quarter)", "Prescriptions per 1,000 enrollees per quarter")
}

GROUP_COL <- c(never = "#E6E6E6", sensitivity = "#FFFFFF")
plot_map <- function(selected = NULL, source = "map") {
  s <- STATES; yrs <- sort(unique(na.omit(s$cohort_year))); ramp <- grDevices::colorRampPalette(c("#FBD9BF", "#E8883F"))(length(yrs)); names(ramp) <- yrs
  s$fill <- ifelse(s$group == "primary", ramp[as.character(s$cohort_year)], GROUP_COL[s$group])
  s$line <- ifelse(s$group == "sensitivity", ACCENT, ifelse(s$state_code %in% selected, INK, "#FFFFFF")); s$lw <- ifelse(s$group == "sensitivity", 3, ifelse(s$state_code %in% selected, 4, 1))
  s$status <- ifelse(s$group == "primary", paste0("Primary analysis; coverage began ", s$cohort_quarter), ifelse(s$group == "sensitivity", "Sensitivity analysis only (uncertain start quarter)", "Never covered in the study window"))
  s$hover <- paste0("<b>", s$state_name, "</b><br>", s$status, ifelse(is.na(s$coverage_start), "", paste0("<br>Start: ", s$coverage_start)), ifelse(is.na(s$coverage_end), "", paste0("<br>End: ", s$coverage_end)),
                    ifelse(is.na(s$prior_authorization), "", paste0("<br>Prior authorization: ", substr(s$prior_authorization, 1, 70))), ifelse(is.na(s$document), "", paste0("<br>Document: ", substr(s$document, 1, 80))))
  plotly::plot_ly(source = source) |>
    plotly::add_trace(data = s, x = ~col, y = ~-row, type = "scatter", mode = "markers+text", text = ~state_code, textfont = list(size = 11, color = INK), customdata = ~state_code, hovertext = ~hover, hoverinfo = "text",
                      marker = list(symbol = "square", size = 31, color = s$fill, line = list(color = s$line, width = s$lw)), showlegend = FALSE) |>
    plotly::layout(xaxis = list(visible = FALSE, range = c(0.3, 12.7)), yaxis = list(visible = FALSE, range = c(-8.6, -0.4)), margin = list(l = 0, r = 0, t = 0, b = 0), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
                   font = list(family = "IBM Plex Sans, sans-serif")) |>
    plotly::config(displayModeBar = FALSE, responsive = TRUE) |> plotly::event_register("plotly_click")
}

plot_state_rates <- function(code) {
  r <- RATES[RATES$state_code == code, ]; r <- r[order(r$quarter_label), ]; n <- NEVER[order(NEVER$quarter_label), ]
  s <- STATES[STATES$state_code == code, ]
  shp <- list(); if (!is.na(s$cohort_quarter) && s$group == "primary") shp <- list(list(type = "line", x0 = s$cohort_quarter, x1 = s$cohort_quarter, y0 = 0, y1 = 1, yref = "paper", line = list(color = ACCENT, dash = "dot", width = 1.5)))
  plotly::plot_ly() |>
    plotly::add_lines(x = n$quarter_label, y = n$never_covered_mean_observed, name = "Never-covering states, mean", line = list(color = LIGHT, width = 3), hovertemplate = "%{x}<br>Never-covering mean %{y:.2f}<extra></extra>") |>
    plotly::add_lines(x = r$quarter_label, y = r$rate, name = STATES$state_name[STATES$state_code == code], line = list(color = ACCENT, width = 3), hovertemplate = "%{x}<br>%{y:.2f} per 1,000<extra></extra>") |>
    plotly::layout(shapes = shp, xaxis = list(categoryorder = "array", categoryarray = QLAB, tickmode = "array", tickvals = QLAB[grepl("Q1$", QLAB)], ticktext = substr(QLAB[grepl("Q1$", QLAB)], 1, 4))) |>
    style_plot(NULL, "Per 1,000 enrollees (observed)")
}

plot_spec <- function() {
  d <- SPECS[SPECS$estimable, ]; prim <- d$att[d$spec == "0"]
  d$label <- paste0(d$spec, ". ", d$specification)
  d <- d[nrow(d):1, ]; d$label <- factor(d$label, levels = d$label); isp <- d$spec == "0"
  plotly::plot_ly(d, x = ~att, y = ~label, type = "scatter", mode = "markers", marker = list(color = ifelse(isp, ACCENT, GREY), size = 8), error_x = list(type = "data", symmetric = FALSE, array = d$ci_high - d$att, arrayminus = d$att - d$ci_low, color = ifelse(isp, PALE, LIGHT)),
                  text = sprintf("%s: %.1f (95%% CI %.1f to %.1f)", d$label, d$att, d$ci_low, d$ci_high), hoverinfo = "text") |>
    plotly::layout(shapes = list(list(type = "line", x0 = prim, x1 = prim, y0 = 0, y1 = 1, yref = "paper", line = list(color = ACCENT, dash = "dash", width = 1)), list(type = "line", x0 = 0, x1 = 0, y0 = 0, y1 = 1, yref = "paper", line = list(color = GREY, width = 1)))) |>
    style_plot("Overall effect per 1,000 enrollees per quarter (95% CI)", NULL, legend = FALSE, margin = list(l = 290, r = 20, t = 10, b = 50))
}

plot_tornado <- function(tor, base_net) {
  d <- tor[nrow(tor):1, ]; d$parameter <- factor(d$parameter, levels = d$parameter)
  plotly::plot_ly(d) |>
    plotly::add_segments(x = ~net_low / 1e6, xend = ~net_high / 1e6, y = ~parameter, yend = ~parameter, line = list(color = PALE, width = 14), hoverinfo = "none", showlegend = FALSE) |>
    plotly::add_markers(x = ~net_low / 1e6, y = ~parameter, marker = list(color = GREY, size = 9), text = ~sprintf("%s: %s, $%.1fM", parameter, low_label, net_low / 1e6), hoverinfo = "text", name = "Low end") |>
    plotly::add_markers(x = ~net_high / 1e6, y = ~parameter, marker = list(color = ACCENT, size = 9), text = ~sprintf("%s: %s, $%.1fM", parameter, high_label, net_high / 1e6), hoverinfo = "text", name = "High end") |>
    plotly::layout(shapes = list(list(type = "line", x0 = base_net / 1e6, x1 = base_net / 1e6, y0 = 0, y1 = 1, yref = "paper", line = list(color = GREY, dash = "dash", width = 1)))) |>
    style_plot("Five-year net cost (USD millions); dashed line = current scenario", NULL, margin = list(l = 250, r = 20, t = 10, b = 60))
}

plot_psa_hist <- function(d, s) {
  plotly::plot_ly(x = d$net5 / 1e6, type = "histogram", nbinsx = 60, marker = list(color = ACCENT, line = list(color = "#FFFFFF", width = 0.5)), hovertemplate = "$%{x:,.0f}M<br>%{y} draws<extra></extra>") |>
    plotly::layout(shapes = lapply(list(list(s[["median"]], INK, "solid"), list(s[["p05"]], GREY, "dash"), list(s[["p95"]], GREY, "dash")), function(z) list(type = "line", x0 = z[[1]] / 1e6, x1 = z[[1]] / 1e6, y0 = 0, y1 = 1, yref = "paper", line = list(color = z[[2]], dash = z[[3]], width = 1.5)))) |>
    style_plot("Five-year net cost (USD millions)", "Draws", legend = FALSE)
}

plot_cdf <- function(d, budget, basis) {
  x <- if (basis == "five_year") d$net5 else apply(d$annual, 1, max); x <- sort(x) / 1e6; p <- seq_along(x) / length(x)
  pr <- mean(x <= budget / 1e6)
  plotly::plot_ly(x = x, y = p, type = "scatter", mode = "lines", line = list(color = ACCENT, width = 3), hovertemplate = "Budget $%{x:,.0f}M<br>Probability of staying within it %{y:.0%}<extra></extra>") |>
    plotly::layout(shapes = list(list(type = "line", x0 = budget / 1e6, x1 = budget / 1e6, y0 = 0, y1 = 1, line = list(color = GREY, dash = "dash")), list(type = "line", x0 = min(x), x1 = max(x), y0 = pr, y1 = pr, line = list(color = LIGHT, dash = "dot"))),
                   yaxis = list(tickformat = ".0%", range = c(0, 1))) |>
    style_plot(if (basis == "five_year") "Five-year net cost budget (USD millions)" else "Annual net cost budget, highest single year (USD millions)", "Probability the cost stays within the budget", legend = FALSE)
}

plot_compare <- function(df) {
  plotly::plot_ly(df, x = ~name, y = ~five_year_net / 1e6, type = "bar", marker = list(color = ACCENT), text = ~sprintf("$%.1fM<br>$%.2f PMPM", five_year_net / 1e6, pmpm_net), textposition = "outside", hovertemplate = "%{x}<br>$%{y:,.1f}M five-year net<extra></extra>") |>
    style_plot(NULL, "Five-year net cost (USD millions)", legend = FALSE)
}
