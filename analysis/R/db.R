# Warehouse access for the analysis: marts only, through one function. Credentials follow dbt: the local server uses trust authentication on
# localhost; if a password is ever required it is read from INCRETIN_PG_PASSWORD (never stored in the repository).
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(dplyr)
})

pg_connect <- function() {
  pw <- Sys.getenv("INCRETIN_PG_PASSWORD", unset = "")
  args <- list(RPostgres::Postgres(), host = Sys.getenv("INCRETIN_PG_HOST", "localhost"), port = as.integer(Sys.getenv("INCRETIN_PG_PORT", "5432")),
               dbname = Sys.getenv("INCRETIN_PG_DBNAME", "incretin"), user = Sys.getenv("INCRETIN_PG_USER", "postgres"))
  if (nzchar(pw)) args$password <- pw
  do.call(DBI::dbConnect, args)
}

#' Read one mart (schema `marts`) as a tibble. Staging and raw tables are deliberately unreachable from here.
get_mart <- function(name) {
  stopifnot(is.character(name), length(name) == 1, grepl("^mart_[a-z0-9_]+$", name))
  con <- pg_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tibble::as_tibble(DBI::dbGetQuery(con, paste0('select * from marts."', name, '"')))
}
