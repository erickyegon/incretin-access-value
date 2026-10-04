# Module D step D1: Part D incretin prescribing descriptives, 2018-2024 (plan_moduleD.md). Aggregate outputs only: no NPI-level table or chart.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(tidyr); library(ineq); library(gt); library(patchwork) })

cap <- "Source: CMS Medicare Part D Prescribers by Provider and Drug (rows with at least 11 claims), NPPES. Part D reflects diabetes and other covered uses, not obesity-brand adoption; counts are claims, and only prescribers with 11 or more claims for a drug appear."
d <- get_mart("mart_prescriber_year", cols = c("prescriber_npi", "data_year", "brand_name", "generic_name", "product_group", "specialty_group", "specialty_group_nppes", "total_claims", "ge65_total_claims"), where = "data_year >= 2018") |>
  mutate(ingredient = tolower(sub(" .*", "", generic_name)), brand = ifelse(tolower(brand_name) == tolower(generic_name), "Liraglutide (generic name)", sub(" .*", "", brand_name)))
groups <- c("Primary care physicians", "Nurse practitioners and physician assistants", "Endocrinology", "Cardiology", "Other")
d$specialty_group <- factor(d$specialty_group, levels = groups)
pal5 <- setNames(unname(okabe_ito[c("blue", "orange", "green", "vermillion", "purple")]), groups)

# ---- 1. claims and prescribers per year by ingredient and brand -----------------------------------------------------------------------------------------------
by_brand <- d |> group_by(data_year, ingredient, brand) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop")
by_ing <- d |> group_by(data_year, ingredient) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop")
all_y <- d |> group_by(data_year) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop")
save_table(by_brand, "moduleD_claims_prescribers_by_brand_year")
save_table(by_ing, "moduleD_claims_prescribers_by_ingredient_year", gt(by_ing |> pivot_wider(names_from = ingredient, values_from = c(claims, prescribers))) |> tab_header(title = "Part D incretin claims and prescribers by ingredient and year"))
ing_cols <- setNames(unname(okabe_ito[c("blue", "orange", "green", "vermillion", "purple", "skyblue")]), c("semaglutide", "tirzepatide", "dulaglutide", "liraglutide", "exenatide", "other"))
by_ing2 <- by_ing |> mutate(ingredient = ifelse(ingredient %in% names(ing_cols), ingredient, "other")) |> group_by(data_year, ingredient) |> summarise(across(c(claims, prescribers), sum), .groups = "drop")
pa <- ggplot(by_ing2, aes(data_year, claims / 1e6, fill = ingredient)) + geom_col() + scale_fill_manual(values = ing_cols, name = NULL) + labs(x = NULL, y = "Claims (millions)") + theme_incretin()
pb <- ggplot(all_y, aes(data_year, prescribers / 1e3)) + geom_col(fill = col_treated) + labs(x = NULL, y = "Prescribers with a 11+ claim row (thousands)") + theme_incretin()
c24 <- all_y |> filter(data_year == 2024); c18 <- all_y |> filter(data_year == 2018)
p1 <- (pa | pb) + plot_annotation(title = stringr::str_wrap(sprintf("Part D incretin claims rose from %s million in 2018 to %s million in 2024, and prescribers from %s thousand to %s thousand", fmt1(c18$claims / 1e6), fmt1(c24$claims / 1e6), fmt1(c18$prescribers / 1e3), fmt1(c24$prescribers / 1e3)), 95),
  subtitle = "Left: claims by ingredient. Right: distinct prescribers with at least one 11-claim row.", caption = stringr::str_wrap(cap, 150), theme = theme_incretin())
save_fig(p1, "30_partd_claims_prescribers", width = 11, height = 5.5, alt = sprintf("Two bar charts, 2018 to 2024. Left: Medicare Part D incretin claims by ingredient, rising from %s million to %s million, with semaglutide and tirzepatide growing fastest. Right: distinct prescribers, rising from %s thousand to %s thousand.", fmt1(c18$claims / 1e6), fmt1(c24$claims / 1e6), fmt1(c18$prescribers / 1e3), fmt1(c24$prescribers / 1e3)))

# ---- 2. specialty mix --------------------------------------------------------------------------------------------------------------------------------------------
mix <- d |> group_by(data_year, specialty_group) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop") |> group_by(data_year) |> mutate(claims_share_pct = 100 * claims / sum(claims), prescriber_share_pct = 100 * prescribers / sum(prescribers)) |> ungroup()
save_table(mix |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleD_specialty_mix_by_year")
m24 <- mix |> filter(data_year == 2024)
p2 <- ggplot(mix, aes(data_year, claims_share_pct, fill = specialty_group)) + geom_col() + scale_fill_manual(values = pal5, name = NULL) + guides(fill = guide_legend(nrow = 2)) +
  labs(title = stringr::str_wrap(sprintf("In 2024, primary care physicians wrote %s%% of Part D incretin claims, nurse practitioners and physician assistants %s%%, endocrinologists %s%% and cardiologists %s%%",
        fmt1(m24$claims_share_pct[m24$specialty_group == groups[1]]), fmt1(m24$claims_share_pct[m24$specialty_group == groups[2]]), fmt1(m24$claims_share_pct[m24$specialty_group == groups[3]]), fmt1(m24$claims_share_pct[m24$specialty_group == groups[4]])), 95),
       subtitle = "Share of Part D incretin claims by prescriber specialty group, 2018-2024 (CMS prescriber type grouped by the committed specialty map)", x = NULL, y = "Share of claims (%)", caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(p2, "31_partd_specialty_mix", width = 10, height = 6, alt = sprintf("Stacked bars of the share of Part D incretin claims by specialty group, 2018 to 2024. In 2024 primary care physicians wrote %s percent, nurse practitioners and physician assistants %s percent, endocrinology %s percent, cardiology %s percent, other %s percent.",
     fmt1(m24$claims_share_pct[1]), fmt1(m24$claims_share_pct[2]), fmt1(m24$claims_share_pct[3]), fmt1(m24$claims_share_pct[4]), fmt1(m24$claims_share_pct[5])))
# cross-check with NPPES grouping
xt <- d |> filter(data_year == 2024, !is.na(specialty_group_nppes)) |> group_by(prescriber_npi) |> summarise(cms = first(as.character(specialty_group)), nppes = first(specialty_group_nppes), .groups = "drop") |> count(cms, nppes) |> group_by(cms) |> mutate(share_of_cms_group_pct = round(100 * n / sum(n), 1)) |> ungroup()
agree <- d |> filter(data_year == 2024, !is.na(specialty_group_nppes)) |> group_by(prescriber_npi) |> summarise(a = first(as.character(specialty_group)) == first(specialty_group_nppes)) |> summarise(agreement_pct = round(100 * mean(a), 1), prescribers = n())
save_table(xt, "moduleD_specialty_crosscheck_cms_vs_nppes")
save_table(agree, "moduleD_specialty_crosscheck_agreement")

# ---- 3. concentration ----------------------------------------------------------------------------------------------------------------------------------------------
tot <- d |> group_by(data_year, prescriber_npi) |> summarise(claims = sum(total_claims), .groups = "drop")
conc <- tot |> group_by(data_year) |> summarise(prescribers = n(), gini = Gini(claims), top10_share_pct = 100 * sum(sort(claims, decreasing = TRUE)[seq_len(ceiling(0.10 * n()))]) / sum(claims),
                                                top1_share_pct = 100 * sum(sort(claims, decreasing = TRUE)[seq_len(ceiling(0.01 * n()))]) / sum(claims), .groups = "drop")
save_table(conc |> mutate(across(where(is.numeric), ~ round(.x, 3))), "moduleD_concentration_by_year", gt(conc |> mutate(across(where(is.numeric), ~ round(.x, 3)))) |> tab_header(title = "Concentration of Part D incretin claims across prescribers") |>
  tab_source_note("Prescribers with at least one 11-claim row in the year; claims summed over all in-scope incretin brands."))
lor <- bind_rows(lapply(c(2018, 2021, 2024), function(y) { x <- tot$claims[tot$data_year == y]; L <- Lc(x); tibble(year = y, p = L$p, L = L$L)[round(seq(1, length(L$p), length.out = 400)), ] }))
c24g <- conc |> filter(data_year == 2024); c18g <- conc |> filter(data_year == 2018)
pl <- ggplot(lor, aes(p, L, colour = factor(year))) + geom_abline(slope = 1, intercept = 0, colour = col_context) + geom_line(linewidth = 1) +
  scale_colour_manual(values = c(`2018` = col_comparison, `2021` = "#8C8C8C", `2024` = col_treated), name = NULL) + coord_equal() +
  labs(x = "Cumulative share of prescribers", y = "Cumulative share of claims") + theme_incretin()
pt <- conc |> pivot_longer(c(top10_share_pct, top1_share_pct), names_to = "grp", values_to = "share") |> mutate(grp = recode(grp, top10_share_pct = "Top 10% of prescribers", top1_share_pct = "Top 1% of prescribers"))
pr <- ggplot(pt, aes(data_year, share, colour = grp)) + geom_line(linewidth = 1) + geom_point() + scale_colour_manual(values = c("Top 10% of prescribers" = col_treated, "Top 1% of prescribers" = col_comparison), name = NULL) + labs(x = NULL, y = "Share of claims (%)") + theme_incretin()
p3 <- (pl | pr) + plot_annotation(title = stringr::str_wrap(sprintf("The top 10%% of Part D incretin prescribers wrote %s%% of claims in 2024 (%s%% in 2018); the Gini coefficient was %s (%s in 2018)", fmt1(c24g$top10_share_pct), fmt1(c18g$top10_share_pct), sprintf("%.2f", c24g$gini), sprintf("%.2f", c18g$gini)), 95),
  subtitle = "Lorenz curves of claims across prescribers (left) and the share written by the top 10% and top 1% (right). Describes prescribers with 11 or more claims for a drug.", caption = stringr::str_wrap(cap, 150), theme = theme_incretin())
save_fig(p3, "32_partd_concentration", width = 11, height = 5.8, alt = sprintf("Left: Lorenz curves of Part D incretin claims across prescribers for 2018, 2021 and 2024, bowing below the equality line. Right: the share of claims by the top 10 percent of prescribers, %s percent in 2018 and %s percent in 2024, and by the top 1 percent, %s and %s percent.", fmt1(c18g$top10_share_pct), fmt1(c24g$top10_share_pct), fmt1(c18g$top1_share_pct), fmt1(c24g$top1_share_pct)))

# ---- 4. tirzepatide adoption ------------------------------------------------------------------------------------------------------------------------------------------
adopt <- d |> filter(data_year >= 2022) |> group_by(data_year, prescriber_npi, specialty_group) |> summarise(any_mounjaro = any(brand == "Mounjaro"), .groups = "drop") |>
  group_by(data_year, specialty_group) |> summarise(prescribers = n(), with_mounjaro = sum(any_mounjaro), share_pct = 100 * mean(any_mounjaro), .groups = "drop")
adopt_all <- d |> filter(data_year >= 2022) |> group_by(data_year, prescriber_npi) |> summarise(a = any(brand == "Mounjaro"), .groups = "drop") |> group_by(data_year) |> summarise(share_pct = 100 * mean(a), prescribers = n(), .groups = "drop")
save_table(adopt |> mutate(share_pct = round(share_pct, 2)), "moduleD_tirzepatide_adoption_by_specialty")
p4 <- ggplot(adopt, aes(data_year, share_pct, colour = specialty_group)) + geom_line(linewidth = 1) + geom_point(size = 2) + scale_colour_manual(values = pal5, name = NULL) + guides(colour = guide_legend(nrow = 2)) + scale_x_continuous(breaks = 2022:2024) +
  labs(title = stringr::str_wrap(sprintf("The share of Part D incretin prescribers with a tirzepatide row rose from %s%% in 2022 to %s%% in 2023 and %s%% in 2024; in 2024 it was %s%% for endocrinology",
        fmt1(adopt_all$share_pct[1]), fmt1(adopt_all$share_pct[2]), fmt1(adopt_all$share_pct[3]), fmt1(adopt$share_pct[adopt$data_year == 2024 & adopt$specialty_group == "Endocrinology"])), 95),
       subtitle = "Share of prescribers with at least one incretin row that have any tirzepatide (Mounjaro) row, by specialty group", x = NULL, y = "Prescribers with a tirzepatide row (%)", caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(p4, "33_partd_tirzepatide_adoption", width = 9, height = 6, alt = sprintf("Lines of the share of Part D incretin prescribers with any tirzepatide row by specialty group, 2022 to 2024. Overall the share rises from %s percent in 2022 to %s percent in 2024.", fmt1(adopt_all$share_pct[1]), fmt1(adopt_all$share_pct[3])))

# ---- 5. Wegovy in Part D after the cardiovascular indication vs Ozempic ----------------------------------------------------------------------------------------------
cv <- d |> filter(data_year == 2024, brand %in% c("Wegovy", "Ozempic")) |> group_by(brand, specialty_group) |> summarise(claims = sum(total_claims), prescribers = n_distinct(prescriber_npi), .groups = "drop") |>
  group_by(brand) |> mutate(claims_share_pct = 100 * claims / sum(claims), prescriber_share_pct = 100 * prescribers / sum(prescribers)) |> ungroup()
save_table(cv |> mutate(across(where(is.numeric), ~ round(.x, 2))), "moduleD_wegovy_vs_ozempic_specialty_2024", gt(cv |> mutate(across(where(is.numeric), ~ round(.x, 1)))) |> tab_header(title = "Wegovy and Ozempic in Part D, 2024, by prescriber specialty group", subtitle = "Descriptive, one year; Wegovy is covered in Part D only for its cardiovascular indication (2024-03-08)"))
wc <- cv |> filter(brand == "Wegovy", specialty_group == "Cardiology"); oc <- cv |> filter(brand == "Ozempic", specialty_group == "Cardiology")
wt <- cv |> filter(brand == "Wegovy") |> summarise(cl = sum(claims), pr = sum(prescribers))
p5 <- ggplot(cv, aes(claims_share_pct, factor(specialty_group, levels = rev(groups)), fill = brand)) + geom_col(position = position_dodge(width = 0.75), width = 0.7) + scale_fill_manual(values = c(Wegovy = col_treated, Ozempic = col_comparison), name = NULL) +
  geom_text(aes(label = paste0(fmt1(claims_share_pct), "%")), position = position_dodge(width = 0.75), hjust = -0.1, size = 3) + scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = stringr::str_wrap(sprintf("In 2024 cardiology wrote %s%% of Wegovy claims in Part D (%s claims, %s prescribers) against %s%% of Ozempic claims", fmt1(wc$claims_share_pct), format(wt$cl, big.mark = ","), format(wt$pr, big.mark = ","), fmt1(oc$claims_share_pct)), 95),
       subtitle = "Share of 2024 Part D claims by prescriber specialty group, Wegovy (cardiovascular indication since 2024-03-08) versus Ozempic. One year of data: descriptive only.", x = "Share of the brand's claims (%)", y = NULL, caption = stringr::str_wrap(cap, 150)) + theme_incretin()
save_fig(p5, "34_partd_wegovy_vs_ozempic_specialty", width = 10, height = 5.5, alt = sprintf("Paired horizontal bars of the share of 2024 Part D claims by prescriber specialty group for Wegovy and Ozempic. Cardiology wrote %s percent of Wegovy claims and %s percent of Ozempic claims.", fmt1(wc$claims_share_pct), fmt1(oc$claims_share_pct)))

print(all_y |> mutate(claims = round(claims))); print(conc |> mutate(across(where(is.numeric), ~ round(.x, 3)))); print(m24 |> select(specialty_group, claims_share_pct, prescriber_share_pct)); print(agree); print(adopt_all)
print(cv |> filter(specialty_group == "Cardiology")); cat("65+ claims populated share (2024):", round(mean(!is.na(d$ge65_total_claims[d$data_year == 2024])), 3), "\n")
