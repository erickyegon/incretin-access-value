# Audit: every public number in the rendered report, deck, website, one-page summary, research pack and README must come from analysis/outputs/key_numbers.csv.
# Run from anywhere:  Rscript audit/check_numbers.R   (writes audit/audit_report.md and exits 1 if anything needs review)
# Classes: exact (matches a key number or a number inside its CI/range text), rounded (an integer rounding of a key number, e.g. "$161 million" in a heading),
#          allowed (audit/allowed_numbers.csv: method parameters, years, sample sizes with a stated reason), UNMATCHED (needs review), STALE (a superseded value).
args <- commandArgs(FALSE); here <- dirname(normalizePath(sub("--file=", "", args[grep("--file=", args)]), winslash = "/")); root <- dirname(here)
`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a
rd <- function(...) readLines(file.path(root, ...), warn = FALSE, encoding = "UTF-8")
kn <- read.csv(file.path(root, "analysis", "outputs", "key_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0))
allow <- read.csv(file.path(here, "allowed_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character")
stale <- read.csv(file.path(here, "superseded_numbers.csv"), stringsAsFactors = FALSE, colClasses = "character")
num_re <- "(?<![\\w.])\\d[\\d,]*(?:\\.\\d+)?(?![\\w])"
toks <- function(txt) { m <- gregexpr(num_re, txt, perl = TRUE); x <- regmatches(txt, m)[[1]]; x <- sub(",$", "", x); x[!grepl("^\\d{1,2}$", x)] }   # integers under 100 are not audited
norm <- function(x) { x <- gsub(",", "", x); ifelse(grepl("\\.", x), sub("\\.?0+$", "", sub("(\\.\\d*?)0+$", "\\1", x)), x) }
key_vals <- unique(norm(unlist(lapply(c(kn$display, kn$ci_or_range, kn$unit), function(s) toks(s)))))
key_round <- unique(unlist(lapply(kn$display, function(s) { v <- suppressWarnings(as.numeric(gsub(",", "", s))); if (is.na(v)) character(0) else c(as.character(round(v)), as.character(floor(v))) })))
dce_files <- list.files(file.path(root, "research_pack", "design"), pattern = "[.]csv$", full.names = TRUE)
dce_vals <- unique(norm(unlist(lapply(dce_files, function(f) toks(gsub(",", " ", paste(readLines(f, warn = FALSE), collapse = " ")))))))   # design and simulation outputs of the research pack (Module F)
dn <- suppressWarnings(as.numeric(dce_vals)); dce_vals <- unique(c(dce_vals, norm(as.character(round(dn[!is.na(dn)], 3))), norm(sprintf("%.3f", dn[!is.na(dn)]))))   # the research pack prints design outputs rounded
allow_vals <- norm(allow$value)
html_text <- function(f) { h <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  at <- unlist(regmatches(h, gregexpr("(?:alt|aria-label|fig-alt)=\"[^\"]*\"", h, perl = TRUE)))
  h <- gsub("(?s)<script.*?</script>|(?s)<style.*?</style>", " ", h, perl = TRUE); h <- gsub("<[^>]+>", " ", h, perl = TRUE); h <- gsub("&[a-z#0-9]+;", " ", h)
  paste(h, paste(at, collapse = " ")) }
pdf_text <- function(f) paste(suppressWarnings(system2("pdftotext", c("-layout", "-enc", "UTF-8", shQuote(f), "-"), stdout = TRUE, stderr = FALSE)), collapse = "\n")
# AUDIT_ONE_PAGER lets the audit be pointed at a test copy of the one-pager
docs <- list(report = file.path(root, "report", "report.html"), deck_pdf = file.path(root, "deck", "deck.pdf"), website = file.path(root, "site", "index.html"),
             one_pager = Sys.getenv("AUDIT_ONE_PAGER", file.path(root, "deck", "one_page_summary.pdf")), research_pack = file.path(root, "research_pack", "research_pack.pdf"), readme = file.path(root, "README.md"))
texts <- lapply(docs, function(f) { if (!file.exists(f)) return(NA_character_); if (grepl("\\.pdf$", f)) pdf_text(f) else if (grepl("\\.html$", f)) html_text(f) else paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n") })
strip_urls <- function(s) gsub("https?://\\S+|[A-Za-z0-9_./-]+\\.(csv|html|pdf|png|R|qmd|md)\\b", " ", s)
res <- do.call(rbind, lapply(names(texts), function(n) { s <- texts[[n]]; if (is.na(s)) return(data.frame(doc = n, token = "FILE MISSING", class = "UNMATCHED")); t <- toks(strip_urls(s)); if (!length(t)) return(NULL)
  nt <- norm(t); cl <- ifelse(nt %in% key_vals, "exact", ifelse(nt %in% allow_vals | (n == "research_pack" & nt %in% dce_vals), "allowed", ifelse(nt %in% key_round, "rounded", ifelse(grepl("^(19|20)\\d\\d$", nt), "allowed", "UNMATCHED"))))
  data.frame(doc = n, token = t, class = cl) }))
st <- do.call(rbind, lapply(seq_len(nrow(stale)), function(i) { do.call(rbind, lapply(names(texts), function(n) { s <- texts[[n]]; if (is.na(s)) return(NULL)
  pat <- stale$pattern[i]; hit <- grepl(pat, s, perl = TRUE); if (hit) data.frame(doc = n, token = stale$label[i], class = "STALE") else NULL })) }))
res <- rbind(res, st)
cnt <- as.data.frame.matrix(table(res$doc, factor(res$class, levels = c("exact", "rounded", "allowed", "UNMATCHED", "STALE")))); cnt$doc <- rownames(cnt)

# ---- other checks ---------------------------------------------------------------------------------------------------------------------------------------------------
checks <- list()
chk <- function(name, ok, detail = "") checks[[length(checks) + 1]] <<- data.frame(check = name, result = ifelse(ok, "PASS", "FAIL"), detail = detail)
all_text <- paste(unlist(texts[!is.na(texts)]), collapse = "\n")
chk("no 'PhD' or 'Ph.D' in titles, bylines or any deliverable text", !grepl("\\bPh\\.?D\\b", all_text), "")
rep_only <- kn[kn$audience == "report_only", ]
pub_docs <- c("deck_pdf", "website", "one_pager")
leak <- unlist(lapply(pub_docs, function(n) { s <- texts[[n]]; if (is.na(s)) return(NULL); s <- gsub("Open Payments", "", s); if (grepl("payment", s, ignore.case = TRUE)) paste(n, "mentions payments") else NULL }))
chk("no Open Payments results in the deck, one-pager or website (report-only numbers)", length(leak) == 0, paste(leak, collapse = "; "))
tabs <- list.files(file.path(root, "analysis", "outputs", "tables"), pattern = "\\.csv$", full.names = TRUE)
npi <- unlist(lapply(tabs, function(f) { h <- strsplit(readLines(f, n = 1, warn = FALSE), ",")[[1]]; if (any(grepl("npi|covered_recipient|provider_name|first_name|last_name", tolower(h)))) basename(f) else NULL }))
chk("no NPI-level or named-clinician columns in any output table", length(npi) == 0, paste(npi, collapse = ", "))
alt <- read.csv(file.path(root, "analysis", "outputs", "figures", "alt_text.csv"), stringsAsFactors = FALSE)
pay_figs <- alt[grepl("payment", alt$figure), ]
chk("no manufacturer named in the payments figure alt text or titles", !any(grepl("Novo|Lilly|Nordisk|Sanofi|AstraZeneca", paste(pay_figs$alt_text, collapse = " "))), "")
pay_src <- paste(rd("analysis", "scripts", "32_moduleD_payments.R"), collapse = " "); chk("no manufacturer named in the payments script titles", !grepl("labs\\(title[^)]*(Novo|Lilly)", pay_src), "")
si <- read.csv(file.path(root, "docs", "sources_index.csv"), stringsAsFactors = FALSE, colClasses = "character")
kept <- si[si$in_repo == "yes", ]; missing_src <- kept$saved_copy[!file.exists(file.path(root, kept$saved_copy))]
chk("every source marked in_repo in docs/sources_index.csv has its saved copy in the repository", length(missing_src) == 0, paste(missing_src, collapse = ", "))
fs <- list.files(file.path(root, "docs", "sources"), pattern = "[.](pdf|html)$"); chk("every document under docs/sources is listed in the index", all(fs %in% basename(kept$saved_copy)), paste(setdiff(fs, basename(kept$saved_copy)), collapse = ", "))
chk("no copyrighted third-party copy is tracked (index in_repo = no for KFF, ISPOR, Sawtooth, journal articles, Cornell LII)", !any(grepl("kff|ispor|sawtooth|debekker|uscode", list.files(file.path(root, "docs", "sources"), ignore.case = TRUE))), "")
ext_ids <- kn$id[grepl("^x_", kn$id)]; ext_src <- kn$source_file[kn$id %in% ext_ids]
ext_ok <- ifelse(grepl("^https?://", ext_src), ext_src %in% si$url, file.exists(file.path(root, "analysis", sub("^[.][.]/", "", ext_src))) | file.exists(file.path(root, sub("^[.][.]/", "", ext_src))))
chk("external-fact key numbers (x_*) point to a saved government source or to a URL listed in the sources index", all(ext_ok), paste(ext_src[!ext_ok], collapse = ", "))
bc <- read.csv(file.path(root, "analysis", "outputs", "build_counts.csv"), stringsAsFactors = FALSE)
mf <- jsonlite::fromJSON(file.path(root, "dbt", "target", "manifest.json")); rt <- table(vapply(mf$nodes, function(x) x$resource_type, ""))
chk("build counts match the dbt manifest (models, seeds, tests)", bc$count[bc$item == "models"] == rt[["model"]] && bc$count[bc$item == "seeds"] == rt[["seed"]] && bc$count[bc$item == "tests"] == rt[["test"]], sprintf("manifest: %d models, %d seeds, %d tests", rt[["model"]], rt[["seed"]], rt[["test"]]))
g <- function(...) suppressWarnings(system2("git", c("-C", shQuote(root), ...), stdout = TRUE, stderr = FALSE))
st_out <- g("status", "--porcelain"); st_out <- st_out[!grepl("audit/audit_report.md", st_out)];  # the audit report itself is rewritten by this script
 chk("git status is clean", length(st_out) == 0, paste(head(st_out, 5), collapse = "; "))
tracked <- g("ls-files"); bad <- tracked[grepl("^data/(raw|interim)/|outputs/cache/|(^|/)target/|profiles\\.yml$|(^|/)\\.env$|\\.parquet$|\\.duckdb$", tracked)]
chk("git ls-files shows no raw/interim data, credentials or caches", length(bad) == 0, paste(head(bad, 5), collapse = "; "))
big <- tracked[file.exists(file.path(root, tracked)) & file.size(file.path(root, tracked)) > 50e6]; chk("no tracked file over 50 MB", length(big) == 0, paste(big, collapse = ", "))
cx <- do.call(rbind, checks)

un <- res[res$class %in% c("UNMATCHED", "STALE"), ]
out <- c("# Number and content audit", "", sprintf("Run: %s. Key numbers: %d rows.", format(Sys.Date()), nrow(kn)), "", "## Numbers by document and class", "",
         "| document | exact | rounded | allowed | UNMATCHED | STALE |", "|---|---|---|---|---|---|",
         apply(cnt, 1, function(r) sprintf("| %s | %s | %s | %s | %s | %s |", r[["doc"]], r[["exact"]] %||% 0, r[["rounded"]] %||% 0, r[["allowed"]] %||% 0, r[["UNMATCHED"]] %||% 0, r[["STALE"]] %||% 0)), "",
         "## Other checks", "", "| check | result | detail |", "|---|---|---|", apply(cx, 1, function(r) sprintf("| %s | %s | %s |", r[["check"]], r[["result"]], r[["detail"]])), "",
         "## Needs review (unmatched or stale numbers)", "", if (nrow(un)) apply(unique(un), 1, function(r) sprintf("- %s: `%s` (%s)", r[["doc"]], r[["token"]], r[["class"]])) else "None.")
writeLines(out, file.path(here, "audit_report.md")); cat(paste(out, collapse = "\n"), "\n")
quit(status = ifelse(nrow(un) > 0 || any(cx$result == "FAIL"), 1, 0))
