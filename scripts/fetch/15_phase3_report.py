"""Phase 3 validation summary: Open Payments, NPPES, NUCC. Facts only."""
import duckdb

from common import INTERIM

con = duckdb.connect()
O = (INTERIM / "open_payments").as_posix()
g = f"read_parquet('{O}/open_payments_*.parquet')"
print("== Open Payments (rows where any product-name field matches an in-scope product)")
print(con.sql(f"""select Program_Year yr, count(*) n_rows, round(sum(try_cast(Total_Amount_of_Payment_USDollars as double))) usd,
   round(avg((Covered_Recipient_NPI is not null)::int),3) share_with_npi,
   count(distinct Covered_Recipient_NPI) distinct_npis,
   round(avg((Covered_Recipient_Type like 'Covered Recipient Physician%')::int),3) share_physician
  from {g} group by 1 order by 1""").df().to_string(index=False))
print("\nrows and dollars by program year x matched product (top)")
d = con.sql(f"""select Program_Year yr, upper(regexp_replace(matched_product_name, '[^A-Za-z]+.*$', '')) product, count(*) n_rows,
   round(sum(try_cast(Total_Amount_of_Payment_USDollars as double))) usd from {g} group by 1,2""").df()
print(d.pivot_table(index="product", columns="yr", values="n_rows", aggfunc="sum").fillna(0).astype(int).to_string())
print("\nUSD:")
print(d.pivot_table(index="product", columns="yr", values="usd", aggfunc="sum").fillna(0).astype(int).to_string())
print("\nChange_Type / dispute status:")
print(con.sql(f"select Change_Type, Dispute_Status_for_Publication, count(*) n from {g} group by 1,2 order by n desc").df().to_string(index=False))
print("\ndistinct matched strings (all years):", con.sql(f"select count(distinct matched_product_name) from {g}").fetchone()[0])
N = (INTERIM / "nppes").as_posix()
try:
    print("\n== NPPES filtered")
    print(con.sql(f"""select count(*) n_rows, count(distinct NPI) npis, sum((NPI_Deactivation_Date is not null)::int) deact from
      (select NPI, "NPI Deactivation Date" NPI_Deactivation_Date from read_parquet('{N}/nppes_filtered_with_primary_taxonomy.parquet'))""").df().to_string(index=False))
    print(con.sql(f"""select "Entity Type Code" entity, count(*) n from read_parquet('{N}/nppes_filtered_with_primary_taxonomy.parquet') group by 1""").df().to_string(index=False))
    print("primary taxonomy codes present in NUCC set:", con.sql(f"""select round(avg((n.Code is not null)::int),3) from read_parquet('{N}/nppes_filtered_with_primary_taxonomy.parquet') p
       left join read_parquet('{N}/nucc_taxonomy.parquet') n on p.primary_taxonomy_code = n.Code""").fetchone()[0])
    print("\nPart D / Open Payments NPIs found in NPPES:")
    P = (INTERIM / "partd_prescribers").as_posix()
    print(con.sql(f"""select 'partd' src, count(distinct cast(Prscrbr_NPI as varchar)) npis,
        count(distinct case when cast(Prscrbr_NPI as varchar) in (select NPI from read_parquet('{N}/nppes_filtered_with_primary_taxonomy.parquet')) then cast(Prscrbr_NPI as varchar) end) found
        from read_parquet('{P}/partd_prescribers_*.parquet')
      union all select 'open_payments', count(distinct Covered_Recipient_NPI),
        count(distinct case when Covered_Recipient_NPI in (select NPI from read_parquet('{N}/nppes_filtered_with_primary_taxonomy.parquet')) then Covered_Recipient_NPI end)
        from {g} where Covered_Recipient_NPI is not null""").df().to_string(index=False))
except Exception as e:
    print("NPPES section not ready:", str(e)[:120])
