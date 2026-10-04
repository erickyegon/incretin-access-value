# Module D in plain language: who prescribes incretin drugs in Medicare Part D

**Important caveat.** Part D reflects diabetes and other covered uses, not obesity-brand adoption: these claims are mostly diabetes products (Ozempic, Mounjaro) and Wegovy, whose Part D use in 2024 coincides with its cardiovascular label. The data do not record the reason for a prescription.
(Plan: [plan_moduleD.md](../plan_moduleD.md), committed before any result; departures in [deviations.md](deviations.md), items 10 and 11.)

**Question.** Which prescribers write these drugs, how concentrated is the prescribing, and does it relate to industry payments?

## Volume and specialty ([claims by ingredient](tables/moduleD_claims_prescribers_by_ingredient_year.csv), [figure](figures/30_partd_claims_prescribers.png))
- Part D incretin claims grew from 2.6 million in 2018 to 19.6 million in 2024; prescribers grew from 56,300 to 199,800 (same table; rows with 11 or more claims only).
- In 2024, primary care physicians wrote 55.8% of claims, nurse practitioners and physician assistants 27.7%, endocrinology 12.7%, cardiology 1.0% and other specialties 2.8% ([specialty mix](tables/moduleD_specialty_mix_by_year.csv), [figure](figures/31_partd_specialty_mix.png)).
- Specialty comes from the CMS prescriber type, grouped with a committed mapping; the NPPES taxonomy agrees for 95.4% of 199,184 prescribers ([agreement](tables/moduleD_specialty_crosscheck_agreement.csv)).

## Concentration ([table](tables/moduleD_concentration_by_year.csv), [figure](figures/32_partd_concentration.png))
- The top 10% of prescribers wrote 43.2% of claims in 2018 and 41.4% in 2024; the top 1% wrote 11.5% and 10.4%. The Gini coefficient moved from 0.529 to 0.551. Prescribing is concentrated but has not become more concentrated as it spread.

## Adoption of tirzepatide (Mounjaro) ([table](tables/moduleD_tirzepatide_adoption_by_specialty.csv), [figure](figures/33_partd_tirzepatide_adoption.png))
- The share of prescribers with Mounjaro claims rose from 1.6% in 2022 to 25.8% in 2023 and 48.6% in 2024. In 2024 it was 88.9% of endocrinologists, 49.4% of primary care physicians, 46.7% of nurse practitioners and physician assistants, and 37.6% of cardiologists.

## Wegovy and Ozempic by specialty, 2024 ([table](tables/moduleD_wegovy_vs_ozempic_specialty_2024.csv), [figure](figures/34_partd_wegovy_vs_ozempic_specialty.png))
- Wegovy had 76,176 Part D claims from 3,956 prescribers in 2024. Cardiology wrote 14.5% of Wegovy claims against 1.2% of Ozempic claims, consistent with the cardiovascular indication added in March 2024. It does not show obesity use.

## Segments (exploratory; [profiles](tables/moduleD_segment_profiles_k5.csv), [figure](figures/35_partd_segments_k5.png))
The pre-specified rule (highest silhouette, [k selection](tables/moduleD_segmentation_k_selection.csv)) gave a two-segment split of new versus continuing prescribers ([profiles](tables/moduleD_segment_profiles.csv)), so the five-segment solution below is supplementary and exploratory (silhouette 0.507, deviation 11); stability (mean bootstrap Jaccard, 1 = identical each time) is shown with each segment.
- High-volume primary care with some tirzepatide: 60,392 prescribers, 66.6% of claims, stability 0.72.
- Mid-volume nurse practitioners and physician assistants with some tirzepatide: 40,328; 13.7%; stability 0.56.
- Mid-volume primary care with little or no tirzepatide: 45,773; 11.7%; stability 0.69.
- Lower-volume primary care new in 2024: 43,345; 6.7%; stability 0.87.
- Lower-volume nurse practitioners and physician assistants new in 2024, mostly tirzepatide: 9,984; 1.3%; stability 0.55.
Two segments have stability near 0.55, so treat their boundaries as soft.
- The share of claims for beneficiaries 65 and over is populated for only 58.5% of rows (below the 80% rule), so it was not used.
- Segments are named by profile; no individual is named and no prescriber-level output is saved.

## Industry payments ([descriptives](tables/moduleD_payments_descriptives.csv), [binned](tables/moduleD_payments_binned.csv), [model](tables/moduleD_payments_model.csv), [figure](figures/36_payments_binned.png))
- In 2023, 36.6% of the 199,822 prescribers with 2024 claims had in-scope payments (73,076 payees; 47.8% of endocrinologists, 41.3% of nurse practitioners and physician assistants, 34.7% of primary care physicians, 39.6% of cardiologists).
- Prescribers with no payment averaged 74.6 claims in 2024 against 271 in the top payment decile; their 2022 baseline claims also differed (26.8 against 139), so raw gaps reflect who gets paid.
- Model form (exact): negative binomial regression of 2024 claims on log(1 + prior-year payments in dollars, not thousands), adjusted for specialty group, state and log(1 + claims two years earlier); robust (HC0) intervals ([model](tables/moduleD_payments_model.csv)). Because the predictor is logged, the coefficient is not a per-$1,000 effect; a "per $1,000" statement would be wrong, so clear contrasts are reported instead ([contrasts](tables/moduleD_payments_contrasts.csv)).
- Incidence rate ratios for 2023 payments and 2024 claims: any payment versus none, at the median payee amount ($87): 1.30 (95% CI 1.29 to 1.31); each doubling of the amount among payees: 1.05 (1.04 to 1.05); $1,000 versus none, a contrast and not a slope: 1.50 (1.48 to 1.52). The 2022 payments and 2023 claims check gives 1.28 (1.27 to 1.29) for any payment, 1.04 per doubling.
- Dose-response by payee decile ([binned table](tables/moduleD_payments_binned.csv)): unadjusted mean claims rise from 74.6 with no payment to 99.3 in the lowest payee decile and 270.8 in the highest, but baseline (2022) claims rise in parallel (26.8, 36.8, 138.7), which is why the adjusted ratios above are much smaller than the raw gap.
- This is an association among prescribers, not an effect of payments: payments go to prescribers who already write more, and the model cannot separate the two. It is reported in aggregate only.

## What this does not show
Obesity-brand adoption, commercial or Medicaid prescribing, or prescribing for individuals; Part D rows with fewer than 11 claims are not in the data, so small prescribers are undercounted.
