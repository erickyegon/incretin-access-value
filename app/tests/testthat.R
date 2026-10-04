# Run from the repository root:  Rscript app/tests/testthat.R   (needs testthat; the app itself does not)
library(testthat)
test_dir("app/tests/testthat", reporter = "summary", stop_on_failure = TRUE)
