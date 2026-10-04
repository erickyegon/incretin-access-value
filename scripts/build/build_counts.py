"""Counts of dbt models, seeds, tests and sources, read from the dbt manifest (dbt/target/manifest.json) after a build; written to analysis/outputs/build_counts.csv.
These counts are quoted in the report and README; they are never summed by hand."""
import csv, json, collections, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
m = json.load(open(root / "dbt" / "target" / "manifest.json"))
nodes = m["nodes"].values()
c = collections.Counter(n["resource_type"] for n in nodes)
mat = collections.Counter(n["config"].get("materialized") for n in nodes if n["resource_type"] == "model")
layer = collections.Counter(n["path"].split("/")[0].split("\\")[0] for n in nodes if n["resource_type"] == "model")
rows = [("models", c["model"], "dbt models", "dbt models in the warehouse (staging, intermediate and marts)"),
        ("seeds", c["seed"], "dbt seeds", "Reference tables committed as dbt seeds"),
        ("tests", c["test"], "dbt tests", "dbt tests (generic and singular)"),
        ("sources", len(m["sources"]), "dbt source tables", "Raw source tables declared in dbt")]
for k in sorted(layer):
    rows.append(("models_" + k, layer[k], "dbt models", "dbt models in the %s layer" % k))
out = root / "analysis" / "outputs" / "build_counts.csv"
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(["item", "count", "unit", "statement"]); w.writerows(rows)
print(out.read_text())
