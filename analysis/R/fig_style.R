# One style system for every figure (sourced by theme.R).
#   fonts   : Source Serif 4 (titles) and IBM Plex Sans (everything else), bundled in assets/fonts (SIL Open Font License) and registered with systemfonts.
#   scale   : title 16 pt (at most two lines), subtitle 12 pt (at most two lines), axis and direct labels at least 10 pt, source line 9 pt (at the saved size).
#   variants: report (title, subtitle, source line; notes go to the Quarto caption), deck (no title or notes, larger type), web (no title or notes, compressed PNG under about 300 KB, plus SVG).
#   save_fig() applies the scale to every figure, writes a QA log row per variant, and writes the notes to outputs/figures/figure_notes.csv.
suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })

FONT_TEXT <- "IBM Plex Sans"; FONT_TITLE <- "Source Serif 4"
register_incretin_fonts <- function() {
  d <- here::here("assets", "fonts"); f <- function(x) file.path(d, x)
  if (!all(file.exists(f(c("IBMPlexSans-Regular.ttf", "SourceSerif4-Regular.ttf"))))) { warning("font files missing in analysis/assets/fonts; falling back to sans/serif"); FONT_TEXT <<- "sans"; FONT_TITLE <<- "serif"; return(invisible(FALSE)) }
  systemfonts::register_font("IBM Plex Sans", plain = f("IBMPlexSans-Regular.ttf"), bold = f("IBMPlexSans-SemiBold.ttf"), italic = f("IBMPlexSans-Italic.ttf"), bolditalic = f("IBMPlexSans-Bold.ttf"))
  systemfonts::register_font("Source Serif 4", plain = f("SourceSerif4-Regular.ttf"), bold = f("SourceSerif4-Semibold.ttf"), italic = f("SourceSerif4-Regular.ttf"), bolditalic = f("SourceSerif4-Bold.ttf"))
  invisible(TRUE)
}
register_incretin_fonts()

# ---- type scale (points at the saved size) --------------------------------------------------------------------------------------------------------------------------
FIG_SCALE <- list(report = list(title = 16, subtitle = 12, axis_text = 10, axis_title = 10.5, legend = 10, strip = 10.5, caption = 9, direct_mm = 3.6),
                  deck   = list(title = 16, subtitle = 12, axis_text = 13, axis_title = 13.5, legend = 13, strip = 13.5, caption = 11, direct_mm = 4.6),
                  web    = list(title = 16, subtitle = 12, axis_text = 10, axis_title = 10.5, legend = 10, strip = 10.5, caption = 9, direct_mm = 3.6))
MIN_TEXT_PT <- 9.9; PT_PER_MM <- 72.27 / 25.4

theme_incretin <- function(base_size = 11, base_family = FONT_TEXT, variant = "report") {
  s <- FIG_SCALE[[variant]]
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      text = element_text(colour = "#222222", family = base_family),
      plot.title = element_text(family = FONT_TITLE, face = "bold", size = s$title, hjust = 0, lineheight = 1.05, margin = margin(b = 4)),
      plot.subtitle = element_text(size = s$subtitle, hjust = 0, colour = "#444444", lineheight = 1.1, margin = margin(b = 8)),
      plot.caption = element_text(size = s$caption, hjust = 0, colour = "#595959", lineheight = 1.1, margin = margin(t = 8)),
      plot.title.position = "plot", plot.caption.position = "plot",
      panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(colour = "#E6E6E6", linewidth = 0.3),
      strip.text = element_text(face = "bold", hjust = 0, size = s$strip),
      axis.text = element_text(size = s$axis_text, colour = "#333333"), axis.title = element_text(size = s$axis_title),
      legend.position = "bottom", legend.text = element_text(size = s$legend), legend.title = element_text(size = s$legend)
    )
}

# ---- contrast: label colour on filled tiles and bars ------------------------------------------------------------------------------------------------------------------
rel_luminance <- function(col) { rgb <- farver::decode_colour(col) / 255; lin <- ifelse(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4); as.numeric(0.2126 * lin[, 1] + 0.7152 * lin[, 2] + 0.0722 * lin[, 3]) }
contrast_ratio <- function(a, b) { la <- rel_luminance(a); lb <- rel_luminance(b); (pmax(la, lb) + 0.05) / (pmin(la, lb) + 0.05) }
text_on <- function(fill, dark = "#111111", light = "#FFFFFF") { fill <- ifelse(is.na(fill), "#FFFFFF", fill); ifelse(contrast_ratio(fill, dark) >= contrast_ratio(fill, light), dark, light) }

# ---- text sizes: bring every text layer to the minimum size and the project font -------------------------------------------------------------------------
.text_geoms <- c("GeomText", "GeomLabel", "GeomTextRepel", "GeomLabelRepel")
bump_layers <- function(p, mm) {
  for (i in seq_along(p$layers)) { g <- class(p$layers[[i]]$geom)
    if (any(g %in% .text_geoms)) { s <- p$layers[[i]]$aes_params$size
      if (is.null(s) && is.null(p$layers[[i]]$mapping$size)) p$layers[[i]]$aes_params$size <- mm else if (!is.null(s) && s < mm) p$layers[[i]]$aes_params$size <- mm
      if (is.null(p$layers[[i]]$aes_params$family)) p$layers[[i]]$aes_params$family <- FONT_TEXT } }
  p
}
min_layer_pt <- function(p) { pl <- c(list(p), if (inherits(p, "patchwork")) p$patches$plots else list()); v <- c()
  for (q in pl) for (l in q$layers) if (any(class(l$geom) %in% .text_geoms) && !is.null(l$aes_params$size)) v <- c(v, l$aes_params$size * PT_PER_MM)
  if (length(v)) min(v) else NA_real_ }
# the type scale on one plot; elements that the plot's theme blanks (theme_void maps) stay blank
add_scale_theme <- function(q, s) {
  blank <- function(el) inherits(q$theme[[el]], "element_blank")
  th <- theme(text = element_text(family = FONT_TEXT), plot.title = element_text(family = FONT_TITLE, face = "bold", size = s$title), plot.subtitle = element_text(family = FONT_TEXT, size = s$subtitle), plot.caption = element_text(family = FONT_TEXT, size = s$caption),
              legend.text = element_text(size = s$legend), legend.title = element_text(size = s$legend), strip.text = element_text(size = s$strip, face = "bold"), plot.margin = margin(10, 14, 10, 14))
  if (!blank("axis.text")) th <- th + theme(axis.text = element_text(size = s$axis_text))
  if (!blank("axis.title")) th <- th + theme(axis.title = element_text(size = s$axis_title))
  q + th
}
apply_scale <- function(p, variant) {
  s <- FIG_SCALE[[variant]]
  if (inherits(p, "patchwork")) { p$patches$plots <- lapply(p$patches$plots, function(q) add_scale_theme(bump_layers(q, s$direct_mm), s)); p <- add_scale_theme(bump_layers(p, s$direct_mm), s)
    p <- p + plot_annotation(theme = theme(plot.title = element_text(family = FONT_TITLE, face = "bold", size = s$title), plot.subtitle = element_text(size = s$subtitle), plot.caption = element_text(size = s$caption), plot.title.position = "plot", plot.caption.position = "plot")) }
  else p <- add_scale_theme(bump_layers(p, s$direct_mm), s)
  p
}

# ---- title, subtitle and source line --------------------------------------------------------------------------------------------------------------------------------
.get <- function(p, what) if (inherits(p, "patchwork")) p$patches$annotation[[what]] else p$labels[[what]]
.set <- function(p, what, value) { if (inherits(p, "patchwork")) p$patches$annotation[[what]] <- value else p$labels[[what]] <- value; p }
unwrap <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) x else gsub("\\s*\n\\s*", " ", x)
n_lines <- function(x) if (is.null(x) || is.na(x)) 0L else length(strsplit(x, "\n", fixed = TRUE)[[1]])
# split a caption into the source line (first sentence) and notes (the rest)
split_caption <- function(cap) {
  cap <- unwrap(cap); if (is.null(cap) || is.na(cap) || !nzchar(cap)) return(list(source = NULL, notes = NULL))
  m <- regexpr("(?<=[a-z0-9\\)\\]%])\\.\\s+(?=[A-Z])", cap, perl = TRUE)
  if (m[1] < 0) list(source = cap, notes = NULL) else list(source = substr(cap, 1, m[1]), notes = trimws(substr(cap, m[1] + attr(m, "match.length"), nchar(cap))))
}
# keep whole sentences while they fit in max_lines at the given size, then cut a too-long first sentence at its last clause boundary that fits;
# the rest is returned as overflow (it goes to the notes, i.e. the Quarto caption)
cap_first <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
end_stop <- function(x) if (grepl("[.!?]$", x)) x else paste0(x, ".")
clause_cut <- function(x, width_in, pt, max_lines) {
  if (n_lines(wrap_to(x, width_in, pt)) <= max_lines) return(list(kept = x, overflow = NULL))
  for (pat in c("; ", ", ", " \\(| - ", " and | against | from ")) {   # semicolon first, then comma, then other boundaries
    pos <- as.integer(gregexpr(pat, x)[[1]]); pos <- pos[pos > 0]
    for (k in rev(pos)) { head <- sub("[,;:\\s-]+$", "", substr(x, 1, k - 1))
      if (nchar(head) >= 0.3 * nchar(x) && n_lines(wrap_to(head, width_in, pt)) <= max_lines) {
        rest <- trimws(sub("^(; |, |\\s*-\\s*|\\s*and |\\s*against |\\s*from )", "", substr(x, k, nchar(x)))); rest <- sub("^\\((.*)\\)$", "\\1", rest)
        return(list(kept = head, overflow = end_stop(cap_first(trimws(rest))))) } } }
  list(kept = x, overflow = NULL)
}
fit_sentences <- function(x, width_in, pt, max_lines = 2) {
  if (is.null(x) || is.na(x)) return(list(kept = x, overflow = NULL))
  parts <- strsplit(x, "(?<=[a-z0-9\\)\\]%])\\.\\s+(?=[A-Z0-9])", perl = TRUE)[[1]]; if (length(parts) > 1) parts[-length(parts)] <- paste0(parts[-length(parts)], ".")
  kept <- character(); for (i in seq_along(parts)) { cand <- paste(c(kept, parts[i]), collapse = " "); if (n_lines(wrap_to(cand, width_in, pt)) <= max_lines || length(kept) == 0) kept <- c(kept, parts[i]) else break }
  rest <- if (length(kept) < length(parts)) paste(parts[-seq_along(kept)], collapse = " ") else NULL
  kt <- paste(kept, collapse = " "); cc <- clause_cut(kt, width_in, pt, max_lines)
  list(kept = cc$kept, overflow = paste(c(cc$overflow, rest), collapse = " ") |> trimws() |> (\(z) if (nzchar(z)) z else NULL)())
}
# a title that needs more than two lines keeps its first clause; the rest moves to the front of the subtitle
fit_title <- function(x, width_in, pt = 16) { if (is.null(x) || is.na(x)) return(list(title = x, moved = NULL)); cc <- clause_cut(x, width_in, pt, 2); list(title = cc$kept, moved = cc$overflow) }
wrap_to <- function(x, width_in, pt) { if (is.null(x) || is.na(x)) return(x); stringr::str_wrap(x, width = floor(width_in * 72 / (pt * 0.56))) }

# ---- QA log and notes ---------------------------------------------------------------------------------------------------------------------------------------------------
.qa_rows <- new.env(); .qa_rows$x <- list()
log_qa <- function(...) .qa_rows$x[[length(.qa_rows$x) + 1]] <- data.frame(..., stringsAsFactors = FALSE)
write_csv_merge <- function(df, f, key) {
  cur <- if (file.exists(f)) readr::read_csv(f, show_col_types = FALSE) else df[0, ]; cur <- cur[!cur[[key]] %in% df[[key]], ]
  for (n in setdiff(names(df), names(cur))) cur[[n]] <- NA; for (n in setdiff(names(cur), names(df))) df[[n]] <- NA
  out <- rbind(cur[names(df)], df); out <- out[order(out[[key]]), ]; readr::write_csv(out, f)
}
write_png_under <- function(p, path, width, height, max_kb = 300, dpi = c(150, 130, 115, 100, 90)) {
  for (d in dpi) { ggplot2::ggsave(path, p, width = width, height = height, dpi = d, bg = "white", device = ragg::agg_png); if (file.size(path) <= max_kb * 1024) break }
  invisible(d)
}

#' Save one figure in the three variants (report, deck, web) and log a QA row for each. `alt` goes to alt_text.csv.
save_fig <- function(p, name, width = 9, height = 6, alt = NA_character_, notes = NULL) {
  d <- out_dir("figures"); warns <- character()
  dir.create(file.path(d, "..", "cache", "figobj"), recursive = TRUE, showWarnings = FALSE); saveRDS(p, file.path(d, "..", "cache", "figobj", paste0(name, ".rds")))   # lets the deck variants be re-exported without re-running the analysis
  ft <- fit_title(unwrap(.get(p, "title")), width, 16); title0 <- ft$title; sub_all <- unwrap(.get(p, "subtitle")); if (!is.null(ft$moved)) sub_all <- paste(c(ft$moved, sub_all), collapse = " "); fs <- fit_sentences(sub_all, width, 12); sub0 <- fs$kept; sc <- split_caption(.get(p, "caption")); fsrc <- fit_sentences(sc$source, width, 9, 2); src <- fsrc$kept; if (!is.null(fsrc$overflow)) sc$notes <- paste(c(fsrc$overflow, sc$notes), collapse = " "); nts <- paste(c(fs$overflow, sc$notes, notes), collapse = " "); nts <- if (nzchar(trimws(nts))) trimws(nts) else NULL
  build <- function(variant) {
    q <- p; s <- FIG_SCALE[[variant]]
    if (variant == "report") { q <- .set(q, "title", wrap_to(title0, width, s$title)); q <- .set(q, "subtitle", wrap_to(sub0, width, s$subtitle)); q <- .set(q, "caption", wrap_to(src, width, s$caption)) }
    else { q <- .set(q, "title", NULL); q <- .set(q, "subtitle", NULL); q <- .set(q, "caption", if (variant == "web") wrap_to(src, width, s$caption) else NULL) }
    apply_scale(q, variant)
  }
  save_variant <- function(variant, path, dpi = 300, svg = FALSE) {
    q <- build(variant); res <- withCallingHandlers({
      if (variant == "web" && !svg) write_png_under(q, path, width, height) else if (svg) ggplot2::ggsave(path, q, width = width, height = height, bg = "white", device = svglite::svglite) else ggplot2::ggsave(path, q, width = width, height = height, dpi = dpi, bg = "white", device = ragg::agg_png) },
      warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") })
    q
  }
  qr <- save_variant("report", file.path(d, paste0(name, ".png")), 300); save_variant("report", file.path(d, paste0(name, ".svg")), svg = TRUE)
  { q <- build("report"); write_png_under(q, file.path(d, paste0(name, "_report.png")), width, height, max_kb = 350, dpi = c(160, 140, 120, 100, 90)) }   # compressed copy of the report variant for the HTML report
  dk <- save_deck(p, name)
  save_variant("web", file.path(d, paste0(name, "_web.png"))); save_variant("web", file.path(d, paste0(name, "_web.svg")), svg = TRUE)
  log_qa(figure = name, width_in = width, height_in = height, title_lines = n_lines(wrap_to(title0, width, 16)), subtitle_lines = n_lines(wrap_to(sub0, width, 12)), source_lines = n_lines(wrap_to(src, width, 9)),
         repel_warnings = sum(grepl("unlabeled data points|overlaps", warns)), other_warnings = sum(!grepl("unlabeled data points|overlaps", warns)), web_kb = round(file.size(file.path(d, paste0(name, "_web.png"))) / 1024), min_label_pt = round(min_layer_pt(qr), 1), deck_w = dk$w, deck_h = dk$h, deck_min_pt = dk$min_pt, deck_repel_warnings = dk$repel)
  write_csv_merge(do.call(rbind, .qa_rows$x[length(.qa_rows$x)]), file.path(d, "figure_qa_log.csv"), "figure")
  if (!is.null(nts)) write_csv_merge(data.frame(figure = name, notes = nts), file.path(d, "figure_notes.csv"), "figure")
  if (!is.na(alt)) write_csv_merge(data.frame(figure = name, alt_text = alt), file.path(d, "alt_text.csv"), "figure")
  invisible(file.path(d, name))
}

# ---- deck variant: sized to the slide area, no title or notes, 13 pt text, simplified by the figure's hook in deck_figs.R --------------------------------------------------------
DECK_PANEL <- c(8.0, 4.6); DECK_FULL <- c(12.3, 4.5)
save_deck <- function(p, name) {
  d <- out_dir("figures"); dims <- if (!is.null(DECK_DIMS[[name]])) DECK_DIMS[[name]] else DECK_PANEL; hook <- DECK_HOOKS[[name]]
  q <- if (is.function(hook)) hook(p) else p
  q <- .set(q, "title", NULL); q <- .set(q, "subtitle", NULL); q <- .set(q, "caption", NULL); q <- apply_scale(q, "deck"); warns <- character()
  withCallingHandlers({
    ggplot2::ggsave(file.path(d, paste0(name, "_deck.png")), q, width = dims[1], height = dims[2], dpi = 200, bg = "white", device = ragg::agg_png)
    ggplot2::ggsave(file.path(d, paste0(name, "_deck.svg")), q, width = dims[1], height = dims[2], bg = "white", device = svglite::svglite) },
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") })
  list(w = dims[1], h = dims[2], min_pt = round(min_layer_pt(q), 1), repel = sum(grepl("unlabeled data points|overlaps", warns)))
}
#' Re-export only the deck variant of a figure from the saved plot object (analysis/outputs/cache/figobj) and update its QA log row.
export_deck <- function(name) {
  p <- readRDS(file.path(out_dir("figures"), "..", "cache", "figobj", paste0(name, ".rds"))); dk <- save_deck(p, name)
  f <- file.path(out_dir("figures"), "figure_qa_log.csv"); qa <- readr::read_csv(f, show_col_types = FALSE)
  for (col in c("deck_w", "deck_h", "deck_min_pt", "deck_repel_warnings")) if (!col %in% names(qa)) qa[[col]] <- NA_real_
  i <- which(qa$figure == name); qa$deck_w[i] <- dk$w; qa$deck_h[i] <- dk$h; qa$deck_min_pt[i] <- dk$min_pt; qa$deck_repel_warnings[i] <- dk$repel; readr::write_csv(qa, f)
  invisible(dk)
}

source(here::here("R", "deck_figs.R"))
