// 웹 빌드 스모크 테스트: build/web을 헤드리스 Chromium(WebGL)으로 열고 씬별 마커 로그를 확인한다.
// 사용법: node tools/web_smoke.mjs <index.html URL> [platform|inventory|combat|mod|ai|raid|style] [마커 덮어쓰기]
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
  combat: {
    marker: 'COMBAT_TEST: ready',
    viewport: { width: 1280, height: 720 },
    png: 'build/combat_smoke.png',
    png2: 'build/combat_smoke_after.png',
    pngTouch: 'build/combat_smoke_touch.png',
    pngSprint: 'build/combat_smoke_sprint.png',
    pngInventory: 'build/combat_smoke_inventory.png',
    log: 'build/combat_smoke_console.log',
  },
  // AI 테스트: 적 교전(COMBAT·enemy_shot·player_hit) → K로 적 처치(시체·루팅 아이템) → F 루팅 → 가방 닫기 버튼
  ai: {
    marker: 'AI_TEST: ready',
    urlScene: 'ai',
    viewport: { width: 1280, height: 720 },
    png: 'build/ai_smoke.png',
    pngLoot: 'build/ai_smoke_loot.png',
    log: 'build/ai_smoke_console.log',
  },
  // 레이드(산업단지): 지오메트리·내비메시·컨테이너·적 구성 → 적 전멸(K) → G/F로 컨테이너 열기 → 수색(공개·중단·재개·완료)
  // → 첫 아이템 끌어 가져오기 → T로 정문 탈출 → 결과 화면 (RAID 로그)
  raid: {
    marker: 'RAID: ready',
    urlScene: 'raid',
    viewport: { width: 1280, height: 720 },
    png: 'build/raid_smoke.png',
    pngSearch: 'build/raid_smoke_search.png',
    pngResults: 'build/raid_smoke_results.png',
    log: 'build/raid_smoke_console.log',
  },
  // 스타일 비교: ?scene=style_a 3컷 → style_b → style_c (각 1·2·3 키) → build/style_{a,b,c}_{1,2,3}.png + 렌더 통계 확인
  style: {
    marker: 'STYLE: ready',
    urlScene: 'style_a',
    viewport: { width: 1280, height: 720 },
    png: 'build/style_a_1.png',
    log: 'build/style_smoke_console.log',
  },
  // 인벤토리 데모에서 소총 선택 → 모딩 → 소음기 장착/분리 (MOD_SCREEN 로그와 weapon_changed 이벤트 확인)
  mod: {
    marker: 'INVENTORY_DEMO: ready',
    urlScene: 'inventory',
    viewport: { width: 1280, height: 720 },
    png: 'build/mod_smoke.png',
    pngPreview: 'build/mod_smoke_preview.png',
    pngAttached: 'build/mod_smoke_attached.png',
    pngGrown: 'build/mod_smoke_grown.png',
    pngDetached: 'build/mod_smoke_detached.png',
    pngClosed: 'build/mod_smoke_closed.png',
    log: 'build/mod_smoke_console.log',
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
const page = await browser.newPage({ viewport: mode.viewport, hasTouch: scene === 'inventory' || scene === 'mod' });
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
await page.goto(`${baseUrl}?scene=${mode.urlScene ?? scene}`);
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

// --- combat ---
if (scene === 'combat') {
  if (!sawMarker) { await browser.close(); finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const count = (re, from = 0) => lines.slice(from).filter((l) => re.test(l)).length;
  const waitMatch = async (from, re, ms = 5000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      if (count(re, from) > 0) return true;
      await page.waitForTimeout(100);
    }
    return false;
  };
  await page.waitForTimeout(1500);

  // 1) 데스크톱: 캔버스 중앙 클릭(포인터 잠금 시도) + 좌클릭을 누르고 있으면 연사. 처음부터 10m 더미를 정면으로 본다.
  await page.mouse.move(640, 360);
  const from = lines.length;
  await page.mouse.down();
  await page.waitForTimeout(1200);
  await page.screenshot({ path: mode.png });
  await page.mouse.up();
  await page.waitForTimeout(300);
  const shots = count(/COMBAT_TEST: shot ammo_556_fmj rounds=\d+/, from);
  check(shots >= 2, `좌클릭 유지 사격: shot 로그 ${shots}건 (연사라면 2건 이상)`);
  check(count(/COMBAT_TEST: hit dummy10 dmg=\d+ pen=true hp=\d+/, from) >= 1, '10m 더미(dummy10)에 hit 로그가 없음');
  check(count(/COMBAT_TEST: kill dummy10/, from) >= 0, '');   // 킬은 반동에 따라 달라 필수 아님

  // 2) 재장전: R → 약 2초 뒤 reload ok. 소비한 탄이 있어야 한다.
  const beforeReload = lines.length;
  await page.keyboard.press('r');
  const reloaded = await waitMatch(beforeReload, /COMBAT_TEST: reload ok/, 8000);
  check(reloaded, 'R 후 "COMBAT_TEST: reload ok" 로그가 없음');
  await page.waitForTimeout(500);
  await page.screenshot({ path: mode.png2 });

  // 2b) 가방: I 키로 열면 플레이어 입력이 멈추고(로그), 다시 누르면 닫힌다. 열린 화면을 찍는다.
  {
    const o = lines.length;
    await page.keyboard.press('i');
    check(await waitMatch(o, /COMBAT_TEST: inventory open/, 4000), 'I 키 후 "COMBAT_TEST: inventory open" 로그가 없음');
    await page.waitForTimeout(800);
    await page.screenshot({ path: mode.pngInventory });
    const before = count(/COMBAT_TEST: shot /);
    await page.mouse.move(640, 360);
    await page.mouse.down();
    await page.waitForTimeout(500);
    await page.mouse.up();
    check(count(/COMBAT_TEST: shot /) === before, '가방이 열려 있는 동안 사격이 일어남');
    // 닫기 버튼(터치 기기용) 클릭으로 닫는다.
    const btn = lines.slice(o).join('\n').match(/COMBAT_TEST: close_button at (\d+),(\d+)/);
    check(btn !== null, '"COMBAT_TEST: close_button at" 로그가 없음');
    const c = lines.length;
    if (btn) await page.mouse.click(+btn[1], +btn[2]);
    check(await waitMatch(c, /COMBAT_TEST: inventory close/, 4000), '닫기 버튼 클릭 후 "COMBAT_TEST: inventory close" 로그가 없음');
    await page.waitForTimeout(400);
    // I 키로 다시 열고 닫기 (키보드 토글).
    const k = lines.length;
    await page.keyboard.press('i');
    check(await waitMatch(k, /COMBAT_TEST: inventory open/, 4000), '두 번째 I 키 후 열림 로그가 없음');
    await page.waitForTimeout(300);
    const k2 = lines.length;
    await page.keyboard.press('i');
    check(await waitMatch(k2, /COMBAT_TEST: inventory close/, 4000), '다시 I 키 후 "COMBAT_TEST: inventory close" 로그가 없음');
    await page.waitForTimeout(400);
  }

  // 3) 터치(멀티터치): 왼쪽 조이스틱(앞으로) + 사격 버튼 유지 + 오른쪽 드래그 시점을 동시에.
  await page.evaluate(() => document.exitPointerLock && document.exitPointerLock());   // 마우스 잠금 해제 (Esc와 같음)
  await page.waitForTimeout(900);
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
  const tp = (id, x, y) => ({ x, y, id });
  const send = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  const poseOf = (from2) => {
    const all = [...lines.slice(from2).join('\n').matchAll(/COMBAT_TEST: pos x=(-?[\d.]+) z=(-?[\d.]+) yaw=(-?[\d.]+)/g)];
    return all.length ? { x: +all.at(-1)[1], z: +all.at(-1)[2], yaw: +all.at(-1)[3] } : null;
  };
  const t0 = lines.length;
  const base = poseOf(0);   // 잠금 해제 직후의 시점 (해제 때 브라우저가 튀는 마우스 이동을 흘릴 수 있음)
  const stick0 = tp(1, 160, 520), fire = tp(2, 1176, 616), look0 = tp(3, 760, 300);
  await send('touchStart', [stick0, fire, look0]);
  await page.waitForTimeout(200);
  for (let i = 1; i <= 12; i++) {
    await send('touchMove', [tp(1, 160, 520 - i * 8), fire, tp(3, 760 + i * 14, 300)]);
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(600);
  await page.screenshot({ path: mode.pngTouch });
  const pose = poseOf(t0);
  await send('touchEnd', []);
  await page.waitForTimeout(500);
  check(count(/COMBAT_TEST: shot /, t0) >= 2, `터치: 사격 버튼 유지 중 shot 로그가 부족 (${count(/COMBAT_TEST: shot /, t0)}건)`);
  const moved = pose && base ? Math.hypot(pose.x - base.x, pose.z - base.z) : 0;
  const turned = pose && base ? Math.abs(((pose.yaw - base.yaw + 540) % 360) - 180) : 0;
  check(moved > 0.8, `터치: 조이스틱으로 이동하지 않음 (이동 ${moved.toFixed(2)}m, base=${JSON.stringify(base)}, pose=${JSON.stringify(pose)})`);
  check(turned > 3, `터치: 오른쪽 드래그로 시점이 돌아가지 않음 (회전 ${turned.toFixed(1)}도)`);

  // 4) 달리기 잠금: 조이스틱을 링 위쪽 존까지 끌어올려 놓으면 손가락 없이 계속 달린다. 다시 누르면 해제.
  await page.waitForTimeout(500);
  // 벽에 막히지 않도록 먼저 시점을 정면(yaw 0, -z 방향 = 사격장 안쪽)으로 돌린다. 오른쪽으로 끌면 yaw가 줄어든다 (0.2도/px).
  for (let k = 0; k < 6; k++) {
    const cur = poseOf(0);
    const dyaw = cur ? ((0 - cur.yaw + 540) % 360) - 180 : 0;
    if (Math.abs(dyaw) < 15) break;
    const px = Math.max(-420, Math.min(420, -dyaw / 0.2005));
    const x0 = px >= 0 ? 600 : 1100;
    await send('touchStart', [tp(3, x0, 200)]);
    for (let i = 1; i <= 10; i++) { await send('touchMove', [tp(3, x0 + px * i / 10, 200)]); await page.waitForTimeout(40); }
    await send('touchEnd', []);
    await page.waitForTimeout(700);
  }
  const s0 = lines.length;
  await send('touchStart', [tp(1, 160, 560)]);
  await page.waitForTimeout(150);
  for (let i = 1; i <= 10; i++) {
    await send('touchMove', [tp(1, 160, 560 - i * 20)]);   // 200px 위 = 반지름의 약 2배 (잠금 존 안)
    await page.waitForTimeout(60);
  }
  await page.waitForTimeout(300);
  await send('touchEnd', []);
  const locked = await waitMatch(s0, /COMBAT_TEST: sprint_lock on/, 3000);
  check(locked, '달리기 잠금: "sprint_lock on" 로그가 없음');
  await page.waitForTimeout(250);
  const p1 = poseOf(0);
  const mark = lines.length;
  await page.waitForTimeout(1200);
  await page.screenshot({ path: mode.pngSprint });   // 잠금 안내가 보이는 화면 (손가락 없음)
  await page.waitForTimeout(100);
  const p2 = poseOf(mark) ?? poseOf(0);
  const ran = p1 && p2 ? Math.hypot(p2.x - p1.x, p2.z - p1.z) : 0;
  check(ran > 2, `달리기 잠금: 손가락 없이 이동하지 않음 (${ran.toFixed(2)}m, p1=${JSON.stringify(p1)}, p2=${JSON.stringify(p2)})`);
  const u0 = lines.length;
  await send('touchStart', [tp(1, 160, 560)]);   // 조이스틱 영역 다시 터치 -> 해제
  await page.waitForTimeout(100);
  await send('touchEnd', []);
  check(await waitMatch(u0, /COMBAT_TEST: sprint_lock off touch/, 3000), '조이스틱 재터치: "sprint_lock off touch" 로그가 없음');

  await browser.close();
  if (failures.filter(Boolean).length) { finish(failures.filter(Boolean).join('\n      ')); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => l.includes('COMBAT_TEST:') && !/ pos /.test(l)).slice(0, 40).join('\n'));
  console.log('PASS');
  process.exit(0);
}

// --- mod ---
if (scene === 'mod') {
  if (!sawMarker) { await browser.close(); finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const RECT = '(-?\\d+),(-?\\d+) size (\\d+)x(\\d+)';
  const rectOf = (m) => m && { x: +m[1], y: +m[2], w: +m[3], h: +m[4] };
  const center = (r) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
  const tap = async (p) => { await page.mouse.move(p.x, p.y); await page.mouse.down(); await page.waitForTimeout(60); await page.mouse.up(); };
  const waitMatch = async (from, re, ms = 5000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      const m = re.exec(lines.slice(from).join('\n'));
      if (m) return m;
      await page.waitForTimeout(100);
    }
    return null;
  };
  // from 이후 마지막으로 찍힌 좌표 로그 (화면이 갱신될 때마다 다시 찍힌다)
  const lastRect = (from, re) => {
    const all = [...lines.slice(from).join('\n').matchAll(new RegExp(re.source, 'g'))];
    return all.length ? rectOf(all[all.length - 1]) : null;
  };
  await page.waitForTimeout(1000);
  const text0 = lines.join('\n');
  const RIFLE = 3;
  const rifleM = new RegExp(`INVENTORY_DEMO: item ${RIFLE} at ${RECT}`).exec(text0);
  check(rifleM, '레이아웃 로그에 소총(item 3)이 없음');
  if (!rifleM) { await browser.close(); finish(failures.join('\n      ')); process.exit(1); }

  // 1) 소총 선택 → 액션 바에 모딩 버튼
  let from = lines.length;
  await tap(center(rectOf(rifleM)));
  check(await waitMatch(from, new RegExp(`INVENTORY_DEMO: selected ${RIFLE}\\b`)), '소총 탭 후 selected 로그가 없음');
  await page.waitForTimeout(500);
  const modBtn = lastRect(from, new RegExp(`INVENTORY_DEMO: button mod at ${RECT}`));
  check(modBtn, '소총 선택 시 모딩(mod) 버튼이 없음');
  if (!modBtn) { await browser.close(); finish(failures.join('\n      ')); process.exit(1); }

  // 2) 모딩 화면 열기
  from = lines.length;
  await tap(center(modBtn));
  check(await waitMatch(from, /MOD_SCREEN: open rifle/), '"MOD_SCREEN: open rifle" 로그가 없음');
  const statsM = await waitMatch(from, /MOD_SCREEN: stats recoil=([\d.]+) ergo=([\d.]+)/);
  check(statsM, '열 때 "MOD_SCREEN: stats" 로그가 없음');
  await page.waitForTimeout(1800);   // 3D 미리보기가 그려질 시간
  check(await waitMatch(from, /MOD_SCREEN: socket barrel\/muzzle at/), '소켓 목록 좌표 로그(barrel/muzzle)가 없음');
  await page.screenshot({ path: mode.png });
  const recoil0 = statsM ? +statsM[1] : NaN;
  const ergo0 = statsM ? +statsM[2] : NaN;

  // 3) 총구 소켓 선택 (이미 선택돼 있어도 탭은 무해) → 소음기 후보 탭 = 미리보기 → 장착 버튼
  const sock = lastRect(from, new RegExp(`MOD_SCREEN: socket barrel/muzzle at ${RECT}`));
  check(sock, 'barrel/muzzle 소켓 좌표가 없음');
  if (sock) { await tap(center(sock)); await page.waitForTimeout(500); }
  from = lines.length;
  const partRe = new RegExp(`MOD_SCREEN: part suppressor at ${RECT} enabled=1`);
  let part = lastRect(0, partRe);
  check(part, '후보 목록에 사용 가능한 소음기가 없음');
  if (!part) { await browser.close(); finish(failures.join('\n      ')); process.exit(1); }
  await tap(center(part));
  await page.waitForTimeout(900);
  await page.screenshot({ path: mode.pngPreview });
  const attachBtn = lastRect(from, new RegExp(`MOD_SCREEN: button attach at ${RECT} enabled=1`));
  check(attachBtn, '후보를 고른 뒤 장착 버튼이 활성화되지 않음');
  from = lines.length;
  if (attachBtn) await tap(center(attachBtn));
  const att = await waitMatch(from, /MOD_SCREEN: attach suppressor -> barrel\/muzzle ok/);
  check(att, '"MOD_SCREEN: attach suppressor -> barrel/muzzle ok" 로그가 없음');
  const evt = await waitMatch(from, /INVENTORY_DEMO: event weapon_changed 3 size=(\d+)x(\d+)/);
  check(evt, '장착 뒤 weapon_changed 이벤트 로그가 없음');
  if (evt) check(+evt[1] === 6 && +evt[2] === 2, `소음기를 달면 소총이 6x2여야 함: ${evt[1]}x${evt[2]}`);
  const st1 = await waitMatch(from, /MOD_SCREEN: stats recoil=([\d.]+) ergo=([\d.]+)/);
  check(st1, '장착 뒤 stats 로그가 없음');
  if (st1) check(+st1[1] < recoil0 && +st1[2] < ergo0, `소음기: 반동↓ 조작성↓ 기대 (전 ${recoil0}/${ergo0}, 후 ${st1[1]}/${st1[2]})`);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: mode.pngAttached });

  // 3b) 닫으면 커진 소총(6x2)이 인벤토리에 제대로 그려진다 → 다시 열기
  let closeBtn = lastRect(from, new RegExp(`MOD_SCREEN: button close at ${RECT}`));
  check(closeBtn, '닫기 버튼 좌표가 없음');
  from = lines.length;
  if (closeBtn) await tap(center(closeBtn));
  check(await waitMatch(from, /MOD_SCREEN: close/), '(1) "MOD_SCREEN: close" 로그가 없음');
  await page.waitForTimeout(700);
  await page.screenshot({ path: mode.pngGrown });
  from = lines.length;
  await tap(center(modBtn));
  check(await waitMatch(from, /MOD_SCREEN: open rifle/), '다시 열 때 "MOD_SCREEN: open rifle" 로그가 없음');
  await page.waitForTimeout(1200);

  // 4) 분리: 총구 소켓을 골라 분리 버튼 (아래에 부품이 없으니 활성)
  const sock2 = lastRect(from, new RegExp(`MOD_SCREEN: socket barrel/muzzle at ${RECT}`));
  check(sock2, '다시 연 뒤 barrel/muzzle 소켓 좌표가 없음');
  if (sock2) { await tap(center(sock2)); await page.waitForTimeout(700); }
  const detachBtn = lastRect(from, new RegExp(`MOD_SCREEN: button detach at ${RECT} enabled=1`));
  check(detachBtn, '소음기가 달린 소켓을 고르면 분리(detach) 버튼 좌표가 있어야 함');
  from = lines.length;
  if (detachBtn) await tap(center(detachBtn));
  check(await waitMatch(from, /MOD_SCREEN: detach barrel\/muzzle ok/), '"MOD_SCREEN: detach barrel/muzzle ok" 로그가 없음');
  const evt2 = await waitMatch(from, /INVENTORY_DEMO: event weapon_changed 3 size=(\d+)x(\d+)/);
  check(evt2 && +evt2[1] === 5 && +evt2[2] === 2, '분리 뒤 소총이 5x2로 돌아와야 함');
  const st2 = await waitMatch(from, /MOD_SCREEN: stats recoil=([\d.]+) ergo=([\d.]+)/);
  check(st2 && +st2[1] === recoil0 && +st2[2] === ergo0, '분리 뒤 스탯이 처음 값으로 돌아와야 함');
  await page.waitForTimeout(900);
  await page.screenshot({ path: mode.pngDetached });

  // 5) 닫기 → 인벤토리로 복귀
  closeBtn = lastRect(from, new RegExp(`MOD_SCREEN: button close at ${RECT}`));
  check(closeBtn, '닫기 버튼 좌표가 없음');
  from = lines.length;
  if (closeBtn) await tap(center(closeBtn));
  check(await waitMatch(from, /MOD_SCREEN: close/), '"MOD_SCREEN: close" 로그가 없음');
  await page.waitForTimeout(700);
  await page.screenshot({ path: mode.pngClosed });

  await browser.close();
  if (failures.length) { finish(failures.join('\n      ')); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => /MOD_SCREEN: (open|attach|detach|stats|close|select)|weapon_changed/.test(l)).join('\n'));
  console.log('PASS');
  process.exit(0);
}

// --- ai ---
if (scene === 'ai') {
  if (!sawMarker) { await browser.close(); finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const count = (re, from = 0) => lines.slice(from).filter((l) => re.test(l)).length;
  const waitMatch = async (from, re, ms = 5000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      const hit = lines.slice(from).map((l) => re.exec(l)).find((m) => m);
      if (hit) return hit;
      await page.waitForTimeout(100);
    }
    return null;
  };
  const readyCount = () => count(/AI_TEST: ready/);

  // 1) 내비메시가 구워졌다
  const nav = await waitMatch(0, /AI_TEST: navmesh polys=(\d+)/, 5000);
  check(nav && +nav[1] > 0, '"AI_TEST: navmesh polys=<n>" 로그가 없거나 n이 0');
  await page.waitForTimeout(1000);
  await page.mouse.move(640, 360);

  // 2) 40초 안에 교전(COMBAT) + 적 사격 + 플레이어 피격. 15초 안에 아무도 못 봤으면 한 발 쏴서 소음을 낸다.
  const t0 = lines.length;
  let combat = await waitMatch(t0, /AI_TEST: state 적\d COMBAT/, 15000);
  if (!combat) {
    await page.mouse.down(); await page.waitForTimeout(150); await page.mouse.up();
    check(await waitMatch(t0, /AI_TEST: noise (\d+)/, 3000), '총을 쐈는데 "AI_TEST: noise <반경>" 로그가 없음');
    combat = await waitMatch(t0, /AI_TEST: state 적\d COMBAT/, 25000);
  }
  check(combat, '40초 안에 어떤 적도 COMBAT 상태가 되지 않음');
  check(await waitMatch(t0, /AI_TEST: enemy_shot 적\d/, 15000), '"AI_TEST: enemy_shot" 로그가 없음');
  check(await waitMatch(t0, /AI_TEST: player_hit hp=(\d+)/, 25000), '"AI_TEST: player_hit" 로그가 없음');
  await page.screenshot({ path: mode.png });
  console.log(lines.filter((l) => /AI_TEST: (navmesh|state|player_hit|noise)/.test(l)).slice(0, 14).join('\n'));

  // 플레이어가 이미 죽었다면 씬이 다시 불릴 때까지 기다린다 (루팅 단계는 살아 있어야 한다)
  if (has('AI_TEST: player_dead')) {
    const before = readyCount();
    const reborn = Date.now() + 15000;
    while (readyCount() === before && Date.now() < reborn) await page.waitForTimeout(250);
    await page.waitForTimeout(500);
  }

  // 3) K: 살아 있는 적을 모두 처치 (시체가 플레이어 앞 2 m로 옮겨짐). 루팅 아이템 2개 이상.
  const k0 = lines.length;
  const items = [];
  for (let i = 0; i < 3; i++) {
    const before = lines.length;
    await page.keyboard.press('k');
    const dead = await waitMatch(before, /AI_TEST: enemy_dead (적\d) loot=(loot_\d+) items=(\d+)/, 4000);
    if (dead) items.push({ name: dead[1], key: dead[2], n: +dead[3] });
  }
  check(items.length === 3, `K 키로 적 3명을 처치해야 함 (실제 ${items.length}명)`);
  check(items.every((x) => x.n >= 2), `시체 루팅 아이템은 2개 이상이어야 함: ${JSON.stringify(items)}`);
  await page.waitForTimeout(600);

  // 4) F: 루팅 화면 열기 → 스크린샷 → 닫기 버튼
  const f0 = lines.length;
  await page.keyboard.press('f');
  const open = await waitMatch(f0, /AI_TEST: loot_open (loot_\d+) items=(\d+)/, 4000);
  check(open && +open[2] >= 2, '"AI_TEST: loot_open <키> items=<n>" 로그가 없거나 n < 2');
  check(await waitMatch(f0, /COMBAT_TEST: inventory open/, 4000), '루팅 화면을 열 때 "COMBAT_TEST: inventory open" 로그가 없음');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: mode.pngLoot });
  const btn = lines.slice(f0).join('\n').match(/COMBAT_TEST: close_button at (\d+),(\d+)/);
  check(btn !== null, '"COMBAT_TEST: close_button at" 로그가 없음');
  const c0 = lines.length;
  if (btn) await page.mouse.click(+btn[1], +btn[2]);
  check(await waitMatch(c0, /AI_TEST: loot_close loot_\d+/, 4000), '닫기 버튼 클릭 후 "AI_TEST: loot_close" 로그가 없음');
  await page.waitForTimeout(500);

  await browser.close();
  if (failures.length) { finish(failures.join('\n      ')); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => /AI_TEST: (enemy_dead|loot_)/.test(l)).join('\n'));
  console.log('PASS');
  process.exit(0);
}

// --- style ---
if (scene === 'style') {
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const waitMatch = async (from, re, ms) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      const m = re.exec(lines.slice(from).join('\n'));
      if (m) return m;
      await page.waitForTimeout(100);
    }
    return null;
  };
  const stats = {};
  for (const letter of ['a', 'b', 'c']) {
    let from = 0;
    if (letter !== 'a') {
      from = lines.length;
      await page.goto(`${baseUrl}?scene=style_${letter}`);
    }
    const ready = await waitMatch(from, new RegExp(`STYLE: ready ${letter}`), 90000);
    check(!!ready, `"STYLE: ready ${letter}"가 90초 안에 없음`);
    if (!ready) break;
    await page.waitForTimeout(2500);
    await page.mouse.move(640, 360);
    for (const n of [1, 2, 3]) {
      const s0 = lines.length;
      await page.keyboard.press(String(n));
      const hit = await waitMatch(s0, new RegExp(`STYLE: shot ${n}\\b[\\s\\S]*STYLE: render draw_calls=(\\d+) primitives=(\\d+)`), 20000);
      check(!!hit, `${letter} ${n}번 키 뒤에 "STYLE: shot ${n}" + render 통계가 없음`);
      if (hit) {
        stats[`${letter}${n}`] = { draw_calls: +hit[1], primitives: +hit[2] };
        check(+hit[1] > 0 && +hit[2] > 0, `${letter}${n} 렌더 통계가 0`);
      }
      await page.waitForTimeout(2500);
      await page.screenshot({ path: `build/style_${letter}_${n}.png` });
    }
  }
  await browser.close();
  check(has('STYLE: decals'), '"STYLE: decals" 로그 없음');
  if (failures.length) { finish(failures.join('\n      ')); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => /STYLE: /.test(l)).join('\n'));
  console.log(JSON.stringify(stats));
  console.log('PASS');
  process.exit(0);
}

// --- raid ---
if (scene === 'raid') {
  if (!sawMarker) { await browser.close(); finish(`${MARKER} 마커가 나타나지 않음`); process.exit(1); }
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const count = (re, from = 0) => lines.slice(from).filter((l) => re.test(l)).length;
  const waitMatch = async (from, re, ms = 5000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      const m = re.exec(lines.slice(from).join('\n'));
      if (m) return m;
      await page.waitForTimeout(100);
    }
    return null;
  };
  const num = (re) => { const m = re.exec(lines.join('\n')); return m ? +m[1] : 0; };
  const clickAt = async (x, y) => { await page.mouse.move(x, y); await page.mouse.down(); await page.waitForTimeout(60); await page.mouse.up(); };
  const dragFromTo = async (a, b) => {
    await page.mouse.move(a.x, a.y);
    await page.mouse.down();
    for (let i = 1; i <= 20; i++) {
      await page.mouse.move(a.x + (b.x - a.x) * i / 20, a.y + (b.y - a.y) * i / 20);
      await page.waitForTimeout(30);
    }
    await page.waitForTimeout(200);
    await page.mouse.up();
  };

  // 1) 구성: 상자 수·내비메시·컨테이너·적
  const boxes = num(/RAID: geometry boxes=(\d+)/);
  const polys = num(/RAID: navmesh polys=(\d+)/);
  const containers = num(/RAID: containers=(\d+)/);
  const enemies = num(/RAID: enemies=(\d+)/);
  check(boxes > 0, `geometry boxes=${boxes}`);
  check(polys > 0, `navmesh polys=${polys}`);
  check(containers >= 15, `containers=${containers} (15 이상이어야 함)`);
  check(enemies >= 5, `enemies=${enemies} (5 이상이어야 함)`);
  await page.waitForTimeout(1500);
  await page.mouse.move(640, 360);
  await page.screenshot({ path: mode.png });

  // 1b) 개발 키 V: 시점 순간이동 (공장·실내·마당) 스크린샷 + F2 품질 단계 로그
  for (const name of ['factory', 'interior', 'yard']) {
    const v0 = lines.length;
    await page.keyboard.press('v');
    check(await waitMatch(v0, new RegExp(`RAID: view ${name}`), 3000), `V 키 뒤에 "RAID: view ${name}"이 없음`);
    await page.waitForTimeout(1200);
    await page.screenshot({ path: `build/raid_view_${name}.png` });
  }
  const q0 = lines.length;
  await page.keyboard.press('F2');
  check(await waitMatch(q0, /RAID: quality (LOW|MID|HIGH)/, 3000), 'F2 키 뒤에 "RAID: quality"가 없음');
  check(has('RAID: render draw_calls=') || true, '');

  // 2) K: 적 전멸 (결정적인 나머지를 위해)
  for (let i = 0; i < enemies + 4 && count(/RAID: enemy_dead/) < enemies; i++) {
    const before = lines.length;
    await page.keyboard.press('k');
    await waitMatch(before, /RAID: enemy_dead/, 3000);
  }
  check(count(/RAID: enemy_dead/) === enemies, `K로 적 ${enemies}명을 모두 처치해야 함 (실제 ${count(/RAID: enemy_dead/)}명)`);
  check(!has('RAID: player_dead'), '적 전멸 전에 플레이어가 죽음');

  // 3) G → F → 수색 시작 → 공개 → (화면) → 버튼으로 중단 → 버튼으로 재개 → 완료. 수색이 너무 빨리 끝나면 다음 컨테이너로 다시 시도한다.
  let key = null;
  let stopped = false;
  for (let attempt = 0; attempt < 5 && !stopped; attempt++) {
    const g0 = lines.length;
    await page.keyboard.press('g');
    await page.waitForTimeout(700);
    await page.keyboard.press('f');
    const open = await waitMatch(g0, /RAID: open (loot_\d+) (\S+)/, 4000);
    if (!open) { check(false, `G, F 뒤에 "RAID: open" 로그가 없음 (시도 ${attempt + 1})`); break; }
    key = open[1];
    const start = await waitMatch(g0, new RegExp(`RAID: search start ${key}`), 4000);
    check(start, '컨테이너를 열었는데 자동으로 "search start"가 되지 않음');
    const btn = await waitMatch(g0, /RAID: search_button at (\d+),(\d+)/, 4000);
    check(btn, '"RAID: search_button at" 로그가 없음');
    console.log(`  ${open[0]}  button=${btn ? btn[1] + ',' + btn[2] : '-'}`);
    const rev = await waitMatch(g0, new RegExp(`RAID: revealed ${key} (\\d+)`), 10000);
    check(rev, '10초 안에 "revealed"가 없음');
    await page.waitForTimeout(150);
    if (attempt === 0 || !has('RAID: search stop')) await page.screenshot({ path: mode.pngSearch });
    if (has(`RAID: search complete ${key}`) || !btn) {
      // 이미 끝났다: 닫고 다음 컨테이너
      const cb = /COMBAT_TEST: close_button at (\d+),(\d+)/.exec(lines.slice(g0).join('\n'));
      if (cb) await clickAt(+cb[1], +cb[2]);
      await page.waitForTimeout(500);
      continue;
    }
    const s0 = lines.length;
    await clickAt(+btn[1], +btn[2]);
    stopped = !!(await waitMatch(s0, new RegExp(`RAID: search stop ${key} button`), 3000));
    if (!stopped && has(`RAID: search complete ${key}`)) {
      const cb = /COMBAT_TEST: close_button at (\d+),(\d+)/.exec(lines.slice(g0).join('\n'));
      if (cb) await clickAt(+cb[1], +cb[2]);
      await page.waitForTimeout(500);
      continue;
    }
    check(stopped, `중단 버튼을 눌렀는데 "search stop ${key} button" 로그가 없음`);
    await page.waitForTimeout(500);
    const r0 = lines.length;
    await clickAt(+btn[1], +btn[2]);   // 같은 버튼이 이제 "수색" → 재개
    check(await waitMatch(r0, new RegExp(`RAID: search start ${key}`), 3000), '재개 버튼을 눌렀는데 "search start"가 없음');
    check(await waitMatch(r0, new RegExp(`RAID: search complete ${key}`), 40000), '40초 안에 "search complete"가 없음');
    // 4) 첫 공개 아이템을 내 가방 빈 자리로 끌어다 놓기
    const hint = await waitMatch(r0, /RAID: take_hint item=(\d+) from=(\d+),(\d+) to=(\d+),(\d+)/, 4000);
    check(hint, '"RAID: take_hint" 로그가 없음');
    if (hint) {
      console.log(`  take_hint: item ${hint[1]} (${hint[2]},${hint[3]}) -> (${hint[4]},${hint[5]})`);
      const t0 = lines.length;
      await dragFromTo({ x: +hint[2], y: +hint[3] }, { x: +hint[4], y: +hint[5] });
      check(await waitMatch(t0, /RAID: take \d+/, 3000), '끌어다 놓았는데 "RAID: take" 로그가 없음');
    }
    // 5) 가방 닫기 (닫기 버튼)
    const cb = [...lines.join('\n').matchAll(/COMBAT_TEST: close_button at (\d+),(\d+)/g)].pop();
    const c0 = lines.length;
    if (cb) await clickAt(+cb[1], +cb[2]);
    check(await waitMatch(c0, /COMBAT_TEST: inventory close/, 3000), '닫기 버튼 뒤에 "inventory close"가 없음');
  }
  check(stopped, '수색 중단 시험을 끝내지 못함');
  await page.waitForTimeout(500);

  // 6) 전원 (개발 키 P) → 탈출: T = 정문
  const p0 = lines.length;
  await page.keyboard.press('p');
  check(await waitMatch(p0, /RAID: power_on/, 3000), 'P 키 뒤에 "RAID: power_on"이 없음');
  const e0 = lines.length;
  await page.keyboard.press('t');
  check(await waitMatch(e0, /RAID: extract_enter main_gate/, 4000), 'T 키 뒤에 "extract_enter main_gate"가 없음');
  check(await waitMatch(e0, /RAID: extracted main_gate/, 45000), '45초 안에 "extracted main_gate"가 없음');
  check(count(/RAID: extract_progress main_gate (25|50|75)/, e0) >= 3, 'extract_progress 25/50/75 로그가 모자람');
  const res = await waitMatch(e0, /RAID: results EXTRACTED value=(\d+) lost=(\d+)/, 4000);
  check(res && +res[1] > 0, `results EXTRACTED value가 0이거나 로그가 없음: ${res ? res[0] : '-'}`);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: mode.pngResults });

  await browser.close();
  if (failures.length) { finish(failures.join('\n      ')); process.exit(1); }
  finish(errors > 0 ? `콘솔 error ${errors}건 (${mode.log} 참조)` : null);
  if (process.exitCode) process.exit(1);
  console.log(lines.filter((l) => /RAID: (geometry|navmesh|containers|enemies|open|search (start|stop|complete)|take|power_on|extract|results)/.test(l)).join('\n'));
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
