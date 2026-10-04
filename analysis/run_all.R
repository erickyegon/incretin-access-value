# Run every analysis step in order from the warehouse: `cd analysis; Rscript run_all.R` (renv activates from analysis/.Rprofile).
# Steps 01-07 are descriptive (Checkpoint A). Model scripts (10 onward) are added after Checkpoint A approval.
options(warn = 1)
cat("R:", R.version.string, "\n")
steps <- sort(list.files(here::here("scripts"), pattern = "^[0-9]{2}[a-z]?_.*\\.R$", full.names = TRUE))
for (s in steps) {
  cat("\n=== ", basename(s), " ===\n", sep = "")
  source(s, local = new.env(), echo = FALSE)
}
