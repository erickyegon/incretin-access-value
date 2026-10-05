# Plan gap 2: flow from NDC to product to ingredient to label group, with counts, from the committed dbt seeds (product_map.csv: 289 NDCs; product_groups.csv: analysis groups).
# Band width = number of NDCs. Counts are NDC (11-digit) codes, not prescriptions.
source(here::here("R", "theme.R"))
suppressPackageStartupMessages(library(tidyr))
pm0 <- readr::read_csv(here::here("..", "dbt", "seeds", "product_map.csv"), show_col_types = FALSE, progress = FALSE, col_types = readr::cols(.default = "c")) |>
  mutate(product = ifelse(is.na(brand) | brand == "", paste("Generic", ingredient), brand), ingredient = tools::toTitleCase(ingredient), label_group = ifelse(label_group == "obesity", "Obesity label", "Diabetes label"))
pm <- pm0; stopifnot(dplyr::n_distinct(pm$ndc11) == nrow(pm))
small <- pm |> count(product) |> filter(n < 10) |> pull(product); pm_full <- pm
pm <- pm |> mutate(product = ifelse(product %in% small, paste0("Other (", length(small), " small products)"), product))
cols <- c("NDC codes", "Product", "Ingredient", "Label group")
flows <- bind_rows(pm |> count(from = "All NDC codes", to = product, name = "n") |> mutate(col = 1), pm |> count(from = product, to = ingredient, name = "n") |> mutate(col = 2), pm |> count(from = ingredient, to = label_group, name = "n") |> mutate(col = 3))
order_by <- function(x) names(sort(tapply(x$n, x$to, sum), decreasing = TRUE))
lg <- pm |> count(label_group) |> arrange(desc(n)); ing <- pm |> count(ingredient, label_group) |> mutate(o = match(label_group, lg$label_group)) |> arrange(o, desc(n)) |> distinct(ingredient, .keep_all = TRUE)
prod <- pm |> count(product, ingredient) |> mutate(o = match(ingredient, ing$ingredient)) |> arrange(o, desc(n)) |> distinct(product, .keep_all = TRUE)
nodes <- bind_rows(tibble(col = 1, name = "All NDC codes", n = nrow(pm)), tibble(col = 2, name = prod$product, n = prod$n), tibble(col = 3, name = ing$ingredient, n = ing$n), tibble(col = 4, name = lg$label_group, n = lg$n))
gap <- 14; nodes <- nodes |> group_by(col) |> mutate(ymax = rev(cumsum(rev(n)) + gap * (n():1 - 1)) , ymin = ymax - n) |> ungroup()
mid <- max(nodes$ymax) / 2; nodes <- nodes |> group_by(col) |> mutate(shift = mid - (max(ymax) + min(ymin)) / 2, ymin = ymin + shift, ymax = ymax + shift) |> ungroup()
pos <- function(nm, cl) nodes[nodes$name == nm & nodes$col == cl, ]
cursor_out <- setNames(nodes$ymax, paste(nodes$col, nodes$name)); cursor_in <- cursor_out
bands <- list(); k <- 0
for (f in seq_len(nrow(flows))) { r <- flows[f, ]; fc <- r$col; fr <- pm; 
  XC <- c(1, 2.75, 4.5, 6.25); y0 <- cursor_out[paste(fc, r$from)]; cursor_out[paste(fc, r$from)] <- y0 - r$n; y1 <- cursor_in[paste(fc + 1, r$to)]; cursor_in[paste(fc + 1, r$to)] <- y1 - r$n
  t <- seq(0, 1, length.out = 40); s <- plogis((t - 0.5) * 10); top <- y0 + (y1 - y0) * s; bot <- top - r$n; k <- k + 1
  bands[[k]] <- data.frame(id = k, x = XC[fc] + 0.16 + t * (XC[fc + 1] - XC[fc] - 0.32), ymin = bot, ymax = top, to = r$to, from = r$from, fc = fc) }
bd <- bind_rows(bands); poly <- bind_rows(bd |> transmute(id, x, y = ymax, to, fc), bd |> arrange(id, desc(x)) |> transmute(id, x, y = ymin, to, fc))
poly$grp <- ifelse(grepl("^Obesity", poly$to) | poly$to %in% pm$ingredient[pm$label_group == "Obesity label"] | poly$to %in% pm$product[pm$label_group == "Obesity label"], "obesity", "diabetes")
tier <- function(df) ifelse(df$id %in% bd$id[bd$to %in% c(pm$product[pm$label_group == "Obesity label"], pm$ingredient[pm$label_group == "Obesity label"], "Obesity label")], "Obesity label", "Diabetes label")
poly$lab <- tier(poly)
XC <- c(1, 2.75, 4.5, 6.25); nodes$x <- XC[nodes$col]; nodes$lbl <- ifelse(nodes$n >= 20 | nodes$col %in% c(1, 4), sprintf("%s (%s)", nodes$name, nodes$n), ""); small_ing <- nodes |> filter(col == 3, n < 20) |> mutate(t = sprintf("%s (%s)", tolower(name), n)) |> pull(t); small_prod <- nodes |> filter(col == 2, n < 20) |> mutate(t = sprintf("%s (%s)", name, n)) |> pull(t); nodes$ym <- (nodes$ymin + nodes$ymax) / 2
nodes$hj <- ifelse(nodes$col == 1, 1, 0); nodes$lx <- ifelse(nodes$col == 1, nodes$col - 0.04, nodes$col + 0.16 + 0.04); nodes$lx[nodes$col == 4] <- 4.16 + 0.04
p <- ggplot() + geom_polygon(data = poly, aes(x, y, group = id, fill = lab), alpha = 0.55, colour = NA) +
  geom_rect(data = nodes, aes(xmin = x - 0.16, xmax = x + 0.16, ymin = ymin, ymax = ymax), fill = "#444444", colour = "white", linewidth = 0.3) +
  geom_text(data = nodes |> filter(col == 1), aes(x = x - 0.2, y = ym, label = lbl), hjust = 1, size = 4, fontface = "bold") +
  geom_text(data = nodes |> filter(col > 1), aes(x = x + 0.2, y = ym, label = lbl), hjust = 0, size = 3.5) +
  annotate("text", x = XC, y = max(nodes$ymax) + 14, label = cols, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("Obesity label" = col_treated, "Diabetes label" = col_context), name = NULL) + scale_x_continuous(limits = c(-0.3, 7.6)) + scale_y_continuous(expand = expansion(mult = c(0.02, 0.04))) +
  theme_void(base_size = 11) + theme(legend.position = "bottom")
nl <- sum(pm$label_group == "Obesity label"); nd <- sum(pm$label_group == "Diabetes label")
p <- p + labs(title = sprintf("The %d NDC codes map to %d products and %d ingredients; %d carry an obesity label and %d a diabetes label", nrow(pm), dplyr::n_distinct(pm_full$product), nrow(ing), nl, nd),
              subtitle = paste0("Band width = number of NDC codes. Unlabeled small nodes: products ", paste(small_prod, collapse = ", "), "; ingredients ", paste(small_ing, collapse = ", "), "."), caption = "Source: dbt seed product_map (FDA NDC directory, RxNorm, SDUD product names), product_groups. Counts are NDC codes, not prescriptions.") + theme(plot.title.position = "plot", plot.caption.position = "plot")
save_table(pm_full |> count(label_group, ingredient, product, name = "ndc_codes") |> arrange(label_group, ingredient, desc(ndc_codes)), "moduleA_ndc_product_ingredient_label_counts")
save_fig(p, "08_ndc_product_flow", width = 11, height = 7.5, alt = sprintf("Flow diagram from %d NDC codes to %d products, %d ingredients and two label groups. %d NDC codes carry an obesity label (Wegovy, Zepbound, Saxenda, Foundayo and generic liraglutide for weight management) and %d a diabetes label.", nrow(pm), nrow(prod) + length(small) - 1, nrow(ing), nl, nd))
write.csv(data.frame(ndc = nrow(pm), products = dplyr::n_distinct(pm_full$product), ingredients = nrow(ing), obesity_label_ndc = nl, diabetes_label_ndc = nd), here::here("outputs", "tables", "moduleA_ndc_flow_counts.csv"), row.names = FALSE)
print(data.frame(ndc = nrow(pm), products = dplyr::n_distinct(pm_full$product), ingredients = nrow(ing), nl, nd))
