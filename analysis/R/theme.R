suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(scales)
  library(here)
  library(gt)
})

# ==============================================================================
# 1. COLOR PALETTE & DESIGN TOKENS
# ==============================================================================
# Refactored for WCAG AA compliance against light backgrounds (#FFFFFF / #F9F9F9)
okabe_ito <- c(
  black      = "#000000", 
  orange     = "#E69F00", 
  skyblue    = "#56B4E9", 
  green      = "#009E73", 
  yellow     = "#F0E442", 
  blue       = "#0072B2",
  vermillion = "#D55E00", 
  purple     = "#CC79A7"
)

col_treated    <- "#D55E00" # Accent (Okabe-Ito vermillion)
col_comparison <- "#595959" # Darkened grey for high-contrast accessibility (WCAG AA)
col_context    <- "#BFBFBF" # Refined context grey for structural lines
col_sensitivity<- "#F2B999" # Pale accent for unverified initial quarters

# ==============================================================================
# 2. DYNAMIC TEMPORAL BOUNDS & SEED METADATA
# ==============================================================================
approval_wegovy     <- as.Date("2021-06-04")
approval_zepbound   <- as.Date("2023-11-08")
label_wegovy_cv     <- as.Date("2024-03-08")
label_zepbound_osa  <- as.Date("2024-12-20")
preliminary_from    <- as.Date("2026-01-01")   # SDUD 2026 Q1 is preliminary (used by the Module C figures)
sdud_window         <- c(as.Date("2018-01-01"), as.Date("2026-03-31"))

# Dynamically derive temporal limits instead of hardcoding cutoff dates
get_sdud_window <- function(data_df, date_col = "quarter_date") {
  if (!is.null(data_df) && date_col %in% names(data_df)) {
    c(min(data_df[[date_col]], na.rm = TRUE), max(data_df[[date_col]], na.rm = TRUE))
  } else {
    c(as.Date("2018-01-01"), Sys.Date())
  }
}

get_preliminary_threshold <- function(data_df, date_col = "quarter_date") {
  max_dt <- if (!is.null(data_df) && date_col %in% names(data_df)) max(data_df[[date_col]], na.rm = TRUE) else Sys.Date()
  # Default preliminary threshold to the start of the current trailing year/quarter
  as.Date(format(max_dt, "%Y-01-01"))
}

caption_sdud <- "Source: CMS State Drug Utilization Data and Medicaid enrollment (warehouse marts). Gross of rebates; counts under 11 suppressed by CMS."
caption_note_prelaunch <- "Wegovy was approved 2021-06-04, so the outcome is mechanically zero before 2021 Q2."

# ==============================================================================
# 3. TYPOGRAPHY & THEME SYSTEM
# ==============================================================================
theme_incretin <- function(base_size = 11, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      text = element_text(colour = "#222222", family = base_family),
      plot.title = element_text(face = "bold", size = base_size + 3, hjust = 0, margin = margin(b = 4)),
      plot.subtitle = element_text(size = base_size, hjust = 0, colour = "#444444", margin = margin(b = 8)),
      plot.caption = element_text(size = base_size - 3, hjust = 0, colour = "#666666", margin = margin(t = 8)),
      plot.title.position = "plot", 
      plot.caption.position = "plot",
      panel.grid.minor = element_blank(), 
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = "#E6E6E6", linewidth = 0.3),
      strip.text = element_text(face = "bold", hjust = 0),
      axis.title = element_text(size = base_size - 1), 
      legend.position = "bottom", 
      legend.title = element_text(size = base_size - 1)
    )
}

# ==============================================================================
# 4. GT TABLE COMPANION HOUSE STYLE
# ==============================================================================
theme_gt_incretin <- function(gt_tbl) {
  gt_tbl %>%
    opt_table_font(font = google_font("Inter")) %>%
    tab_options(
      table.font.color = "#222222",
      heading.title.font.size = px(16),
      heading.title.font.weight = "bold",
      heading.subtitle.font.size = px(13),
      column_labels.font.weight = "bold",
      column_labels.border.top.color = "#222222",
      column_labels.border.bottom.color = "#222222",
      table_body.border.bottom.color = "#222222",
      table.background.color = "#FFFFFF"
    ) %>%
    cols_align(align = "left", columns = everything())
}

# ==============================================================================
# 5. UTILITIES & FORMATTING HELPERS
# ==============================================================================
quarter_to_date <- function(q) {
  as.Date(paste0(substr(q, 1, 4), "-", sprintf("%02d", (as.integer(substr(q, 6, 6)) - 1) * 3 + 1), "-01"))
}

out_dir <- function(kind) {
  d <- here::here("outputs", kind)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

save_fig <- function(p, name, width = 9, height = 6, alt = NA_character_) {
  d <- out_dir("figures")
  # long titles, subtitles and captions that were not wrapped by the script are wrapped to the figure width so nothing is clipped
  wrap1 <- function(x, w) if (is.null(x) || length(x) == 0 || is.na(x) || grepl("\n", x)) x else stringr::str_wrap(x, w)
  w <- round(width * 10.5)
  if (inherits(p, "patchwork")) { a <- p$patches$annotation
    if (!is.null(a$subtitle)) p$patches$annotation$subtitle <- wrap1(a$subtitle, w)
    if (!is.null(a$title)) p$patches$annotation$title <- wrap1(a$title, round(w * 0.8))
    if (!is.null(a$caption)) p$patches$annotation$caption <- wrap1(a$caption, round(w * 1.2))
  } else { if (!is.null(p$labels$subtitle)) p$labels$subtitle <- wrap1(p$labels$subtitle, w)
    if (!is.null(p$labels$title)) p$labels$title <- wrap1(p$labels$title, round(w * 0.8))
    if (!is.null(p$labels$caption)) p$labels$caption <- wrap1(p$labels$caption, round(w * 1.2)) }
  ggplot2::ggsave(file.path(d, paste0(name, ".png")), p, width = width, height = height, dpi = 300, bg = "white")
  ggplot2::ggsave(file.path(d, paste0(name, ".svg")), p, width = width, height = height, bg = "white")
  # deck variant without the baked-in title (the slide headline carries the finding); subtitle, caption and notes are kept
  pd <- p; if (inherits(pd, "patchwork")) { if (!is.null(pd$patches$annotation$title)) pd$patches$annotation$title <- NULL } else pd$labels$title <- NULL
  ggplot2::ggsave(file.path(d, paste0(name, "_deck.png")), pd, width = width, height = height, dpi = 200, bg = "white")
  # alt text for every figure is kept in outputs/figures/alt_text.csv
  if (!is.na(alt)) {
    f <- file.path(d, "alt_text.csv")
    cur <- if (file.exists(f)) readr::read_csv(f, show_col_types = FALSE) else data.frame(figure = character(), alt_text = character())
    cur <- rbind(cur[cur$figure != name, c("figure", "alt_text")], data.frame(figure = name, alt_text = alt))
    readr::write_csv(cur[order(cur$figure), ], f)
  }
  invisible(file.path(d, name))
}

save_table <- function(df, name, gt_table = NULL) {
  d <- out_dir("tables")
  readr::write_csv(df, file.path(d, paste0(name, ".csv")))
  if (!is.null(gt_table)) {
    styled_gt <- theme_gt_incretin(gt_table)
    gt::gtsave(styled_gt, file.path(d, paste0(name, ".html")))
  }
  invisible(file.path(d, name))
}

# Standardized rounding rules: one decimal, halves rounded up
fmt1 <- function(x) sprintf("%.1f", floor(abs(x) * 10 + 0.5 + 1e-9) / 10 * sign(x))
fmt_pct1 <- function(x) paste0(fmt1(100 * x), "%")