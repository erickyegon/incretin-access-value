"""Step 5.8: NPPES full monthly file (download.cms.gov; link found by rendering the NPI Files page) and NUCC taxonomy code set.
NPPES is stream-filtered straight from the zip WITHOUT unzipping (zipfile member stream -> pyarrow CSV reader in blocks),
keeping only NPIs that appear in Part D prescribers (5.4) or Open Payments (5.7). The zip is kept (about 1.2 GB) so the
filter can be re-run; its sha256 is in the manifest. NUCC: latest version listed on nucc.org (found on the CSV page).
Usage: python 14_nppes_nucc.py [nppes_url]"""
import csv
import io
import re
import sys
import zipfile

import duckdb
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.csv as pacsv
import pyarrow.parquet as pq

from common import INTERIM, RAW, download, get_logger, manifest_add, request, sha256_file

log = get_logger("14_nppes_nucc")
NPPES_URL = "https://download.cms.gov/nppes/NPPES_Data_Dissemination_September_2026_V2.zip"   # found on NPI_Files.html (2026-10-03)
NUCC_PAGE = "https://www.nucc.org/index.php/code-sets-mainmenu-41/provider-taxonomy-mainmenu-40/csv-mainmenu-57"
OUT = INTERIM / "nppes"
KEEP_BASE = ["NPI", "Entity Type Code", "Provider Credential Text", "Provider Enumeration Date", "Last Update Date", "NPI Deactivation Date",
             "NPI Reactivation Date", "Provider Business Practice Location Address State Name",
             "Provider Business Practice Location Address Postal Code", "Provider Gender Code"]


def npi_set():
    con = duckdb.connect()
    a = con.sql(f"select distinct cast(Prscrbr_NPI as varchar) n from read_parquet('{(INTERIM / 'partd_prescribers').as_posix()}/partd_prescribers_*.parquet')").df().n
    b = con.sql(f"select distinct cast(Covered_Recipient_NPI as varchar) n from read_parquet('{(INTERIM / 'open_payments').as_posix()}/open_payments_*.parquet') where Covered_Recipient_NPI is not null").df().n
    s = set(a) | set(b)
    s.discard("None")
    log.info("NPIs: partd %d, open payments %d, union %d", len(a), len(b), len(s))
    return s, len(set(a)), len(set(b))


def nppes(url):
    OUT.mkdir(parents=True, exist_ok=True)
    z = download(url, RAW / "nppes" / url.rsplit("/", 1)[1], "nppes_raw", log, release=url.rsplit("/", 1)[1], years="2026-09",
                 notes="NPPES full monthly dissemination file; zip kept, never unzipped")
    want, n_pd, n_op = npi_set()
    wanted = pa.array(sorted(want), type=pa.string())
    with zipfile.ZipFile(z) as zf:
        member = next(i for i in zf.infolist() if re.fullmatch(r"npidata_pfile_\d{8}-\d{8}\.csv", i.filename))
        log.info("member %s (%.2f GB uncompressed)", member.filename, member.file_size / 1e9)
        with zf.open(member) as fh:
            header = fh.readline().decode("utf-8").strip()
        cols = next(csv.reader([header]))
        tax = [c for c in cols if c.startswith(("Healthcare Provider Taxonomy Code_", "Healthcare Provider Primary Taxonomy Switch_"))]
        keep = [c for c in KEEP_BASE if c in cols] + tax + [c for c in ("Provider Last Name (Legal Name)", "Provider First Name",
                "Provider Organization Name (Legal Business Name)") if c in cols]
        types = {c: pa.string() for c in cols}
        total = kept = 0
        writer = None
        with zf.open(member) as fh:
            rd = pacsv.open_csv(fh, read_options=pacsv.ReadOptions(block_size=64 << 20),
                                convert_options=pacsv.ConvertOptions(column_types=types, include_columns=keep, strings_can_be_null=True))
            for batch in rd:
                total += batch.num_rows
                mask = pc.is_in(batch.column("NPI"), value_set=wanted)
                sub = batch.filter(mask)
                if sub.num_rows:
                    kept += sub.num_rows
                    if writer is None:
                        writer = pq.ParquetWriter(OUT / "nppes_filtered.parquet", sub.schema)
                    writer.write_batch(sub)
                if (total // batch.num_rows) % 20 == 0:
                    log.info("streamed %d rows, kept %d", total, kept)
        if writer:
            writer.close()
    found = duckdb.sql(f"select count(distinct NPI) from read_parquet('{(OUT / 'nppes_filtered.parquet').as_posix()}')").fetchone()[0]
    # primary taxonomy: code whose switch = 'Y' (first), else code_1
    con = duckdb.connect()
    sw = " ".join(f"when \"Healthcare Provider Primary Taxonomy Switch_{i}\" = 'Y' then \"Healthcare Provider Taxonomy Code_{i}\"" for i in range(1, 16) if f"Healthcare Provider Taxonomy Code_{i}" in tax)
    con.execute(f"""copy (select *, case {sw} else "Healthcare Provider Taxonomy Code_1" end as primary_taxonomy_code,
        substr("Provider Business Practice Location Address Postal Code", 1, 5) as practice_zip5
        from read_parquet('{(OUT / 'nppes_filtered.parquet').as_posix()}')) to '{(OUT / 'nppes_filtered_with_primary_taxonomy.parquet').as_posix()}' (format parquet)""")
    f = OUT / "nppes_filtered_with_primary_taxonomy.parquet"
    manifest_add(dataset="nppes", file_name=f.name, source_url=url, release_or_version=url.rsplit("/", 1)[1], years_covered="snapshot 2026-09",
                 bytes=f.stat().st_size, sha256=sha256_file(f), row_count=kept,
                 notes=f"stream-filtered from zip (no unzip); NPPES rows read {total}; NPIs requested {len(want)} (Part D {n_pd}, Open Payments {n_op}); found {found}")
    log.info("NPPES done: rows read %d, kept %d, distinct NPIs found %d of %d requested", total, kept, found, len(want))
    print(dict(rows_read=total, kept=kept, requested=len(want), found=found, part_d_npis=n_pd, open_payments_npis=n_op))


def nucc():
    page = request("GET", NUCC_PAGE, log=log, timeout=200).text
    links = re.findall(r'href="([^"]*nucc_taxonomy_(\d+)\.csv)"', page)
    path, ver = max(links, key=lambda x: int(x[1]))
    url = "https://www.nucc.org" + path
    p = download(url, RAW / "nucc" / f"nucc_taxonomy_{ver}.csv", "nucc", log, release=f"NUCC Health Care Provider Taxonomy version {ver[:-1]}.{ver[-1]}", years="current")
    import pandas as pd
    df = pd.read_csv(p, dtype=str)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / "nucc_taxonomy.parquet"
    df.to_parquet(out, index=False)
    manifest_add(dataset="nucc", file_name=out.name, source_url=url, release_or_version=f"version {ver}", years_covered="current",
                 bytes=out.stat().st_size, sha256=sha256_file(out), row_count=len(df), notes="NUCC taxonomy code set (Code, Grouping, Classification, Specialization, Definition, Notes, Display Name)")
    log.info("NUCC %s: %d codes", ver, len(df))
    print("NUCC", ver, len(df), list(df.columns))


if __name__ == "__main__":
    nucc()
    if "--nucc-only" not in sys.argv:
        nppes(sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].startswith("http") else NPPES_URL)
