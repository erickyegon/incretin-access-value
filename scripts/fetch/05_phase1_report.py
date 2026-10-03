"""Phase 1 validation summary for SDUD (reads data/interim/sdud/_validation_*.json and parquet)."""
import glob
import json

import duckdb

from common import INTERIM, REF

V = [json.load(open(f, encoding="utf-8")) for f in sorted(glob.glob(str(INTERIM / "sdud" / "_validation_*.json")))]
print("year | raw rows | kept | suppressed kept | supp share kept | raw supp share | XX rows kept | quarters present")
for v in V:
    print(v["year"], "|", v["raw_rows"], "|", v["filtered_rows"], "|", v["filtered_suppressed_rows"], "|",
          f'{v["filtered_suppressed_rows"] / max(v["filtered_rows"], 1):.1%}', "|",
          f'{v["raw_suppressed_rows"] / v["raw_rows"]:.1%}', "|", v["filtered_xx_rows"], "|",
          sorted(v["raw_rows_by_quarter"]))
print("suppressed rows with non-null prescriptions (should be 0):", sum(v["filtered_suppressed_but_nonnull_rx"] for v in V))
print("\nunmatched in-scope-looking NDCs (not in product_map):")
seen = {}
for v in V:
    for ndc, name, n in v["unmatched_candidates"]:
        seen.setdefault((ndc, name.strip()), 0)
        seen[(ndc, name.strip())] += n
for k, n in sorted(seen.items(), key=lambda x: -x[1]):
    print(k, n)
con = duckdb.connect()
g = f"read_parquet('{(INTERIM / 'sdud').as_posix()}/sdud_*_states.parquet')"
print("\nrows by year-quarter (kept, states only):")
print(con.sql(f"select year, quarter, count(*) n from {g} group by 1,2 order by 1,2").df().pivot(index="year", columns="quarter", values="n").to_string())
print("\nkept NDCs seen in SDUD:", con.sql(f"select count(distinct ndc) from {g}").fetchone()[0],
      "| NDCs not in map:", con.sql(f"select count(*) from (select distinct ndc from {g}) where ndc not in (select ndc11 from read_csv('{(REF / 'product_map.csv').as_posix()}', all_varchar=true))").fetchone()[0])
print("\nstates present 2025Q4 / 2026Q1 for CA NH PA SC:")
print(con.sql(f"select state, year, quarter, count(*) n_rows, sum((not suppression_used)::int) unsuppressed_rows, sum(number_of_prescriptions) rx from {g} where state in ('CA','NH','PA','SC') and ((year=2025 and quarter>=3) or year=2026) group by all order by 1,2,3").df().to_string())
