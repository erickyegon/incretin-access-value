# Look and feel: the project palette (grey plus one accent), fonts matching the project site (Source Serif 4 headings, IBM Plex Sans text), light mode, and small formatting helpers.
ACCENT <- "#D55E00"; INK <- "#222222"; GREY <- "#595959"; LIGHT <- "#BFBFBF"; PALE <- "#F2B999"; PANEL <- "#F6F6F6"
SITE <- "https://erickyegon.github.io/incretin-access-value/"
REPO <- "https://github.com/erickyegon/incretin-access-value"

app_theme <- bslib::bs_theme(
  version = 5, bg = "#FFFFFF", fg = INK, primary = ACCENT, secondary = GREY, success = GREY, info = GREY, warning = ACCENT,
  base_font = bslib::font_google("IBM Plex Sans", wght = "400;500;600", local = FALSE), heading_font = bslib::font_google("Source Serif 4", wght = "500;600;700", local = FALSE),
  font_scale = 0.96, `border-radius` = "0.6rem", `card-border-color` = "#E2E2E2") |>
  bslib::bs_add_rules("
    .navbar { border-bottom: 3px solid #D55E00; }
    .navbar-brand { font-family: 'Source Serif 4', serif; font-weight: 700; line-height: 1.15; white-space: normal; }
    .navbar-brand .sub { display: block; font-family: 'IBM Plex Sans', sans-serif; font-size: 0.72rem; font-weight: 400; color: #595959; }
    .card-header { font-family: 'Source Serif 4', serif; font-weight: 600; background: #FFFFFF; }
    .card-footer { font-size: 0.78rem; color: #595959; background: #FFFFFF; }
    .bslib-value-box { border-left: 6px solid #D55E00; background: #F6F6F6; color: #222222; }
    .bslib-value-box .value-box-value { font-family: 'Source Serif 4', serif; color: #D55E00; }
    .headline { font-family: 'Source Serif 4', serif; font-size: 1.35rem; line-height: 1.35; font-weight: 600; }
    .chip { border-radius: 999px; border: 1.5px solid #D55E00; color: #D55E00; background: #FFFFFF; padding: 0.25rem 0.8rem; font-size: 0.85rem; }
    .chip:hover { background: #D55E00; color: #FFFFFF; }
    .callout { border-left: 5px solid #D55E00; background: #F6F6F6; padding: 0.7rem 1rem; border-radius: 0.4rem; }
    .badge-measured { background: #595959; color: #fff; } .badge-sourced { background: #FFFFFF; color: #595959; border: 1px solid #595959; } .badge-assumed { background: #D55E00; color: #fff; }
    .small-note { font-size: 0.82rem; color: #595959; }
    .accordion-button:not(.collapsed) { background: #FFF1E6; color: #222222; }
    .shiny-output-error-validation { color: #595959; font-style: italic; }
    @media (max-width: 576px) { .headline { font-size: 1.1rem; } }")

# ---- formatting -------------------------------------------------------------------------------------------------------------------------------------------------
usd <- function(x) paste0("$", formatC(round(x), format = "d", big.mark = ","))
usdm <- function(x, digits = 1) paste0("$", formatC(x / 1e6, format = "f", digits = digits, big.mark = ","), "M")
num <- function(x) formatC(round(x), format = "d", big.mark = ",")
pct <- function(x, digits = 1) paste0(formatC(100 * x, format = "f", digits = digits), "%")
plan_label <- function(plan) if (plan >= 1e6) paste0(formatC(plan / 1e6, format = "f", digits = ifelse(abs(plan / 1e6 - round(plan / 1e6)) < 1e-9, 0, 2)), "-million-enrollee") else paste0(num(plan), "-enrollee")
info <- function(label, text) bslib::tooltip(shiny::span(label, shiny::span(" ⓘ", style = "color:#D55E00; cursor:help;")), text, placement = "right")
src_line <- function(...) shiny::p(class = "mb-0", ...)

# ---- plotly house style -----------------------------------------------------------------------------------------------------------------------------------------
style_plot <- function(p, xtitle = NULL, ytitle = NULL, legend = TRUE, margin = list(l = 60, r = 20, t = 10, b = 50)) {
  p |> plotly::layout(font = list(family = "IBM Plex Sans, sans-serif", color = INK, size = 12), xaxis = list(title = list(text = if (is.null(xtitle)) "" else xtitle), gridcolor = "#EEEEEE", zeroline = FALSE), yaxis = list(title = list(text = if (is.null(ytitle)) "" else ytitle), gridcolor = "#EEEEEE", zeroline = FALSE),
                      legend = list(orientation = "h", x = 0, y = 1.12, yanchor = "bottom"), showlegend = legend, margin = if (legend) modifyList(margin, list(t = 45)) else margin, paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)", hoverlabel = list(font = list(family = "IBM Plex Sans, sans-serif"))) |>
    plotly::config(displayModeBar = FALSE, responsive = TRUE)
}
