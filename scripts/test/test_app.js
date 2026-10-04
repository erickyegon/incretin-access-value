// Browser test of the budget-model app in a clean R session: start the app with
//   Rscript --vanilla -e 'shiny::runApp("app", port = 8765, launch.browser = FALSE)'
// then run:  NODE_PATH=<folder with puppeteer-core> node scripts/test/test_app.js
// Checks that the defaults reproduce the central case and that every control moves the five-year net cost as the budget model says (expected values are the
// one-way sensitivity values in analysis/outputs/tables/moduleE_tornado.csv and the central case in key_numbers.csv).
const puppeteer = require("puppeteer-core");
const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const browser = await puppeteer.launch({ executablePath: exe, headless: "new" });
  const page = await browser.newPage(); await page.setViewport({ width: 1400, height: 1000 });
  const errors = []; page.on("pageerror", (e) => errors.push(String(e))); page.on("response", (r) => { if (r.status() >= 400 && !r.url().includes("favicon")) errors.push(r.status() + " " + r.url()); });
  await page.goto("http://127.0.0.1:" + (process.env.APP_PORT || 8765) + "/", { waitUntil: "networkidle0", timeout: 60000 }); await page.waitForFunction(() => document.querySelector("#net5") && document.querySelector("#net5").textContent.trim().length > 0, { timeout: 60000 });
  const read = async () => page.evaluate(() => Object.fromEntries(["pmpm", "net5", "gross5", "peruser", "percont"].map((id) => [id, document.getElementById(id).textContent.trim()])));
  const setSlider = async (id, v) => { await page.evaluate((id, v) => { const s = $("#" + id).data("ionRangeSlider"); s.update({ from: v }); $("#" + id).trigger("change"); }, id, v); await sleep(1500); };
  const setNum = async (id, v) => { await page.evaluate((id, v) => { Shiny.setInputValue(id, v); }, id, v); await sleep(1500); };
  const clickRadio = async (name, val) => { await page.click(`input[name="${name}"][value="${val}"]`); await sleep(1500); };
  const reset = async () => { await page.click("#reset"); await sleep(2000); };
  const results = []; const check = async (label, expectNet, extra) => { const r = await read(); const ok = r.net5 === "$" + expectNet + "M" && (!extra || Object.entries(extra).every(([k, v]) => r[k] === v)); results.push({ label, got: r.net5, expected: "$" + expectNet + "M", ok, ...(extra ? { extra: JSON.stringify({ got: Object.fromEntries(Object.keys(extra).map((k) => [k, r[k]])), expected: extra }) } : {}) }); };
  await check("defaults (central case)", "161.3", { pmpm: "$2.69", gross5: "$330.7M", peruser: "$2,511", percont: "$6,943" });
  await setSlider("uptake", 0.75); await check("uptake 0.75", "121.0"); await setSlider("uptake", 1.25); await check("uptake 1.25", "201.6"); await reset();
  await setSlider("pa", 0.5); await check("PA multiplier 0.5 (tight)", "80.7"); await setSlider("pa", 1.25); await check("PA multiplier 1.25 (loose)", "201.6"); await reset();
  await clickRadio("effect", "lo"); await check("effect lower CI", "63.7"); await clickRadio("effect", "hi"); await check("effect upper CI", "258.9"); await reset();
  await clickRadio("y35", "growth"); await check("years 3-5 growth", "234.3"); await clickRadio("y35", "decline"); await check("years 3-5 decline", "131.4"); await reset();
  await clickRadio("price", "announced"); await check("announced $245", "68.3", { pmpm: "$1.14" }); await reset();
  await setSlider("rebate", 23.1); await check("rebate 23.1%", "254.3"); await setSlider("rebate", 79.35); await check("rebate 79.35%", "68.3"); await reset();
  await setNum("gross", 1164.45); await check("gross cost 1,164.45", "158.4"); await setNum("gross", 1251.96); await check("gross cost 1,251.96", "170.3"); await reset();
  await setNum("plan", 2000000); await check("plan size 2,000,000", "322.6"); await reset();
  await check("after reset (central case again)", "161.3", { pmpm: "$2.69" });
  await page.click('a[data-value="Notes"]'); await sleep(500);
  const notes = await page.evaluate(() => document.querySelector('div[data-value="Notes"]').innerText);
  const notesOk = ["Gross of rebates", "Rebate range", "Scenarios, not forecasts", "Data sources", "erickyegon.github.io/incretin-access-value", "AI-use statement"].every((t) => notes.includes(t));
  results.push({ label: "notes panel has all required notes", ok: notesOk });
  for (const r of results) console.log((r.ok ? "PASS " : "FAIL ") + r.label + (r.got ? "  got " + r.got + " expected " + r.expected : "") + (r.extra && !r.ok ? "  " + r.extra : ""));
  console.log("browser errors:", errors.length ? errors.join(" | ") : "none");
  await browser.close(); process.exit(results.every((r) => r.ok) && !errors.length ? 0 : 1);
})();
