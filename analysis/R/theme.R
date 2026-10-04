# House style for Module C figures and tables.
# Colour meaning is the same in every figure: treated = accent, comparison = grey. Okabe-Ito colours are used only when more than two groups
# must be told apart.
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(scales)
  library(here)
})

okabe_ito <- c(black = "#000000", orange = "#E69F00", skyblue = "#56B4E9", green = "#009E73", yellow = "#F0E442", blue = "#0072B2",
               vermillion = "#D55E00", purple = "#CC79A7")
col_treated <- "#D55E00"       # accent (Okabe-Ito vermillion)
col_comparison <- "#8C8C8C"    # grey
col_context <- "#D0D0D0"       # light grey for context lines and shading
col_sensitivity <- "#F2B999"   # pale accent: treated but start quarter unknown

# Dates annotated on figures: from the label_events seed (Drugs@FDA original approvals)
approval_wegovy <- as.Date("2021-06-04")
approval_zepbound <- as.Date("2023-11-08")
sdud_window <- c(as.Date("2018-01-01"), as.Date("2026-03-31"))
preliminary_from <- as.Date("2026-01-01")   # 2026 Q1 SDUD is preliminary

caption_sdud <- "Source: CMS State Drug Utilization Data and Medicaid enrollment (warehouse marts). Gross of rebates; counts under 11 suppressed by CMS."
caption_note_prelaunch <- "Wegovy was approved 2021-06-04, so the outcome is mechanically zero before 2021 Q2."

theme_incretin <- function(base_size = 11) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      text = element_text(colour = "#222222"),
      plot.title = element_text(face = "bold", size = base_size + 3, hjust = 0, margin = margin(b = 4)),
      plot.subtitle = element_text(size = base_size, hjust = 0, colour = "#444444", margin = margin(b = 8)),
      plot.caption = element_text(size = base_size - 3, hjust = 0, colour = "#666666", margin = margin(t = 8)),
      plot.title.position = "plot", plot.caption.position = "plot",
      panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = "#E6E6E6", linewidth = 0.3),
      strip.text = element_text(face = "bold", hjust = 0),
      axis.title = element_text(size = base_size - 1), legend.position = "bottom", legend.title = element_text(size = base_size - 1)
    )
}

#' Convert a quarter label such as "2023Q4" to the first day of that quarter.
quarter_to_date <- function(q) as.Date(paste0(substr(q, 1, 4), "-", sprintf("%02d", (as.integer(substr(q, 6, 6)) - 1) * 3 + 1), "-01"))

out_dir <- function(kind) {
  d <- here::here("outputs", kind)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

#' Save a figure as PNG (300 dpi) and SVG.
save_fig <- function(p, name, width = 9, height = 6) {
  d <- out_dir("figures")
  ggplot2::ggsave(file.path(d, paste0(name, ".png")), p, width = width, height = height, dpi = 300, bg = "white")
  ggplot2::ggsave(file.path(d, paste0(name, ".svg")), p, width = width, height = height, bg = "white")
  invisible(file.path(d, name))
}

#' Save a table as CSV and a gt HTML file.
save_table <- function(df, name, gt_table = NULL) {
  d <- out_dir("tables")
  readr::write_csv(df, file.path(d, paste0(name, ".csv")))
  if (!is.null(gt_table)) gt::gtsave(gt_table, file.path(d, paste0(name, ".html")))
  invisible(file.path(d, name))
}
