# Deck variants: slide-area sizes and per-figure simplifications. DECK_PANEL (8.0 x 4.6 in) sits left of the takeaway panel; DECK_FULL (12.3 x 4.5 in) is full width.
# Each hook receives the plot built for the report and returns the version for the slide (no legends where direct labels exist, shorter axis titles, fewer labels).
DECK_DIMS <- list()
DECK_HOOKS <- list()

# ---- helpers used by the hooks ------------------------------------------------------------------------------------------------------------------------------------
drop_layers <- function(p, geoms) { p$layers <- Filter(function(l) !any(class(l$geom) %in% geoms), p$layers); p }
TEXT_GEOMS <- c("GeomText", "GeomLabel", "GeomTextRepel", "GeomLabelRepel")
nolegend <- function(p) p + ggplot2::theme(legend.position = "none")

# ---- one-pager variant: sized to the printed page (7.4 x 3.0 in at 300 dpi), type at least 9 pt at print size ----------------------------------------------------------
FIG_SCALE$page <- list(title = 16, subtitle = 12, axis_text = 9.5, axis_title = 10, legend = 9.5, strip = 10, caption = 9, direct_mm = 3.45)
PAGE_HOOKS <- list()
export_page <- function(name, w = 7.4, h = 3.0) {
  p <- readRDS(file.path(out_dir("figures"), "..", "cache", "figobj", paste0(name, ".rds"))); hook <- PAGE_HOOKS[[name]]; q <- if (is.function(hook)) hook(p) else p
  q <- .set(q, "title", NULL); q <- .set(q, "subtitle", NULL); q <- .set(q, "caption", NULL); q <- apply_scale(q, "page")
  f <- file.path(here::here("..", "deck", "assets"), paste0(name, "_page.png")); dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
  ggplot2::ggsave(f, q, width = w, height = h, dpi = 300, bg = "white", device = ragg::agg_png); invisible(f)
}

# ---- hooks ------------------------------------------------------------------------------------------------------------------------------------------------------------
# funnel: the obesity pathway only, large, measured bars solid and modeled bars hatched, labels wrapped
DECK_HOOKS[["20_funnel"]] <- function(p) {
  d <- p$patches$plots[[1]]$data
  d$lab <- paste0(stringr::str_wrap(sprintf("%s: %sM", d$label, fmt1(d$est)), 30), "\n", ifelse(d$status == "measured", sprintf("95%% CI %s to %s (measured)", fmt1(d$lo), fmt1(d$hi)), sprintf("range %s to %s (modeled)", fmt1(d$lo), fmt1(d$hi))))
  ggplot2::ggplot(d) +
    ggpattern::geom_rect_pattern(ggplot2::aes(xmin = -half, xmax = half, ymin = y - 0.4, ymax = y + 0.4, pattern = status, fill = status), colour = col_treated, pattern_colour = col_treated, pattern_fill = "white", pattern_density = 0.35, pattern_spacing = 0.02, pattern_angle = 45, linewidth = 0.4) +
    ggplot2::geom_text(ggplot2::aes(x = max(est) / 2 + 6, y = y, label = lab), hjust = 0, lineheight = 0.95, colour = "#222222", size = 4.6) +
    ggpattern::scale_pattern_manual(values = c(measured = "none", modeled = "stripe"), name = NULL) + ggplot2::scale_fill_manual(values = c(measured = col_treated, modeled = "#FFFFFF"), name = NULL) +
    ggplot2::scale_x_continuous(limits = c(-max(d$est) / 2 - 3, max(d$est) / 2 + 250)) + ggplot2::scale_y_continuous(expand = ggplot2::expansion(add = 0.45)) + ggplot2::labs(x = NULL, y = NULL) + theme_incretin(variant = "deck") +
    ggplot2::theme(axis.text = ggplot2::element_blank(), panel.grid = ggplot2::element_blank(), legend.position = "none")
}
DECK_HOOKS[["11_specification_chart"]] <- function(p) p + ggplot2::labs(x = "Overall effect (95% CI)")
DECK_HOOKS[["01_coverage_timing_map"]] <- function(p) {
  p$data$label <- substr(sub("\n.*$", "", p$data$label), 1, 2)
  ny <- length(unique(stats::na.omit(p$data$cohort_year)))
  p + ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, title = NULL, override.aes = list(colour = c(rep("white", ny), col_treated, "white"), linetype = c(rep("solid", ny), "dashed", "solid"), linewidth = 0.9))) + ggplot2::theme(legend.position = "bottom")
}
DECK_HOOKS[["54_trial_weight_change"]] <- function(p) {
  p <- drop_layers(p, TEXT_GEOMS)
  p + ggplot2::geom_text(ggplot2::aes(x = pmin(value, ci_low, na.rm = TRUE), label = sprintf("%.1f", value)), hjust = 1.35, size = 4.6, show.legend = FALSE) +
    ggplot2::scale_y_discrete(labels = function(x) sub(" [(]max. tolerated dose[)]", " (MTD)", x), expand = ggplot2::expansion(add = 0.6)) + ggplot2::scale_x_continuous(labels = function(x) paste0(x, "%"), expand = ggplot2::expansion(mult = c(0.12, 0.03))) +
    ggplot2::labs(x = "Mean change in body weight (95% CI where reported)")
}
DECK_HOOKS[["06_managed_care_split"]] <- function(p) p + ggplot2::scale_x_discrete(labels = function(x) paste0(substr(x, 3, 4), " ", substr(x, 5, 6))) + ggplot2::labs(y = "Prescriptions per 1,000 enrollees") + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5), legend.position = "bottom")
DECK_DIMS[["51_timeline"]] <- c(12.3, 4.9); DECK_DIMS[["10_event_study_primary"]] <- c(12.3, 3.3)
DECK_HOOKS[["51_timeline"]] <- function(p) {
  pl <- p$patches$plots; p2 <- pl[[2]]; d <- p2$data; i <- which.max(d$n)
  k <- which(vapply(pl[[1]]$layers, function(l) inherits(l$geom, "GeomTextRepel"), logical(1))); if (length(k)) { pl[[1]]$layers[[k[1]]]$geom_params$direction <- "both"; pl[[1]]$layers[[k[1]]]$geom_params$max.overlaps <- Inf }
  pl[[1]]$data$lab <- gsub("cardiovascular indication", "CV indication", gsub("sleep apnea indication", "sleep apnea", pl[[1]]$data$lab))
  p2 <- drop_layers(p2, "GeomTextRepel") + ggplot2::annotate("text", x = d$month[i] - 40, y = d$n[i] + 1.4, label = sprintf("%d states at the peak", d$n[i]), hjust = 1, size = 4.6, colour = "#222222") + ggplot2::scale_y_continuous(limits = c(0, max(d$n) + 2.5), breaks = c(0, 5, 10))
  pl[[1]] <- pl[[1]] + ggplot2::theme(axis.text.x = ggplot2::element_blank()); pl[[2]] <- p2 + ggplot2::theme(axis.text.x = ggplot2::element_blank()); p$patches$plots <- pl; p + patchwork::plot_layout(heights = c(1.5, 1.3, 0.8))
}
mil <- function(x) x / 1e6   # plots built in the budget script call mil() inside aes(); defined here so the saved objects can be re-exported
DECK_HOOKS[["50_spending_trend"]] <- function(p) {
  fix <- function(q) { k <- which(vapply(q$layers, function(l) inherits(l$geom, "GeomTextRepel"), logical(1))); l <- q$layers[[k[1]]]
    q <- drop_layers(q, "GeomTextRepel")
    q + ggrepel::geom_text_repel(data = l$data, mapping = l$mapping, hjust = 0, direction = "y", nudge_x = 0.4, size = 4.6, segment.size = 0.2, box.padding = 0.35, min.segment.length = 0.3, seed = 4, show.legend = FALSE) +
      ggplot2::scale_x_continuous(breaks = c(2020, 2022, 2024), limits = c(2020, 2027.4)) }
  p$patches$plots <- lapply(p$patches$plots, fix); fix(p) }
DECK_HOOKS[["05b_withdrawal_change"]] <- function(p) p + ggplot2::labs(x = "Normalized change, 2025 Q4 to 2026 Q1 (preliminary)")
DECK_HOOKS[["31_partd_specialty_mix"]] <- function(p) p + ggplot2::scale_x_continuous(breaks = 2018:2024)

DECK_HOOKS[["40_tornado"]] <- function(p) {
  p$data$lab <- c("79.3% (implied by $245)" = "79.3%", "23.1% (statutory minimum)" = "23.1%", "announced $245 net" = "$245 net", "continued growth" = "growth", "0.5 (tight)" = "0.5", "1.25 (loose)" = "1.25", "central rebate" = "central")[p$data$lab] |> (\(x) ifelse(is.na(x), p$data$lab, x))()
  p + ggplot2::scale_y_discrete(labels = function(x) sub(" [(].*$", "", x)) + ggplot2::scale_x_continuous(breaks = c(0, 100, 200, 300), labels = function(x) paste0("$", x, "M"), expand = ggplot2::expansion(mult = c(0.35, 0.3))) + ggplot2::labs(x = "Five-year net budget impact (USD millions)")
}
DECK_HOOKS[["42_cost_by_scenario"]] <- function(p) p + ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.42))) + ggplot2::labs(y = "USD millions") + ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2)) + ggplot2::theme(legend.position = "bottom")
DECK_HOOKS[["41_waterfall_pmpm"]] <- function(p) p + ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.18)))
DECK_HOOKS[["34_partd_wegovy_vs_ozempic_specialty"]] <- function(p) p + ggplot2::scale_x_continuous(limits = c(0, 70), expand = ggplot2::expansion(mult = c(0, 0)))
DECK_HOOKS[["10_event_study_primary"]] <- function(p) drop_layers(p, TEXT_GEOMS) + ggplot2::labs(y = "Effect per 1,000 enrollees")
PAGE_HOOKS[["10_event_study_primary"]] <- DECK_HOOKS[["10_event_study_primary"]]
PAGE_HOOKS[["10_event_study_primary"]] <- function(p) drop_layers(p, TEXT_GEOMS) + ggplot2::labs(y = "Per 1,000 enrollees")
