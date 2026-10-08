// 웹 빌드 스모크 테스트: build/web을 헤드리스 Chromium(WebGL)으로 열고 씬별 마커 로그를 확인한다.
// 사용법: node tools/web_smoke.mjs <index.html URL> [platform|inventory] [마커 덮어쓰기]
import { createRequire } from 'node:module';
import fs from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const baseUrl = process.argv[2];
const scene = process.argv[3] || 'platform';
const MODES = {
  platform: {
    marker: 'PLATFORM_TEST:',
    viewport: { width: 1280, height: 720 },
    png: 'build/web_smoke.png',
    log: 'build/web_smoke_console.log',
  },
  inventory: {
    marker: 'INVENTORY_DEMO: ready',
    viewport: { width: 1280, height: 800 },
    png: 'build/inventory_smoke.png',
    png2: 'build/inventory_smoke_after.png',
    log: 'build/inventory_smoke_console.log',
  },
};
const mode = MODES[scene];
if (!mode) { console.error(`알 수 없는 씬: ${scene}`); process.exit(2); }
const MARKER = process.argv[4] || mode.marker;

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
const page = await browser.newPage({ viewport: mode.viewport });
const lines = [];
let errors = 0;
const has = (needle) => lines.some((l) => l.includes(needle));
page.on('console', (m) => {
  const t = m.type();
  const text = m.text();
  lines.push(`[${t}] ${text}`);
  if (t === 'error' && !/favicon/i.test(text + (m.location().url ?? ''))) errors++;
});
page.on('pageerror', (e) => { lines.push(`[pageerror] ${e.message}`); errors++; });

async function waitFor(needle, ms) {
  const deadline = Date.now() + ms;
  while (!has(needle) && Date.now() < deadline) await page.waitForTimeout(250);
  return has(needle);
}
function finish(failure) {
  fs.writeFileSync(mode.log, lines.join('\n') + '\n');
  if (failure) { console.error(`FAIL: ${failure}`); process.exitCode = 1; }
}

fs.mkdirSync('build', { recursive: true });
await page.goto(`${baseUrl}?scene=${scene}`);
const sawMarker = await waitFor(MARKER, 60000);

if (scene === 'platform') {
  await page.waitForTimeout(5000);
  await page.screenshot({ path: mode.png });
  await browser.close();
  if (!sawMarker) { finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => l.includes(MARKER)).join('\n'));
  console.log('PASS');
  process.exit(0);
}

// --- inventory ---
if (!sawMarker) { await browser.close(); finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
await page.waitForTimeout(1000);
await page.screenshot({ path: mode.png });

const text = lines.join('\n');
const stash = /INVENTORY_DEMO: stash origin=(-?\d+),(-?\d+) cell=(\d+)/.exec(text);
const item = /INVENTORY_DEMO: item 1 at (-?\d+),(-?\d+) size (\d+)x(\d+)/.exec(text);
if (!stash || !item) { await browser.close(); finish('레이아웃 로그(stash origin / item 1)가 없음'); process.exit(1); }
const [ox, oy, cell] = [+stash[1], +stash[2], +stash[3]];
const [ix, iy] = [+item[1], +item[2]];
// 권총(1)을 잡은 지점 = 아이템 좌상단 + 반 칸. 스태시의 빈 칸 (7,5)에 좌상단이 오도록 옮긴다.
const start = { x: ix + cell / 2, y: iy + cell / 2 };
const end = { x: ox + 7 * cell + cell / 2, y: oy + 5 * cell + cell / 2 };
await page.mouse.move(start.x, start.y);
await page.mouse.down();
for (let i = 1; i <= 20; i++) {
  await page.mouse.move(start.x + (end.x - start.x) * i / 20, start.y + (end.y - start.y) * i / 20);
  await page.waitForTimeout(30);
}
await page.waitForTimeout(200);
await page.screenshot({ path: 'build/inventory_smoke_dragging.png' });
await page.mouse.up();
const moved = await waitFor('INVENTORY_DEMO: event item_moved 1', 5000);
await page.waitForTimeout(500);
await page.screenshot({ path: mode.png2 });
await browser.close();

if (!moved) { finish('드래그 후 "event item_moved 1" 로그가 없음'); process.exit(1); }
finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
if (process.exitCode) process.exit(1);
console.log(lines.filter((l) => l.includes('INVENTORY_DEMO:')).join('\n'));
console.log('PASS');
