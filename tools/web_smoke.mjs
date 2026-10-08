// 웹 빌드 스모크 테스트: build/web을 헤드리스 Chromium(WebGL)으로 열어 PLATFORM_TEST 로그를 확인한다.
import { createRequire } from 'node:module';
import fs from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const url = process.argv[2];
const outPng = process.argv[3] ?? 'build/web_smoke.png';
const outLog = process.argv[4] ?? 'build/web_smoke_console.log';
const MARKER = 'PLATFORM_TEST:';

let exe;
for (const p of [process.env.CHROMIUM_PATH, '/opt/pw-browsers/chromium-1194/chrome-linux/chrome']) {
  if (p && fs.existsSync(p)) { exe = p; break; }
}
const browser = await chromium.launch({
  executablePath: exe,
  headless: true,
  args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader',
         '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const lines = [];
let sawMarker = false;
let errors = 0;
page.on('console', (m) => {
  const t = m.type();
  const text = m.text();
  lines.push(`[${t}] ${text}`);
  if (text.includes(MARKER)) sawMarker = true;
  if (t === 'error' && !/favicon/i.test(text + (m.location().url ?? ''))) errors++;
});
page.on('pageerror', (e) => { lines.push(`[pageerror] ${e.message}`); errors++; });

await page.goto(url);
const deadline = Date.now() + 60000;
while (!sawMarker && Date.now() < deadline) await page.waitForTimeout(500);
await page.waitForTimeout(5000);
fs.mkdirSync('build', { recursive: true });
await page.screenshot({ path: outPng });
fs.writeFileSync(outLog, lines.join('\n') + '\n');
await browser.close();

if (!sawMarker) { console.error('FAIL: PLATFORM_TEST 마커가 나타나지 않음'); process.exit(1); }
if (errors > 0) { console.error(`FAIL: 콘솔 error ${errors}건 (${outLog} 참조)`); process.exit(1); }
console.log(lines.filter((l) => l.includes(MARKER)).join('\n'));
console.log('PASS');
