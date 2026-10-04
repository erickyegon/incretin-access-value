# Loads the app's R/ files (model, data, PSA, modules) with the app folder as working directory, as Shiny does.
library(shiny); library(bslib); library(plotly)
.app_dir <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
.old <- setwd(.app_dir)
for (f in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) source(f)
setwd(.old)
APP_DIR <- .app_dir
tornado_ref <- read.csv(file.path("fixtures", "moduleE_tornado.csv"), stringsAsFactors = FALSE)
m1 <- function(x) sprintf("%.1f", x / 1e6)          # USD millions, one decimal, as displayed in key_numbers.csv
