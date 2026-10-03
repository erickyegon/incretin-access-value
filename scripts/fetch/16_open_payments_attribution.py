"""Open Payments product attribution (decided 2026-10-03).
Headline totals count each payment RECORD once. Product-level figures are produced two ways from a long table:
  amount_equal_split  = record amount / n_inscope_products (sums to the headline total)
  amount_overlapping  = full record amount counted for every in-scope product named ("payments mentioning the product";
                        sums EXCEED the headline total and must be labelled overlapping)
n_inscope_products = number of DISTINCT in-scope products among the five product-name fields of a record. A product is the brand
(or, for a generic-only string, the ingredient) found in the name field. Physician flag supports physician-only cross-2021 trends
(NPs/PAs become covered recipients in program year 2021)."""
import re

import duckdb
import pandas as pd

from common import INTERIM, REF, get_logger

log = get_logger("16_open_payments_attribution")
OUT = INTERIM / "open_payments"
NAME_COLS = [f"Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_{i}" for i in range(1, 6)]
# product key patterns (brand first, then generic); order matters only for tie-breaking, a field maps to ONE product
PRODUCTS = [("ozempic", r"ozempic"), ("wegovy", r"wegovy"), ("rybelsus", r"rybelsus"), ("mounjaro", r"mounjaro"), ("zepbound", r"zepbound"),
            ("trulicity", r"trulicity"), ("saxenda", r"saxenda"), ("victoza", r"victoza"), ("byetta", r"byetta"),
            ("bydureon", r"bydureon"), ("soliqua", r"soliqua"), ("xultophy", r"xultophy"), ("adlyxin", r"adlyxin"),
            ("tanzeum", r"tanzeum"), ("foundayo", r"foundayo|orforglipron"),
            ("semaglutide", r"semaglutide"), ("tirzepatide", r"tirzepatide"), ("liraglutide", r"liraglutide"),
            ("dulaglutide", r"dulaglutide"), ("exenatide", r"exenatide"), ("lixisenatide", r"lixisenatide"), ("albiglutide", r"albiglutide")]
COMB = [(k, re.compile(p, re.I)) for k, p in PRODUCTS]


def key(s):
    if s is None:
        return None
    for k, rx in COMB:
        if rx.search(s):
            return k
    return None


def main():
    con = duckdb.connect()
    cols = ", ".join(f'"{c}"' for c in NAME_COLS)
    df = con.sql(f"""select Record_ID, Program_Year, Covered_Recipient_Type, Covered_Recipient_NPI, Covered_Recipient_Specialty_1,
        try_cast(Total_Amount_of_Payment_USDollars as double) amount, {cols}
        from read_parquet('{OUT.as_posix()}/open_payments_*.parquet')""").df()
    cache = {}
    def k2(s):
        if s not in cache:
            cache[s] = key(s)
        return cache[s]
    keys = pd.DataFrame({c: df[c].map(k2) for c in NAME_COLS})
    df["products"] = keys.apply(lambda r: sorted({x for x in r if isinstance(x, str)}), axis=1)
    df["n_inscope_products"] = df.products.map(len)
    df["is_physician"] = df.Covered_Recipient_Type.fillna("").str.startswith("Covered Recipient Physician")
    rec = df[["Record_ID", "Program_Year", "Covered_Recipient_Type", "is_physician", "Covered_Recipient_NPI", "amount", "n_inscope_products", "products"]].copy()
    rec["products"] = rec.products.map(lambda x: ";".join(x))
    rec.to_parquet(OUT / "op_record_products.parquet", index=False)
    long = df[df.n_inscope_products > 0].explode("products")[["Record_ID", "Program_Year", "is_physician", "Covered_Recipient_NPI", "products", "amount", "n_inscope_products"]]
    long = long.rename(columns={"products": "product"})
    long["amount_equal_split"] = long.amount / long.n_inscope_products
    long["amount_overlapping"] = long.amount
    long.to_parquet(OUT / "op_product_attribution_long.parquet", index=False)

    print("records:", len(rec), "| records with no recognised in-scope product (matched on text but no key):", int((rec.n_inscope_products == 0).sum()))
    print("\nshare of records naming >1 in-scope product, by program year:")
    s = rec.groupby("Program_Year").agg(n=("Record_ID", "size"), multi=("n_inscope_products", lambda x: (x > 1).sum()),
                                         max_products=("n_inscope_products", "max"))
    s["share_multi"] = (s.multi / s.n).round(4)
    print(s.to_string())
    print("overall share >1:", round((rec.n_inscope_products > 1).mean(), 4))
    print("\nheadline (each record once): n and USD by year; physician-only alongside")
    h = rec.groupby("Program_Year").agg(n=("Record_ID", "size"), usd=("amount", "sum"))
    hp = rec[rec.is_physician].groupby("Program_Year").agg(n_phys=("Record_ID", "size"), usd_phys=("amount", "sum"))
    print(h.join(hp).round(0).to_string())
    print("\nproduct x year: equal-split USD (sums to headline) vs overlapping USD (exceeds)")
    p1 = long.pivot_table(index="product", columns="Program_Year", values="amount_equal_split", aggfunc="sum").fillna(0).round(0)
    p2 = long.pivot_table(index="product", columns="Program_Year", values="amount_overlapping", aggfunc="sum").fillna(0).round(0)
    print("equal split:\n", p1.astype(int).to_string())
    print("overlapping (label as such):\n", p2.astype(int).to_string())
    print("\ncheck: equal-split total == headline total:", round(long.amount_equal_split.sum()), round(rec.amount.sum()),
          "| overlapping total:", round(long.amount_overlapping.sum()))
    log.info("wrote op_record_products.parquet and op_product_attribution_long.parquet")


if __name__ == "__main__":
    main()
