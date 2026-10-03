"""SDUD suppression diagnostics (no modelling). Reads the filtered SDUD Parquet and product_map.
Output: data/interim/sdud_suppression_diagnostics.parquet, stacked with a `diagnostic` column:
  a_zero_rx_unsuppressed / b_xx_suppression : single-row counts
  c_state_quarter_group : state x quarter x label_group (FFSU + MCOU combined)
  d_xx_residual : NDC x quarter x utilization_type, national XX minus observed state rows vs suppressed-row count
A row = state x NDC x quarter x utilization type. Suppressed rows have NULL prescriptions (counts under 11)."""
import duckdb
import pandas as pd

from common import INTERIM, REF, get_logger

log = get_logger("11_sdud_suppression_diagnostics")
SD = (INTERIM / "sdud").as_posix()
con = duckdb.connect()
con.execute(f"create view st as select * from read_parquet('{SD}/sdud_*_states.parquet')")
con.execute(f"create view xx as select * from read_parquet('{SD}/sdud_*_national_xx.parquet')")
con.execute(f"create view pm as select ndc11 ndc, label_group, is_combination from read_csv('{(REF / 'product_map.csv').as_posix()}', all_varchar=true)")

out = []

# (a) unsuppressed rows with 0 prescriptions
a = con.sql("""select count(*) unsuppressed_rows,
    sum((number_of_prescriptions = 0)::int) rx_equal_0, min(number_of_prescriptions) min_rx_unsuppressed,
    sum((number_of_prescriptions between 1 and 10)::int) rx_1_to_10_unsuppressed,
    sum((number_of_prescriptions is null)::int) rx_null_unsuppressed,
    sum((suppression_used and number_of_prescriptions is not null)::int) suppressed_with_value
  from st where not suppression_used""").df()
print("(a) unsuppressed state rows:\n", a.to_string(index=False))
print("   suppressed rows with a non-NULL value:", con.sql("select count(*) from st where suppression_used and number_of_prescriptions is not null").fetchone()[0])
print("   suppressed rows total:", con.sql("select count(*) from st where suppression_used").fetchone()[0],
      "| unsuppressed rx min/max distribution of small counts:",
      con.sql("select number_of_prescriptions, count(*) from st where not suppression_used and number_of_prescriptions <= 12 group by 1 order by 1").fetchall())
out.append(a.assign(diagnostic="a_zero_rx_unsuppressed"))

# (b) XX rows suppressed?
b = con.sql("""select count(*) xx_rows, sum(suppression_used::int) xx_suppressed_rows,
    sum((number_of_prescriptions is null)::int) xx_null_rx from xx""").df()
print("\n(b) national XX rows:\n", b.to_string(index=False))
out.append(b.assign(diagnostic="b_xx_suppression"))

# (c) state x quarter x label_group
c = con.sql("""select s.state, s.year, s.quarter, p.label_group,
    coalesce(sum(s.number_of_prescriptions), 0) observed_rx,
    sum(s.suppression_used::int) suppressed_rows, count(*) total_rows,
    sum(coalesce(p.is_combination = 'TRUE', false)::int) combination_rows
  from st s join pm p on s.ndc = p.ndc group by 1,2,3,4""").df()
c["hidden_max_rx"] = 10 * c.suppressed_rows
c["max_hidden_share"] = c.hidden_max_rx / (c.observed_rx + c.hidden_max_rx)
c.loc[(c.observed_rx + c.hidden_max_rx) == 0, "max_hidden_share"] = 0.0
print("\n(c) cells:", len(c), "| overall max hidden share:", round(c.max_hidden_share.max(), 4))
print("    pooled max hidden share (all cells): ",
      round(c.hidden_max_rx.sum() / (c.observed_rx.sum() + c.hidden_max_rx.sum()), 4))
big = c[c.max_hidden_share > 0.05].sort_values(["max_hidden_share"], ascending=False)
print("    cells with max hidden share > 5%:", len(big), "of", len(c))
print(big.groupby(["label_group"]).size().to_string())
print("    top 15:\n", big.head(15)[["state", "year", "quarter", "label_group", "observed_rx", "suppressed_rows", "max_hidden_share"]].to_string(index=False))
out.append(c.assign(diagnostic="c_state_quarter_group"))

# (d) XX residual vs suppressed state rows, by NDC x quarter x utilization type
d = con.sql("""with s as (select ndc, year, quarter, utilization_type,
        coalesce(sum(number_of_prescriptions), 0) obs_state_rx, sum(suppression_used::int) suppressed_state_rows, count(*) state_rows
      from st group by 1,2,3,4)
    select x.ndc, x.year, x.quarter, x.utilization_type, x.number_of_prescriptions xx_rx, x.suppression_used xx_suppressed,
      coalesce(s.obs_state_rx, 0) obs_state_rx, coalesce(s.suppressed_state_rows, 0) suppressed_state_rows,
      coalesce(s.state_rows, 0) state_rows
    from xx x left join s using (ndc, year, quarter, utilization_type)""").df()
d["residual"] = d.xx_rx - d.obs_state_rx
ok = ~d.xx_suppressed & d.xx_rx.notna()
d["within_1x_10x"] = None
sub = d[ok]
w = ((sub.residual >= sub.suppressed_state_rows) & (sub.residual <= 10 * sub.suppressed_state_rows))
d.loc[sub.index, "within_1x_10x"] = w
d["residual_class"] = None
r = sub.residual; s_ = sub.suppressed_state_rows
d.loc[sub.index, "residual_class"] = pd.Series(
    ["no_suppressed_rows_residual_0" if (si == 0 and ri == 0) else "no_suppressed_rows_residual_nonzero" if si == 0
     else "below_1x" if ri < si else "above_10x" if ri > 10 * si else "within_1x_10x" for ri, si in zip(r, s_)], index=sub.index)
print("\n(d) XX NDC x quarter x util-type rows:", len(d), "| usable (unsuppressed XX):", int(ok.sum()))
print(d.residual_class.value_counts(dropna=False).to_string())
bad = d[ok & ~d.residual_class.isin(["within_1x_10x", "no_suppressed_rows_residual_0"])]
print("    failing rows:", len(bad), "| residual<0 rows:", int((sub.residual < 0).sum()))
if len(bad):
    print(bad.head(12)[["ndc", "year", "quarter", "utilization_type", "xx_rx", "obs_state_rx", "residual", "suppressed_state_rows", "state_rows", "residual_class"]].to_string(index=False))
    print("    failures by year:", bad.groupby("year").size().to_dict())
out.append(d.assign(diagnostic="d_xx_residual"))

res = pd.concat(out, ignore_index=True)
for col in res.columns:
    if res[col].dtype == object and col not in ("diagnostic", "state", "label_group", "ndc", "utilization_type", "residual_class"):
        res[col] = res[col].astype("float64", errors="ignore")
f = INTERIM / "sdud_suppression_diagnostics.parquet"
res.to_parquet(f, index=False)
log.info("wrote %s rows=%d", f, len(res))
print("\nsaved", f)
