"""Stage 1: load every interim Parquet file listed in section 3 of the brief into PostgreSQL schema `raw` (database `incretin`).

Method: DuckDB `postgres` extension (ATTACH ... TYPE postgres, CREATE TABLE ... AS SELECT) - types and NULLs are carried over
exactly; nothing is cast, filled or trimmed. One raw table per file (yearly files stay separate; staging unions them).
Metadata columns on every table: _source_file, _loaded_at, _sha256 (the file's sha256 recorded in data/manifest.csv).
Idempotent: raw._load_log remembers (table, sha256 of the file loaded); an unchanged file is skipped, a changed one is replaced.
Reconciliation (docs/load_reconciliation.csv): Parquet rows vs PostgreSQL rows vs manifest rows, plus exact key-measure sums
(integer-scaled so they are exact in both engines). Any mismatch stops the run with a non-zero exit.

Not loaded (by design): SDUD *_unmatched_name_candidates (already merged into the state files), nppes_filtered.parquet (superseded by the
primary-taxonomy file), sdud_suppression_diagnostics.parquet (a diagnostic output). Loaded although derived: the two Open Payments
attribution tables from scripts/fetch/16_open_payments_attribution.py, so the product split is exactly the Phase 3 definition."""
import csv
import hashlib
import logging
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd
import psycopg2

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "fetch"))
from common import get_logger, manifest_add  # noqa: E402

log = get_logger("load_raw")
INTERIM = ROOT / "data" / "interim"
PG = dict(host="localhost", port=5432, user="postgres", dbname="incretin")
DUCK_DSN = "dbname=incretin user=postgres host=localhost port=5432"


def sha256(p, chunk=1 << 22):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while b := f.read(chunk):
            h.update(b)
    return h.hexdigest()


def yr(name):
    return re.search(r"(?<!\d)(\d{4})(?!\d)", name).group(1)


YEAR_RX = re.compile(r"(?<!\d)(\d{4})(?!\d)")


def yr(name):
    return YEAR_RX.search(name).group(1)


def plan():
    """(raw table name, parquet path, dataset label) for every file to load."""
    out = []
    g = lambda pat: sorted(INTERIM.glob(pat))
    for f in g("sdud/sdud_*_states.parquet"):
        out.append((f"sdud_state_{yr(f.name)}", f, "sdud"))
    for f in g("sdud/sdud_*_national_xx.parquet"):
        out.append((f"sdud_national_{yr(f.name)}", f, "sdud"))
    for f in g("partd_prescribers/partd_prescribers_*.parquet"):
        out.append((f"partd_prescribers_{yr(f.name)}", f, "partd_prescribers"))
    for f in g("nadac/nadac_*.parquet"):
        out.append((f"nadac_{yr(f.name)}", f, "nadac"))
    for f in g("open_payments/open_payments_*.parquet"):
        out.append((f"open_payments_general_{yr(f.name)}", f, "open_payments"))
    out.append(("open_payments_record_products", INTERIM / "open_payments/op_record_products.parquet", "open_payments_derived"))
    out.append(("open_payments_product_attribution", INTERIM / "open_payments/op_product_attribution_long.parquet", "open_payments_derived"))
    names = {"medicaid_chip_enrollment_monthly": "enrollment_medicaid_chip_monthly", "managed_care_enrollment_monthly_by_type": "enrollment_managed_care_monthly_by_type",
             "managed_care_enrollment_summary_yearly": "enrollment_managed_care_summary_yearly", "managed_care_enrollment_yearly_by_type": "enrollment_managed_care_yearly_by_type"}
    for k, v in names.items():
        out.append((v, INTERIM / f"enrollment/{k}.parquet", "enrollment"))
    for prog in ("partd", "medicaid"):
        for kind in ("long", "wide"):
            ds = "spending_by_drug_" + prog
            out.append((f"spending_{prog}_{kind}", INTERIM / f"spending_by_drug/{prog}_spending_by_drug_{kind}.parquet", ds))
    out.append(("nppes_provider", INTERIM / "nppes/nppes_filtered_with_primary_taxonomy.parquet", "nppes"))
    out.append(("nucc_taxonomy", INTERIM / "nppes/nucc_taxonomy.parquet", "nucc"))
    for f in g("nhanes/*.parquet"):
        out.append((f"nhanes_{f.stem.lower()}", f, "nhanes"))
    for f in g("meps/meps_*.parquet"):
        m = re.match(r"meps_(\w+?)_(\d{4})_", f.name)
        out.append((f"meps_{m.group(1)}_{m.group(2)}", f, "meps"))
    out.append(("ctgov_studies", INTERIM / "clinicaltrials/clinicaltrials_inscope.parquet", "clinicaltrials"))
    for k in ("applications", "products", "submissions", "application_docs", "marketing_status"):
        out.append((f"fda_{k}", INTERIM / f"drugsatfda/drugsatfda_{k}.parquet", "drugsatfda"))
    return out


# key measures: (raw table prefix regex, name, group col, expression for parquet side and pg side). Integer-scaled sums are exact.
def measures(table):
    t = table
    if t.startswith(("sdud_state_", "sdud_national_")):
        yr = re.search(r"(\d{4})$", t).group(1)
        return [("sum_number_of_prescriptions_x1000", f"sum(round(number_of_prescriptions*1000)::bigint)", yr),
                ("sum_total_amount_reimbursed_cents", f"sum(round(total_amount_reimbursed*100)::bigint)", yr),
                ("sum_units_reimbursed_x1000", f"sum(round(units_reimbursed*1000)::bigint)", yr),
                ("n_suppressed_rows", "sum(suppression_used::int)", yr)]
    if t.startswith("partd_prescribers_"):
        yr = re.search(r"(\d{4})$", t).group(1)
        return [("sum_tot_clms", "sum(round(tot_clms)::bigint)", yr), ("sum_tot_drug_cst_cents", "sum(round(tot_drug_cst*100)::bigint)", yr)]
    if t.startswith("open_payments_general_"):
        yr = re.search(r"(\d{4})$", t).group(1)
        return [("sum_amount_usd_cents", "sum(round(try_cast(total_amount_of_payment_usdollars as decimal(18,2))*100)::bigint)", yr)]
    if t.startswith("open_payments_record_products"):
        return [("sum_amount_usd_cents", "sum(round(amount*100)::bigint)", "all")]
    if t.startswith("nadac_"):
        yr = re.search(r"(\d{4})$", t).group(1)
        return [("nadac_row_count", "count(*)", yr), ("sum_nadac_per_unit_x1e6", "sum(round(nadac_per_unit*1000000)::bigint)", yr)]
    return []


def main():
    man = pd.read_csv(ROOT / "data" / "manifest.csv", dtype=str)
    mrows = {}
    for r in man.itertuples():
        mrows.setdefault(r.file_name, r)
    con = duckdb.connect()
    con.execute("install postgres; load postgres;")
    con.execute(f"attach '{DUCK_DSN}' as pg (type postgres)")
    pgc = psycopg2.connect(**PG)
    pgc.autocommit = True
    cur = pgc.cursor()
    cur.execute("create schema if not exists raw")
    cur.execute("""create table if not exists raw._load_log (table_name text primary key, source_file text, sha256 text, parquet_rows bigint, loaded_at timestamptz)""")
    rec, failures = [], []
    for table, path, dataset in plan():
        fn = path.name
        if not path.exists():
            raise SystemExit(f"missing interim file: {path}")
        sha_file = sha256(path)
        m = mrows.get(fn)
        if m is None:   # derived files without a manifest row: record them (provenance = script 16)
            manifest_add(dataset=dataset, file_name=fn, source_url="derived by scripts/fetch/16_open_payments_attribution.py from data/interim/open_payments/open_payments_*.parquet",
                         release_or_version="Phase 3 attribution", years_covered="2019-2025", bytes=path.stat().st_size, sha256=sha_file, row_count="",
                         notes="derived table; loaded to raw so the product split equals the Phase 3 definition")
            man = pd.read_csv(ROOT / "data" / "manifest.csv", dtype=str)
            mrows = {}
            for r in man.itertuples():
                mrows.setdefault(r.file_name, r)
            m = mrows[fn]
        sha_manifest = m.sha256
        pq = path.as_posix()
        prows = con.execute(f"select count(*) from read_parquet('{pq}')").fetchone()[0]
        # PostgreSQL allows at most 1,600 columns per table: a wider file (MEPS 2024 FYC has 1,615) is split into column parts that
        # all carry the person key DUPERSID, so parts can be joined 1:1; every part is loaded and reconciled.
        allcols = [r[0] for r in con.execute(f"describe select * from read_parquet('{pq}')").fetchall()]
        if len(allcols) + 3 > 1590:
            key = "DUPERSID"
            rest = [c for c in allcols if c != key]
            size = 1400
            targets = [(f"{table}_p{k + 1}", ", ".join('"%s"' % c for c in [key] + rest[i:i + size])) for k, i in enumerate(range(0, len(rest), size))]
            log.info("%s has %d columns: split into %d parts", table, len(allcols), len(targets))
        else:
            targets = [(table, "*")]
        for tgt, sel in targets:
            cur.execute("select sha256 from raw._load_log where table_name=%s", (tgt,))
            prev = cur.fetchone()
            cur.execute("select to_regclass(%s)", (f"raw.{tgt}",))
            exists = cur.fetchone()[0] is not None
            if exists and prev and prev[0] == sha_file:
                log.info("skip %s (unchanged)", tgt)
            else:
                cur.execute(f'drop table if exists raw."{tgt}"')
                con.execute(f"""create table pg.raw."{tgt}" as select {sel}, '{fn}' as _source_file, now()::timestamptz as _loaded_at,
                                '{sha_manifest}' as _sha256 from read_parquet('{pq}')""")
                cur.execute("insert into raw._load_log values (%s,%s,%s,%s,now()) on conflict (table_name) do update set source_file=excluded.source_file, sha256=excluded.sha256, parquet_rows=excluded.parquet_rows, loaded_at=excluded.loaded_at",
                            (tgt, fn, sha_file, prows))
                log.info("loaded raw.%s (%d rows)", tgt, prows)
        # reconciliation (one 'rows' record per loaded table; parts of a split file are each checked against the file's row count)
        mrow = int(m.row_count) if str(m.row_count).isdigit() else None
        for tgt, _sel in targets[1:]:
            cur.execute(f'select count(*) from raw."{tgt}"')
            n_part = cur.fetchone()[0]
            rec.append(dict(dataset=dataset, table=f"raw.{tgt}", kind="rows", measure="row_count", group="all", parquet_value=prows, postgres_value=n_part,
                            manifest_rows=mrow if mrow is not None else "", match=(n_part == prows and (mrow is None or mrow == prows)),
                            file_sha256_matches_manifest=(sha_file == sha_manifest), parquet_nan_values="(see part 1)", source_file=fn))
            if n_part != prows:
                failures.append((tgt, prows, n_part, mrow))
        table = targets[0][0]
        cur.execute(f'select count(*) from raw."{table}"')
        pgrows = cur.fetchone()[0]
        nan = 0
        for col, typ, *_ in con.execute(f"describe select * from read_parquet('{pq}')").fetchall():
            if typ in ("DOUBLE", "FLOAT"):
                nan += con.execute(f'select coalesce(sum(isnan("{col}")::int),0) from read_parquet(\'{pq}\')').fetchone()[0]
        ok = (prows == pgrows) and (mrow is None or mrow == prows)
        rec.append(dict(dataset=dataset, table=f"raw.{table}", kind="rows", measure="row_count", group="all", parquet_value=prows, postgres_value=pgrows,
                        manifest_rows=mrow if mrow is not None else "", match=prows == pgrows and (mrow is None or mrow == prows),
                        file_sha256_matches_manifest=(sha_file == sha_manifest), parquet_nan_values=nan, source_file=fn))
        if not ok:
            failures.append((table, prows, pgrows, mrow))
        for name, expr, grp in measures(table):
            # DuckDB and PostgreSQL both support this SQL; try_cast is DuckDB only, so PG uses a regex-guarded cast
            expr_pg = expr.replace("try_cast(total_amount_of_payment_usdollars as decimal(18,2))", "nullif(total_amount_of_payment_usdollars,'')::numeric(18,2)")
            # PostgreSQL keeps the original mixed-case column names: quote the actual names in the PG expression
            pqcols = [r[0] for r in con.execute(f"describe select * from read_parquet('{pq}')").fetchall()]
            for c in sorted(pqcols, key=len, reverse=True):
                expr_pg = re.sub(rf"(?<![\w\"]){re.escape(c.lower())}(?![\w\"])", f'"{c}"', expr_pg, flags=re.I)
            pv = con.execute(f"select {expr} from read_parquet('{pq}')").fetchone()[0]
            cur.execute(f'select {expr_pg} from raw."{table}"')
            gv = cur.fetchone()[0]
            pv, gv = (int(pv) if pv is not None else None), (int(gv) if gv is not None else None)
            rec.append(dict(dataset=dataset, table=f"raw.{table}", kind="measure", measure=name, group=grp, parquet_value=pv, postgres_value=gv,
                            manifest_rows="", match=(pv == gv), file_sha256_matches_manifest="", parquet_nan_values="", source_file=fn))
            if pv != gv:
                failures.append((table, name, pv, gv))
    out = ROOT / "docs" / "load_reconciliation.csv"
    pd.DataFrame(rec).to_csv(out, index=False, encoding="utf-8")
    n = len(rec)
    tabs = len({r["table"] for r in rec})
    log.info("reconciliation written: %d checks over %d tables, %d failures", n, tabs, len(failures))
    print(f"tables {tabs} | checks {n} | failures {len(failures)} | rows-match {sum(1 for r in rec if r['kind']=='rows' and r['match'])}/{sum(1 for r in rec if r['kind']=='rows')}")
    if failures:
        print("MISMATCHES:", failures)
        sys.exit(1)


if __name__ == "__main__":
    main()
