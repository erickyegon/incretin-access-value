"""Phase 2 validation summary: Part D prescribers, spending by drug, NADAC. Prints facts only; no interpretation."""
import duckdb

from common import INTERIM

con = duckdb.connect()
P = (INTERIM / "partd_prescribers").as_posix()
print("== Part D prescribers by provider and drug (server-side Gnrc_Name filter)")
print(con.sql(f"""select data_year, count(*) n_rows, count(distinct Prscrbr_NPI) unique_npis,
    sum(Tot_Clms) claims, round(sum(Tot_Drug_Cst)) drug_cost,
    round(avg((Tot_Benes is null)::int),3) share_benes_suppressed,
    round(avg((GE65_Tot_Clms is null)::int),3) share_ge65_claims_null
  from read_parquet('{P}/partd_prescribers_*.parquet') group by 1 order by 1""").df().to_string(index=False))
print("\nclaims by year and brand (top brands, null Brnd_Name kept)")
print(con.sql(f"""select data_year, Brnd_Name, sum(Tot_Clms) claims, count(*) n_rows
  from read_parquet('{P}/partd_prescribers_*.parquet') where data_year>=2018 group by 1,2 order by 1, claims desc""").df()
      .pivot_table(index="Brnd_Name", columns="data_year", values="claims", aggfunc="sum").fillna(0).astype(int).to_string())
print("\nsuppression flags (CMS): GE65_Sprsn_Flag / GE65_Bene_Sprsn_Flag values")
print(con.sql(f"select GE65_Sprsn_Flag, GE65_Bene_Sprsn_Flag, count(*) n from read_parquet('{P}/partd_prescribers_*.parquet') group by 1,2 order by n desc").df().to_string(index=False))
print("\nfirst data year with each ingredient (Gnrc_Name)")
print(con.sql(f"select Gnrc_Name, min(data_year) first_year, max(data_year) last_year, sum(Tot_Clms) claims from read_parquet('{P}/partd_prescribers_*.parquet') group by 1 order by 2, 1").df().to_string(index=False))

S = (INTERIM / "spending_by_drug").as_posix()
for k in ("partd", "medicaid"):
    print(f"\n== {k} spending by drug (long), Mftr_Name = 'Overall' rows only (manufacturer rows would double count)")
    print(con.sql(f"select year, count(*) n_drugs, round(sum(Tot_Spndng)) spending, sum(Tot_Clms) claims from read_parquet('{S}/{k}_spending_by_drug_long.parquet') where Mftr_Name = 'Overall' group by 1 order by 1").df().to_string(index=False))

N = (INTERIM / "nadac").as_posix()
print("\n== NADAC (product-map NDCs)")
print(con.sql(f"""select year(effective_date) yr, count(*) n_rows, count(distinct ndc) ndcs, min(effective_date) first_eff, max(effective_date) last_eff,
   max(as_of_date) last_as_of from read_parquet('{N}/nadac_*.parquet') group by 1 order by 1""").df().to_string(index=False))
print(con.sql(f"""select year(effective_date) yr, count(distinct as_of_date) weekly_files_with_rows from read_parquet('{N}/nadac_*.parquet') group by 1 order by 1""").df().to_string(index=False))
