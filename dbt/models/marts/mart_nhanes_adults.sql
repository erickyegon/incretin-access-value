-- NHANES participants aged 20 and over, both cycles stacked (2021_2023 and 2017_2020 pre-pandemic). Grain: cycle x seqn.
-- Every adult is kept, including those with missing BMI (bmi_missing). Survey design variables sdmvstra and sdmvpsu are kept with every
-- weight the files provide. The weights are cycle-specific and are NOT rescaled for combining cycles here:
--   interview weight  wtint2yr (2021-2023) / wtintprp (2017-2020 pre-pandemic)
--   MEC exam weight   wtmec2yr (2021-2023) / wtmecprp (2017-2020 pre-pandemic)  <- use with BMI, blood pressure, glycohemoglobin
--   fasting-subsample weight wtph2yr is in the glycohemoglobin file and listed as wtph2yr
-- weight_interview and weight_mec take whichever of the pair the cycle has. Prescription medication files are not joined: the 2021-2023
-- file has drug codes but no drug names.
select
    d.cycle, d.seqn,
    d.ridstatr, d.riagendr, d.ridageyr, d.ridreth1, d.ridreth3, d.dmdborn4, d.dmdeduc2, d.dmdmartz, d.ridexprg, d.indfmpir,
    d.sdmvstra, d.sdmvpsu,
    d.wtint2yr, d.wtmec2yr, d.wtintprp, d.wtmecprp,
    coalesce(d.wtint2yr, d.wtintprp) as weight_interview,
    coalesce(d.wtmec2yr, d.wtmecprp) as weight_mec,
    g.wtph2yr,
    b.bmdstats, b.bmxwt, b.bmxht, b.bmxbmi, b.bmxwaist, b.bmxhip,
    (b.bmxbmi is null) as bmi_missing,
    o.bpxosy1, o.bpxodi1, o.bpxosy2, o.bpxodi2, o.bpxosy3, o.bpxodi3,
    g.lbxgh,
    q.bpq020, q.bpq040a, q.bpq050a,
    di.diq010, di.diq050, di.diq070,
    m.mcq010, m.mcq160a, m.mcq160b, m.mcq160c, m.mcq160d, m.mcq160e, m.mcq160f, m.mcq220
from {{ ref('stg_nhanes__demo') }} d
left join {{ ref('stg_nhanes__bmx') }} b on b.cycle = d.cycle and b.seqn = d.seqn
left join {{ ref('stg_nhanes__bpxo') }} o on o.cycle = d.cycle and o.seqn = d.seqn
left join {{ ref('stg_nhanes__bpq') }} q on q.cycle = d.cycle and q.seqn = d.seqn
left join {{ ref('stg_nhanes__ghb') }} g on g.cycle = d.cycle and g.seqn = d.seqn
left join {{ ref('stg_nhanes__diq') }} di on di.cycle = d.cycle and di.seqn = d.seqn
left join {{ ref('stg_nhanes__mcq') }} m on m.cycle = d.cycle and m.seqn = d.seqn
where d.ridageyr >= 20
