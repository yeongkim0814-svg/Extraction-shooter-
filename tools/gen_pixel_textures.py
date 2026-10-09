#!/usr/bin/env python3
"""스타일 C("레트로 로우폴리") 픽셀 텍스처를 절차적으로 그린다 (numpy + Pillow, 시드 고정 -> 결정적).

출력: assets/textures/retro/<이름>.png  (32 또는 64 px, 타일형, 손으로 칠한 느낌의 제한 팔레트)
  concrete        콘크리트 패널 격자 + 물 얼룩 + 모서리 깨짐 + 아래쪽 때
  asphalt         균열·보수 패치·기름 얼룩
  lane            바랜 차선 페인트 (아스팔트가 비치게 벗겨짐)
  brick           벽돌 줄눈(층), 그을음, 흰 백화 자국
  corrugated_red / corrugated_slate   컨테이너 골판 세로 주름 + 녹물 줄기·물방울 + 벗겨진 도장
  door_red / door_slate               컨테이너 문: 굵은 세로 리브 + 잠금 막대 자리
  steel / rust    강판(리벳·이음매) / 녹슨 판
  wood            널빤지(옹이·이음·못)
  paint           회백색 도장 금속 (정점 색으로 물들인다: 드럼통·트럭·지게차)
  hazard          바랜 호박색/숯색 사선 경고 띠
  window / window_lit   어두운 유리(하늘빛 반사·때) / 따뜻하게 불 켜진 창

규약
- 월드 텍셀 밀도는 TEXELS_PER_M(16)으로 고정: 64 px = 4 m, 32 px = 2 m 한 장. 재질 쪽(retro_materials.gd)이 같은 값을 쓴다.
- 이미지의 아래쪽 행이 지면(y = 0)에 닿는다 (MeshBuilder.world_uv): 때 그라데이션은 아래, 녹 줄기는 위에서 아래로.
- 색은 PIL 적응 팔레트 양자화로 텍스처당 12~24색으로 줄인다 (디더링 없음).
- .import는 무손실 + 최근접 밉맵(재질이 필터를 정한다) + 3D 자동 VRAM 압축 끔으로 맞춘다.

사용법: python3 tools/gen_pixel_textures.py [--only 이름 ...] [--preview 경로] [--patch-import]
  순서: 텍스처 생성 -> godot --headless --import (.import 생성) -> --patch-import -> 다시 --import
"""
import argparse
import os
import sys
import zlib

import numpy as np
from PIL import Image

TEXELS_PER_M = 16
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "retro")


# ---------------------------------------------------------------- 도구

def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()) & 0xFFFFFFFF)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def vnoise(rng, n, cells):
    """주기적 값 노이즈 [0, 1] (n x n)."""
    g = rng.random((cells, cells)).astype(np.float32)
    xs = (np.arange(n, dtype=np.float32) + 0.5) / n * cells - 0.5
    x0 = np.floor(xs).astype(int)
    f = xs - x0
    f = f * f * (3.0 - 2.0 * f)
    x1 = (x0 + 1) % cells
    x0 = x0 % cells
    top = g[np.ix_(x0, x0)] * (1 - f)[None, :] + g[np.ix_(x0, x1)] * f[None, :]
    bot = g[np.ix_(x1, x0)] * (1 - f)[None, :] + g[np.ix_(x1, x1)] * f[None, :]
    return top * (1 - f)[:, None] + bot * f[:, None]


def fbm(rng, n, cells=(4, 8), weights=(0.65, 0.35)):
    out = np.zeros((n, n), np.float32)
    for c, w in zip(cells, weights):
        out += vnoise(rng, n, c) * w
    return out / sum(weights)


def steps(a, levels):
    """연속값을 몇 단계로 끊는다 (칠한 듯한 덩어리)."""
    return np.floor(np.clip(a, 0, 0.9999) * levels) / (levels - 1)


class Canvas:
    def __init__(self, n, base):
        self.n = n
        self.img = np.zeros((n, n, 3), np.float32)
        self.img[:] = base

    def mix(self, mask, color, amount=1.0):
        m = (np.clip(mask, 0, 1) * amount)[..., None]
        self.img = self.img * (1 - m) + np.asarray(color, np.float32) * m

    def px(self, x, y, color):
        self.img[y % self.n, x % self.n] = color

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.px(x, y, color)

    def hline(self, y, color, x0=0, x1=None, every=None):
        x1 = self.n if x1 is None else x1
        ys = [y] if every is None else range(y % every, self.n, every)
        for yy in ys:
            self.img[yy % self.n, x0:x1] = color

    def vline(self, x, color, y0=0, y1=None, every=None):
        y1 = self.n if y1 is None else y1
        xs = [x] if every is None else range(x % every, self.n, every)
        for xx in xs:
            self.img[y0:y1, xx % self.n] = color

    def shade(self, factor):
        self.img = np.clip(self.img * factor[..., None], 0, 1)

    def to_image(self, colors):
        arr = (np.clip(self.img, 0, 1) * 255 + 0.5).astype(np.uint8)
        im = Image.fromarray(arr, "RGB")
        q = im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        return q.convert("RGB")


def bottom_dirt(cv, rng, color, rows_frac=0.34, strength=0.7, blotch=0.5):
    """이미지 아래쪽(지면)으로 갈수록 때가 낀다. 경계는 노이즈로 들쭉날쭉."""
    n = cv.n
    yy = np.arange(n, dtype=np.float32)[:, None] / (n - 1)
    edge = 1.0 - rows_frac
    wob = (fbm(rng, n, (3, 6)) - 0.5) * blotch
    t = np.clip((yy - edge + wob) / rows_frac, 0, 1)
    cv.mix(steps(t, 5), color, strength)


def streaks(cv, rng, count, colors, lmin, lmax, top_bias=False, width=1, y_from=None):
    """위에서 아래로 흐르는 녹물·물때 줄기. 끝에 물방울 한 픽셀."""
    n = cv.n
    for _ in range(count):
        x = int(rng.integers(0, n))
        y0 = int(rng.integers(0, n // 2)) if top_bias else int(rng.integers(0, n))
        if y_from is not None:
            y0 = int(y_from)
        length = int(rng.integers(lmin, lmax + 1))
        col = colors[int(rng.integers(0, len(colors)))]
        wob = 0
        for i in range(length):
            if rng.random() < 0.12:
                wob += int(rng.integers(-1, 2))
            for w in range(width):
                fade = 1.0 - 0.5 * i / max(length, 1)
                cur = cv.img[(y0 + i) % n, (x + wob + w) % n]
                cv.img[(y0 + i) % n, (x + wob + w) % n] = cur * (1 - fade) + col * fade
        cv.px(x + wob, y0 + length, col * 0.8)


def chips(cv, rng, count, colors, weight=None, size=(1, 3)):
    """벗겨진 페인트 조각 (불규칙한 작은 덩어리). weight는 n x n 확률 분포(선택)."""
    n = cv.n
    if weight is not None:
        p = (weight / weight.sum()).ravel()
        idx = rng.choice(n * n, size=count, p=p)
    else:
        idx = rng.integers(0, n * n, size=count)
    for k in idx:
        y, x = divmod(int(k), n)
        w = int(rng.integers(size[0], size[1] + 1))
        h = int(rng.integers(size[0], size[1] + 1))
        col = colors[int(rng.integers(0, len(colors)))]
        for dy in range(h):
            for dx in range(w):
                if rng.random() < 0.78:
                    cv.px(x + dx, y + dy, col)


def speckle(cv, rng, density, color, jitter=0.0):
    m = (rng.random((cv.n, cv.n)) < density).astype(np.float32)
    cv.mix(m, color, 1.0)


def walk(cv, rng, start, steps_n, color, bias=(0, 1), branch=0.0, depth=0):
    """균열: 한 픽셀 폭 무작위 걷기."""
    x, y = start
    for _ in range(steps_n):
        cv.px(x, y, color)
        r = rng.random()
        if r < 0.5:
            x += bias[0]
            y += bias[1]
        elif r < 0.75:
            x += int(rng.choice([-1, 1]))
            y += bias[1]
        else:
            x += bias[0] + int(rng.choice([-1, 1])) * (1 if bias[0] == 0 else 0)
            y += bias[1] if bias[1] else int(rng.choice([-1, 1]))
        if depth < 2 and rng.random() < branch:
            walk(cv, rng, (x, y), steps_n // 3, color, (int(rng.choice([-1, 1])), 1), 0.0, depth + 1)


# ---------------------------------------------------------------- 텍스처

def make_concrete():
    n = 64
    rng = rng_for("concrete")
    dark, light = hexc("4a535e"), hexc("6b7681")
    cv = Canvas(n, dark)
    t = steps(fbm(rng, n, (3, 7, 14), (0.5, 0.3, 0.2)), 4)
    cv.mix(t, light)
    speckle(cv, rng, 0.05, hexc("7c8791"))
    speckle(cv, rng, 0.05, hexc("3f4852"))
    # 패널 이음매 (2 m 간격): 어두운 줄 + 아래 반사 하이라이트
    seam, hi = hexc("2f363f"), hexc("7d8892")
    for s in (0, 32):
        cv.hline(s, seam)
        cv.hline(s + 1, hi * 0.92)
        cv.vline(s, seam)
        cv.vline(s + 1, hi * 0.92)
    # 볼트 구멍
    for bx in (6, 26, 38, 58):
        for by in (6, 26, 38, 58):
            cv.px(bx, by, hexc("2a3038"))
            cv.px(bx + 1, by, hexc("55606b"))
    # 이음매 아래 물때 줄기
    streaks(cv, rng, 9, [hexc("424a54"), hexc("39414a")], 5, 16, y_from=None)
    # 모서리 깨짐: 철근 녹이 드러남
    for cx, cy in ((3, 3), (35, 3), (3, 35), (35, 35)):
        if rng.random() < 0.8:
            chips(cv, rng, 2, [hexc("6c4a3a"), hexc("533a30"), hexc("2f363f")], size=(1, 2))
            cv.px(cx, cy, hexc("7a4f3a"))
    bottom_dirt(cv, rng, hexc("463f3a"), 0.3, 0.75)
    return cv.to_image(18)


def make_asphalt():
    n = 64
    rng = rng_for("asphalt")
    cv = Canvas(n, hexc("323a43"))
    cv.mix(steps(fbm(rng, n, (3, 6, 12), (0.5, 0.3, 0.2)), 4), hexc("464f59"), 0.8)
    speckle(cv, rng, 0.05, hexc("4c5560"))
    speckle(cv, rng, 0.04, hexc("2a3038"))
    # 보수 패치 두 장 (약간 다른 톤) + 가장자리 선
    cv.rect(6, 38, 26, 52, hexc("2a3138"))
    cv.hline(38, hexc("1d2228"), 6, 26)
    cv.hline(51, hexc("1d2228"), 6, 26)
    cv.vline(6, hexc("1d2228"), 38, 52)
    cv.vline(25, hexc("1d2228"), 38, 52)
    cv.rect(40, 8, 58, 20, hexc("3c4550"))
    cv.hline(8, hexc("232930"), 40, 58)
    cv.hline(19, hexc("232930"), 40, 58)
    # 균열
    walk(cv, rng, (12, 2), 30, hexc("171b20"), (0, 1), 0.06)
    walk(cv, rng, (50, 30), 24, hexc("171b20"), (1, 0), 0.05)
    walk(cv, rng, (30, 20), 18, hexc("1c2127"), (1, 1), 0.04)
    # 기름 얼룩
    oil = steps(np.clip(vnoise(rng, n, 5) - 0.62, 0, 1) * 5, 3)
    cv.mix(oil, hexc("1b2026"), 0.9)
    return cv.to_image(14)


def make_lane():
    n = 32
    rng = rng_for("lane")
    cv = Canvas(n, hexc("a8a698"))
    cv.mix(steps(fbm(rng, n, (3, 6)), 3), hexc("8f8d80"), 0.8)
    speckle(cv, rng, 0.06, hexc("bdbaa9"))
    # 벗겨져 아스팔트가 비치는 곳
    wear = steps(np.clip(fbm(rng, n, (4, 9), (0.5, 0.5)) - 0.5, 0, 1) * 2.6, 3)
    cv.mix(wear, hexc("3a4149"), 0.95)
    chips(cv, rng, 10, [hexc("3a4149"), hexc("4a525a")], size=(1, 2))
    bottom_dirt(cv, rng, hexc("55524a"), 0.3, 0.6)
    return cv.to_image(12)


def make_brick():
    n = 64
    rng = rng_for("brick")
    cv = Canvas(n, hexc("3b3834"))
    palette = [hexc(c) for c in ("6b4a3f", "5d4339", "4f3d38", "705548", "58524d", "4b4f57", "66463a")]
    bw, bh = 8, 4
    for row in range(n // bh):
        off = (row % 2) * (bw // 2)
        for col in range(n // bw + 1):
            x0 = col * bw - off
            base = palette[int(rng.integers(0, len(palette)))]
            shade = 0.9 + 0.2 * rng.random()
            for dy in range(1, bh):
                for dx in range(1, bw):
                    f = shade * (1.1 if dy == 1 else (0.86 if dy == bh - 1 else 1.0))
                    cv.px(x0 + dx, row * bh + dy, np.clip(base * f, 0, 1))
            if rng.random() < 0.04:  # 빠진 벽돌 / 너무 시커먼 벽돌
                cv.rect(x0 + 1, row * bh + 1, x0 + bw, row * bh + bh, hexc("2a2825"))
    # 줄눈 하이라이트 얇게: 벽돌 사이 줄은 어둡게 (이미 base)
    speckle(cv, rng, 0.05, hexc("7a6a5c"))
    speckle(cv, rng, 0.05, hexc("302c29"))
    # 백화(흰 석회) 줄기와 그을음
    streaks(cv, rng, 5, [hexc("86857b"), hexc("77766c")], 6, 18, top_bias=True)
    streaks(cv, rng, 8, [hexc("2d2a28"), hexc("353230")], 8, 22, top_bias=True)
    bottom_dirt(cv, rng, hexc("2f2b28"), 0.28, 0.75)
    return cv.to_image(22)


def _corrugated(name, base_hex, hi_hex, dark_hex, rust_hexes):
    n = 64
    rng = rng_for(name)
    base, hi, dk = hexc(base_hex), hexc(hi_hex), hexc(dark_hex)
    cv = Canvas(n, base)
    for x in range(n):
        k = x % 4
        col = (hi, base, base, dk)[k]
        cv.vline(x, col)
    # 바랜 도장: 위쪽이 더 밝게 날아감
    bleach = steps(fbm(rng, n, (2, 5)), 3)
    yy = (1.0 - np.arange(n, dtype=np.float32) / (n - 1))[:, None]
    cv.mix(bleach * yy * 0.9, hi * 1.12, 0.55)
    speckle(cv, rng, 0.04, hi * 1.1)
    speckle(cv, rng, 0.05, dk * 0.85)
    rust = [hexc(h) for h in rust_hexes]
    # 벗겨진 도장: 아래·리브 하이라이트 쪽에 몰린다
    w = np.tile((np.arange(n) % 4 == 0).astype(np.float32), (n, 1)) * 0.6 + 0.4
    w = w * (0.35 + 0.9 * (np.arange(n, dtype=np.float32)[:, None] / n) ** 2)
    chips(cv, rng, 34, rust, weight=w, size=(1, 3))
    # 녹물 줄기와 물방울
    streaks(cv, rng, 11, rust[:2], 8, 30, top_bias=True)
    streaks(cv, rng, 4, [rust[-1]], 4, 12)
    bottom_dirt(cv, rng, hexc("3a2f29"), 0.28, 0.7)
    return cv.to_image(22)


def make_corrugated_red():
    return _corrugated("corrugated_red", "88493e", "9e5c4c", "6a382f", ("8a5030", "6e3d27", "4d3226"))


def make_corrugated_slate():
    return _corrugated("corrugated_slate", "5a6a70", "6e8086", "47565c", ("7e5232", "5f3f2b", "46342b"))


def _door(name, base_hex, hi_hex, dark_hex, rust_hexes):
    n = 64
    rng = rng_for(name)
    base, hi, dk = hexc(base_hex), hexc(hi_hex), hexc(dark_hex)
    cv = Canvas(n, base)
    # 굵은 세로 리브: 8 px 주기 [홈, 하이라이트, 면 x4, 그림자, 홈]
    pat = [dk * 0.7, hi, base, base, base, base, dk, dk * 0.75]
    for x in range(n):
        cv.vline(x, pat[x % 8])
    # 가로 보강띠(1 m 간격 아래위 + 가운데)와 리벳
    for y in (0, 32):
        cv.hline(y, dk * 0.65)
        cv.hline(y + 1, hi * 0.95)
        cv.hline(y + 2, dk * 0.85)
    for x in range(2, n, 8):
        for y in (4, 28, 36, 60):
            cv.px(x, y, hi * 0.9)
    # 잠금 막대 자리: 16 px 간격 어두운 세로 줄 + 손잡이
    for x in (7, 23, 39, 55):
        cv.vline(x, hexc("2b2e32"))
        cv.px(x + 1, 28, hexc("55595e"))
        cv.px(x + 1, 29, hexc("55595e"))
    # 번호 스텐실 비슷한 바랜 글자 블록
    for i, bx in enumerate(range(10, 30, 4)):
        if i % 2 == 0:
            cv.rect(bx, 12, bx + 2, 18, hi * 1.25)
        else:
            cv.rect(bx, 12, bx + 3, 14, hi * 1.25)
            cv.rect(bx, 16, bx + 3, 18, hi * 1.25)
    speckle(cv, rng, 0.05, dk * 0.8)
    rust = [hexc(h) for h in rust_hexes]
    w = 0.3 + 0.9 * (np.arange(n, dtype=np.float32)[:, None] / n) ** 2 * np.ones((1, n), np.float32)
    chips(cv, rng, 30, rust, weight=w, size=(1, 3))
    streaks(cv, rng, 10, rust[:2], 8, 28, top_bias=True)
    bottom_dirt(cv, rng, hexc("3a2f29"), 0.25, 0.7)
    return cv.to_image(22)


def make_door_red():
    return _door("door_red", "7f4136", "9b5545", "5c2e28", ("8a5030", "6e3d27", "4d3226"))


def make_door_slate():
    return _door("door_slate", "485e6a", "5d7886", "36484f", ("7e5232", "5f3f2b", "46342b"))


def make_steel():
    n = 32
    rng = rng_for("steel")
    cv = Canvas(n, hexc("565f69"))
    cv.mix(steps(fbm(rng, n, (3, 7)), 4), hexc("6c7782"), 0.9)
    speckle(cv, rng, 0.06, hexc("7b8691"))
    speckle(cv, rng, 0.06, hexc("424a53"))
    for s in (0, 16):
        cv.hline(s, hexc("2b3138"))
        cv.hline(s + 1, hexc("79848f"))
        cv.vline(s, hexc("2b3138"))
        cv.vline(s + 1, hexc("79848f"))
    for bx in (3, 13, 19, 29):
        for by in (3, 13, 19, 29):
            cv.px(bx, by, hexc("353c44"))
            cv.px(bx + 1, by, hexc("8a95a0"))
    # 긁힘
    for _ in range(5):
        x, y = int(rng.integers(0, n)), int(rng.integers(0, n))
        for i in range(int(rng.integers(3, 8))):
            cv.px(x + i, y + i // 2, hexc("8d98a3"))
    # 이음매의 녹
    rust = [hexc("7a4b32"), hexc("5e3b29"), hexc("8d5a38")]
    streaks(cv, rng, 6, rust[:2], 4, 12)
    chips(cv, rng, 9, rust, size=(1, 2))
    bottom_dirt(cv, rng, hexc("3b3834"), 0.3, 0.7)
    return cv.to_image(16)


def make_rust():
    n = 32
    rng = rng_for("rust")
    cv = Canvas(n, hexc("7c4630"))
    cv.mix(steps(fbm(rng, n, (3, 6, 11), (0.5, 0.3, 0.2)), 5), hexc("a46a40"), 0.85)
    cv.mix(steps(np.clip(vnoise(rng, n, 5) - 0.45, 0, 1) * 2, 3), hexc("43291f"), 0.9)
    speckle(cv, rng, 0.08, hexc("b9804e"))
    speckle(cv, rng, 0.07, hexc("32211a"))
    cv.hline(0, hexc("2e211b"))
    cv.vline(0, hexc("2e211b"))
    cv.hline(16, hexc("2e211b"))
    cv.vline(16, hexc("2e211b"))
    streaks(cv, rng, 5, [hexc("4a2d21"), hexc("5e3a28")], 5, 14)
    return cv.to_image(14)


def make_wood():
    n = 32
    rng = rng_for("wood")
    cv = Canvas(n, hexc("5e4d3b"))
    plank = [hexc(c) for c in ("6d5a45", "5e4d3b", "746049", "574638", "665544")]
    ph = 4
    for row in range(n // ph):
        base = plank[int(rng.integers(0, len(plank)))]
        joint = int(rng.integers(4, n - 4))
        for dy in range(ph):
            for x in range(n):
                f = 1.08 if dy == 1 else (0.84 if dy == 0 else (0.92 if dy == ph - 1 else 1.0))
                cv.px(x, row * ph + dy, np.clip(base * f, 0, 1))
        cv.vline(joint, hexc("2f261e"), row * ph, row * ph + ph)
        cv.px(joint + 2, row * ph + 1, hexc("8a8274"))
        cv.px(joint - 2, row * ph + 1, hexc("8a8274"))
        # 결 줄무늬
        for _ in range(3):
            x = int(rng.integers(0, n))
            ln = int(rng.integers(3, 10))
            for i in range(ln):
                cv.px(x + i, row * ph + int(rng.integers(1, ph)), base * 0.78)
        if rng.random() < 0.3:
            kx = int(rng.integers(2, n - 3))
            cv.rect(kx, row * ph + 1, kx + 2, row * ph + 3, hexc("2f261e"))
    # 회색으로 바랜 얼룩
    cv.mix(steps(np.clip(fbm(rng, n, (3, 6)) - 0.5, 0, 1) * 2.2, 3), hexc("7d776b"), 0.5)
    speckle(cv, rng, 0.04, hexc("8a8274"))
    bottom_dirt(cv, rng, hexc("3a3029"), 0.25, 0.6)
    return cv.to_image(16)


def make_paint():
    n = 32
    rng = rng_for("paint")
    cv = Canvas(n, hexc("b2b4b0"))
    cv.mix(steps(fbm(rng, n, (3, 6)), 3), hexc("9b9d9a"), 0.8)
    cv.mix(steps(fbm(rng, n, (2, 4)), 3), hexc("c6c7c2"), 0.45)
    speckle(cv, rng, 0.05, hexc("8a8c89"))
    for s in (0, 16):
        cv.hline(s, hexc("6d6f6d"))
        cv.vline(s, hexc("6d6f6d"))
    rust = [hexc("6e4630"), hexc("55392a"), hexc("3f2f27")]
    w = 0.3 + (np.arange(n, dtype=np.float32)[:, None] / n) ** 2 * np.ones((1, n), np.float32)
    chips(cv, rng, 22, rust, weight=w, size=(1, 2))
    streaks(cv, rng, 5, rust[:2], 5, 14, top_bias=True)
    bottom_dirt(cv, rng, hexc("57524b"), 0.3, 0.7)
    return cv.to_image(16)


def make_hazard():
    n = 32
    rng = rng_for("hazard")
    amber, char = hexc("b08a38"), hexc("2d2f33")
    cv = Canvas(n, char)
    xx, yy = np.meshgrid(np.arange(n), np.arange(n))
    stripe = (((xx + yy) // 4) % 2).astype(np.float32)
    cv.mix(stripe, amber)
    speckle(cv, rng, 0.07, hexc("c9a24c") * 0.9)
    speckle(cv, rng, 0.06, hexc("1e2024"))
    chips(cv, rng, 16, [hexc("5c5f62"), hexc("3a3d41")], size=(1, 2))
    bottom_dirt(cv, rng, hexc("46433c"), 0.3, 0.65)
    return cv.to_image(12)


def make_window():
    n = 32
    rng = rng_for("window")
    top, bot = hexc("3b4c61"), hexc("1f2730")
    cv = Canvas(n, bot)
    t = (np.arange(n, dtype=np.float32) / (n - 1))[:, None] * np.ones((1, n), np.float32)
    cv.mix(steps(1.0 - t, 6), top)
    # 대각 반사 띠
    xx, yy = np.meshgrid(np.arange(n), np.arange(n))
    d = ((xx - yy) % n)
    cv.mix(((d >= 9) & (d < 12)).astype(np.float32), hexc("56687e"), 0.7)
    cv.mix(((d >= 15) & (d < 16)).astype(np.float32), hexc("4a5b70"), 0.6)
    speckle(cv, rng, 0.05, hexc("2a3340"))
    streaks(cv, rng, 6, [hexc("2c353f"), hexc("252d36")], 6, 20, top_bias=True)
    bottom_dirt(cv, rng, hexc("2a2a2a"), 0.25, 0.5)
    return cv.to_image(12)


def make_window_lit():
    n = 32
    rng = rng_for("window_lit")
    cv = Canvas(n, hexc("7a4d2c"))
    t = (np.arange(n, dtype=np.float32) / (n - 1))[:, None] * np.ones((1, n), np.float32)
    cv.mix(steps(1.0 - t * 0.9, 6), hexc("d4a65a"))
    cv.mix(steps(np.clip(1.0 - 2.6 * t, 0, 1), 4), hexc("ead9a0"), 0.7)
    speckle(cv, rng, 0.06, hexc("a1713d"))
    streaks(cv, rng, 4, [hexc("8b5c33"), hexc("73492a")], 5, 14, top_bias=True)
    bottom_dirt(cv, rng, hexc("4d3320"), 0.25, 0.55)
    return cv.to_image(12)


TEXTURES = {
    "concrete": make_concrete,
    "asphalt": make_asphalt,
    "lane": make_lane,
    "brick": make_brick,
    "corrugated_red": make_corrugated_red,
    "corrugated_slate": make_corrugated_slate,
    "door_red": make_door_red,
    "door_slate": make_door_slate,
    "steel": make_steel,
    "rust": make_rust,
    "wood": make_wood,
    "paint": make_paint,
    "hazard": make_hazard,
    "window": make_window,
    "window_lit": make_window_lit,
}


# ---------------------------------------------------------------- 가져오기 설정

IMPORT_PARAMS = {
    "compress/mode": "0",             # 무손실: 픽셀이 뭉개지지 않게 (텍스처가 작아 용량은 문제 없음)
    "compress/high_quality": "false",
    "mipmaps/generate": "true",       # 재질이 NEAREST_WITH_MIPMAPS: 멀리서 반짝임만 줄이고, 가까이는 칸이 그대로 보인다
    "process/fix_alpha_border": "false",
    "detect_3d/compress_to": "0",     # 3D에서 쓰인다고 자동으로 VRAM 압축으로 바꾸지 않는다
}


def patch_imports():
    changed = 0
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".png.import"):
            continue
        path = os.path.join(OUT, fn)
        text = open(path, encoding="utf-8").read()
        lines = text.split("\n")
        seen = set()
        out = []
        for line in lines:
            key = line.split("=")[0]
            if key in IMPORT_PARAMS:
                line = f"{key}={IMPORT_PARAMS[key]}"
                seen.add(key)
            out.append(line)
        if "detect_3d/compress_to" not in seen:
            # [params] 줄 바로 뒤에 끼운다
            idx = out.index("[params]")
            out.insert(idx + 1, f"detect_3d/compress_to={IMPORT_PARAMS['detect_3d/compress_to']}")
        new = "\n".join(out)
        if new != text:
            open(path, "w", encoding="utf-8").write(new)
            changed += 1
    print(f".import {changed}개 수정")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="만들 텍스처 이름 (기본: 전부)")
    ap.add_argument("--preview", help="확대 미리보기 PNG 경로 (저장은 하지 않음)")
    ap.add_argument("--patch-import", action="store_true", help=".import를 픽셀용으로 고친다")
    ap.add_argument("--out", help="출력 폴더 (기본: assets/textures/retro)")
    args = ap.parse_args()
    global OUT
    if args.out:
        OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    if args.patch_import:
        patch_imports()
        return 0
    names = args.only or list(TEXTURES)
    images = []
    total = 0
    for name in names:
        if name not in TEXTURES:
            print("알 수 없는 이름:", name, file=sys.stderr)
            return 2
        im = TEXTURES[name]()
        colors = len(set(im.getdata()))
        images.append((name, im))
        if not args.preview:
            p = os.path.join(OUT, name + ".png")
            im.save(p, "PNG", optimize=True)
            sz = os.path.getsize(p)
            total += sz
            print(f"  {name:18s} {im.size[0]}x{im.size[1]} {colors:2d}색 {sz} B")
        else:
            print(f"  {name:18s} {im.size[0]}x{im.size[1]} {colors:2d}색")
    if args.preview:
        scale = 4
        cell = 128 * scale + 8
        cols = 3
        rows = (len(images) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * cell), (20, 22, 26))
        for i, (_, im) in enumerate(images):
            w, h = im.size
            big = Image.new("RGB", (w * 2, h * 2))
            for ox in (0, w):  # 2x2 타일링으로 이음매 확인
                for oy in (0, h):
                    big.paste(im, (ox, oy))
            big = big.resize((big.size[0] * scale, big.size[1] * scale), Image.NEAREST)
            sheet.paste(big, ((i % cols) * cell + 4, (i // cols) * cell + 4))
        sheet.save(args.preview)
    else:
        print(f"합계 {total / 1024:.1f} KB ({len(names)}장)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
