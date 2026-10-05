# Figure QA over every figure in analysis/outputs/figures (run from anywhere: Rscript audit/check_figures.R).
# Checks, per figure and variant:
#   1. files exist (report png and svg, deck png, web png and svg); image size matches the variant (report 300 dpi, deck 200 dpi, web at most 300 KB)
#   2. type scale: title at most two lines, subtitle at most two lines, source line at most two lines (from the save_fig log); minimum direct-label size at least 10 pt
#   3. clipping: no ink touches the image border (text cut at the edge), in every PNG variant
#   4. label overlap: ggrepel reported no unlabeled data points while saving
#   5. alt text exists in alt_text.csv
# Also writes analysis/outputs/figures/contact_sheet.png (all report figures). Exits with an error if any check fails.
suppressPackageStartupMessages({ library(png) })
root <- if (file.exists("analysis/outputs/figures")) "." else ".."
fd <- file.path(root, "analysis", "outputs", "figures")
qa <- read.csv(file.path(fd, "figure_qa_log.csv"), stringsAsFactors = FALSE)
alt <- read.csv(file.path(fd, "alt_text.csv"), stringsAsFactors = FALSE)
figs <- sort(unique(sub("([.]svg|[.]png)$", "", sub("(_deck|_web|_report)(?=[.](png|svg)$)", "", perl = TRUE, list.files(fd, pattern = "^[0-9]{2}_.*[.](png|svg)$")))))
figs <- setdiff(figs, c())
rows <- list(); chk <- function(f, what, ok, detail = "") rows[[length(rows) + 1]] <<- data.frame(figure = f, check = what, ok = isTRUE(ok), detail = detail, stringsAsFactors = FALSE)
edge_ink <- function(path, px = 2) { a <- png::readPNG(path); if (length(dim(a)) == 3) a <- pmin(a[, , 1], a[, , 2], a[, , 3]); h <- nrow(a); w <- ncol(a)
  ink <- a < 0.9; sum(ink[1:px, ]) + sum(ink[(h - px + 1):h, ]) + sum(ink[, 1:px]) + sum(ink[, (w - px + 1):w]) }
deck_src <- paste(readLines(file.path(root, "deck", "deck.qmd"), warn = FALSE), collapse = "
")
in_deck <- function(f) grepl(paste0('"', f, '"'), deck_src, fixed = TRUE)   # deck checks apply to the figures the deck uses
for (f in figs) {
  p <- function(s) file.path(fd, paste0(f, s)); q <- qa[qa$figure == f, ]
  chk(f, "all variants exist", all(file.exists(p(c(".png", ".svg", "_deck.png", "_web.png", "_web.svg")))))
  if (!all(file.exists(p(c(".png", "_deck.png", "_web.png"))))) next
  if (nrow(q) == 1) {
    dims <- function(s) { d <- dim(png::readPNG(p(s), native = TRUE)); c(w = d[2], h = d[1]) }
    r <- dims(".png"); dk <- dims("_deck.png"); wb <- dims("_web.png")
    chk(f, "report image is 300 dpi at the saved size", abs(r["w"] - q$width_in * 300) <= 2 && abs(r["h"] - q$height_in * 300) <= 2, sprintf("%d x %d", r["w"], r["h"]))
    dw <- if (is.null(q$deck_w) || is.na(q$deck_w)) q$width_in else q$deck_w; dh <- if (is.null(q$deck_h) || is.na(q$deck_h)) q$height_in else q$deck_h
    if (in_deck(f)) chk(f, "deck image is 200 dpi at the slide-area size", abs(dk["w"] - dw * 200) <= 2 && abs(dk["h"] - dh * 200) <= 2, sprintf("%d x %d (expected %d x %d)", dk["w"], dk["h"], round(dw * 200), round(dh * 200)))
    if (in_deck(f)) chk(f, "deck text at least 13 pt", is.null(q$deck_min_pt) || is.na(q$deck_min_pt) || q$deck_min_pt >= 12.9, q$deck_min_pt)
    if (in_deck(f)) chk(f, "no ggrepel overlap warnings in the deck variant", is.null(q$deck_repel_warnings) || is.na(q$deck_repel_warnings) || q$deck_repel_warnings == 0, q$deck_repel_warnings)
    chk(f, "web image same aspect ratio and at most 300 KB", abs(wb["w"] / wb["h"] - q$width_in / q$height_in) < 0.01 && file.size(p("_web.png")) <= 300 * 1024, sprintf("%d KB", round(file.size(p("_web.png")) / 1024)))
    chk(f, "title at most two lines", q$title_lines <= 2, q$title_lines); chk(f, "subtitle at most two lines", q$subtitle_lines <= 2, q$subtitle_lines); chk(f, "source line at most two lines", q$source_lines <= 2, q$source_lines)
    chk(f, "smallest direct label at least 10 pt", is.na(q$min_label_pt) || q$min_label_pt >= 9.9, q$min_label_pt)
    chk(f, "no ggrepel overlap warnings (no unlabeled data points)", q$repel_warnings == 0, q$repel_warnings)
  } else chk(f, "has a QA log row (re-run the figure script)", FALSE)
  for (s in c(".png", if (in_deck(f)) "_deck.png", "_web.png")) chk(f, paste0("no ink at the image border (", sub("^_", "", sub("[.]png", "", s)) , if (s == ".png") "report" else "", ")"), edge_ink(p(s)) == 0, edge_ink(p(s)))
  chk(f, "alt text exists", f %in% alt$figure && nzchar(alt$alt_text[alt$figure == f][1]))
}
res <- do.call(rbind, rows); write.csv(res, file.path(root, "analysis", "outputs", "tables", "figure_qa_check.csv"), row.names = FALSE)
bad <- res[!res$ok, ]; if (nrow(bad)) { print(bad, row.names = FALSE, right = FALSE) }
cat(sum(res$ok), "of", nrow(res), "figure checks pass across", length(figs), "figures\n")

# contact sheet of all report figures
suppressPackageStartupMessages({ library(grid) })
rep <- file.path(fd, paste0(figs, ".png")); rep <- rep[file.exists(rep)]; ncol <- 5; nrow <- ceiling(length(rep) / ncol)
ragg::agg_png(file.path(fd, "contact_sheet.png"), width = ncol * 480, height = nrow * 360, res = 96, background = "white")
grid.newpage(); pushViewport(viewport(layout = grid.layout(nrow, ncol)))
for (i in seq_along(rep)) { pushViewport(viewport(layout.pos.row = ceiling(i / ncol), layout.pos.col = (i - 1) %% ncol + 1)); a <- png::readPNG(rep[i])
  grid.raster(a, width = unit(0.95, "npc"), height = unit(0.88, "npc"), default.units = "npc", interpolate = TRUE)
  grid.text(sub("[.]png$", "", basename(rep[i])), y = unit(1, "npc") - unit(2, "mm"), gp = gpar(fontsize = 7, col = "#444444")); popViewport() }
invisible(dev.off())
cat("contact sheet written:", file.path(fd, "contact_sheet.png"), "\n")
if (nrow(bad)) quit(status = 1)
