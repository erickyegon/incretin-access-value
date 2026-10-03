"""Diagnostic (c) v2 (diagnostics only, no modelling):
 - Soliqua and Xultophy (is_combination = TRUE) excluded;
 - analysis sample = 50 states + DC; territories stay in the data, flagged (is_territory, in_analysis_sample);
 - adds max_hidden_per_1000 = 10 x suppressed rows / total Medicaid+CHIP enrollment (state-quarter average of monthly
   PI total_medicaid_and_chip_enrollment, updated row preferred over preliminary) x 1000.
Appends diagnostic = 'c2_state_quarter_group' rows to data/interim/sdud_suppression_diagnostics.parquet (replacing any
earlier c2 rows) and prints distributions. Coverage periods come from medicaid_obesity_coverage.csv (sourced dates only)."""
import duckdb
import numpy as np
import pandas as pd

from common import INTERIM, REF, get_logger

log = get_logger("12_sdud_suppression_c2")
SD = (INTERIM / "sdud").as_posix()
DIAG = INTERIM / "sdud_suppression_diagnostics.parquet"
STATES_DC = set("AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY".split())
AB = {"Delaware": "DE", "Kansas": "KS", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO",
      "North Carolina": "NC", "Rhode Island": "RI", "Tennessee": "TN", "Utah": "UT", "Virginia": "VA", "Wisconsin": "WI",
      "California": "CA", "New Hampshire": "NH", "Pennsylvania": "PA", "South Carolina": "SC"}

con = duckdb.connect()
con.execute(f"create view st as select * from read_parquet('{SD}/sdud_*_states.parquet')")
con.execute(f"create view pm as select ndc11 ndc, label_group from read_csv('{(REF / 'product_map.csv').as_posix()}', all_varchar=true) where is_combination <> 'TRUE'")
c = con.sql("""select s.state, s.year, s.quarter, p.label_group, coalesce(sum(s.number_of_prescriptions), 0) observed_rx,
    sum(s.suppression_used::int) suppressed_rows, count(*) total_rows
  from st s join pm p on s.ndc = p.ndc group by 1,2,3,4""").df()
c["is_territory"] = ~c.state.isin(STATES_DC)
c["in_analysis_sample"] = ~c.is_territory
c["hidden_max_rx"] = 10 * c.suppressed_rows
den = c.observed_rx + c.hidden_max_rx
c["max_hidden_share"] = np.where(den > 0, c.hidden_max_rx / den.where(den > 0, 1), 0.0)

# enrollment: quarter average of monthly total Medicaid+CHIP (U preferred over P)
e = pd.read_parquet(INTERIM / "enrollment" / "medicaid_chip_enrollment_monthly.parquet")
e = e.sort_values(["state_abbreviation", "reporting_period", "preliminary_or_updated"]).drop_duplicates(["state_abbreviation", "reporting_period"], keep="last")
e["year"] = e.reporting_period.str[:4].astype(int)
e["quarter"] = (e.reporting_period.str[4:6].astype(int) - 1) // 3 + 1
# mean over the months that report a value (zeros were set to NULL upstream); months_avail records how many of 3 were used
q = e.groupby(["state_abbreviation", "year", "quarter"]).agg(enroll_q=("total_medicaid_and_chip_enrollment", "mean"), months_avail=("total_medicaid_and_chip_enrollment", "count")).reset_index()
c = c.merge(q.rename(columns={"state_abbreviation": "state"}), on=["state", "year", "quarter"], how="left")
c["max_hidden_per_1000"] = 10 * c.suppressed_rows / c.enroll_q * 1000

# coverage period class for the OBESITY label group, sourced dates only
cov = pd.read_csv(REF / "medicaid_obesity_coverage.csv", dtype=str).fillna("")
cov["ab"] = cov.state.map(AB)


def qi(y, m):
    return y * 4 + (m - 1) // 3 + 1


def period_class(r):
    if r.label_group != "obesity":
        return "n/a"
    rows = cov[cov.ab == r.state]
    starts = [x for x in rows.coverage_start if len(x) >= 7]
    ends = [x for x in rows.coverage_end if len(x) >= 7]
    if not starts:
        return "no_sourced_start"
    cur = qi(int(r.year), int(r.quarter) * 3)
    spans = []
    for _, w in rows.iterrows():
        if len(w.coverage_start) >= 7:
            s = qi(int(w.coverage_start[:4]), int(w.coverage_start[5:7]))
            en = qi(int(w.coverage_end[:4]), int(w.coverage_end[5:7])) if len(w.coverage_end) >= 7 else 10 ** 6
            spans.append((s, en))
    first_s = min(s for s, _ in spans)
    if cur < first_s:
        return "pre_start"
    for s, en in spans:
        if cur == s or (en < 10 ** 6 and cur == en):
            return "transition_quarter"
    for s, en in spans:
        if s < cur < en:
            return "covered"
    return "post_end" if ends else "covered"


c["coverage_period"] = c.apply(period_class, axis=1)
c["diagnostic"] = "c2_state_quarter_group"
a = c[c.in_analysis_sample]
print("(c2) cells:", len(c), "| analysis sample (50 states + DC):", len(a), "| territory cells kept/flagged:", int(c.is_territory.sum()),
      "(", sorted(set(c[c.is_territory].state)), ")")
print("overall max hidden share (analysis sample):", round(a.max_hidden_share.max(), 4), "| pooled:",
      round(a.hidden_max_rx.sum() / (a.observed_rx.sum() + a.hidden_max_rx.sum()), 4))
big = a[a.max_hidden_share > 0.05]
print("cells > 5%:", len(big), "of", len(a), "| by group:", big.groupby("label_group").size().to_dict(), "| observed>0:", int((big.observed_rx > 0).sum()))
print("enrollment missing for analysis cells:", int(a.enroll_q.isna().sum()))


def dist(x, title):
    x = x.dropna()
    print(f"\n{title}: n={len(x)} mean={x.mean():.3f} " + " ".join(f"p{p}={np.percentile(x, p):.3f}" for p in (50, 75, 90, 95, 99)) + f" max={x.max():.3f}")


dist(a.max_hidden_per_1000, "max_hidden_per_1000, all analysis cells")
for g, x in a.groupby("label_group"):
    dist(x.max_hidden_per_1000, f"  label_group={g}")
cols = ["state", "year", "quarter", "label_group", "observed_rx", "suppressed_rows", "enroll_q", "max_hidden_per_1000", "max_hidden_share", "coverage_period"]
print("\n10 largest max_hidden_per_1000, all analysis cells:\n", a.nlargest(10, "max_hidden_per_1000")[cols].round(3).to_string(index=False))
ob = a[a.label_group == "obesity"]
for cls in ("pre_start", "transition_quarter", "covered", "post_end", "no_sourced_start"):
    x = ob[ob.coverage_period == cls]
    dist(x.max_hidden_per_1000, f"obesity group, {cls}")
for cls in ("pre_start", "covered"):
    x = ob[ob.coverage_period == cls]
    print(f"\n10 largest, obesity group, {cls}:\n", x.nlargest(10, "max_hidden_per_1000")[cols].round(3).to_string(index=False))
print("\nstates in pre_start/covered classes (sourced dates):", sorted(set(ob[ob.coverage_period.isin(['pre_start', 'covered'])].state)))

old = pd.read_parquet(DIAG)
old = old[old.diagnostic != "c2_state_quarter_group"]
res = pd.concat([old, c], ignore_index=True)
res.to_parquet(DIAG, index=False)
log.info("wrote %s (c2 rows %d)", DIAG, len(c))
