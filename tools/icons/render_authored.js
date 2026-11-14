// Rasteriza cada SVG de authored/ a un PNG cuadrado (tinta negra, fondo
// blanco) para que trace.py lo calque igual que a las laminas.
// Uso: node render_authored.js <dir_salida> [lado_px]
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const out = process.argv[2];
  const side = Number(process.argv[3] || 960);
  const dir = path.join(__dirname, 'authored');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: side, height: side } });
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.svg')).sort()) {
    const svg = fs
      .readFileSync(path.join(dir, file), 'utf8')
      .replace('<svg', `<svg width="${side}" height="${side}"`);
    await page.setContent(
      `<body style="margin:0;background:#fff">${svg}</body>`,
    );
    await page.screenshot({ path: path.join(out, file.replace('.svg', '.png')) });
  }
  await browser.close();
})();
