# One-time project setup: renv project with the packages named in the Module C brief. Re-run restores nothing; use renv::restore() instead.
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!file.exists("renv.lock")) renv::init(bare = TRUE, restart = FALSE)
pk <- c("DBI","RPostgres","dplyr","tidyr","did","HonestDiD","fixest","ggplot2","patchwork","geofacet","statebins","gt","scales","here","readr","svglite","ragg","purrr","stringr","webshot2","jsonlite")
for (p in pk) tryCatch(renv::install(p, prompt = FALSE), error = function(e) message("FAILED ", p, ": ", conditionMessage(e)))
# fwildclusterboot is archived on CRAN: install from the author's r-universe
tryCatch(renv::install("fwildclusterboot", repos = c("https://s3alfisc.r-universe.dev", "https://cloud.r-project.org"), prompt = FALSE),
         error = function(e) message("FAILED fwildclusterboot: ", conditionMessage(e)))
renv::snapshot(prompt = FALSE, type = "all")
