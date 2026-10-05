// Renders the social preview card (1200 x 630) from an HTML file with headless Chrome.
// Run: NODE_PATH=<folder with puppeteer-core> node scripts/build/make_social_card.js in.html out.png
const puppeteer = require("puppeteer-core");
const exe = process.env.CHROME_PATH || "C:/Program Files/Google/Chrome/Application/chrome.exe";
(async () => {
  const b = await puppeteer.launch({ executablePath: exe, headless: "new", args: ["--allow-file-access-from-files"] });
  const p = await b.newPage(); await p.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
  await p.goto("file:///" + require("path").resolve(process.argv[2]).replace(/\\/g, "/")); await p.evaluate(() => document.fonts.ready); await new Promise((r) => setTimeout(r, 400));
  await p.screenshot({ path: process.argv[3], clip: { x: 0, y: 0, width: 1200, height: 630 } }); await b.close();
})();
