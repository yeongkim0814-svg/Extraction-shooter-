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
    viewport: { width: 1280, height: 720 },
    png: 'build/inventory_smoke.png',
    pngSelected: 'build/inventory_smoke_selected.png',
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
const page = await browser.newPage({ viewport: mode.viewport, hasTouch: scene === 'inventory' });
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

// 로그 파서: 데모가 출력한 창 픽셀 좌표를 읽는다 (아이템 id는 스모크 테스트가 고정 가정).
const RECT = '(-?\\d+),(-?\\d+) size (\\d+)x(\\d+)';
const text0 = lines.join('\n');
const stash = /INVENTORY_DEMO: stash origin=(-?\d+),(-?\d+) cell=(\d+)/.exec(text0);
const itemRe = (id) => new RegExp(`INVENTORY_DEMO: item ${id} at ${RECT}`).exec(text0);
const rectOf = (m) => m && { x: +m[1], y: +m[2], w: +m[3], h: +m[4] };
const center = (r) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
const glassesId = +(/INVENTORY_DEMO: role glasses id=(\d+)/.exec(text0)?.[1] ?? 0);
const PISTOL = 1, RIFLE = 3, ARMOR = 13;
if (!stash || !itemRe(PISTOL) || !itemRe(RIFLE) || !itemRe(ARMOR) || !glassesId || !itemRe(glassesId)) {
  await browser.close(); finish('레이아웃 로그(stash origin / item 1,3,13 / glasses)가 없음'); process.exit(1);
}
const [ox, oy, cell] = [+stash[1], +stash[2], +stash[3]];
const cellCenter = (cx, cy) => ({ x: ox + cx * cell + cell / 2, y: oy + cy * cell + cell / 2 });
const failures = [];
const check = (ok, msg) => { if (!ok) failures.push(msg); };

async function tap(p) {
  await page.mouse.move(p.x, p.y);
  await page.mouse.down();
  await page.waitForTimeout(60);
  await page.mouse.up();
}
async function dragTo(start, end, shot) {
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  for (let i = 1; i <= 20; i++) {
    await page.mouse.move(start.x + (end.x - start.x) * i / 20, start.y + (end.y - start.y) * i / 20);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(200);
  if (shot) await page.screenshot({ path: shot });
  await page.mouse.up();
}
// 지금까지의 로그 길이 이후에 나타난 첫 매치를 기다린다.
async function waitMatch(from, re, ms = 5000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    const m = re.exec(lines.slice(from).join('\n'));
    if (m) return m;
    await page.waitForTimeout(100);
  }
  return null;
}
// from 이후 마지막 scroll 로그 (없으면 null).
function lastScroll(from) {
  const all = [...lines.slice(from).join('\n').matchAll(/INVENTORY_DEMO: scroll left=(\d+) right=(\d+)/g)];
  return all.length ? all[all.length - 1] : null;
}
// 선택 직후의 액션 바 버튼 좌표 (선택 로그 뒤에 "button <key> at ..." 줄이 따라온다).
async function selectItem(id, label) {
  const from = lines.length;
  const r = rectOf(itemRe(id));
  await tap(center(r));
  const sel = await waitMatch(from, new RegExp(`INVENTORY_DEMO: selected ${id}\\b`));
  check(sel, `${label}: 탭해도 selected ${id} 로그가 없음`);
  await page.waitForTimeout(500);
  const block = lines.slice(from).join('\n');
  const buttons = {};
  for (const m of block.matchAll(new RegExp(`INVENTORY_DEMO: button (\\w+) at ${RECT}`, 'g'))) {
    buttons[m[1]] = { x: +m[2], y: +m[3], w: +m[4], h: +m[5] };
  }
  return buttons;
}

// 1) 드래그: 스태시 권총(1)을 누른 채 움직이면 즉시 집힌다 (롱프레스 없음). 빈 칸 (7,5)로.
{
  const from = lines.length;
  const r = rectOf(itemRe(PISTOL));
  await dragTo({ x: r.x + cell / 2, y: r.y + cell / 2 }, cellCenter(7, 5), 'build/inventory_smoke_dragging.png');
  const m = await waitMatch(from, /INVENTORY_DEMO: event item_moved 1 to=stash@(\d+),(\d+)/);
  check(m, '드래그 후 "event item_moved 1" 로그가 없음');
  if (m) check(+m[1] === 7 && +m[2] === 5, `드래그 도착 칸이 (7,5)가 아님: ${m[1]},${m[2]}`);
}

// 2) 탭 선택 → 액션 바 → 빈 칸 탭으로 이동: 소총(3)
{
  const buttons = await selectItem(RIFLE, '소총');
  for (const k of ['rotate', 'info', 'discard']) check(buttons[k], `소총 선택 시 ${k} 버튼 로그가 없음`);
  check(!buttons.split && !buttons.equip && !buttons.unequip && !buttons.sell, '소총에는 split/equip/unequip/sell 버튼이 없어야 함');
  await page.screenshot({ path: mode.pngSelected });
  const from = lines.length;
  await tap(cellCenter(5, 8));
  const m = await waitMatch(from, /INVENTORY_DEMO: event item_moved 3 to=stash@(\d+),(\d+) rot=(\d)/);
  check(m, '선택 후 빈 칸 탭 이동: "event item_moved 3" 로그가 없음');
  if (m) check(+m[2] >= 7 && +m[2] <= 8 && +m[1] >= 1 && +m[1] <= 5, `탭 이동 위치가 (5,8) 근처가 아님: ${m[1]},${m[2]}`);
  check(await waitMatch(from, /INVENTORY_DEMO: deselected/, 3000), '이동 후 deselected 로그가 없음');
}

// 3) 탭 선택 → 장착: 안경(스태시) → EYE 슬롯
{
  const buttons = await selectItem(glassesId, '안경');
  check(buttons.equip, '안경에 장착 버튼이 없음');
  if (buttons.equip) {
    const from = lines.length;
    await tap(center(buttons.equip));
    const m = await waitMatch(from, new RegExp(`INVENTORY_DEMO: event item_moved ${glassesId} to=slot_eye@`));
    check(m, '장착 버튼 후 "event item_moved <glasses> to=slot_eye" 로그가 없음');
  }
}

// 4) 탭 선택 → 해제: 방탄복(13, ARMOR 슬롯) → 스태시
{
  const buttons = await selectItem(ARMOR, '방탄복');
  check(buttons.unequip, '장착 중인 방탄복에 해제 버튼이 없음');
  check(!buttons.equip, '장착 중인 방탄복에 장착 버튼이 있으면 안 됨');
  if (buttons.unequip) {
    const from = lines.length;
    await tap(center(buttons.unequip));
    const m = await waitMatch(from, /INVENTORY_DEMO: event item_moved 13 to=stash@/);
    check(m, '해제 버튼 후 "event item_moved 13 to=stash" 로그가 없음');
  }
}
await page.waitForTimeout(500);
await page.screenshot({ path: mode.png2 });

// 4b) 실제 터치 입력(CDP): 탭으로 선택 → 선택한 채로 같은 아이템을 끌면 선택이 풀리고 드래그가 된다
{
  const cdp = await page.context().newCDPSession(page);
  const touch = (type, p) => cdp.send('Input.dispatchTouchEvent',
    { type, touchPoints: type === 'touchEnd' ? [] : [{ x: p.x, y: p.y, id: 1 }] });
  const at = cellCenter(7, 5);   // 1)에서 옮겨 둔 권총 (7,5)
  let from = lines.length;
  await touch('touchStart', at); await page.waitForTimeout(60); await touch('touchEnd', at);
  check(await waitMatch(from, /INVENTORY_DEMO: selected 1\b/), '터치 탭으로 권총이 선택되지 않음');
  from = lines.length;
  await touch('touchStart', at);
  const end = cellCenter(7, 9);
  for (let i = 1; i <= 12; i++) {
    await touch('touchMove', { x: at.x, y: at.y + (end.y - at.y) * i / 12 });
    await page.waitForTimeout(30);
  }
  await touch('touchEnd', end);
  const m = await waitMatch(from, /INVENTORY_DEMO: event item_moved 1 to=stash@(\d+),(\d+)/);
  check(m, '터치 드래그 후 "event item_moved 1" 로그가 없음');
  if (m) check(+m[1] === 7 && +m[2] === 9, `터치 드래그 도착 칸이 (7,9)가 아님: ${m[1]},${m[2]}`);
  check(await waitMatch(from, /INVENTORY_DEMO: deselected/, 3000), '드래그 시작 시 선택이 풀리지 않음');
}

// 5) 스크롤: 빈 곳을 누른 채 움직이면 그 쪽 절반이 스크롤된다 (왼쪽 슬롯 페이지 / 오른쪽 스태시)
{
  const from = lines.length;
  const start = cellCenter(8, 3);           // 스태시의 빈 칸 (위쪽 끝)
  await page.mouse.move(640 - 80, 520);     // 왼쪽 절반의 오른쪽 빈 공간 (슬롯 페이지 폭 바깥)
  await page.mouse.down();
  for (let i = 1; i <= 10; i++) { await page.mouse.move(640 - 80, 520 - i * 25); await page.waitForTimeout(30); }
  await page.mouse.up();
  await page.waitForTimeout(400);
  const left = lastScroll(from);
  check(left && +left[1] > 100, `왼쪽 절반이 스크롤되지 않음: ${left && left[0]}`);
  const from2 = lines.length;
  await page.mouse.move(start.x, 600);
  await page.mouse.down();
  for (let i = 1; i <= 10; i++) { await page.mouse.move(start.x, 600 - i * 25); await page.waitForTimeout(30); }
  await page.mouse.up();
  await page.waitForTimeout(400);
  const right = lastScroll(from2);
  check(right && +right[2] > 100, `오른쪽 스태시가 스크롤되지 않음: ${right && right[0]}`);
  check(!lines.slice(from).some((l) => l.includes('event ')), '스크롤 제스처가 아이템 이벤트를 일으킴 (드래그로 오인)');
  await page.screenshot({ path: 'build/inventory_smoke_scrolled.png' });
}

// 6) 군장/배낭/보안 컨테이너 구역: 왼쪽 페이지를 맨 아래로 스크롤해 장착 상태를 찍고,
//    배낭을 해제해서 빈 상태(슬롯 네모만)도 찍는다.
{
  const scale = +(/INVENTORY_DEMO: scale ([\d.]+)/.exec(text0)?.[1] ?? 1);
  const packId = +(/INVENTORY_DEMO: role backpack id=(\d+)/.exec(text0)?.[1] ?? 0);
  const bagSlot = rectOf(new RegExp(`INVENTORY_DEMO: slot BACKPACK at ${RECT}`).exec(text0));
  check(packId && bagSlot, '레이아웃 로그에 role backpack / slot BACKPACK이 없음');
  if (packId && bagSlot) {
    await page.mouse.move(640 - 80, 400);
    for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, 600); await page.waitForTimeout(120); }
    await page.waitForTimeout(500);
    const sc = lastScroll(0);
    const scrollPx = sc ? +sc[1] * scale : 0;
    check(sc && +sc[1] > 100, `왼쪽 페이지가 아래로 스크롤되지 않음: ${sc && sc[0]}`);
    // 가려지지 않게 스크롤 후 슬롯 위치 = 처음 좌표 - 스크롤
    const bag = { x: bagSlot.x, y: bagSlot.y - scrollPx, w: bagSlot.w, h: bagSlot.h };
    check(bag.y >= 0 && bag.y + bag.h <= 720, `스크롤 후 배낭 슬롯이 화면 밖: y=${bag.y}`);
    await page.screenshot({ path: 'build/inventory_smoke_sections.png' });
    const from = lines.length;
    await tap(center(bag));
    check(await waitMatch(from, new RegExp(`INVENTORY_DEMO: selected ${packId}\\b`)), '배낭 슬롯 탭 후 selected 로그가 없음');
    await page.waitForTimeout(500);
    const buttons = {};
    for (const m of lines.slice(from).join('\n').matchAll(new RegExp(`INVENTORY_DEMO: button (\\w+) at ${RECT}`, 'g'))) {
      buttons[m[1]] = { x: +m[2], y: +m[3], w: +m[4], h: +m[5] };
    }
    check(buttons.unequip, '배낭에 해제 버튼이 없음');
    if (buttons.unequip) {
      const from2 = lines.length;
      await tap(center(buttons.unequip));
      check(await waitMatch(from2, new RegExp(`INVENTORY_DEMO: event item_moved ${packId} to=stash@`)),
        '배낭 해제 후 item_moved 로그가 없음');
      await page.waitForTimeout(600);
      await page.screenshot({ path: 'build/inventory_smoke_sections_empty.png' });
      await page.mouse.move(640 - 80, 400);
      for (let i = 0; i < 2; i++) { await page.mouse.wheel(0, -100); await page.waitForTimeout(120); }
      await page.waitForTimeout(400);
      await page.screenshot({ path: 'build/inventory_smoke_rig.png' });
    }
  }
}
await browser.close();

if (failures.length) { finish(failures.join('\n      ')); process.exit(1); }
finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
if (process.exitCode) process.exit(1);
console.log(lines.filter((l) => l.includes('INVENTORY_DEMO:') && !/ item \d+ at /.test(l)).join('\n'));
console.log('PASS');
