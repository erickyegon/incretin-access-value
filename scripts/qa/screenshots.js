// QA screenshots of the published outputs: site (390 and 1366 px wide), report (top and three sections), one notebook, the app tabs.
// Run: NODE_PATH=<folder with puppeteer-core> node scripts/qa/screenshots.js [outdir=docs/qa] [siteUrl] [appUrl]
// Also writes horizontal-scroll and button-height checks for the site, and counts blank interactive widgets in the report.
const puppeteer = require("puppeteer-core"); const fs = require("fs"); const path = require("path");
const out = process.argv[2] || "docs/qa"; const SITE = (process.argv[3] || "https://erickyegon.github.io/incretin-access-value/").replace(/\/?$/, "/");
const APP = process.argv[4] || "https://01a108a8-ecde-397c-5353-39196812b10c.share.connect.posit.cloud/";
const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe"; const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  fs.mkdirSync(out, { recursive: true }); const b = await puppeteer.launch({ executablePath: exe, headless: "new" }); const report = [];
  const open = async (w, h, url, wait = 2500) => { const p = await b.newPage(); await p.setViewport({ width: w, height: h, deviceScaleFactor: w < 600 ? 2 : 1 }); await p.goto(url, { waitUntil: "networkidle0", timeout: 120000 }); await sleep(wait); return p; };
  for (const [w, h, tag] of [[390, 844, "390"], [1366, 900, "1366"]]) {
    const p = await open(w, h, SITE.startsWith("file:") ? SITE + "index.html" : SITE); const m = await p.evaluate(() => ({ scroll: document.documentElement.scrollWidth, inner: innerWidth, small: [...document.querySelectorAll(".btn")].filter((e) => e.getBoundingClientRect().height < 43.5).length, imgs: [...document.querySelectorAll("img")].filter((i) => i.getBoundingClientRect().width > innerWidth + 1).length }));
    report.push(`site ${tag}px: scroll ${m.scroll}/${m.inner}, buttons under 44 px: ${m.small}, images wider than the viewport: ${m.imgs}`); await p.screenshot({ path: path.join(out, `site_${tag}.png`), fullPage: true }); await p.close();
  }
  const rp = await open(1366, 900, SITE + "report.html", 5000);
  await rp.screenshot({ path: path.join(out, "report_top.png") });
  for (const [key, tag] of [["C. Coverage study", "coverage"], ["E. Budget impact", "budget"], ["A. Data and coding layer", "data"]]) {
    await rp.evaluate((k) => { const h = [...document.querySelectorAll("h1")].find((e) => e.textContent.trim().startsWith(k)); if (h) h.scrollIntoView(); }, key); await sleep(1500); await rp.screenshot({ path: path.join(out, `report_${tag}.png`) });
  }
  const blank = await rp.evaluate(() => [...document.querySelectorAll(".widget, .plotly")].map((w) => w.getBoundingClientRect().height < 200 || !w.querySelector("svg, canvas")).filter(Boolean).length);
  report.push(`report: interactive widgets that did not render: ${blank}; page size ${(await rp.evaluate(() => document.documentElement.scrollHeight))} px tall`); await rp.close();
  const nb = await open(1366, 900, SITE + "notebooks/C_coverage_study.html", 3000); await nb.screenshot({ path: path.join(out, "notebook_C.png"), fullPage: false });
  report.push(`notebook C: horizontal scroll ${await nb.evaluate(() => document.documentElement.scrollWidth + "/" + innerWidth)}`); await nb.close();
  for (const [w, h, tag] of [[1440, 1000, "desktop"], [390, 844, "phone"]]) {
    const ap = await open(w, h, APP, 7000);
    for (const t of ["overview", "evidence", "budget", "uncertainty", "compare", "sources"]) {
      await ap.evaluate((t) => { const a = document.querySelector(`a[data-value="${t}"]`); if (a) a.click(); }, t); await sleep(3500);
      if (tag === "desktop" || t === "overview") await ap.screenshot({ path: path.join(out, `app_${t}_${tag}.png`), fullPage: true });
    }
    await ap.close();
  }
  fs.writeFileSync(path.join(out, "qa_report.txt"), report.join("\n") + "\n"); console.log(report.join("\n")); await b.close();
})();
