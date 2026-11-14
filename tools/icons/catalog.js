// Pinta el catalogo de iconos con la fuente ya generada, para revisar a ojo
// que cada glifo salio bien. Uso: node tools/icons/catalog.js
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const root = path.join(__dirname, '..', '..');
  const codes = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'codepoints.json'), 'utf8'),
  );
  const font = fs
    .readFileSync(path.join(root, 'assets/fonts/VetIcons.ttf'))
    .toString('base64');
  let html = `<style>
    @font-face{font-family:V;src:url(data:font/ttf;base64,${font})}
    body{margin:0;padding:20px;width:1160px;background:#F1F4F8;
      font:10px sans-serif;color:#64748B;display:flex;flex-wrap:wrap;gap:10px}
    .c{width:86px;text-align:center;background:#F7F9FC;border-radius:16px;
      padding:2px 0 8px;box-shadow:4px 4px 10px #DDE4EE,-4px -4px 10px #fff}
    .i{font:44px/44px V;height:44px;margin:8px auto 6px;color:#0B1C30}
  </style>`;
  for (const name of Object.keys(codes).sort()) {
    html += `<div class="c"><div class="i">&#x${codes[name].toString(16)};</div>${name}</div>`;
  }
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1200, height: 800 },
    deviceScaleFactor: 1.5,
  });
  await page.setContent(html);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({
    path: path.join(root, 'docs/design/iconos-vetdosis.png'),
    fullPage: true,
  });
  await browser.close();
})();
