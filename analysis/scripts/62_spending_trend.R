# Item 3 of the plan reconciliation: Medicare Part D and Medicaid spending on GLP-1 and GIP products by brand, 2020-2024 (mart_drug_spending_year, from the CMS Spending by Drug
# dashboards). Spending is GROSS of rebates (the dashboards report spending before manufacturer rebates). Aggregates by brand and year only.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(ggrepel); library(patchwork) })
d <- get_mart("mart_drug_spending_year")
brand_grp <- function(b) ifelse(grepl("^Victoza", b), "Victoza", ifelse(b %in% c("Bydureon Bcise", "Byetta", "Liraglutide"), "Other diabetes GLP-1", b))
long <- d |> transmute(brand = brand_grp(brand_name), year, product_group, `Medicare Part D` = partd_spending, Medicaid = medicaid_spending) |>
  pivot_longer(c(`Medicare Part D`, Medicaid), names_to = "program", values_to = "spend") |> group_by(program, brand, year, product_group) |> summarise(spend = sum(spend, na.rm = TRUE), .groups = "drop") |>
  group_by(program, brand, year) |> summarise(spend = sum(spend), obesity = any(product_group %in% c("obesity_wz", "obesity_saxenda")), .groups = "drop") |> filter(spend > 0)
tot <- long |> group_by(program, year) |> summarise(spend = sum(spend), .groups = "drop")
save_table(long |> mutate(spend_millions = round(spend / 1e6, 1)) |> select(program, brand, year, obesity_label_brand = obesity, spend_millions), "moduleA_spending_by_brand_year")
save_table(tot |> mutate(spend_billions = round(spend / 1e9, 2)) |> select(program, year, spend_billions), "moduleA_spending_totals")
tv <- function(p, y) tot$spend[tot$program == p & tot$year == y] / 1e9
ttl <- sprintf("Gross spending on GLP-1 and GIP products rose from $%sB in 2020 to $%sB in 2024 in Medicare Part D and from $%sB to $%sB in Medicaid; Ozempic and Mounjaro lead the growth", fmt1(tv("Medicare Part D", 2020)), fmt1(tv("Medicare Part D", 2024)), fmt1(tv("Medicaid", 2020)), fmt1(tv("Medicaid", 2024)))
lab <- long |> filter(year == 2024) |> group_by(program) |> mutate(rank = rank(-spend)) |> ungroup() |> filter(rank <= 6 | obesity)
panel <- function(p) { x <- long |> filter(program == p); l <- lab |> filter(program == p)
  ggplot(x, aes(year, spend / 1e9, group = brand)) + geom_line(aes(colour = obesity), linewidth = 0.9) + geom_point(data = x |> filter(year == 2024), aes(colour = obesity), size = 1.8) +
    ggrepel::geom_text_repel(data = l, aes(label = sprintf("%s $%sB", brand, fmt1(spend / 1e9)), colour = obesity), hjust = 0, direction = "y", nudge_x = 0.12, size = 2.9, segment.size = 0.2, box.padding = 0.12, min.segment.length = 0.5, show.legend = FALSE) +
    scale_colour_manual(values = c(`FALSE` = col_comparison, `TRUE` = col_treated), guide = "none") + scale_x_continuous(breaks = 2020:2024, limits = c(2020, 2026.4)) +
    labs(subtitle = p, x = NULL, y = "Gross spending (USD billions)") + theme_incretin(base_size = 10) + theme(plot.subtitle = element_text(face = "bold")) }
cap <- "Source: CMS Medicare Part D Spending by Drug and Medicaid Spending by Drug (warehouse mart mart_drug_spending_year). Spending is gross of rebates. Orange: brands labelled for obesity (Wegovy, Zepbound, Saxenda); grey: diabetes brands. Part D brands also include diabetes and other covered uses; Victoza packs are combined. CMS outlier flags are kept."
p <- (panel("Medicare Part D") | panel("Medicaid")) + plot_annotation(title = ttl, caption = stringr::str_wrap(cap, 160), theme = theme_incretin(base_size = 10))
save_fig(p, "50_spending_trend", width = 12, height = 6.2, alt = sprintf("Two line charts of gross spending by brand, 2020 to 2024, with direct labels. Medicare Part D total rises from %s to %s billion dollars and Medicaid from %s to %s billion; Ozempic is the largest brand in both programmes in 2024 and Mounjaro grows fastest. Obesity-labelled brands (Wegovy, Zepbound, Saxenda) are small in Part D and larger in Medicaid.",
                                          fmt1(tv("Medicare Part D", 2020)), fmt1(tv("Medicare Part D", 2024)), fmt1(tv("Medicaid", 2020)), fmt1(tv("Medicaid", 2024))))
print(as.data.frame(tot |> mutate(spend = round(spend / 1e9, 2)) |> pivot_wider(names_from = program, values_from = spend)))
