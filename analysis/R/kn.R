# Helpers to quote numbers from outputs/key_numbers.csv inline in Quarto documents (report, deck, research pack): every public number comes through here.
.kn_path <- function() {
  p <- normalizePath(getwd(), winslash = "/"); for (i in 1:6) { f <- file.path(p, "analysis", "outputs", "key_numbers.csv"); if (file.exists(f)) return(f)
    f <- file.path(p, "outputs", "key_numbers.csv"); if (file.exists(f) && basename(p) == "analysis") return(f); p <- dirname(p) }
  stop("key_numbers.csv not found from ", getwd())
}
.kn <- local({ cache <- NULL; function() { if (is.null(cache)) cache <<- utils::read.csv(.kn_path(), stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0)); cache } })
.row <- function(id) { k <- .kn(); r <- k[k$id == id, ]; if (nrow(r) != 1) stop("key number not found: ", id); r }
kn <- function(id) .row(id)$display                       # number as displayed
kn_ci <- function(id) .row(id)$ci_or_range                # "95% CI 8.4 to 16.0"
kn_unit <- function(id) .row(id)$unit
kn_src <- function(id) .row(id)$source_file
kn_full <- function(id) { r <- .row(id); paste0(r$display, " ", r$unit, ifelse(nzchar(r$ci_or_range), paste0(" (", r$ci_or_range, ")"), "")) }
# a number with its CI in the form "12.2 (95% CI 8.4 to 16.0)"
kn_c <- function(id) { r <- .row(id); ifelse(nzchar(r$ci_or_range), paste0(r$display, " (", r$ci_or_range, ")"), r$display) }
