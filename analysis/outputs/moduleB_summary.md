# Module B in plain language: who is eligible, how many are treated, and how the number might grow

**Question.** How many U.S. adults are eligible for obesity-labelled incretins, how many are diagnosed and treated, and how might treatment grow over five years?
(Plan: [plan_moduleB.md](../plan_moduleB.md), committed before any result; departures are in [deviations.md](deviations.md).)

**Data.** NHANES adults aged 18 and over, August 2021 to August 2023 (primary) and 2017 to March 2020 (comparison), analysed with the survey design and the weights NCHS prescribes
([variables and codebook descriptions](tables/nhanes_variables_used.csv)); KFF Health Tracking Polls for the share of adults using a GLP-1 drug (see `docs/sources_index.csv`); Medicaid and Medicare data for the brand split.

## Who is eligible (measured)
- **Adults.** The weights represent 253.8 million U.S. adults in 2021–2023 (civilian, non-institutionalised) ([totals](tables/moduleB_adult_totals.csv)).
- **Eligible.** At least 128.8 million adults (95% CI 117.2 to 140.3), about half of all adults, meet the labels' weight criteria: BMI 30 or more (99.6 million), or BMI 27 to 29.9 with a condition NHANES can measure
  ([estimates](tables/moduleB_survey_estimates.csv)). This is a lower bound: sleep apnea and the labels' other conditions are not measured. The label text gives no BMI numbers; they come from the label's trial populations (see the plan).
- **Obesity classes.** Class 1 (BMI 30 to 34.9) 51.4 million, class 2 (35 to 39.9) 24.9 million, class 3 (40 or more) 23.3 million.
- **Diabetes.** 11.3% of adults (10.0 to 12.6) have diagnosed diabetes; a further 2.2% (1.7 to 2.6), 5.5 million, have an HbA1c of 6.5% or more without a diagnosis (HbA1c analyses use the phlebotomy weight).
- **Trend.** 2017–2020 estimates are close: obesity 41.4% (39.2 to 43.7) versus 39.8% (36.2 to 43.3); eligible 130.4 million versus 128.8 million.
- **Medicaid.** 34.3 million adults report Medicaid coverage; 17.8 million of them (14.7 to 20.9) are label-eligible, the input for the budget model.
- **Medicare.** The measurable part of the Medicare GLP-1 Bridge criteria covers 10.8 million adults aged 65 and over (8.6 to 13.0), a lower bound.

## How many are diagnosed and treated (funnel; measured solid, modelled hatched)
[Funnel figure](figures/20_funnel.png), [table](tables/moduleB_funnel.csv).
- **Aware.** 85.5 million label-eligible adults were told by a doctor they were overweight (2017–2020; the question was not asked in 2021–2023). 28.8 million adults have diagnosed diabetes and 24.2 million of them take insulin or pills.
- **Treated (modelled).** KFF's February–March 2026 poll puts current GLP-1 use at 12% of adults (±3 points), about 30.4 million (23.5 to 37.5) across all drugs and indications. Taking KFF's 45% use among adults with diabetes (range assumed 35–55%),
  about 12.9 million have diabetes and 17.4 million (9.9 to 25.2) do not, a proxy for weight-management use that also includes use for heart disease.
- **Brand split, by payer** ([table](tables/moduleB_brand_split_by_payer.csv)). In Medicaid states with coverage the Wegovy share of Wegovy plus Zepbound prescriptions fell from 84.3% (2024 Q1) to 53.3% (2025 Q3) and 36.3% (2026 Q1, preliminary); in Medicare Part D 2024,
  Wegovy is essentially all of it (Wegovy is covered there only for its cardiovascular indication). These are payer shares, not national shares.

## Five-year scenarios, not a prediction
[Fan chart](figures/21_forecast_fan.png), [year-end table](tables/moduleB_forecast_year_end.csv), [scenarios](tables/moduleB_forecast_scenarios.csv), [assumptions with sources](tables/moduleB_assumptions.csv).
Across 10,000 draws over the assumed ranges, adults using a GLP-1 drug without diagnosed diabetes reach a median of 33.8 million by end-2030 (90% interval 17.4 to 51.7) from 17.5 million in early 2026; the downside, base and upside parameter sets give 16.5, 35.1 and 65.6 million.
The Medicare GLP-1 Bridge (July 2026 to December 2027, $50 copay) and oral options are included as access events with assumed sizes; no source gives their effect on use.

## What this does not show
The KFF poll counts all GLP-1 drugs and all indications, so the treated numbers are not obesity-brand counts. The growth rate, ceiling and access-event sizes are assumptions (sources and ranges in the assumptions table); the forecast would change with them. Price is not in this forecast; it enters Module E.
