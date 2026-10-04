// Screenshots of every tab of the budget-model app (desktop and phone width) plus a console and server-error scan.
// Start the app first: Rscript --vanilla -e 'shiny::runApp("app", port = 8765, launch.browser = FALSE)'
// Run: NODE_PATH=<folder with puppeteer-core> node scripts/test/screenshot_app.js [outdir] [url]
const puppeteer = require("puppeteer-core"); const fs = require("fs"); const path = require("path");
const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe";
const out = process.argv[2] || "docs/figures/app"; const url = process.argv[3] || "http://127.0.0.1:8765/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const tabs = [["overview", "Overview"], ["evidence", "Evidence"], ["budget", "Budget model"], ["uncertainty", "Uncertainty"], ["compare", "Compare"], ["sources", "Sources"]];
(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await puppeteer.launch({ executablePath: exe, headless: "new" });
  const errors = [];
  for (const [w, h, suffix] of [[1440, 1000, ""], [390, 844, "_phone"]]) {
    const page = await browser.newPage(); await page.setViewport({ width: w, height: h, deviceScaleFactor: suffix ? 2 : 1 });
    page.on("pageerror", (e) => errors.push(`[${w}] ${e}`)); page.on("response", (r) => { if (r.status() >= 400 && !r.url().includes("favicon")) errors.push(`[${w}] ${r.status()} ${r.url()}`); });
    await page.goto(url, { waitUntil: "networkidle0", timeout: 90000 }); await sleep(4000);
    for (const [id, label] of tabs) {
      await page.evaluate((id) => { const a = document.querySelector(`a[data-value="${id}"]`); if (a) a.click(); }, id); await sleep(3500);
      const bad = await page.evaluate(() => Array.from(document.querySelectorAll(".shiny-output-error:not(.shiny-output-error-validation)")).map((e) => e.textContent.slice(0, 160)));
      if (bad.length) errors.push(`[${w}] ${label}: ${bad.join(" | ")}`);
      await page.screenshot({ path: path.join(out, `${id}${suffix}.png`), fullPage: true });
    }
    await page.close();
  }
  console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "no errors on any tab (desktop and phone)");
  await browser.close(); process.exit(errors.length ? 1 : 0);
})();
