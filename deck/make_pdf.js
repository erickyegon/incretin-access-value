// Prints the Quarto revealjs deck to PDF with headless Chrome (puppeteer-core). Usage: node make_pdf.js <deck.html> <deck.pdf>
// Requires puppeteer-core (npm install puppeteer-core) and Chrome; set CHROME_PATH if Chrome is not in the default Windows location.
const puppeteer = require("puppeteer-core");
const path = require("path");
(async () => {
  const [html, pdf] = [path.resolve(process.argv[2]), path.resolve(process.argv[3])];
  const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe";
  const browser = await puppeteer.launch({ executablePath: exe, headless: "new" });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  await page.goto("file:///" + html.replace(/\\/g, "/") + "?print-pdf", { waitUntil: "networkidle0", timeout: 120000 });
  await page.waitForSelector(".reveal.ready, .reveal .slides section", { timeout: 60000 });
  await new Promise((r) => setTimeout(r, 4000));
  await page.pdf({ path: pdf, width: "1280px", height: "720px", printBackground: true, preferCSSPageSize: true });
  await browser.close();
})();
