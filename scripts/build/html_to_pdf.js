// Prints an HTML file to PDF with headless Chrome: running footer with page numbers, optional running header, page size and margins.
// Run: NODE_PATH=<folder with puppeteer-core> node scripts/build/html_to_pdf.js in.html out.pdf [--landscape] [--footer "text"] [--header "text"] [--css-page]
const puppeteer = require("puppeteer-core"); const path = require("path");
const a = process.argv.slice(2); const [html, pdf] = [path.resolve(a[0]), path.resolve(a[1])];
const opt = (k) => { const i = a.indexOf(k); return i >= 0 ? a[i + 1] : null; };
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
(async () => {
  const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe";
  const b = await puppeteer.launch({ executablePath: exe, headless: "new", args: ["--allow-file-access-from-files"] }); const p = await b.newPage();
  await p.goto("file:///" + html.replace(/\\/g, "/"), { waitUntil: "networkidle0", timeout: 120000 }); await p.evaluate(() => document.fonts.ready); await new Promise((r) => setTimeout(r, 1200));
  const foot = opt("--footer"), head = opt("--header"); const st = 'font-family: "IBM Plex Sans", Arial, sans-serif; font-size: 8px; color: #595959; width: 100%; padding: 0 14mm;';
  if (a.includes("--css-page")) { await p.pdf({ path: pdf, preferCSSPageSize: true, printBackground: true, displayHeaderFooter: false }); await b.close(); return; }   // page size, margins and running footer come from the page's own @page CSS
  await p.pdf({ path: pdf, format: "Letter", landscape: a.includes("--landscape"), printBackground: true, displayHeaderFooter: true, margin: { top: head ? "18mm" : "14mm", bottom: "16mm", left: "14mm", right: "14mm" },
    headerTemplate: head ? `<div style="${st} border-bottom: 1px solid #D55E00; padding-bottom: 3px;">${esc(head)}</div>` : "<span></span>",
    footerTemplate: `<div style="${st} display: flex; justify-content: space-between;"><span>${esc(foot || "")}</span><span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span></div>` });
  await b.close();
})();
