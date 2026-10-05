// Browser test of the budget-model app in a clean R session. Start the app with
//   Rscript --vanilla -e 'shiny::runApp("app", port = 8765, launch.browser = FALSE)'
// then run:  NODE_PATH=<folder with puppeteer-core> node scripts/test/test_app.js   (APP_URL overrides the address, for example the live app)
// Checks the central-case numbers, every control of the Budget model tab (read back on the Overview; expected values come from app/tests/expected_values.R),
// each tab for errors, the probabilistic analysis, the budget curve, saved scenarios and presets.
const puppeteer = require("puppeteer-core"); const fs = require("fs");
const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe"; const url = process.env.APP_URL || "http://127.0.0.1:8765/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const browser = await puppeteer.launch({ executablePath: exe, headless: "new" });
  const page = await browser.newPage(); await page.setViewport({ width: 1440, height: 1000 });
  const errors = []; page.on("pageerror", (e) => errors.push(String(e))); page.on("response", (r) => { if (r.status() >= 400 && !r.url().includes("favicon")) errors.push(r.status() + " " + r.url()); });
  await page.goto(url, { waitUntil: "networkidle0", timeout: 90000 }); await sleep(4000);
  const txt = (id) => page.evaluate((id) => { const e = document.getElementById(id); return e ? e.textContent.trim() : null; }, id);
  const tab = async (v, ms = 3000) => { await page.evaluate((v) => { const a = document.querySelector(`a[data-value="${v}"]`); if (a) a.click(); }, v); await sleep(ms); };
  const slider = async (id, v) => { await page.evaluate((id, v) => { const s = $("#" + id).data("ionRangeSlider"); s.update({ from: v }); $("#" + id).trigger("change"); }, id, v); await sleep(900); };
  const setv = async (id, v) => { await page.evaluate((id, v) => { Shiny.setInputValue(id, v, { priority: "event" }); }, id, v); await sleep(900); };
  const radio = async (id, v) => { await page.evaluate((id, v) => { const e = document.querySelector(`input[name="${id}"][value="${v}"]`); e.click(); }, id, v); await sleep(900); };
  const num = async (id, v) => { await page.evaluate((id, v) => { const e = document.getElementById(id); e.value = v; $(e).trigger("change"); $(e).trigger("input"); }, id, String(v)); await sleep(1200); };
  const results = []; const rec = (label, got, expected, ok) => results.push({ label, got, expected, ok: ok === undefined ? got === expected : ok });
  const net = async () => { await tab("overview", 1500); return txt("overview-v_net5"); };
  const reset = async () => { await tab("budget", 1200); await page.click("#budget-reset"); await sleep(2500); };
  // defaults
  rec("net five-year cost", await txt("overview-v_net5"), "$161.3M"); rec("PMPM", await txt("overview-v_pmpm"), "$2.69"); rec("members treated", await txt("overview-v_users"), "15,873"); rec("net cost per user per year", await txt("overview-v_peruser"), "$2,511");
  rec("headline", await txt("overview-headline"), "Covering Wegovy and Zepbound for a 1-million-enrollee Medicaid program is estimated to cost $161.3M net over five years ($2.69 per member per month), with a 90% range of $58.1M to $319.9M.");
  // every control of the Budget model tab (expected values: app/tests/expected_values.R)
  const ctl = [["custom multiplier 0.75", () => slider("budget-uptake", 0.75), "$121.0M"], ["custom multiplier 1.25", () => slider("budget-uptake", 1.25), "$201.6M"], ["prior authorization 0.5", () => slider("budget-pa", 0.5), "$80.7M"], ["prior authorization 1.25", () => slider("budget-pa", 1.25), "$201.6M"],
    ["effect lower CI", () => radio("budget-effect", "lo"), "$63.7M"], ["effect upper CI", () => radio("budget-effect", "hi"), "$258.9M"], ["years 3-5 growth", () => radio("budget-y35", "growth"), "$234.3M"], ["years 3-5 decline", () => radio("budget-y35", "decline"), "$131.4M"],
    ["announced $245 price", () => radio("budget-price", "announced"), "$68.3M"], ["rebate 23.1%", () => slider("budget-rebate", 23.1), "$254.3M"], ["rebate 79.35%", () => slider("budget-rebate", 79.35), "$68.3M"],
    ["gross cost 1,164.45", () => num("budget-gross", 1164.45), "$158.4M"], ["gross cost 1,251.96", () => num("budget-gross", 1251.96), "$170.3M"], ["plan size 2 million", () => num("budget-plan", 2000000), "$322.6M"]];
  for (const [label, act, exp] of ctl) { await reset(); await tab("budget", 800); await act(); rec(label, await net(), exp); }
  // a state's enrollment scales the cost linearly
  await reset(); const ca = fs.readFileSync("app/data/state_enrollment.csv", "utf8").split("\n").find((l) => l.startsWith("CA,")).trim().split(","); const caN = parseFloat(ca[ca.length - 1]);
  await tab("budget", 800); await radio("budget-plan_mode", "state"); await page.evaluate(() => Shiny.setInputValue("budget-state", "CA")); await sleep(1500); const caNet = parseFloat((await net()).replace(/[$M,]/g, ""));
  rec(`California enrollment (${caN}) scales the cost`, caNet, (caN / 1e6 * 161.3172).toFixed(1), Math.abs(caNet - caN / 1e6 * 161.3172) < 0.11);
  await reset(); rec("after reset (central case)", await net(), "$161.3M");
  await tab("budget", 800); await num("budget-plan", -5); await sleep(1200); const msg = await page.evaluate(() => Array.from(document.querySelectorAll(".shiny-output-error-validation")).map((e) => e.textContent.trim()).join(" | "));
  rec("negative plan size gives a friendly message", msg.includes("plan size"), true); await reset();
  // evidence
  await tab("evidence", 4000); rec("evidence opens on the covering-state average", (await txt("evidence-title_state")).startsWith("Average of the 10 covering states"), true);
  await page.evaluate(() => Shiny.setInputValue("evidence-state", "SC")); await sleep(1500); const scd = await page.evaluate(() => document.getElementById("evidence-state_detail").innerText); rec("South Carolina detail shows the start-date and criteria sources separately", scd.includes("Start date source") && scd.includes("Milliman") && scd.includes("Criteria source") && scd.includes("news report"), true);
  await page.evaluate(() => Shiny.setInputValue("evidence-state", "CA")); await sleep(1500); rec("state chart title follows the selector", (await txt("evidence-title_state")).includes("California"), true);
  rec("evidence specification title", await txt("evidence-title_spec"), "The estimate holds in all 15 estimable alternative analyses (fee-for-service only is not estimable)");
  rec("evidence charts drawn", await page.evaluate(() => ["evidence-es_chart", "evidence-map", "evidence-spec_chart"].every((i) => document.querySelectorAll(`#${i} .main-svg`).length > 0)), true);
  // uncertainty
  await tab("uncertainty", 3000); await page.click("#uncertainty-run"); await sleep(3000); rec("PSA title", await txt("uncertainty-title_psa"), "Five-year net cost: median $145.4M, 90% interval $58.1M to $319.9M (10,000 draws)");
  rec("budget probability", (await txt("uncertainty-title_cdf")).length > 20, true);
  await page.click("#uncertainty-common"); await sleep(400); await page.click("#uncertainty-run"); await sleep(3000); rec("PSA interval changes with correlated effects", (await txt("uncertainty-title_psa")) !== "Five-year net cost: median $145.4M, 90% interval $58.1M to $319.9M (10,000 draws)", true);
  await page.click("#uncertainty-common"); await sleep(300);
  // compare
  await tab("compare", 2000); const t0 = await page.evaluate(() => document.querySelector("#compare-table").innerText); rec("compare opens with the prior authorization preset", ["$80.7M", "$161.3M", "$201.6M"].every((x) => t0.includes(x)), true);
  await page.click("#compare-preset_pa"); await sleep(2000); const t1 = await page.evaluate(() => document.querySelector("#compare-table").innerText); rec("prior authorization preset", ["$80.7M", "$161.3M", "$201.6M"].every((x) => t1.includes(x)), true);
  await page.click("#compare-preset_price"); await sleep(2000); const t2 = await page.evaluate(() => document.querySelector("#compare-table").innerText); rec("price preset", ["$254.3M", "$161.3M", "$68.3M"].every((x) => t2.includes(x)), true);
  await page.click("#compare-clear"); await sleep(500); await page.type("#compare-name", "my scenario"); await page.click("#compare-save"); await sleep(1500); const t3 = await page.evaluate(() => document.querySelector("#compare-table").innerText); rec("save a scenario", t3.includes("my scenario") && t3.includes("$161.3M"), true);
  // sources and every tab clean
  await tab("sources", 1500); const src = await page.evaluate(() => ({ badges: document.querySelectorAll(".badge").length, links: document.querySelectorAll("a[href^='http']").length }));
  rec("sources: badges and links", src.badges >= 8 && src.links >= 8, true, src.badges >= 8 && src.links >= 8); results[results.length - 1].got = src;
  for (const v of ["overview", "evidence", "budget", "uncertainty", "compare", "sources"]) { await tab(v, 1200); const bad = await page.evaluate(() => Array.from(document.querySelectorAll(".shiny-output-error:not(.shiny-output-error-validation)")).map((e) => e.textContent.slice(0, 120))); rec(`no server errors on ${v}`, bad.length === 0, true); }
  let fail = 0; for (const r of results) { console.log((r.ok ? "PASS " : "FAIL ") + r.label + (r.ok ? "" : `  got ${JSON.stringify(r.got)} expected ${JSON.stringify(r.expected)}`)); if (!r.ok) fail++; }
  console.log(`${results.length - fail} of ${results.length} checks pass; browser errors: ${errors.length ? errors.join(" | ") : "none"}`);
  await browser.close(); process.exit(fail || errors.length ? 1 : 0);
})();
