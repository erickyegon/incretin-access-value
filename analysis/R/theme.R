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
# theme_incretin() and save_fig() live in fig_style.R (one style system: fonts, type scale, report/deck/web variants, QA log).

# ==============================================================================
# 4. GT TABLE COMPANION HOUSE STYLE
# ==============================================================================
theme_gt_incretin <- function(gt_tbl) {
  gt_tbl %>%
    opt_table_font(font = list(google_font("IBM Plex Sans"), default_fonts())) %>%
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

source(here::here("R", "fig_style.R"))
