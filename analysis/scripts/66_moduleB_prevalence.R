# Plan gap 3: survey-weighted BMI-class and diagnosed-diabetes prevalence by age group and sex, NHANES 2021-2023 adults (same design as 20_moduleB_survey.R:
# svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~WTMEC2YR, nest = TRUE) on all adults, then subset on the design). Prevalence is among adults with the measure available.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(survey); library(tidyr); library(patchwork) })
options(survey.lonely.psu = "adjust")
raw <- get_mart("mart_nhanes_adults") |> filter(cycle == "2021_2023")
clean <- function(w) ifelse(is.na(w) | w < 1e-6, 0, w)
d <- raw |> mutate(w = clean(wtmec2yr), bmi = bmxbmi, sex = ifelse(riagendr == 1, "Men", ifelse(riagendr == 2, "Women", NA)),
  age_group = cut(ridageyr, c(18, 40, 60, 65, Inf), right = FALSE, labels = c("18-39", "40-59", "60-64", "65+")),
  bmi_class = cut(bmi, c(-Inf, 25, 30, 35, 40, Inf), right = FALSE, labels = c("Under 25", "25-29.9 (overweight)", "30-34.9 (class 1)", "35-39.9 (class 2)", "40+ (class 3)")),
  dm_diag = ifelse(is.na(diq010), NA, diq010 == 1))
des <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~w, nest = TRUE, data = d)
est <- function(var, lvl = NULL, sub) {
  dd <- subset(des, sub & !is.na(des$variables[[var]])); y <- if (is.null(lvl)) as.numeric(dd$variables[[var]]) else as.numeric(dd$variables[[var]] == lvl); dd$variables$y <- y
  r <- svymean(~y, dd); ci <- confint(r); c(estimate = 100 * unname(coef(r)), ci_low = 100 * ci[1], ci_high = 100 * ci[2], n = sum(dd$variables$w > 0))
}
rows <- list()
for (s in c("Men", "Women")) for (g in levels(d$age_group)) {
  sub <- with(des$variables, sex %in% s & age_group %in% g & w > 0)
  for (cl in levels(d$bmi_class)) rows[[length(rows) + 1]] <- data.frame(measure = paste("BMI", cl), sex = s, age_group = g, t(est("bmi_class", cl, sub)), check.names = FALSE)
  rows[[length(rows) + 1]] <- data.frame(measure = "Diagnosed diabetes", sex = s, age_group = g, t(est("dm_diag", NULL, sub)))
}
out <- bind_rows(rows) |> mutate(across(c(estimate, ci_low, ci_high), ~ round(.x, 2)))
obs <- out |> filter(grepl("^BMI (30|35|40)", measure)) |> group_by(sex, age_group) |> summarise(estimate = round(sum(estimate), 2), .groups = "drop") |> mutate(measure = "Obesity (BMI 30 or more)", ci_low = NA_real_, ci_high = NA_real_, n = NA_real_)
out <- bind_rows(out, obs) |> arrange(sex, age_group, factor(measure, levels = unique(c(out$measure, "Obesity (BMI 30 or more)"))))
save_table(out, "moduleB_prevalence_age_sex",
  gt::gt(out |> transmute(Measure = measure, Sex = sex, Age = age_group, `Prevalence, %` = round(estimate, 1), `95% CI` = ifelse(is.na(ci_low), "", sprintf("%.1f to %.1f", ci_low, ci_high)), `Adults examined` = n)) |>
    gt::tab_header(title = "BMI class and diagnosed diabetes by age group and sex, U.S. adults, NHANES 2021-2023", subtitle = "Survey-weighted prevalence among adults with the measure available") |> gt::tab_source_note("NCHS NHANES 2021-2023, exam weights, design-based 95% CIs."))
bm <- out |> filter(measure != "Diagnosed diabetes", !grepl("^Obesity", measure)) |> mutate(cls = factor(sub("^BMI ", "", measure), levels = levels(d$bmi_class))) |> arrange(sex, age_group, desc(cls)) |> group_by(sex, age_group) |> mutate(ytop = 100 - (cumsum(estimate) - estimate), ymid = ytop - estimate / 2) |> ungroup() |> mutate(cls = factor(cls, levels = rev(levels(d$bmi_class))))
ob <- out |> filter(grepl("^Obesity", measure)) |> transmute(sex, age_group, obesity = estimate)
shades <- c("Under 25" = "#E6E6E6", "25-29.9 (overweight)" = "#BFBFBF", "30-34.9 (class 1)" = "#F2B999", "35-39.9 (class 2)" = "#E8883F", "40+ (class 3)" = "#8E3A00")
pa <- ggplot(bm, aes(age_group, estimate, fill = cls)) + geom_col(width = 0.75) + facet_wrap(~sex) + scale_fill_manual(values = shades, name = NULL, breaks = names(shades)) +
  geom_text(data = bm |> filter(estimate >= 4), aes(y = ymid, label = sprintf("%.0f", estimate), colour = I(text_on(shades[as.character(cls)]))), size = 3.4, show.legend = FALSE) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.01))) + labs(x = "Age group", y = "Share of adults (%)", subtitle = "BMI class") + theme_incretin() + theme(legend.position = "bottom") + guides(fill = guide_legend(nrow = 1, reverse = TRUE))
dm <- out |> filter(measure == "Diagnosed diabetes")
pb <- ggplot(dm, aes(age_group, estimate, colour = sex, group = sex)) + geom_line(linewidth = 0.9, position = position_dodge(width = 0.3)) + geom_pointrange(aes(ymin = ci_low, ymax = ci_high), position = position_dodge(width = 0.3), size = 0.5) +
  scale_colour_manual(values = c(Men = col_comparison, Women = col_treated), name = NULL) + scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.08))) + labs(x = "Age group", y = "Diagnosed diabetes (%)", subtitle = "Diagnosed diabetes, 95% CI") + theme_incretin() + theme(legend.position = "bottom")
ob65 <- ob$obesity[ob$sex == "Women" & ob$age_group == "40-59"]; mx <- max(ob$obesity); mxr <- ob[which.max(ob$obesity), ]
dm65 <- dm$estimate[dm$age_group == "65+"]
p <- (pa | pb) + plot_layout(widths = c(1.5, 1)) + plot_annotation(
  title = sprintf("Obesity (BMI 30 or more) is highest at ages 40 to 59 (up to %s%% of %s), and diagnosed diabetes rises to %s%% to %s%% at 65 and older", fmt1(mx), tolower(mxr$sex), fmt1(min(dm65)), fmt1(max(dm65))),
  subtitle = "U.S. adults, NHANES 2021-2023, survey-weighted.", caption = "Source: NCHS NHANES 2021-2023, exam weights; design-based 95% CIs. Prevalence among adults with the measure available. Cell labels are percent of adults.", theme = theme_incretin())
save_fig(p, "07_bmi_diabetes_age_sex", width = 12, height = 6, alt = sprintf("Left: stacked bars of BMI class (under 25, overweight, and obesity classes 1 to 3) by age group, for men and women. Right: diagnosed diabetes prevalence by age group and sex with 95 percent intervals; at 65 and older it is %s percent for men and %s percent for women.", fmt1(dm65[1]), fmt1(dm65[2])))
print(as.data.frame(ob)); print(as.data.frame(dm |> select(sex, age_group, estimate)))
