# Module B step 1-2: NHANES survey estimates of eligibility for obesity-labelled incretins (plan_moduleB.md).
# Design: svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~weight, nest = TRUE) on ALL adults 18+, then subset() on the design.
# Weights: exam weight for BMI / blood pressure / questionnaire variables; phlebotomy weight (WTPH2YR, 2021-2023) for anything using HbA1c.
# Output: outputs/tables/moduleB_survey_estimates.csv (long: cycle, measure, stratum, estimate, ci), moduleB_adult_totals.csv.
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
suppressPackageStartupMessages({ library(survey); library(tidyr) })
options(survey.lonely.psu = "adjust")

raw <- get_mart("mart_nhanes_adults")
set.seed(20261004)

derive <- function(d, cyc) {
  anyk <- function(...) { m <- cbind(...); r <- apply(m, 1, function(x) if (any(x %in% TRUE)) TRUE else if (all(x %in% FALSE)) FALSE else NA); r }
  d$weight_exam <- if (cyc == "2021_2023") d$wtmec2yr else d$wtmecprp
  d$weight_ph <- if (cyc == "2021_2023") d$wtph2yr else d$wtmecprp
  d$bmi <- d$bmxbmi
  d$bmi_class <- cut(d$bmi, c(-Inf, 18.5, 25, 27, 30, 35, 40, Inf), right = FALSE,
                     labels = c("under 18.5", "18.5-24.9", "25-26.9", "27-29.9", "30-34.9 (class 1)", "35-39.9 (class 2)", "40+ (class 3)"))
  d$age_group <- cut(d$ridageyr, c(18, 40, 60, 65, Inf), right = FALSE, labels = c("18-39", "40-59", "60-64", "65+"))
  d$sex <- ifelse(d$riagendr == 1, "Male", ifelse(d$riagendr == 2, "Female", NA))
  sy <- rowMeans(d[, c("bpxosy1", "bpxosy2", "bpxosy3")], na.rm = TRUE); di <- rowMeans(d[, c("bpxodi1", "bpxodi2", "bpxodi3")], na.rm = TRUE)
  sy[is.nan(sy)] <- NA; di[is.nan(di)] <- NA
  d$htn_told <- d$bpq020 == 1
  d$htn_med <- if (cyc == "2021_2023") d$bpq150 == 1 else (d$bpq040a == 1 | d$bpq050a == 1)
  d$htn_meas <- ifelse(is.na(sy) & is.na(di), NA, (sy >= 130 | di >= 80) %in% TRUE)
  d$hypertension <- anyk(d$htn_told, d$htn_med, d$htn_meas)
  d$chol_med <- if (cyc == "2021_2023") d$bpq101d == 1 else d$bpq100d == 1
  d$dyslipidemia <- anyk(d$bpq080 == 1, d$chol_med)
  d$cvd <- anyk(d$mcq160b == 1, d$mcq160c == 1, d$mcq160d == 1, d$mcq160e == 1, d$mcq160f == 1)
  d$dm_diag <- d$diq010 == 1
  d$a1c_dm <- d$lbxgh >= 6.5
  d$undiag_dm <- ifelse(is.na(d$a1c_dm) | is.na(d$dm_diag), NA, !d$dm_diag & d$a1c_dm)
  d$dm_any <- anyk(d$dm_diag, d$a1c_dm)
  cond_noa1c <- anyk(d$hypertension, d$dyslipidemia, d$cvd, d$dm_diag)
  cond_a1c <- anyk(d$hypertension, d$dyslipidemia, d$cvd, d$dm_any)
  elig <- function(cond) ifelse(is.na(d$bmi), NA, ifelse(d$bmi >= 30, TRUE, ifelse(d$bmi >= 27, cond, FALSE)))
  d$eligible <- elig(cond_noa1c)            # exam design; no lab variable
  d$eligible_a1c <- elig(cond_a1c)          # includes undiagnosed diabetes by HbA1c: phlebotomy design
  d$obesity <- ifelse(is.na(d$bmi), NA, d$bmi >= 30)
  d$overweight_elig <- ifelse(is.na(d$bmi), NA, d$bmi >= 27 & d$bmi < 30 & cond_noa1c %in% TRUE)
  # HIQ032A-I are check-all-that-apply items coded with the item number when ticked (codebook: Medicaid = 4, Medicare = 2, CHIP = 5), blank otherwise
  d$medicaid <- ifelse(is.na(d$hiq011), NA, !is.na(d$hiq032d) & d$hiq032d == 4)
  d$medicare <- ifelse(is.na(d$hiq011), NA, !is.na(d$hiq032b) & d$hiq032b == 2)
  d$told_overweight <- if (cyc == "2017_2020") d$mcq080 == 1 else NA
  d$elig_told <- ifelse(is.na(d$eligible) | is.na(d$told_overweight), NA, d$eligible & d$told_overweight)
  d$dm_meds <- ifelse(d$dm_diag %in% TRUE, (d$diq050 == 1 | d$diq070 == 1) %in% TRUE, NA)
  # Medicare GLP-1 Bridge criteria that NHANES can measure (lower bound; docs/sources/cms_medicare_glp1_bridge_prescribers.txt): adults 65+, no diagnosed diabetes,
  # BMI >= 35, or BMI >= 27 with told prediabetes, a previous heart attack or a previous stroke. Uncontrolled hypertension and kidney disease are not measurable.
  pre <- anyk(d$diq160 == 1, d$mcq160e == 1, d$mcq160f == 1)
  d$bridge_elig <- ifelse(d$ridageyr < 65 | is.na(d$bmi) | is.na(d$dm_diag), NA, !d$dm_diag & (d$bmi >= 35 | (d$bmi >= 27 & pre %in% TRUE)))
  d
}

res <- list(); tot <- list()
add <- function(cyc, measure, stratum, unit, est, lo, hi, n, wt) res[[length(res) + 1]] <<- tibble(cycle = cyc, measure = measure, stratum = stratum, unit = unit, estimate = est, ci_low = lo, ci_high = hi, n_unweighted = n, weight = wt)

for (cyc in c("2021_2023", "2017_2020")) {
  d <- derive(raw |> filter(cycle == cyc), cyc)
  # no weight = not examined / no blood specimen: weight 0 (NCHS convention). The SAS missing code arrives as ~5e-79, so values below 1e-6 are set to 0.
  clean <- function(w) ifelse(is.na(w) | w < 1e-6, 0, w)
  d$w_exam <- clean(d$weight_exam); d$w_ph <- clean(d$weight_ph)
  des <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~w_exam, nest = TRUE, data = d)
  desph <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra, weights = ~w_ph, nest = TRUE, data = d)
  wname <- if (cyc == "2021_2023") "WTMEC2YR" else "WTMECPRP"; wph <- if (cyc == "2021_2023") "WTPH2YR (HbA1c)" else "WTMECPRP (HbA1c)"
  # adults: sum of weights, examined adults only (weight 0 otherwise)
  ad <- svytotal(~I(w_exam > 0), des); ci <- confint(ad)
  tot[[cyc]] <- tibble(cycle = cyc, adults_18plus_interviewed = nrow(d), adults_examined = sum(d$w_exam > 0, na.rm = TRUE), sum_of_exam_weights_millions = sum(d$w_exam, na.rm = TRUE) / 1e6,
                       sum_of_phlebotomy_weights_millions = sum(d$w_ph, na.rm = TRUE) / 1e6, bmi_missing_examined = sum(is.na(d$bmi) & d$w_exam > 0))
  tot_m <- function(des_, var, sub = NULL, what) {                      # weighted total in millions with 95% CI
    dd <- if (is.null(sub)) des_ else do.call(subset, list(des_, sub))
    r <- svytotal(as.formula(paste0("~I(", var, " %in% TRUE)")), dd, na.rm = TRUE); ci <- confint(r)
    c(est = unname(coef(r)[2]) / 1e6, lo = ci[2, 1] / 1e6, hi = ci[2, 2] / 1e6, n = sum(dd$variables[[var]] %in% TRUE & dd$variables$w_exam > 0, na.rm = TRUE))
  }
  prev <- function(des_, var, sub = NULL) {                              # prevalence in %, among non-missing
    dd <- if (is.null(sub)) des_ else do.call(subset, list(des_, sub))
    dd <- subset(dd, !is.na(dd$variables[[var]]))
    r <- svymean(as.formula(paste0("~as.numeric(", var, ")")), dd); ci <- confint(r)
    c(est = 100 * unname(coef(r)), lo = 100 * ci[1], hi = 100 * ci[2], n = sum(dd$variables$w_exam > 0))
  }
  strata <- list(All = NULL)
  for (g in levels(d$age_group)) strata[[paste("age", g)]] <- bquote(age_group %in% .(g))
  for (s in c("Male", "Female")) strata[[paste("sex", s)]] <- bquote(sex %in% .(s))
  strata[["Medicaid (HIQ032D)"]] <- quote(medicaid %in% TRUE)
  strata[["Medicare (HIQ032B)"]] <- quote(medicare %in% TRUE)
  for (nm in names(strata)) {
    sub <- strata[[nm]]
    mk <- function(var, des_, wt, label, nmx = nm) {
      t_ <- tot_m(des_, var, sub); p_ <- prev(des_, var, sub)
      add(cyc, paste0(label, ": count"), nmx, "millions", t_["est"], t_["lo"], t_["hi"], t_["n"], wt)
      add(cyc, paste0(label, ": prevalence"), nmx, "percent of adults with the measure available", p_["est"], p_["lo"], p_["hi"], p_["n"], wt)
    }
    # adults in the stratum (denominator)
    if (is.null(sub)) { r <- svytotal(~I(w_exam > 0), des); ci <- confint(r); add(cyc, "Adults 18+: count", nm, "millions", coef(r)[2] / 1e6, ci[2, 1] / 1e6, ci[2, 2] / 1e6, sum(d$w_exam > 0), wname) }
    else { dd <- do.call(subset, list(des, sub)); r <- svytotal(~I(w_exam > 0), dd); ci <- confint(r); add(cyc, "Adults 18+: count", nm, "millions", coef(r)[2] / 1e6, ci[2, 1] / 1e6, ci[2, 2] / 1e6, nrow(dd$variables), wname) }
    mk("obesity", des, wname, "BMI 30 or more")
    mk("overweight_elig", des, wname, "BMI 27-29.9 with a measurable condition")
    mk("eligible", des, wname, "Label-eligible (lower bound), without HbA1c")
    mk("eligible_a1c", desph, wph, "Label-eligible (lower bound), including HbA1c diabetes")
    mk("dm_diag", des, wname, "Diagnosed diabetes")
    mk("undiag_dm", desph, wph, "Undiagnosed diabetes (HbA1c >= 6.5%, no diagnosis)")
    mk("hypertension", des, wname, "Hypertension (told, medication or measured)")
    mk("bridge_elig", des, wname, "Medicare GLP-1 Bridge criteria met (measurable part, 65+)")
    if (cyc == "2017_2020") { mk("told_overweight", des, wname, "Told by a doctor overweight (MCQ080)"); mk("elig_told", des, wname, "Label-eligible (lower bound) and told by a doctor overweight") }
  }
  # obesity classes and diabetes treatment among diagnosed diabetes
  for (cl in levels(d$bmi_class)) { dd <- des; dd$variables$cls <- d$bmi_class == cl
    t_ <- tot_m(dd, "cls", NULL); add(cyc, paste0("BMI class ", cl, ": count"), "All", "millions", t_["est"], t_["lo"], t_["hi"], t_["n"], wname)
    p_ <- prev(dd, "cls"); add(cyc, paste0("BMI class ", cl, ": prevalence"), "All", "percent of adults with the measure available", p_["est"], p_["lo"], p_["hi"], p_["n"], wname) }
  dm <- subset(des, dm_diag %in% TRUE)
  m_ <- tot_m(dm, "dm_meds", NULL); add(cyc, "Diabetes medication (insulin or pills) among diagnosed diabetes: count", "All", "millions", m_["est"], m_["lo"], m_["hi"], m_["n"], wname)
  p_ <- prev(dm, "dm_meds"); add(cyc, "Diabetes medication (insulin or pills) among diagnosed diabetes: prevalence", "All", "percent of adults with the measure available", p_["est"], p_["lo"], p_["hi"], p_["n"], wname)
  # eligible among Medicaid adults, by age group (Module E input)
  for (g in levels(d$age_group)) { sub <- bquote(medicaid %in% TRUE & age_group %in% .(g)); dd <- subset(des, medicaid %in% TRUE & age_group %in% g)
    if (nrow(dd$variables) > 30) { t_ <- tot_m(des, "eligible", sub); add(cyc, "Label-eligible (lower bound), without HbA1c: count", paste("Medicaid, age", g), "millions", t_["est"], t_["lo"], t_["hi"], t_["n"], wname)
      r <- svytotal(~I(w_exam > 0), dd); ci <- confint(r); add(cyc, "Adults 18+: count", paste("Medicaid, age", g), "millions", coef(r)[2] / 1e6, ci[2, 1] / 1e6, ci[2, 2] / 1e6, nrow(dd$variables), wname) } }
}
out <- bind_rows(res) |> mutate(across(c(estimate, ci_low, ci_high), ~ signif(as.numeric(.x), 5)))
save_table(out, "moduleB_survey_estimates")
save_table(bind_rows(tot) |> mutate(across(where(is.numeric), ~ round(.x, 3))), "moduleB_adult_totals")
print(bind_rows(tot))
print(out |> filter(stratum == "All", cycle == "2021_2023", grepl("Label-eligible|BMI 30|Adults 18|Diagnosed diab|Undiag", measure)) |> select(measure, estimate, ci_low, ci_high, n_unweighted), n = 30)
