"""Link check for the website, README and one-page summary. Relative links are checked against site/ (or the repo for the README); external links are fetched.
Usage: python audit/check_links.py [site_base_url]   e.g. https://erickyegon.github.io/incretin-access-value/  (also checks each site link on the live site)"""
import pathlib, re, subprocess, sys, urllib.request, urllib.error
root = pathlib.Path(__file__).resolve().parents[1]
base = sys.argv[1].rstrip("/") + "/" if len(sys.argv) > 1 else None
def fetch(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}); r = urllib.request.urlopen(req, timeout=30); return r.status
    except urllib.error.HTTPError as e: return e.code
    except Exception as e: return str(e)[:60]
rows = []
site = (root / "site" / "index.html").read_text(encoding="utf-8")
for href in sorted(set(re.findall(r'(?:href|src)="([^"]+)"', site))):
    if href.startswith("#") or href.startswith("mailto:"): continue
    if href.startswith("http"):
        if "fonts.g" in href: continue
        rows.append(("site", href, fetch(href)))
    else:
        ok = (root / "site" / href).exists(); rows.append(("site (file)", href, "ok" if ok else "MISSING"))
        if base: rows.append(("site (live)", base + href, fetch(base + href)))
readme = (root / "README.md").read_text(encoding="utf-8")
for u in sorted(set(re.findall(r'<(https?://[^>]+)>', readme) + re.findall(r'\]\((https?://[^)\s]+)\)', readme))): rows.append(("README", u, fetch(u)))
for path in sorted(set(re.findall(r'\]\((?!http|mailto)([^)#]+)\)', readme))): rows.append(("README (file)", path, "ok" if (root / path).exists() else "MISSING"))
for p in re.findall(r'`((?:report|deck|site|research_pack|app|audit|analysis|docs|scripts|dbt)/[^`\s]+)`', readme):
    q = p.rstrip("/").split(" ")[0]
    if "*" in q or "{" in q: continue
    rows.append(("README (path)", q, "ok" if (root / q).exists() else "MISSING"))
op = subprocess.run(["pdftotext", str(root / "deck" / "one_page_summary.pdf"), "-"], capture_output=True, text=True).stdout
for u in sorted(set(re.findall(r'github\.com/[\w./-]+', op))): rows.append(("one-pager", "https://" + u.rstrip("."), fetch("https://" + u.rstrip("."))))
for u in ("https://erickyegon.github.io/oncology-rwe-nsclc/", "https://github.com/erickyegon/incretin-access-value"): rows.append(("check", u, fetch(u)))
bad = [r for r in rows if r[2] not in (200, "ok")]
for r in rows: print(f"{'OK ' if r not in bad else 'BAD'} {r[0]:14} {r[2]!s:8} {r[1]}")
print(f"\n{len(rows)} links checked, {len(bad)} not resolving")
sys.exit(1 if bad else 0)
