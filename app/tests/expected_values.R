# Prints the five-year net cost (USD millions, 1 decimal) that the model gives for each control setting used by scripts/test/test_app.js
setwd(here <- if (file.exists("app/app.R")) "app" else "."); for (f in list.files("R", full.names = TRUE)) if (!grepl("mod_|plots", f)) source(f)
shiny_theme <- NULL
f <- function(...) { p <- BASE; a <- list(...); for (n in names(a)) p[[n]] <- a[[n]]; sprintf("%.1f", bia_run(p)$total$five_year_net / 1e6) }
out <- c(central = f(), uptake075 = f(uptake_mult = .75), uptake125 = f(uptake_mult = 1.25), pa05 = f(pa_mult = .5), pa125 = f(pa_mult = 1.25), lo = f(att9 = INP$att$ci_low), hi = f(att9 = INP$att$ci_high), growth = f(y35 = "growth"), decline = f(y35 = "decline"),
  announced = f(price = "announced"), reb231 = f(rebate = .231), reb7935 = f(rebate = .7935), gross_lo = f(gross = 1164.45), gross_hi = f(gross = 1251.96), plan2m = f(plan = 2e6))
print(out)
