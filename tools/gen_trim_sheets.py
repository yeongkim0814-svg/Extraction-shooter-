#!/usr/bin/env python3
"""스타일 D("트림시트 스타일라이즈드 PBR") 텍스처를 절차적으로 만든다 (numpy + Pillow, 시드 고정 -> 결정적).

기법 출처: Godot 4 데모 "Abandoned Spaceship" (Perfoon, MIT)의 트림시트 방식을 따른다. 이 스크립트의 텍스처는 직접 그린 것이며
데모의 에셋을 쓰지 않는다. 모든 소품이 같은 텍스처 한 벌(1~2장)을 나눠 쓰고, 페인트 마스크로 소품마다 다른 색을 칠한다.

출력: assets/textures/trim/
  trim1_{albedo,orm,normal,mask}.webp   시트 1: 콘크리트·벽돌 (평벽, 패널, 벽돌 띠, 페인트 띠, 경고 줄무늬, 금속 모서리, 창, 환기구)
  trim2_{albedo,orm,normal,mask}.webp   시트 2: 금속·컨테이너 (골판, 리벳 판, 벗겨진 도장, 녹, 격자 통로, 파이프, 경첩·잠금, 경고 라벨)
  trim_detail.webp                      512 px 이음매 없는 때·얼룩 디테일 (밝은 회색 바탕, 곱하기)
  foliage.webp                          RGBA 담쟁이(왼쪽 절반)·고사리(오른쪽 절반) 알파 카드용
  trim_layout.json                      줄(strip)별 v 범위. scripts/core/geometry/trim_layout.gd와 테스트가 맞춰 본다.

채널 규약
  albedo : sRGB. 페인트가 칠해지는 자리는 옅은 회백색 (셰이더가 paint_color를 곱한다).
  orm    : R = AO, G = 거칠기, B = 금속성 (선형).
  normal : OpenGL(Y+) 법선 (선형).
  mask   : R = 높이, G = 페인트 마스크 (1 = 페인트가 칠한 곳), B = 발광 마스크 (불 켜진 유리).

시트 1024 x 1024에 가로 띠(줄)가 쌓인다. U는 가로로 이어 붙게 주기적이다 (4 m = 1024 px = 256 px/m).
줄 위아래 가장자리에는 닳은 하이라이트와 AO가 구워져 있어 모따기에 면이 닿는 자리가 또렷하다.
줄 사이 4 px 여백은 가장자리 줄을 복제해 밉맵 번짐을 줄인다.

사용법: python3 tools/gen_trim_sheets.py [--preview 경로.png] [--patch-import]
"""
import argparse
import json
import os
import zlib

import numpy as np
from PIL import Image, ImageDraw

W = 1024
GUTTER = 4
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "trim")

SHEET1 = [("wall", 176), ("panel", 188), ("brick", 156), ("band", 88), ("hazard", 64), ("edge_trim", 48),
          ("window", 144), ("vent", 96)]
SHEET2 = [("corrugated", 184), ("plate", 152), ("chipped", 128), ("rust", 112), ("grate", 128), ("pipe", 96),
          ("hinge", 96), ("label", 64)]


# ---------------------------------------------------------------- 도구

def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()) & 0xFFFFFFFF)


def c(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fnoise(rng, h, w, sx, sy=None):
    """주기적 가우시안 저역 노이즈 (표준편차 1). sx, sy = 가로·세로 블러 반지름 (px)."""
    sy = sx if sy is None else sy
    n = rng.standard_normal((h, w)).astype(np.float32)
    fx = np.fft.fftfreq(w)[None, :]
    fy = np.fft.fftfreq(h)[:, None]
    g = np.exp(-2.0 * np.pi ** 2 * ((fx * sx) ** 2 + (fy * sy) ** 2))
    o = np.fft.ifft2(np.fft.fft2(n) * g).real
    return ((o - o.mean()) / (o.std() + 1e-9)).astype(np.float32)


def fbm(rng, h, w, sigmas, weights=None):
    weights = weights or [1.0] * len(sigmas)
    acc = np.zeros((h, w), np.float32)
    for s, wt in zip(sigmas, weights):
        acc += wt * fnoise(rng, h, w, s)
    return acc / np.sqrt(sum(x * x for x in weights))


def blur(a, px):
    """가로 주기, 세로 반사 경계 가우시안 블러."""
    h = a.shape[0]
    pad = int(px * 3) + 2
    ext = np.concatenate([a[pad:0:-1], a, a[-2:-pad - 2:-1]], axis=0) if pad < h else a
    fx = np.fft.fftfreq(a.shape[1])[None, :]
    fy = np.fft.fftfreq(ext.shape[0])[:, None]
    g = np.exp(-2.0 * np.pi ** 2 * ((fx * px) ** 2 + (fy * px) ** 2))
    o = np.fft.ifft2(np.fft.fft2(ext) * g).real.astype(np.float32)
    return o[pad:pad + h] if pad < h else o


def normal_from_height(hgt, strength):
    """높이 -> 법선 (OpenGL Y+). 가로 주기, 세로는 가장자리 복제."""
    hb = blur(hgt, 0.8)
    dx = (np.roll(hb, -1, axis=1) - np.roll(hb, 1, axis=1)) * 0.5
    up = np.vstack([hb[:1], hb[:-1]])
    dn = np.vstack([hb[1:], hb[-1:]])
    dy = (dn - up) * 0.5
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(hb)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx * inv, ny * inv, nz * inv], axis=-1) * 0.5 + 0.5


class Strip:
    """한 줄: 알베도·거칠기·금속성·높이·페인트·발광 맵 (세로 h px, 가로 W px)."""

    def __init__(self, name, h, base, rough=0.8, metal=0.0):
        self.name = name
        self.h = h
        self.rng = rng_for("trim_" + name)
        self.alb = np.tile(np.asarray(base, np.float32), (h, W, 1))
        self.rough = np.full((h, W), rough, np.float32)
        self.metal = np.full((h, W), metal, np.float32)
        self.hgt = np.full((h, W), 0.5, np.float32)
        self.paint = np.zeros((h, W), np.float32)
        self.emit = np.zeros((h, W), np.float32)
        self.ao = np.ones((h, W), np.float32)
        self.nstrength = 3.0
        self.Y, self.X = np.mgrid[0:h, 0:W].astype(np.float32)

    def noise(self, sx, sy=None):
        return fnoise(self.rng, self.h, W, sx, sy)

    def fbm(self, sigmas, weights=None):
        return fbm(self.rng, self.h, W, sigmas, weights)

    def tone(self, amount, sigmas=(90, 30), weights=(1.0, 0.5)):
        """알베도 전체에 저주파 명암 얼룩 (면이 단조롭지 않게)."""
        n = self.fbm(list(sigmas), list(weights))
        self.alb *= (1.0 + amount * n)[..., None]

    def stains_down(self, amount, length=40.0, density=0.5):
        """위에서 아래로 흘러내린 얼룩 (세로로 늘어진 노이즈)."""
        n = self.noise(5.0, length)
        m = smooth(n, 0.4 + (1.0 - density) * 0.6, 1.6)
        fall = smooth(self.Y / self.h, 0.0, 0.5) * 0.4 + 0.6
        self.alb *= (1.0 - amount * m * fall)[..., None]
        self.rough += 0.05 * m


def paint_set(s, pale, mask):
    """mask 자리를 페인트(옅은 회백색)로 칠한다. 아래 알베도는 mask 밖에 남는다."""
    s.alb = s.alb * (1.0 - mask[..., None]) + np.asarray(pale, np.float32) * mask[..., None]
    s.paint = np.maximum(s.paint, mask)


# ---------------------------------------------------------------- 시트 1: 콘크리트·벽돌

CONC = c(128, 124, 116)
CONC_DK = c(92, 90, 86)
PALE = c(205, 203, 196)  # 페인트 옅은 바탕 (곱해지는 색을 거의 그대로 보여 준다)


def strip_wall(h):
    s = Strip("wall", h, CONC, 0.88)
    s.tone(0.12)
    # 거푸집 자국(타이 홀) 두 줄
    for cx in range(64, W, 256):
        for cy in (h * 0.27, h * 0.73):
            d = np.hypot(s.X - cx, s.Y - cy)
            hole = 1.0 - smooth(d, 5.0, 8.0)
            rim = smooth(d, 6.0, 9.0) * (1.0 - smooth(d, 9.0, 13.0))
            s.hgt += 0.12 * rim - 0.40 * hole
            s.alb *= (1.0 - 0.45 * hole - 0.07 * rim)[..., None]
    # 기공
    pores = smooth(s.noise(1.1), 1.7, 2.6)
    s.hgt -= 0.18 * pores
    s.alb *= (1.0 - 0.18 * pores)[..., None]
    s.stains_down(0.20, 45.0, 0.5)
    s.hgt += 0.04 * s.fbm([6, 2])
    return s


def strip_panel(h):
    s = Strip("panel", h, CONC, 0.86)
    s.tone(0.10)
    xm = np.mod(s.X, 512.0)
    dx = np.minimum(xm, 512.0 - xm)
    groove = 1.0 - smooth(dx, 2.0, 5.5)
    s.hgt = 0.62 * smooth(dx, 0.0, 14.0) + 0.18 + 0.03 * s.fbm([8, 3])
    s.hgt -= 0.45 * groove
    s.ao *= 1.0 - 0.55 * (1.0 - smooth(dx, 0.0, 22.0))
    s.alb *= (1.0 - 0.45 * groove)[..., None]
    # 패널마다 색조 차이
    idx = np.floor(s.X / 512.0)
    s.alb *= (1.0 + 0.05 * np.where(idx % 2 == 0, 1.0, -1.0))[..., None]
    # 이음 위 볼트 판 (패널 이음마다 네 개)
    for sx in (0, 512):
        for by in (h * 0.2, h * 0.8):
            for ox in (-1, 1):
                for oy in (-1, 1):
                    px = sx + ox * 22
                    py = by + oy * 10
                    d = np.minimum(np.hypot(s.X - px, s.Y - py), np.hypot(s.X - (px + W * (1 if px < 100 else 0)), s.Y - py))
                    dm = np.hypot(np.minimum(np.abs(s.X - px), W - np.abs(s.X - px)), s.Y - py)
                    bolt = 1.0 - smooth(dm, 3.5, 5.5)
                    s.hgt += 0.35 * bolt
                    s.alb = s.alb * (1.0 - 0.8 * bolt[..., None]) + CONC_DK * 0.8 * bolt[..., None]
    s.stains_down(0.22, 60.0, 0.45)
    return s


def strip_brick(h):
    s = Strip("brick", h, c(128, 122, 112), 0.9)
    rows, row_h, pitch = 6, 26, 64
    rng = s.rng
    pal = [c(138, 70, 54), c(122, 58, 46), c(150, 84, 64), c(110, 54, 46), c(132, 76, 60)]
    brick_mask = np.zeros((h, W), np.float32)
    dist_edge = np.zeros((h, W), np.float32)
    col = np.tile(c(124, 122, 116), (h, W, 1))
    tone = rng.random((rows, W // pitch + 2))
    pick = rng.integers(0, len(pal), (rows, W // pitch + 2))
    for r in range(rows):
        y0 = r * row_h
        off = (r % 2) * (pitch // 2)
        for ci in range(-1, W // pitch + 1):
            x0 = ci * pitch + off + 2
            x1 = x0 + pitch - 4
            ys = slice(y0 + 1, min(y0 + row_h - 1, h))
            xs = np.arange(x0, x1) % W
            base = pal[pick[r, ci % (W // pitch)]]
            t = 0.88 + 0.22 * tone[r, ci % (W // pitch)]
            col[ys][:, xs] = base * t
            brick_mask[ys][:, xs] = 1.0
            yy = np.arange(ys.start, ys.stop)[:, None]
            xx = np.arange(x0, x1)[None, :]
            de = np.minimum(np.minimum(yy - ys.start, ys.stop - 1 - yy), np.minimum(xx - x0, x1 - 1 - xx))
            dist_edge[ys][:, xs] = de
    s.alb = col
    s.hgt = 0.2 + 0.55 * brick_mask * smooth(dist_edge, 0.0, 3.5) + 0.04 * s.fbm([4, 1.5])
    s.alb *= (1.0 + 0.06 * s.fbm([40, 12]))[..., None]
    s.ao *= 1.0 - 0.5 * (1.0 - brick_mask) * 0.8
    s.rough[:] = np.where(brick_mask > 0.5, 0.82, 0.95)
    # 그을음 얼룩
    s.stains_down(0.25, 50.0, 0.5)
    s.nstrength = 2.6
    return s


def strip_band(h):
    s = Strip("band", h, CONC, 0.88)
    s.tone(0.10)
    # 칠이 벗겨진 곳 (노이즈 문턱) + 아래로 흘러내린 얼룩
    n = s.fbm([36, 12], [1.0, 0.6]) + 0.55 * s.noise(10, 3)
    edge_bias = (smooth(s.Y, 0, 14) * 0 + 0)  # 가장자리에서 더 잘 벗겨짐
    near_edge = 1.0 - smooth(np.minimum(s.Y, h - 1 - s.Y), 0.0, 16.0)
    chip = smooth(n + 1.1 * near_edge + edge_bias - 0.55, 0.9, 1.15)
    paint = 1.0 - chip
    drip = smooth(s.noise(4.0, 35.0), 1.1, 1.8)
    s.rough += 0.0
    paint_set(s, PALE, paint)
    # 페인트 가장자리 두께 (칠이 살짝 올라온 단)
    thick = smooth(blur(paint, 1.5), 0.0, 1.0)
    s.hgt = 0.35 + 0.12 * thick + 0.03 * s.fbm([5, 2])
    s.alb *= (1.0 - 0.10 * drip * paint)[..., None]
    s.alb *= (1.0 + 0.04 * s.fbm([50, 16]))[..., None]
    s.rough = np.where(paint > 0.5, 0.58, 0.9).astype(np.float32)
    # 위아래 몰딩 선
    bead = (1.0 - smooth(np.abs(s.Y - 6.0), 1.5, 4.0)) + (1.0 - smooth(np.abs(s.Y - (h - 7.0)), 1.5, 4.0))
    s.hgt += 0.25 * bead
    s.ao *= 1.0 - 0.22 * bead
    return s


def strip_hazard(h):
    s = Strip("hazard", h, c(30, 30, 30), 0.7)
    period = 64.0
    t = np.mod(s.X + s.Y, period)
    yellow = smooth(t, 30.0, 33.0) * (1.0 - smooth(t, 62.0, 64.0)) + smooth(t, 0.0, 2.0) * 0
    yellow = np.clip(yellow, 0, 1)
    ycol = c(224, 170, 24)
    kcol = c(26, 26, 28)
    s.alb = ycol * yellow[..., None] + kcol * (1.0 - yellow[..., None])
    n = s.fbm([20, 6], [1.0, 0.6])
    wear = smooth(n + 1.2 * (1.0 - smooth(np.minimum(s.Y, h - 1 - s.Y), 0.0, 10.0)) - 0.2, 0.7, 1.4)
    s.alb = s.alb * (1.0 - 0.8 * wear[..., None]) + c(110, 108, 100) * 0.8 * wear[..., None]
    s.alb *= (1.0 - 0.18 * smooth(s.fbm([6, 2]), 0.3, 1.6))[..., None]
    s.rough = (0.55 + 0.35 * wear).astype(np.float32)
    s.hgt = 0.5 + 0.08 * (1.0 - wear) + 0.03 * s.fbm([4, 2])
    s.nstrength = 2.0
    return s


def strip_edge_trim(h):
    s = Strip("edge_trim", h, c(168, 170, 174), 0.42, 0.85)
    prof = np.sin(np.pi * (s.Y + 0.5) / h) ** 0.55
    s.hgt = 0.2 + 0.7 * prof
    scr = smooth(s.noise(90.0, 1.0), 1.0, 2.2)
    s.alb *= (1.0 - 0.22 * scr)[..., None]
    s.alb *= (1.0 - 0.18 * (1.0 - prof))[..., None]
    s.rough += 0.2 * scr
    for cx in range(32, W, 64):
        d = np.hypot(s.X - cx, s.Y - h * 0.5)
        riv = 1.0 - smooth(d, 5.0, 7.0)
        s.hgt += 0.3 * riv
        s.alb *= (1.0 + 0.12 * riv)[..., None]
        ring = smooth(d, 6.0, 8.0) * (1.0 - smooth(d, 8.0, 10.0))
        s.ao *= 1.0 - 0.3 * ring
    s.alb *= (1.0 + 0.06 * s.fbm([60, 8]))[..., None]
    s.nstrength = 2.4
    return s


def strip_window(h):
    s = Strip("window", h, CONC, 0.88)
    s.tone(0.06)
    unit = 256.0
    xm = np.mod(s.X, unit)
    ft, sill, mull = 14.0, 26.0, 10.0
    inner_x0, inner_x1 = ft, unit - ft
    inner_y0, inner_y1 = ft, h - sill
    frame = np.ones((h, W), np.float32)
    # 유리 창 네 칸: 가운데 세로 문설주와 가로 띠
    glass = np.zeros((h, W), np.float32)
    mid_x = unit * 0.5
    mid_y = (inner_y0 + inner_y1) * 0.5
    for gx0, gx1 in ((inner_x0, mid_x - mull * 0.5), (mid_x + mull * 0.5, inner_x1)):
        for gy0, gy1 in ((inner_y0, mid_y - 4.0), (mid_y + 4.0, inner_y1)):
            gm = smooth(xm, gx0 - 0.5, gx0 + 0.5) * (1.0 - smooth(xm, gx1 - 0.5, gx1 + 0.5))
            gm = gm * smooth(s.Y, gy0 - 0.5, gy0 + 0.5) * (1.0 - smooth(s.Y, gy1 - 0.5, gy1 + 0.5))
            glass = np.maximum(glass, gm)
    frame = 1.0 - glass
    # 벽 바탕과 페인트 칠한 틀 (틀은 벽보다 조금 안쪽까지 칠)
    in_win = smooth(xm, 4.0, 6.0) * (1.0 - smooth(xm, unit - 6.0, unit - 4.0)) * smooth(s.Y, 3.0, 5.0)
    paint_zone = in_win * frame * (1.0 - glass)
    paint_set(s, PALE, paint_zone * smooth(s.noise(24, 8) + 2.4, 0.4, 1.4))
    # 유리: 어두운 파랑 + 대각 반사 줄무늬
    sheen = smooth(np.sin((s.X + s.Y * 1.6) * 0.045) * 0.5 + 0.5, 0.78, 0.98) * 0.5
    glass_col = c(14, 22, 30) + c(60, 76, 90) * sheen[..., None]
    grime = smooth(s.Y / h, 0.55, 1.0) * (0.5 + 0.5 * smooth(s.noise(30, 20), -0.5, 1.2))
    glass_col = glass_col * (1.0 - 0.3 * grime[..., None]) + c(52, 54, 50) * 0.3 * grime[..., None]
    s.alb = s.alb * (1.0 - glass[..., None]) + glass_col * glass[..., None]
    s.rough = np.where(glass > 0.5, 0.1 + 0.4 * grime, 0.85).astype(np.float32)
    s.rough = np.where(paint_zone > 0.5, 0.55, s.rough).astype(np.float32)
    s.metal = np.where(glass > 0.5, 0.0, 0.0).astype(np.float32)
    s.emit = (glass * (1.0 - 0.6 * grime)).astype(np.float32)
    s.hgt = 0.62 * in_win + 0.45 * (1.0 - in_win)
    s.hgt = s.hgt * (1.0 - glass) + 0.34 * glass
    s.hgt += 0.03 * s.fbm([5, 2])
    # 창턱: 아래 튀어나온 단
    sillm = in_win * smooth(s.Y, h - sill + 2, h - sill + 5)
    s.hgt += 0.18 * sillm
    s.ao *= 1.0 - 0.4 * glass * (1.0 - smooth(np.minimum(xm - inner_x0, inner_x1 - xm), 0, 8)) * 0.8
    s.stains_down(0.12, 40.0, 0.4)
    s.nstrength = 2.2
    return s


def strip_vent(h):
    s = Strip("vent", h, CONC, 0.88)
    s.tone(0.08)
    unit = 256.0
    xm = np.mod(s.X, unit)
    bx0, bx1, by0, by1 = 28.0, 228.0, 8.0, h - 8.0
    inb = smooth(xm, bx0 - 0.5, bx0 + 0.5) * (1.0 - smooth(xm, bx1 - 0.5, bx1 + 0.5)) * smooth(s.Y, by0 - 0.5, by0 + 0.5) * (
        1.0 - smooth(s.Y, by1 - 0.5, by1 + 0.5))
    frame_w = 9.0
    inner = smooth(xm, bx0 + frame_w - 0.5, bx0 + frame_w + 0.5) * (1.0 - smooth(xm, bx1 - frame_w - 0.5, bx1 - frame_w + 0.5)) * \
        smooth(s.Y, by0 + frame_w - 0.5, by0 + frame_w + 0.5) * (1.0 - smooth(s.Y, by1 - frame_w - 0.5, by1 - frame_w + 0.5))
    frame = inb * (1.0 - inner)
    pitch = 13.0
    t = np.mod(s.Y - by0, pitch) / pitch
    slat = smooth(t, 0.04, 0.12) * (1.0 - smooth(t, 0.62, 0.72))  # 비스듬한 날개
    slat_face = slat * inner
    gap = inner * (1.0 - slat)
    s.alb = s.alb * (1.0 - inb[..., None])
    s.alb += inb[..., None] * 0
    metal_col = c(110, 112, 116)
    s.alb = s.alb + frame[..., None] * PALE + slat_face[..., None] * c(150, 152, 156) + gap[..., None] * c(10, 11, 13)
    s.paint = np.maximum(s.paint, frame)
    s.hgt = 0.45 + 0.35 * frame + 0.18 * slat_face - 0.25 * gap + 0.03 * s.fbm([5, 2])
    s.metal = (0.5 * slat_face).astype(np.float32)
    s.rough = np.where(inb > 0.5, 0.55, 0.88).astype(np.float32)
    s.ao *= 1.0 - 0.6 * gap - 0.25 * (1.0 - smooth(t, 0.5, 0.9)) * slat_face * 0.0
    s.alb *= (1.0 - 0.25 * (1.0 - smooth(s.Y, 0, 30)) * 0)[..., None]
    s.stains_down(0.18, 40.0, 0.5)
    del metal_col
    s.nstrength = 3.0
    return s


# ---------------------------------------------------------------- 시트 2: 금속·컨테이너

STEEL = c(122, 126, 132)
STEEL_DK = c(64, 66, 70)
RUSTC = c(112, 58, 28)


def edge_chips(s, paint, amount, scale=14.0):
    """페인트가 벗겨져 맨 금속이 드러나는 자리 (가장자리·튀어나온 곳일수록 잘 벗겨짐)."""
    return paint


def strip_corrugated(h):
    s = Strip("corrugated", h, STEEL, 0.5, 0.2)
    pitch = 32.0
    xm = np.mod(s.X, pitch) / pitch
    # 사다리꼴 파형: 평평한 능선, 비스듬한 골
    wave = np.clip(1.0 - np.abs(xm * 2.0 - 1.0) * 1.9 + 0.25, 0.0, 1.0)
    wave = smooth(wave, 0.0, 1.0)
    s.hgt = 0.15 + 0.8 * wave
    n = s.fbm([30, 8], [1.0, 0.6])
    ridge = wave
    # 능선 끝에서 벗겨짐, 위아래 가장자리에서 더 많이
    near_edge = 1.0 - smooth(np.minimum(s.Y, h - 1 - s.Y), 0.0, 24.0)
    chip = smooth(n * 0.8 + 0.9 * (ridge - 0.5) + 0.8 * near_edge + 0.2 * s.noise(3.0, 12.0) - 0.55, 1.0, 1.35)
    paint = np.clip(1.0 - chip, 0.0, 1.0)
    s.alb = s.alb * 0.75
    rust = smooth(s.fbm([14, 5]) + 0.7 * chip, 0.2, 1.1) * chip
    s.alb = s.alb * (1.0 - rust[..., None]) + RUSTC * rust[..., None]
    paint_set(s, PALE * 0.98, paint)
    s.alb *= (1.0 - 0.14 * (1.0 - wave) * paint)[..., None]  # 골은 약간 어둡게 (컨테이너의 깊이감)
    s.alb *= (1.0 + 0.05 * s.fbm([80, 40]))[..., None]
    s.stains_down(0.22, 70.0, 0.5)
    s.rough = np.where(paint > 0.5, 0.52, 0.78).astype(np.float32)
    s.metal = (0.12 + 0.5 * (1.0 - paint) * (1.0 - rust)).astype(np.float32)
    s.ao *= 1.0 - 0.38 * (1.0 - wave)
    s.nstrength = 7.5  # 골판은 법선이 세다
    return s


def strip_plate(h):
    s = Strip("plate", h, STEEL, 0.5, 0.25)
    pw = 256.0
    xm = np.mod(s.X, pw)
    dx = np.minimum(xm, pw - xm)
    seam = 1.0 - smooth(dx, 1.5, 4.5)
    hseam = (1.0 - smooth(np.abs(s.Y - h * 0.5), 1.5, 4.5))
    s.hgt = 0.55 + 0.10 * smooth(dx, 4.0, 22.0) - 0.4 * seam - 0.35 * hseam
    s.hgt += 0.05 * s.fbm([40, 14]) + 0.02 * s.fbm([6, 3])
    # 리벳: 이음 양옆에 일정 간격
    rivets = np.zeros_like(s.hgt)
    ring = np.zeros_like(s.hgt)
    for sx in (0, 256, 512, 768):
        for ox in (-12, 12):
            for cy in np.arange(12, h, 28):
                dm = np.hypot(np.minimum(np.abs(s.X - (sx + ox)), W - np.abs(s.X - (sx + ox))), s.Y - cy)
                rivets = np.maximum(rivets, 1.0 - smooth(dm, 4.2, 6.0))
                ring = np.maximum(ring, smooth(dm, 5.0, 7.0) * (1.0 - smooth(dm, 7.0, 10.0)))
    for cx in np.arange(16, W, 32):
        for oy in (-12, 12):
            dm = np.hypot(np.minimum(np.abs(s.X - cx), W - np.abs(s.X - cx)), s.Y - (h * 0.5 + oy))
            rivets = np.maximum(rivets, 1.0 - smooth(dm, 4.2, 6.0))
            ring = np.maximum(ring, smooth(dm, 5.0, 7.0) * (1.0 - smooth(dm, 7.0, 10.0)))
    s.hgt += 0.32 * rivets
    s.ao *= 1.0 - 0.35 * ring - 0.45 * np.maximum(seam, hseam)
    n = s.fbm([26, 9], [1.0, 0.6])
    chip = smooth(n + 1.6 * np.maximum(rivets, 0) * 0.5 + 0.8 * near(h, s) - 0.9, 1.0, 1.4)
    paint = np.clip((1.0 - chip) * (1.0 - 0.85 * np.maximum(seam, hseam) * smooth(s.noise(6, 6), 0.2, 1.0)), 0, 1)
    s.alb = s.alb * 0.7
    rust = smooth(s.fbm([12, 5]) + 0.5, 0.4, 1.2) * (1.0 - paint) * 0.8
    s.alb = s.alb * (1.0 - rust[..., None]) + RUSTC * rust[..., None]
    paint_set(s, PALE, paint)
    s.alb *= (1.0 + rivets * 0.12)[..., None]
    s.alb *= (1.0 - 0.15 * np.maximum(seam, hseam))[..., None]
    s.stains_down(0.18, 50.0, 0.5)
    s.rough = np.where(paint > 0.5, 0.5, 0.74).astype(np.float32)
    s.metal = (0.1 + 0.5 * (1.0 - paint)).astype(np.float32)
    s.nstrength = 4.5
    return s


def near(h, s):
    return 1.0 - smooth(np.minimum(s.Y, h - 1 - s.Y), 0.0, 14.0)


def strip_chipped(h):
    s = Strip("chipped", h, STEEL_DK, 0.6, 0.45)
    n = s.fbm([46, 16], [1.0, 0.7]) + 0.5 * s.fbm([12, 5])
    flake = smooth(n - 0.5, 0.55, 0.75)  # 큰 조각이 벗겨진 곳
    scratch = smooth(s.noise(70.0, 0.9), 1.3, 2.0)  # 가는 긁힘
    drip = smooth(s.noise(3.0, 40.0), 1.2, 2.0)
    paint = np.clip(1.0 - flake - 0.6 * scratch, 0.0, 1.0)
    base_metal = STEEL_DK * (1.0 + 0.25 * s.fbm([20, 6])[..., None])
    rust = smooth(s.fbm([10, 4]) + 0.6, 0.5, 1.3) * (1.0 - paint) * 0.9
    s.alb = base_metal * (1.0 - rust[..., None]) + RUSTC * rust[..., None]
    # 벗겨진 가장자리는 페인트 두께 때문에 올라온 단
    edge = np.clip(blur(paint, 1.3) - paint, 0, 1)
    s.hgt = 0.3 + 0.2 * blur(paint, 1.2) + 0.03 * s.fbm([5, 2])
    paint_set(s, PALE, paint)
    s.alb *= (1.0 - 0.14 * drip * paint)[..., None]
    s.alb *= (1.0 + 0.5 * edge)[..., None] * 0 + 1.0
    s.rough = np.where(paint > 0.5, 0.48, 0.7).astype(np.float32)
    s.metal = (0.08 + 0.6 * (1.0 - paint) * (1.0 - rust)).astype(np.float32)
    s.ao *= 1.0 - 0.3 * edge * 2.0
    s.stains_down(0.14, 50.0, 0.45)
    s.nstrength = 5.0
    return s


def strip_rust(h):
    s = Strip("rust", h, RUSTC, 0.82, 0.12)
    n1 = s.fbm([50, 14], [1.0, 0.8])
    n2 = s.fbm([14, 5])
    n3 = s.noise(1.6)
    patina = smooth(n1, -0.4, 1.0)
    base = c(92, 44, 22) * (1.0 - patina[..., None]) + c(150, 84, 40) * patina[..., None]
    dark = smooth(n2 + 0.2, 0.7, 1.5)
    s.alb = base * (1.0 - 0.45 * dark[..., None])
    pit = smooth(n3, 1.5, 2.3)
    s.alb *= (1.0 - 0.4 * pit)[..., None]
    s.hgt = 0.5 + 0.12 * n2 + 0.18 * patina - 0.25 * pit + 0.03 * n3
    # 남은 도장 쪼가리 (마스크 0, 짙은 회청)
    s.rough = (0.74 + 0.16 * patina).astype(np.float32)
    s.metal = (0.04 + 0.18 * (1.0 - patina)).astype(np.float32)
    # 가로 용접 이음 한 줄
    seam = 1.0 - smooth(np.abs(s.Y - h * 0.5), 2.0, 6.0)
    s.hgt += 0.2 * seam * (0.7 + 0.3 * np.sin(s.X * 0.7))
    s.ao *= 1.0 - 0.25 * seam
    s.stains_down(0.20, 60.0, 0.6)
    s.nstrength = 4.0
    return s


def strip_grate(h):
    s = Strip("grate", h, c(86, 88, 92), 0.55, 0.65)
    pitch = 32.0
    ym = np.mod(s.Y, pitch)
    xm = np.mod(s.X, pitch)
    # 가로로 긴 지지대(두꺼운 띠)와 세로 가로대(가는 봉)
    bearing = 1.0 - smooth(np.abs(ym - pitch * 0.5), 5.0, 6.5)
    cross = 1.0 - smooth(np.abs(xm - pitch * 0.5), 2.0, 3.2)
    bars = np.maximum(bearing, cross * 0.0 + 0.0)
    bars = np.maximum(bearing, cross)
    gap = 1.0 - bars
    s.hgt = 0.15 + 0.7 * bearing + 0.45 * cross * (1.0 - bearing)
    s.hgt -= 0.15 * gap
    s.alb = s.alb * (1.0 + 0.22 * (smooth(np.abs(ym - pitch * 0.5), 0.0, 5.0) * 0 + (1.0 - smooth(np.abs(ym - pitch * 0.5), 0, 5.0))))[..., None]
    s.alb *= (1.0 + 0.25 * s.fbm([20, 8]))[..., None]
    rust = smooth(s.fbm([16, 6]) + 0.3, 0.5, 1.4) * bars
    s.alb = s.alb * (1.0 - 0.6 * rust[..., None]) + RUSTC * 0.6 * rust[..., None]
    s.alb = s.alb * bars[..., None] + c(6, 6, 8) * gap[..., None]
    s.rough = np.where(gap > 0.5, 1.0, 0.55 + 0.3 * rust).astype(np.float32)
    s.metal = (0.7 * bars * (1.0 - rust)).astype(np.float32)
    s.ao *= 1.0 - 0.7 * gap
    s.nstrength = 5.0
    return s


def strip_pipe(h):
    """파이프·원통 감기. U = 축 방향, V = 둘레 (대칭 접힘이므로 위아래가 같은 무늬)."""
    s = Strip("pipe", h, STEEL, 0.5, 0.3)
    sym = np.minimum(s.Y, h - 1 - s.Y)
    # 용접 이음과 플랜지 띠: U 주기 256 px마다 용접, 512 px마다 얇은 죔쇠
    xm = np.mod(s.X, 256.0)
    dx = np.minimum(xm, 256.0 - xm)
    weld = 1.0 - smooth(dx, 2.0, 8.0)
    xm2 = np.mod(s.X, 512.0)
    dx2 = np.minimum(xm2, 512.0 - xm2)
    clamp = 1.0 - smooth(dx2, 10.0, 18.0)
    s.hgt = 0.45 + 0.22 * weld * (0.8 + 0.2 * np.sin(sym * 0.9)) + 0.3 * clamp
    s.hgt += 0.03 * s.fbm([6, 3])
    n = s.fbm([36, 14], [1.0, 0.6])
    chip = smooth(n + 0.5 * weld + 0.3 * clamp - 0.7 + 0.4 * (1.0 - smooth(sym, 0, 20)), 0.9, 1.3)
    paint = np.clip(1.0 - chip, 0, 1)
    s.alb = s.alb * 0.7
    rust = smooth(s.fbm([14, 5]) + 0.4, 0.4, 1.2) * chip
    s.alb = s.alb * (1.0 - rust[..., None]) + RUSTC * rust[..., None]
    paint_set(s, PALE, paint)
    s.alb *= (1.0 - 0.16 * weld * paint - 0.1 * clamp * paint)[..., None]
    s.ao *= 1.0 - 0.3 * weld - 0.2 * clamp
    s.rough = np.where(paint > 0.5, 0.45, 0.72).astype(np.float32)
    s.metal = (0.15 + 0.45 * (1.0 - paint) * (1.0 - rust)).astype(np.float32)
    s.stains_down(0.12, 20.0, 0.4)
    s.nstrength = 3.5
    return s


def strip_hinge(h):
    s = Strip("hinge", h, c(72, 76, 80), 0.5, 0.55)
    s.alb *= (1.0 + 0.2 * s.fbm([30, 10]))[..., None]
    s.hgt = 0.4 + 0.04 * s.fbm([6, 2])
    unit = 512.0
    xm = np.mod(s.X, unit)
    ym = s.Y
    # 잠금 막대 둘: 수직 원통 모양 (밝은 줄기)
    for bx in (150.0, 230.0):
        d = np.abs(xm - bx)
        bar = 1.0 - smooth(d, 10.0, 12.0)
        prof = np.sqrt(np.clip(1.0 - (d / 11.0) ** 2, 0, 1))
        s.hgt = np.maximum(s.hgt, 0.4 + 0.5 * prof * bar)
        s.alb = s.alb * (1.0 - bar[..., None]) + c(150, 152, 156) * (0.65 + 0.35 * prof)[..., None] * bar[..., None]
        s.metal = np.maximum(s.metal, 0.85 * bar)
        s.rough = np.where(bar > 0.5, 0.35, s.rough)
        # 막대를 잡는 걸쇠 (가로 판)
        for cy in (h * 0.2, h * 0.8):
            clasp = (1.0 - smooth(np.abs(xm - bx), 17.0, 19.0)) * (1.0 - smooth(np.abs(ym - cy), 6.0, 8.0))
            s.hgt = np.maximum(s.hgt, 0.4 + 0.45 * clasp)
            s.alb = s.alb * (1.0 - clasp[..., None]) + c(60, 62, 66) * clasp[..., None]
            s.ao *= 1.0 - 0.3 * smooth(clasp, 0.2, 0.9) * 0
    # 경첩 판: 큰 사각 판 + 볼트 + 핀
    for hx in (350.0, 450.0):
        pl = (1.0 - smooth(np.abs(xm - hx), 30.0, 32.0)) * (1.0 - smooth(np.abs(ym - h * 0.5), h * 0.38, h * 0.38 + 2))
        s.hgt = np.maximum(s.hgt, 0.4 + 0.3 * pl)
        s.alb = s.alb * (1.0 - pl[..., None]) + c(52, 54, 58) * pl[..., None]
        for ox in (-20, 20):
            for oy in (-h * 0.22, h * 0.22):
                d = np.hypot(xm - (hx + ox), ym - (h * 0.5 + oy))
                bolt = 1.0 - smooth(d, 5.0, 6.5)
                s.hgt += 0.3 * bolt
                s.alb = s.alb * (1.0 - 0.6 * bolt[..., None]) + c(120, 122, 126) * 0.6 * bolt[..., None]
        pin = (1.0 - smooth(np.abs(xm - hx), 6.0, 8.0)) * (1.0 - smooth(np.abs(ym - h * 0.5), h * 0.3, h * 0.3 + 2))
        s.hgt += 0.3 * pin
        s.alb = s.alb * (1.0 - 0.7 * pin[..., None]) + c(140, 142, 146) * 0.7 * pin[..., None]
    rust = smooth(s.fbm([14, 5]) + 0.3, 0.5, 1.4) * 0.6
    s.alb = s.alb * (1.0 - rust[..., None]) + RUSTC * rust[..., None]
    s.ao *= 1.0 - 0.2 * smooth(s.noise(10, 10), 0.5, 1.5)
    s.stains_down(0.15, 40.0, 0.5)
    s.nstrength = 4.0
    return s


def strip_label(h):
    s = Strip("label", h, STEEL, 0.5, 0.2)
    n = s.fbm([40, 12])
    base_paint = smooth(n + 3.0, 0.5, 1.5)
    paint_set(s, PALE, base_paint)
    s.hgt = 0.5 + 0.03 * s.fbm([5, 2])
    unit = 256.0
    xm = np.mod(s.X, unit)
    ym = s.Y
    # 라벨 판: 흰 바탕 + 검은 테두리 + 노란 삼각 경고 + 글줄
    lx0, lx1, ly0, ly1 = 20.0, 236.0, 8.0, h - 8.0
    inl = smooth(xm, lx0 - 0.5, lx0 + 0.5) * (1.0 - smooth(xm, lx1 - 0.5, lx1 + 0.5)) * smooth(ym, ly0 - 0.5, ly0 + 0.5) * (
        1.0 - smooth(ym, ly1 - 0.5, ly1 + 0.5))
    border = inl * (1.0 - smooth(np.minimum(np.minimum(xm - lx0, lx1 - xm), np.minimum(ym - ly0, ly1 - ym)), 3.0, 4.5))
    face = inl - border
    s.alb = s.alb * (1.0 - inl[..., None]) + c(220, 218, 208) * face[..., None] + c(18, 18, 20) * border[..., None]
    s.paint = s.paint * (1.0 - inl)
    # 삼각 경고 표지
    tcx, tcy = lx0 + 38.0, h * 0.5 + 2.0
    ty = (ym - (tcy - 17.0)) / 34.0
    half = ty * 17.0
    tri = smooth(half - np.abs(xm - tcx), -0.5, 0.5) * smooth(ty, 0.0, 0.02) * (1.0 - smooth(ty, 0.99, 1.0)) * face
    tri_in = smooth(half - 5.0 - np.abs(xm - tcx), -0.5, 0.5) * smooth(ty, 0.22, 0.24) * (1.0 - smooth(ty, 0.84, 0.86)) * face
    bang = (1.0 - smooth(np.abs(xm - tcx), 1.5, 2.5)) * smooth(ym, tcy - 6, tcy - 5) * (1.0 - smooth(ym, tcy + 5, tcy + 6)) * tri_in
    s.alb = s.alb * (1.0 - tri[..., None]) + c(210, 40, 36) * tri[..., None]
    s.alb = s.alb * (1.0 - tri_in[..., None]) + c(226, 222, 212) * tri_in[..., None]
    s.alb = s.alb * (1.0 - bang[..., None]) + c(20, 20, 22) * bang[..., None]
    # 글줄 막대 (읽을 수 없는 문구)
    rg = s.rng
    for k, ly in enumerate((h * 0.3, h * 0.5, h * 0.7)):
        for ux in range(3):
            wd = 8 + 40 * rg.random()
            x0 = lx0 + 76 + 24 * 0 + ux * 0
        bar = (1.0 - smooth(np.abs(ym - ly), 2.0, 3.0)) * smooth(xm, lx0 + 76, lx0 + 77) * (1.0 - smooth(xm, lx1 - 14 - 22 * (k == 1), lx1 - 13 - 22 * (k == 1))) * face
        s.alb = s.alb * (1.0 - 0.8 * bar[..., None]) + c(30, 30, 34) * 0.8 * bar[..., None]
    wear = smooth(s.fbm([12, 5]) + 0.2, 0.9, 1.6) * inl
    s.alb = s.alb * (1.0 - 0.45 * wear[..., None]) + c(120, 112, 98) * 0.45 * wear[..., None]
    s.hgt += 0.12 * inl - 0.1 * border * 0
    s.rough = np.where(inl > 0.5, 0.6, np.where(s.paint > 0.5, 0.5, 0.7)).astype(np.float32)
    s.metal = (0.15 * (1.0 - inl)).astype(np.float32)
    s.ao *= 1.0 - 0.25 * (smooth(np.minimum(np.minimum(xm - lx0, lx1 - xm), np.minimum(ym - ly0, ly1 - ym)), -2, 0.5) -
                           smooth(np.minimum(np.minimum(xm - lx0, lx1 - xm), np.minimum(ym - ly0, ly1 - ym)), 0.5, 4.0)) * 0
    s.stains_down(0.12, 30.0, 0.4)
    s.nstrength = 3.0
    return s


STRIPS1 = {"wall": strip_wall, "panel": strip_panel, "brick": strip_brick, "band": strip_band, "hazard": strip_hazard,
           "edge_trim": strip_edge_trim, "window": strip_window, "vent": strip_vent}
STRIPS2 = {"corrugated": strip_corrugated, "plate": strip_plate, "chipped": strip_chipped, "rust": strip_rust,
           "grate": strip_grate, "pipe": strip_pipe, "hinge": strip_hinge, "label": strip_label}


# ---------------------------------------------------------------- 마무리 (AO·모서리 닳음 굽기)

def finish(s):
    """높이 공동(cavity)에서 AO를, 튀어나온 모서리에서 닳은 하이라이트를, 줄 위아래 가장자리에 하이라이트+AO를 굽는다.
    반환: (albedo, orm, normal, mask) 각 (h, W, 3) 0~1."""
    h = s.h
    hb = blur(s.hgt, 6.0)
    cavity = np.clip((hb - s.hgt) * 3.0, 0.0, 1.0)
    convex = np.clip((s.hgt - blur(s.hgt, 2.0)) * 5.0, 0.0, 1.0)
    ao = s.ao * (1.0 - 0.55 * cavity)
    # 모서리 닳음: 튀어나온 가장자리가 밝아지고 거칠어진다 (페인트가 닳아 맨 금속이 비치는 느낌은 개별 줄이 이미 만든다)
    s.alb = s.alb * (1.0 + 0.30 * convex)[..., None]
    s.rough = np.clip(s.rough + 0.12 * convex, 0.04, 1.0)
    # 줄 가장자리: 바깥 3 px 하이라이트, 안쪽 AO 띠. 모따기에 닿는 자리라 면이 또렷해진다.
    de = np.minimum(s.Y, h - 1 - s.Y)
    rim = 1.0 - smooth(de, 0.0, 3.5)
    band = (1.0 - smooth(de, 3.0, 26.0))
    s.alb = s.alb * (1.0 + 0.28 * rim)[..., None]
    s.rough = np.clip(s.rough + 0.14 * rim, 0.04, 1.0)
    ao = ao * (1.0 - 0.34 * band * (1.0 - 0.6 * rim))
    s.alb = s.alb * (1.0 - 0.10 * band)[..., None]
    normal = normal_from_height(s.hgt, s.nstrength)
    alb = np.clip(s.alb, 0.0, 1.0)
    orm = np.stack([np.clip(ao, 0, 1), np.clip(s.rough, 0.04, 1.0), np.clip(s.metal, 0, 1)], axis=-1)
    mask = np.stack([np.clip(s.hgt, 0, 1), np.clip(s.paint, 0, 1), np.clip(s.emit, 0, 1)], axis=-1)
    return alb, orm, normal, mask


def assemble(strip_table, order, funcs):
    """줄들을 시트에 쌓고 여백을 가장자리 줄 복제로 채운다. 반환: (4개 맵, 레이아웃 dict)."""
    sheets = [np.zeros((W, W, 3), np.float32) for _ in range(4)]
    layout = {}
    y = GUTTER
    for name, h in order:
        maps = finish(funcs[name](h))
        for i in range(4):
            sheets[i][y:y + h] = maps[i]
            sheets[i][y - GUTTER:y] = maps[i][:1]
            sheets[i][y + h:y + h + GUTTER] = maps[i][-1:]
        layout[name] = {"y": y, "h": h, "v0": y / W, "v1": (y + h) / W}
        y += h + GUTTER * 2
    assert y - GUTTER <= W, "줄이 시트(%d)를 넘친다: %d" % (W, y - GUTTER)
    # 마지막에 남는 여백 (있다면) 도 복제
    last_end = y - GUTTER
    if last_end < W:
        for i in range(4):
            sheets[i][last_end:] = sheets[i][last_end - 1:last_end]
    return sheets, layout


# ---------------------------------------------------------------- 디테일·식생

def make_detail():
    """512 px 이음매 없는 때·얼룩. 밝은 회색 바탕 (곱하기용)이라 평균 ~0.85."""
    n = 512
    rng = rng_for("trim_detail")
    big = fnoise(rng, n, n, 70)
    mid = fnoise(rng, n, n, 24)
    fine = fnoise(rng, n, n, 3.0)
    streak = fnoise(rng, n, n, 4.0, 60.0)
    dirt = smooth(0.7 * big + 0.5 * mid + 0.15 * fine, -0.2, 1.6)
    grunge = np.clip(0.15 * dirt + 0.12 * smooth(streak, 0.5, 1.8) + 0.05 * smooth(fine, 0.8, 2.0), 0, 0.5)
    v = 0.98 - grunge
    r = v * (1.0 + 0.0)
    g = v * (0.99 - 0.02 * dirt)
    b = v * (0.97 - 0.05 * dirt)
    return np.clip(np.stack([r, g, b], -1), 0, 1)


def make_foliage():
    """RGBA 512 x 512: 왼쪽 절반 = 담쟁이 줄기, 오른쪽 절반 = 고사리 잎. 4배 슈퍼샘플로 그려 줄인다."""
    ss = 4
    w = 512 * ss
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = rng_for("trim_foliage")

    def leaf_poly(cx, cy, size, ang):
        pts = []
        for i in range(48):
            t = np.pi * 2 * i / 48
            x = 16 * np.sin(t) ** 3
            y = -(13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t))
            pts.append((x, y))
        pts = np.array(pts) * (size / 17.0)
        ca, sa = np.cos(ang), np.sin(ang)
        rot = np.stack([pts[:, 0] * ca - pts[:, 1] * sa, pts[:, 0] * sa + pts[:, 1] * ca], axis=-1)
        return [(cx + p[0], cy + p[1]) for p in rot]

    greens = [(52, 86, 44), (66, 104, 52), (44, 74, 40), (78, 118, 58)]
    # 담쟁이: 줄기는 위에서 아래로 휘는 선, 잎은 줄기 따라 교대
    x = 128.0 * ss
    pts = []
    for i in range(0, 60):
        t = i / 59.0
        pts.append((x + np.sin(t * 5.0) * 34 * ss, (8 + t * 496) * ss))
    d.line(pts, fill=(48, 40, 28, 255), width=3 * ss)
    for i in range(2, 58, 2):
        px, py = pts[i]
        side = 1 if (i // 2) % 2 else -1
        size = (24 + 14 * rng.random()) * ss
        ang = side * (0.6 + 0.5 * rng.random()) + np.pi * 0.0
        col = greens[int(rng.integers(0, len(greens)))]
        poly = leaf_poly(px + side * size * 0.9, py + size * 0.1, size, ang)
        d.polygon(poly, fill=col + (255,))
        # 잎맥
        d.line([(px, py), poly[0]], fill=(30, 52, 28, 255), width=ss)
    for (sx0, sy0, sc) in ((200, 440, 0.8), (60, 300, 0.7), (190, 200, 0.75)):
        for k in range(5):
            size = (16 + 8 * rng.random()) * ss * sc
            col = greens[int(rng.integers(0, len(greens)))]
            d.polygon(leaf_poly((sx0 + 30 * np.cos(k * 1.3)) * ss, (sy0 + 26 * np.sin(k * 1.3)) * ss, size, k * 1.2), fill=col + (255,))
    # 고사리: 휜 중심 줄기 + 양옆 깃 잎
    def frond(base, tip_dx, length, leaflets, width):
        bx, by = base
        pts = []
        for i in range(41):
            t = i / 40.0
            pts.append((bx + tip_dx * (t ** 1.6) * ss, by - t * length * ss))
        d.line(pts, fill=(40, 62, 32, 255), width=2 * ss)
        for k in range(1, leaflets):
            t = k / leaflets
            px, py = pts[int(t * 40)]
            ln = width * (1.0 - t ** 1.3) * ss + 3 * ss
            for sgn in (-1, 1):
                col = greens[int(rng.integers(0, len(greens)))]
                tip = (px + sgn * ln, py - ln * 0.35)
                mid = (px + sgn * ln * 0.5, py - ln * 0.28 + 3 * ss)
                mid2 = (px + sgn * ln * 0.5, py - ln * 0.28 - 3 * ss)
                d.polygon([(px, py), mid2, tip, mid], fill=col + (255,))

    frond((384 * ss, 506 * ss), 14, 470, 22, 62)
    frond((440 * ss, 506 * ss), 50, 420, 20, 54)
    frond((340 * ss, 506 * ss), -36, 430, 20, 54)
    img = img.resize((512, 512), Image.LANCZOS)
    arr = np.array(img)
    # 투명한 곳 RGB를 가까운 불투명 색으로 번지게 한다 (밉맵 가장자리 후광 방지)
    a = arr[..., 3:4].astype(np.float32) / 255.0
    rgb = arr[..., :3].astype(np.float32)
    fill = (rgb * a).sum((0, 1)) / max(a.sum(), 1.0)
    rgb = np.where(a > 0.05, rgb / np.maximum(a, 0.05), fill)
    arr[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------- 저장

def to_u8(a):
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


def save(img, path, lossless):
    if lossless:
        img.save(path, "WEBP", lossless=True, quality=100, method=6, exact=True)
    else:
        img.save(path, "WEBP", quality=90, method=6)


def write_sheet(tag, sheets):
    paths = []
    names = [("albedo", False), ("orm", True), ("normal", True), ("mask", True)]
    for arr, (nm, lossless) in zip(sheets, names):
        p = os.path.join(OUT, f"{tag}_{nm}.webp")
        save(Image.fromarray(to_u8(arr), "RGB"), p, lossless)
        paths.append(p)
    return paths


IMPORT_PARAMS = {"compress/mode": "2", "mipmaps/generate": "true"}


def patch_imports():
    """Godot가 만든 .import의 파라미터를 모바일용으로 고친다 (VRAM 압축 + 밉맵, 법선은 RG 법선 압축)."""
    changed = 0
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".import"):
            continue
        params = dict(IMPORT_PARAMS)
        if "_normal." in fn:
            params["compress/normal_map"] = "1"
        path = os.path.join(OUT, fn)
        text = open(path, encoding="utf-8").read()
        lines = []
        for line in text.split("\n"):
            key = line.split("=")[0]
            if key in params:
                line = f"{key}={params[key]}"
            lines.append(line)
        new = "\n".join(lines)
        if new != text:
            open(path, "w", encoding="utf-8").write(new)
            changed += 1
    print(f".import {changed}개 수정")


def preview(all_sheets, path):
    tiles = []
    for sheets in all_sheets:
        row = [Image.fromarray(to_u8(a), "RGB").resize((512, 512), Image.LANCZOS) for a in sheets]
        tiles.append(row)
    canvas = Image.new("RGB", (512 * 4, 512 * len(tiles)))
    for r, row in enumerate(tiles):
        for k, im in enumerate(row):
            canvas.paste(im, (k * 512, r * 512))
    canvas.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="미리보기 PNG 경로 (저장은 하지 않음)")
    ap.add_argument("--patch-import", action="store_true", help=".import 파라미터를 모바일용으로 고친다")
    ap.add_argument("--out", help="출력 폴더")
    args = ap.parse_args()
    global OUT
    if args.out:
        OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    if args.patch_import:
        patch_imports()
        return 0
    s1, lay1 = assemble(STRIPS1, SHEET1, STRIPS1)
    s2, lay2 = assemble(STRIPS2, SHEET2, STRIPS2)
    if args.preview:
        preview([s1, s2], args.preview)
        return 0
    written = write_sheet("trim1", s1) + write_sheet("trim2", s2)
    det = Image.fromarray(to_u8(make_detail()), "RGB")
    p = os.path.join(OUT, "trim_detail.webp")
    save(det, p, False)
    written.append(p)
    p = os.path.join(OUT, "foliage.webp")
    make_foliage().save(p, "WEBP", quality=88, method=6, exact=True)
    written.append(p)
    p = os.path.join(OUT, "trim_layout.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump({"size": W, "texels_per_m": 256, "sheets": {"1": lay1, "2": lay2}}, f, indent=1)
    written.append(p)
    total = 0
    for p in written:
        sz = os.path.getsize(p)
        total += sz
        print("%8.1f KB  %s" % (sz / 1024.0, os.path.relpath(p, ROOT)))
    print("합계 %.2f MB" % (total / 1048576.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
