#!/usr/bin/env python3
"""텍스처 v2 (docs/ART.md 11장 "아트 바이블 v2")를 절차적으로 만든다 (numpy + Pillow, 시드 고정 -> 결정적).

핵심 규칙: **넓은 면은 조용하게, 디테일은 줄(strip)의 가장자리·이음매에만.**
"면" 줄(wall, panel, plate, beam, band, cabinet, duct 등)은 가운데 60% 높이의 알베도 명도 편차(표준편차/평균)가
QUIET_LIMIT(0.06) 이하여야 한다. 이 스크립트가 줄마다 측정해 출력하고, 하나라도 넘으면 비정상 종료한다.
닳음·때·칩·가장자리 하이라이트·AO 띠는 줄 위아래 바깥 20%에 몬다. 무늬 줄(벽돌, 경고 줄무늬, 창, 셔터 등)은 검사에서 빠지지만
고주파 노이즈 없이 절제한다.

출력: assets/textures/v2/
  t{1,2,3}_{albedo,orm,normal,mask}.webp   트림시트 3장 (T1 구조, T2 금속, T3 설비)
  ground_{asphalt,concrete,gravel}_{albedo,orm,normal}.webp   양 축 주기 1024 px = 4 m 바닥
  detail_v2.webp                           512 px 주기 선형 데이터 (R 6 m 얼룩, G 1.5 m 때, B 잔 점)
  decals.webp / decals.json                1024 RGBA 4 x 4 아틀라스
  kit_layout.json                          줄별 v 범위 + 조용함 지표. scripts/core/geometry/kit_layout.gd와 테스트가 맞춰 본다.

채널 규약 (스타일 D와 같다)
  albedo : sRGB. 페인트가 칠해지는 자리는 옅은 회백색 ~#CDCBC4 (셰이더가 paint_color를 곱한다).
  orm    : R = AO, G = 거칠기, B = 금속성 (선형).
  normal : OpenGL(Y+) 법선 (선형).
  mask   : R = 높이, G = 페인트 마스크 (1 = 페인트가 칠한 곳), B = 발광 마스크.
시트 1024 x 1024, 256 px/m, U는 가로로 주기적 (4 m). 줄 사이 4 px 여백은 가장자리 줄을 복제한다.

사용법: python3 tools/gen_textures_v2.py [--preview 경로.png] [--patch-import] [--out 폴더]
"""
import argparse
import json
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw

W = 1024
GUTTER = 4
QUIET_LIMIT = 0.06
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "v2")

SHEET1 = [("wall", 160), ("panel", 176), ("brick", 144), ("band", 80), ("hazard", 56), ("window", 136),
          ("shutter", 136), ("sill", 48)]
SHEET2 = [("corrugated", 176), ("plate", 144), ("chipped", 120), ("rust", 112), ("grate", 120), ("pipe", 96),
          ("beam", 96), ("tread", 96)]
SHEET3 = [("vent", 128), ("pipe_joint", 96), ("cable", 80), ("cabinet", 160), ("sign", 96), ("fluoro", 64),
          ("door_hw", 128), ("duct", 128)]
# 조용함 검사 대상 ("면" 줄). 나머지는 무늬 줄이라 면제.
SURFACE = {"wall", "panel", "band", "sill", "corrugated", "plate", "beam", "cabinet", "duct"}


# ---------------------------------------------------------------- 도구

def rng_for(name):
    return np.random.default_rng(zlib.crc32(("v2_" + name).encode()) & 0xFFFFFFFF)


def c(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def wrap(dx, period=W):
    """주기 경계에서 가장 짧은 부호 있는 거리."""
    return np.mod(dx + period * 0.5, period) - period * 0.5


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


def pblur(a, px):
    """양 축 주기 가우시안 블러 (바닥용)."""
    fx = np.fft.fftfreq(a.shape[1])[None, :]
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    g = np.exp(-2.0 * np.pi ** 2 * ((fx * px) ** 2 + (fy * px) ** 2))
    return np.fft.ifft2(np.fft.fft2(a) * g).real.astype(np.float32)


def normal_from_height(hgt, strength):
    """높이 -> 법선 (OpenGL Y+). 가로 주기, 세로는 가장자리 복제."""
    hb = blur(hgt, 0.8)
    dx = (np.roll(hb, -1, axis=1) - np.roll(hb, 1, axis=1)) * 0.5
    up = np.vstack([hb[:1], hb[:-1]])
    dn = np.vstack([hb[1:], hb[-1:]])
    dy = (dn - up) * 0.5
    return _pack_normal(dx, dy, strength)


def normal_from_height_2d(hgt, strength):
    """양 축 주기 높이 -> 법선 (OpenGL Y+)."""
    hb = pblur(hgt, 0.8)
    dx = (np.roll(hb, -1, axis=1) - np.roll(hb, 1, axis=1)) * 0.5
    dy = (np.roll(hb, -1, axis=0) - np.roll(hb, 1, axis=0)) * 0.5
    return _pack_normal(dx, dy, strength)


def _pack_normal(dx, dy, strength):
    nx = -dx * strength
    ny = dy * strength  # v가 아래로 늘어나므로 dh/dv = 이미지 위쪽(Y+) 기울기의 부호 반전 -> OpenGL 규약
    nz = np.ones_like(dx)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx * inv, ny * inv, nz * inv], axis=-1) * 0.5 + 0.5


def boxm(X, Y, x0, x1, y0, y1, soft=0.6):
    """사각형 마스크 (부드러운 경계)."""
    return (smooth(X, x0 - soft, x0 + soft) * (1.0 - smooth(X, x1 - soft, x1 + soft)) *
            smooth(Y, y0 - soft, y0 + soft) * (1.0 - smooth(Y, y1 - soft, y1 + soft)))


def disc(X, Y, cx, cy, r, soft=0.7, periodic=True):
    dx = wrap(X - cx) if periodic else X - cx
    return 1.0 - smooth(np.hypot(dx, Y - cy), r - soft, r + soft)


SEGS = {0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg",
        9: "abcdfg"}


def digit_mask(X, Y, x0, y0, w, hh, t, d):
    """7 세그먼트 블록 숫자 (글꼴 없이)."""
    half = hh * 0.5
    seg = {"a": (x0, x0 + w, y0, y0 + t), "b": (x0 + w - t, x0 + w, y0, y0 + half + t * 0.5),
           "c": (x0 + w - t, x0 + w, y0 + half - t * 0.5, y0 + hh), "d": (x0, x0 + w, y0 + hh - t, y0 + hh),
           "e": (x0, x0 + t, y0 + half - t * 0.5, y0 + hh), "f": (x0, x0 + t, y0, y0 + half + t * 0.5),
           "g": (x0, x0 + w, y0 + half - t * 0.5, y0 + half + t * 0.5)}
    m = np.zeros_like(X)
    for k in SEGS[d]:
        a, b, cc, dd = seg[k]
        m = np.maximum(m, boxm(X, Y, a, b, cc, dd, 0.5))
    return m


class Strip:
    """한 줄: 알베도·거칠기·금속성·높이·페인트·발광 맵 (세로 h px, 가로 W px).
    edge = 줄 위아래 바깥 20%에서만 0보다 큰 가중치 (가장자리 1 -> 20% 지점 0). 닳음·때는 반드시 edge를 곱해 가장자리에 가둔다."""

    def __init__(self, name, h, base, rough=0.8, metal=0.0):
        self.name = name
        self.h = h
        self.rng = rng_for(name)
        self.alb = np.tile(np.asarray(base, np.float32), (h, W, 1))
        self.rough = np.full((h, W), rough, np.float32)
        self.metal = np.full((h, W), metal, np.float32)
        self.hgt = np.full((h, W), 0.5, np.float32)
        self.paint = np.zeros((h, W), np.float32)
        self.emit = np.zeros((h, W), np.float32)
        self.ao = np.ones((h, W), np.float32)
        self.nstrength = 3.0
        self.convex_alb = 0.10  # 튀어나온 모서리 밝힘 (finish)
        self.Y, self.X = np.mgrid[0:h, 0:W].astype(np.float32)
        self.de = np.minimum(self.Y, h - 1 - self.Y)
        self.Et = 1.0 - smooth(self.Y, 0.0, 0.2 * h)
        self.Eb = 1.0 - smooth(h - 1 - self.Y, 0.0, 0.2 * h)
        self.edge = np.maximum(self.Et, self.Eb)

    def noise(self, sx, sy=None):
        return fnoise(self.rng, self.h, W, sx, sy)

    def fbm(self, sigmas, weights=None):
        return fbm(self.rng, self.h, W, sigmas, weights)

    def lowtone(self, amount=0.03):
        """아주 낮은 주파수의 명암 (면이 죽지 않을 정도)."""
        n = fnoise(self.rng, self.h, W, 150.0, max(self.h * 1.5, 60.0))
        self.alb *= (1.0 + amount * n)[..., None]

    def mul(self, m, amount):
        self.alb *= (1.0 - amount * m)[..., None]

    def grime(self, amount, scale=(16, 5), top_heavy=True):
        """가장자리 때: 노이즈로 들쭉날쭉한 어두운 띠 (위쪽이 더 진하다)."""
        n = smooth(self.noise(*scale), -0.8, 1.1)
        w = np.maximum(self.Et * (1.0 if top_heavy else 0.8), self.Eb * 0.8)
        m = w * (0.35 + 0.65 * n)
        self.mul(m, amount)
        self.rough += 0.06 * m
        return m

    def chips(self, under, thr=2.00, scale=(9, 3), depth=0.25, side="both", amount=1.0):
        """가장자리 칩: 위쪽 층이 떨어져 under 색이 드러난다. 반환: 칩 마스크."""
        n = self.noise(*scale)
        e = {"both": self.edge, "top": self.Et, "bottom": self.Eb}[side]
        m = smooth(0.5 * n + 1.9 * e - thr, 0.0, 0.25) * smooth(e, 0.0, 0.12) * amount
        under = np.asarray(under, np.float32)
        self.alb = self.alb * (1.0 - m[..., None]) + under * m[..., None]
        self.hgt -= depth * m
        self.rough = self.rough * (1.0 - m) + 0.7 * m
        return m


def paint_set(s, pale, mask):
    """mask 자리를 페인트(옅은 회백색)로 칠한다. 아래 알베도는 mask 밖에 남는다."""
    s.alb = s.alb * (1.0 - mask[..., None]) + np.asarray(pale, np.float32) * mask[..., None]
    s.paint = np.maximum(s.paint, mask)


CONC = c(140, 137, 132)
CONC_DK = c(94, 92, 89)
CONC_LT = c(152, 149, 143)
METAL = c(110, 115, 122)
STEEL_DK = c(62, 66, 72)
PALE = c(205, 203, 196)
RUST_A = c(112, 57, 28)
RUST_B = c(150, 84, 42)
PRIMER = c(98, 72, 62)
BLACK = c(26, 26, 28)


# ---------------------------------------------------------------- 시트 1: 구조

def strip_wall(h):
    """콘크리트 평벽: 가운데는 거의 단색, 거푸집 이음·타이 홀은 법선·AO 위주."""
    s = Strip("wall", h, CONC, 0.9)
    s.lowtone(0.03)
    g = 1.0 - smooth(np.abs(s.Y - h * 0.5), 0.5, 2.2)
    s.hgt -= 0.30 * g
    s.mul(g, 0.05)
    for cx in range(64, W, 256):
        for cy in (h * 0.27, h * 0.73):
            d = np.hypot(wrap(s.X - cx), s.Y - cy)
            hole = 1.0 - smooth(d, 4.0, 7.0)
            rim = smooth(d, 5.0, 8.0) * (1.0 - smooth(d, 8.0, 12.0))
            s.hgt += 0.10 * rim - 0.38 * hole
            s.mul(hole, 0.10)
    pores = smooth(s.noise(1.1), 1.6, 2.4) * s.edge
    s.hgt -= 0.20 * pores
    s.mul(pores, 0.18)
    drip = smooth(s.noise(5.0, 28.0), 0.5, 1.7) * s.Et
    s.mul(drip, 0.30)
    s.grime(0.16)
    s.chips(CONC_DK, side="bottom", thr=1.80)
    s.chips(CONC_LT, side="top", thr=1.95, amount=0.7)
    return s


def strip_panel(h):
    """프리캐스트 패널 (2 m마다 이음). 이음의 홈·볼트 판은 가장자리 구역에만 알베도를 바꾼다."""
    s = Strip("panel", h, CONC, 0.88)
    s.lowtone(0.025)
    xm = np.mod(s.X, 512.0)
    dx = np.minimum(xm, 512.0 - xm)
    groove = 1.0 - smooth(dx, 1.5, 4.0)
    s.hgt = 0.62 * smooth(dx, 0.0, 14.0) + 0.18
    s.hgt -= 0.45 * groove
    s.ao *= 1.0 - 0.55 * (1.0 - smooth(dx, 0.0, 22.0))
    s.mul(groove, 0.12)
    idx = np.floor(s.X / 512.0)
    s.alb *= (1.0 + 0.02 * np.where(idx % 2 == 0, 1.0, -1.0))[..., None]
    for sx in (0, 512):
        for by in (h * 0.11, h * 0.89):
            for ox in (-18, 18):
                bolt = disc(s.X, s.Y, sx + ox, by, 3.6)
                s.hgt += 0.35 * bolt
                s.alb = s.alb * (1.0 - 0.7 * bolt[..., None]) + CONC_DK * 0.7 * bolt[..., None]
    drip = smooth(s.noise(5.0, 32.0), 0.5, 1.7) * s.Et
    s.mul(drip, 0.28)
    s.grime(0.18)
    s.chips(CONC_DK, side="bottom", thr=1.80)
    return s


def strip_brick(h):
    """벽돌 줄 (무늬): 벽돌마다 약한 색차, 모르타르 줄눈은 법선으로. 그을음은 가장자리만."""
    s = Strip("brick", h, c(150, 146, 138), 0.9)
    rows, row_h, pitch = 5, 28, 64
    rng = s.rng
    pal = [c(132, 84, 68), c(122, 78, 64), c(140, 92, 74), c(114, 72, 62), c(128, 82, 68)]
    ncol = W // pitch
    brick_mask = np.zeros((h, W), np.float32)
    dist_edge = np.zeros((h, W), np.float32)
    col = np.tile(c(150, 146, 138), (h, W, 1))
    tone = rng.random((rows, ncol))
    pick = rng.integers(0, len(pal), (rows, ncol))
    y_off = (h - rows * row_h) // 2
    for r in range(rows):
        y0 = y_off + r * row_h
        off = (r % 2) * (pitch // 2)
        for ci in range(-1, ncol + 1):
            x0 = ci * pitch + off + 2
            x1 = x0 + pitch - 4
            ys = slice(y0 + 2, y0 + row_h - 2)
            xs = np.arange(x0, x1) % W
            t = 0.94 + 0.12 * tone[r, ci % ncol]
            col[ys][:, xs] = pal[pick[r, ci % ncol]] * t
            brick_mask[ys][:, xs] = 1.0
            yy = np.arange(ys.start, ys.stop)[:, None]
            xx = np.arange(x0, x1)[None, :]
            de = np.minimum(np.minimum(yy - ys.start, ys.stop - 1 - yy), np.minimum(xx - x0, x1 - 1 - xx))
            dist_edge[ys][:, xs] = de
    s.alb = col
    s.hgt = 0.2 + 0.55 * brick_mask * smooth(dist_edge, 0.0, 3.0)
    s.ao *= 1.0 - 0.4 * (1.0 - brick_mask)
    s.rough[:] = np.where(brick_mask > 0.5, 0.82, 0.95)
    s.alb *= (1.0 + 0.03 * fnoise(rng, h, W, 160.0, 90.0))[..., None]
    s.mul(smooth(s.noise(6.0, 24.0), 0.4, 1.6) * s.Et, 0.30)
    s.grime(0.22)
    s.nstrength = 2.6
    return s


def strip_band(h):
    """페인트 띠: 가운데는 매끈한 도장, 가장자리부터 칠이 벗겨져 콘크리트가 드러난다."""
    s = Strip("band", h, CONC, 0.88)
    s.lowtone(0.02)
    n = s.noise(12.0, 4.0)
    chip = smooth(0.5 * n + 1.9 * s.edge - 1.6, 0.0, 0.2) * smooth(s.edge, 0.0, 0.1)
    paint = 1.0 - chip
    paint_set(s, PALE, paint)
    s.alb *= (1.0 + 0.02 * fnoise(s.rng, h, W, 200.0, 80.0))[..., None]
    thick = smooth(blur(paint, 1.5), 0.0, 1.0)
    s.hgt = 0.35 + 0.12 * thick
    s.rough = np.where(paint > 0.5, 0.55, 0.9).astype(np.float32)
    bead = (1.0 - smooth(np.abs(s.Y - 5.0), 1.0, 3.0)) + (1.0 - smooth(np.abs(s.Y - (h - 6.0)), 1.0, 3.0))
    s.hgt += 0.25 * bead
    s.ao *= 1.0 - 0.22 * bead
    drip = smooth(s.noise(4.0, 26.0), 0.8, 1.8) * s.Et * paint
    s.mul(drip, 0.18)
    s.grime(0.20)
    return s


def strip_hazard(h):
    """경고 줄무늬 (무늬): 노랑·검정 사선. 닳음은 가장자리만."""
    s = Strip("hazard", h, BLACK, 0.7)
    period = 64.0
    t = np.mod(s.X + s.Y, period)
    yellow = smooth(t, 30.0, 32.5) * (1.0 - smooth(t, 62.0, 64.0))
    ycol = c(214, 158, 36)
    s.alb = ycol * yellow[..., None] + BLACK * (1.0 - yellow[..., None])
    s.lowtone(0.03)
    wear = smooth(s.noise(14.0, 4.0) + 1.6 * s.edge - 0.7, 0.4, 1.2) * smooth(s.edge, 0.0, 0.15)
    s.alb = s.alb * (1.0 - 0.7 * wear[..., None]) + c(112, 110, 104) * 0.7 * wear[..., None]
    s.grime(0.18)
    s.rough = (0.55 + 0.30 * wear).astype(np.float32)
    s.hgt = 0.5 + 0.06 * (1.0 - wear)
    s.nstrength = 2.0
    return s


def strip_window(h):
    """창 줄 (무늬): 256 px마다 한 칸. 틀은 페인트(마스크 1), 유리는 어두운 청회색. 발광 없음."""
    s = Strip("window", h, CONC, 0.9)
    s.lowtone(0.03)
    unit = 256.0
    xm = np.mod(s.X, unit)
    fw = 12.0
    ox0, ox1 = 22.0, unit - 22.0
    oy0, oy1 = 16.0, h - 30.0
    opening = boxm(xm, s.Y, ox0, ox1, oy0, oy1)
    gx0, gx1 = ox0 + fw, ox1 - fw
    mid = unit * 0.5
    midy = (oy0 + oy1) * 0.5
    glass = np.zeros_like(opening)
    for a, b in ((gx0, mid - 4.0), (mid + 4.0, gx1)):
        for ya, yb in ((oy0 + fw, midy - 3.0), (midy + 3.0, oy1 - fw)):
            glass = np.maximum(glass, boxm(xm, s.Y, a, b, ya, yb))
    frame = opening * (1.0 - glass)
    paint_set(s, PALE, frame)
    sheen = smooth(np.sin((s.X * 0.8 + s.Y * 1.3) * 0.03) * 0.5 + 0.5, 0.82, 0.99) * 0.35
    gcol = c(30, 38, 46) + c(44, 52, 60) * sheen[..., None]
    s.alb = s.alb * (1.0 - glass[..., None]) + gcol * glass[..., None]
    sill = boxm(xm, s.Y, ox0 - 8.0, ox1 + 8.0, oy1 + 2.0, oy1 + 12.0)
    s.alb = s.alb * (1.0 - sill[..., None]) + CONC_LT * sill[..., None]
    s.hgt = 0.5 + 0.18 * sill - 0.30 * opening + 0.22 * frame + 0.05 * glass
    s.rough = np.where(glass > 0.5, 0.10, np.where(frame > 0.5, 0.55, 0.9)).astype(np.float32)
    s.ao *= 1.0 - 0.45 * (opening - frame * 0.6).clip(0, 1) * smooth(boxm(xm, s.Y, ox0 + 2, ox1 - 2, oy0 + 2, oy1 - 2), 0, 1)
    s.grime(0.2)
    s.mul(smooth(s.noise(4.0, 28.0), 0.8, 1.8) * s.Eb, 0.25)
    s.nstrength = 3.0
    return s


def strip_shutter(h):
    """롤업 셔터 슬랫 (무늬): 슬랫 17 px, 틈은 가는 어두운 선. 아래 막대에 손잡이. 페인트 마스크 1."""
    s = Strip("shutter", h, PALE, 0.55, 0.15)
    pitch = 17.0
    ym = np.mod(s.Y, pitch)
    prof = np.sin(np.pi * (ym + 0.5) / pitch) ** 0.7
    gap = 1.0 - smooth(np.minimum(ym, pitch - ym), 0.5, 2.0)
    s.hgt = 0.25 + 0.55 * prof
    s.paint = np.ones((h, W), np.float32)
    idx = np.floor(s.Y / pitch)
    s.alb *= (1.0 + 0.012 * np.where(idx % 2 == 0, 1.0, -1.0))[..., None]
    s.alb *= (1.0 - 0.10 * gap)[..., None]
    s.ao *= 1.0 - 0.5 * gap
    s.lowtone(0.02)
    # 아래 막대와 손잡이
    bar = smooth(s.Y, h - 19.0, h - 18.0)
    s.hgt += 0.12 * bar
    for hx in (256, 768):
        lug = boxm(wrap(s.X - hx), s.Y, -26.0, 26.0, h - 13.0, h - 5.0)
        s.alb = s.alb * (1.0 - 0.8 * lug[..., None]) + STEEL_DK * 0.8 * lug[..., None]
        s.paint = s.paint * (1.0 - lug)
        s.metal = np.maximum(s.metal, 0.7 * lug)
        s.hgt += 0.3 * lug
    # 슬랫 끝 가이드 레일 자국 (U 주기 이음)
    s.grime(0.22)
    chip = s.chips(c(120, 118, 112), thr=1.85)
    s.paint *= 1.0 - chip
    s.rough = np.where(s.paint > 0.5, 0.55, s.rough)
    s.nstrength = 3.0
    return s


def strip_sill(h):
    """콘크리트 코핑·가장자리 트림: 윗면 경사, 아래 물끊기 홈."""
    s = Strip("sill", h, CONC_LT, 0.88)
    s.lowtone(0.025)
    y = s.Y
    top = 1.0 - smooth(y, 0.0, 11.0)
    drip = 1.0 - smooth(np.abs(y - (h - 7.0)), 0.8, 2.5)
    s.hgt = 0.35 + 0.55 * smooth(y, 0.0, 12.0) * (1.0 - 0.15 * smooth(y, 12.0, h - 10.0)) - 0.35 * drip
    s.hgt = np.clip(s.hgt, 0, 1)
    s.mul(drip, 0.10)
    s.ao *= 1.0 - 0.5 * drip
    s.alb *= (1.0 + 0.04 * top)[..., None]
    s.grime(0.22)
    s.chips(CONC_DK, side="bottom", thr=1.70, depth=0.15)
    s.nstrength = 3.0
    return s


# ---------------------------------------------------------------- 시트 2: 금속

def strip_corrugated(h):
    """골판: 가로로 이어진 세로 골. 골의 입체는 법선·AO에, 알베도는 거의 단색. 위아래에 나사 줄과 녹."""
    s = Strip("corrugated", h, PALE, 0.5, 0.35)
    s.paint = np.ones((h, W), np.float32)
    period = 32.0
    s.hgt = 0.5 + 0.40 * np.sin(2.0 * np.pi * s.X / period)
    s.convex_alb = 0.0
    s.lowtone(0.025)
    s.nstrength = 5.0
    for yy in (h * 0.07, h * 0.93):
        for sx in range(8, W, 32):
            sc = disc(s.X, s.Y, sx, yy, 3.0)
            s.hgt += 0.3 * sc
            s.alb = s.alb * (1.0 - 0.5 * sc[..., None]) + c(120, 120, 120) * 0.5 * sc[..., None]
            s.paint *= 1.0 - sc * 0.8
    s.grime(0.28, scale=(10, 5))
    ru = smooth(s.noise(14, 5) + 1.9 * s.edge - 1.8, 0.0, 0.3) * smooth(s.edge, 0.0, 0.12)
    ru_col = RUST_A * 0.5 + PRIMER * 0.5
    s.alb = s.alb * (1.0 - ru[..., None]) + ru_col * ru[..., None]
    s.paint *= 1.0 - ru
    s.rough = np.where(ru > 0.3, 0.85, s.rough).astype(np.float32)
    s.metal = s.metal * (1.0 - ru)
    s.hgt -= 0.1 * ru
    return s


def strip_plate(h):
    """리벳 강판: 2 m마다 맞대기 이음(벗겨진 가장자리에서만 리벳이 두드러진다). 페인트 마스크 1."""
    s = Strip("plate", h, PALE, 0.5, 0.3)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.025)
    xm = np.mod(s.X, 512.0)
    dx = np.minimum(xm, 512.0 - xm)
    seam = 1.0 - smooth(dx, 1.0, 3.0)
    lap = smooth(dx, 0.0, 10.0)
    s.hgt = 0.4 + 0.2 * (1.0 - lap) - 0.3 * seam
    s.mul(seam, 0.12)
    s.ao *= 1.0 - 0.5 * seam
    # 리벳: 이음 양쪽 두 줄 + 위아래 가장자리 줄
    pts = []
    for sx in (0, 512):
        for ox in (-14, 14):
            for yy in np.arange(12.0, h - 6.0, 26.0):
                pts.append((sx + ox, yy))
    for yy in (9.0, h - 10.0):
        for sx in range(16, W, 48):
            pts.append((sx, yy))
    for px, py in pts:
        r = disc(s.X, s.Y, px, py, 3.4)
        s.hgt += 0.33 * r
        s.alb *= (1.0 - 0.10 * r)[..., None]
        s.ao *= 1.0 - 0.15 * disc(s.X, s.Y, px, py, 5.6)
    s.grime(0.28, scale=(10, 5))
    chip = s.chips(PRIMER, thr=1.70, depth=0.2)
    s.paint *= 1.0 - chip
    ru = smooth(s.noise(10, 4) + 1.9 * s.Eb - 1.8, 0.0, 0.3) * smooth(s.Eb, 0.0, 0.1)
    s.alb = s.alb * (1.0 - ru[..., None]) + (RUST_A * 0.75 + RUST_B * 0.25) * ru[..., None]
    s.paint *= 1.0 - ru
    s.nstrength = 3.5
    return s


def strip_chipped(h):
    """도장 벗겨진 금속: 가운데는 온전한 칠, 벗겨짐은 가장자리에서 번진다. 칠 아래는 프라이머·녹·맨 금속."""
    s = Strip("chipped", h, PALE, 0.55, 0.2)
    s.lowtone(0.03)
    n = s.fbm([16, 5], [1.0, 0.6])
    score = 0.5 * n + 1.8 * s.edge - 1.55
    chip = smooth(score, 0.0, 0.14) * smooth(s.edge, 0.0, 0.15)
    paint = 1.0 - chip
    under_n = smooth(s.noise(8, 3), -0.3, 1.0)
    under = PRIMER * (1.0 - under_n[..., None]) + RUST_B * under_n[..., None]
    bare = smooth(s.noise(6, 2) + 0.8, 0.8, 1.6)[..., None]
    under = under * (1.0 - 0.6 * bare) + c(124, 126, 130) * 0.6 * bare
    s.alb = s.alb * (1.0 - chip[..., None]) + under * chip[..., None]
    s.paint = paint
    s.hgt = 0.5 - 0.16 * chip + 0.04 * smooth(blur(paint, 1.5), 0, 1)
    s.rough = (0.55 + 0.3 * chip).astype(np.float32)
    s.metal = (0.15 + 0.4 * chip * bare[..., 0]).astype(np.float32)
    s.grime(0.30)
    s.nstrength = 3.5
    return s


def strip_rust(h):
    """녹 줄 (무늬): 큰 얼룩만. #70391C ~ #96542A 사이를 저주파로 오가고, 잔 점은 없다."""
    s = Strip("rust", h, RUST_A, 0.88, 0.1)
    t = smooth(s.fbm([60, 22], [1.0, 0.6]), -1.2, 1.2)
    s.alb = RUST_A * (1.0 - t[..., None]) + RUST_B * t[..., None]
    streak = smooth(s.noise(6.0, 40.0), 0.4, 1.8)
    s.alb *= (1.0 - 0.22 * streak)[..., None]
    dark = smooth(s.noise(30, 12), 0.8, 2.0)
    s.alb *= (1.0 - 0.25 * dark)[..., None]
    s.hgt = 0.5 + 0.06 * s.fbm([14, 5]) - 0.10 * dark
    s.rough = (0.82 + 0.1 * t).astype(np.float32)
    s.grime(0.2)
    s.nstrength = 2.5
    return s


def strip_grate(h):
    """강판 격자 (무늬): 가로 막대 32 px 간격 + 세로 연결봉 64 px. 틈은 어둡게."""
    s = Strip("grate", h, STEEL_DK * 0.5, 0.7, 0.8)
    bar_w = 7.0
    xm = np.mod(s.X, 32.0)
    bx = 1.0 - smooth(np.abs(xm - 16.0), bar_w * 0.5 - 0.5, bar_w * 0.5 + 0.5)
    ym = np.mod(s.Y, 32.0)
    rod = 1.0 - smooth(np.abs(ym - 16.0), 1.5, 2.5)
    frame = (1.0 - smooth(s.de, 6.0, 8.0))
    solid = np.clip(np.maximum(np.maximum(bx, rod * 0.9), frame), 0, 1)
    s.alb = c(104, 108, 112) * solid[..., None] + c(14, 14, 16) * (1.0 - solid[..., None])
    s.alb *= (1.0 + 0.03 * fnoise(s.rng, h, W, 150.0, 60.0))[..., None]
    s.hgt = 0.1 + 0.7 * solid
    s.ao *= 0.25 + 0.75 * solid
    s.rough = (0.45 + 0.2 * (1.0 - solid)).astype(np.float32)
    s.metal = (0.85 * solid).astype(np.float32)
    rust = smooth(s.noise(14, 5) + 1.9 * s.edge - 1.4, 0.0, 0.4) * solid
    s.alb = s.alb * (1.0 - 0.6 * rust[..., None]) + RUST_A * 0.6 * rust[..., None]
    s.nstrength = 3.0
    return s


def strip_pipe(h):
    """파이프 몸통 (회전체 축 방향 사상): 용접 이음 고리 두 개, 길이 방향 용접선은 v 가장자리. 페인트 마스크 1."""
    s = Strip("pipe", h, PALE, 0.5, 0.35)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.02)
    for wx in (0, 512):
        wd = 1.0 - smooth(np.abs(wrap(s.X - wx)), 3.0, 7.0)
        s.hgt += 0.30 * wd
        s.mul(wd, 0.06)
        s.ao *= 1.0 - 0.3 * (1.0 - smooth(np.abs(wrap(s.X - wx)), 6.0, 12.0)) * (1.0 - wd)
    s.grime(0.22, scale=(14, 5), top_heavy=False)
    drip = smooth(s.noise(24.0, 3.0), 0.9, 1.9) * s.Et
    s.mul(drip, 0.18)
    chip = s.chips(PRIMER, thr=1.85, depth=0.15)
    s.paint *= 1.0 - chip
    s.nstrength = 3.0
    return s


def strip_beam(h):
    """페인트 칠한 철골 부재: 마스크 거의 1, 가장자리에서 칠이 벗겨진다. 위아래 가장자리에 리벳 줄."""
    s = Strip("beam", h, PALE, 0.5, 0.3)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.02)
    for yy in (8.0, h - 9.0):
        for sx in range(20, W, 64):
            r = disc(s.X, s.Y, sx, yy, 3.8)
            s.hgt += 0.3 * r
            s.alb = s.alb * (1.0 - 0.12 * r[..., None])
            s.ao *= 1.0 - 0.2 * disc(s.X, s.Y, sx, yy, 6.0)
    s.hgt += 0.15 * (1.0 - smooth(s.de, 0.0, 6.0))
    s.grime(0.26, scale=(12, 5))
    chip = s.chips(PRIMER, thr=1.65, depth=0.2)
    s.paint *= 1.0 - chip
    ru = smooth(s.noise(10, 4) + 1.9 * s.Eb - 1.8, 0.0, 0.3) * smooth(s.Eb, 0.0, 0.1)
    s.alb = s.alb * (1.0 - ru[..., None]) + RUST_A * ru[..., None]
    s.paint *= 1.0 - ru
    s.nstrength = 3.2
    return s


def strip_tread(h):
    """다이아몬드 플레이트 (무늬): 32 px 칸마다 ±45도 번갈아 놓인 돌기. 맨 철판."""
    s = Strip("tread", h, c(104, 108, 114), 0.42, 0.75)
    cell = 32.0
    lug = np.zeros((h, W), np.float32)
    ci = np.floor(s.X / cell)
    cj = np.floor(s.Y / cell)
    lx = np.mod(s.X, cell) - cell * 0.5
    ly = np.mod(s.Y, cell) - cell * 0.5
    sgn = np.where((ci + cj) % 2 == 0, 1.0, -1.0)
    u = (lx + sgn * ly) * 0.7071
    v = (lx - sgn * ly) * 0.7071
    lug = 1.0 - smooth(np.sqrt((u / 9.5) ** 2 + (v / 3.0) ** 2), 0.85, 1.1)
    s.hgt = 0.4 + 0.45 * lug
    s.alb *= (1.0 + 0.06 * lug)[..., None]
    s.alb *= (1.0 + 0.025 * fnoise(s.rng, h, W, 120.0, 60.0))[..., None]
    s.ao *= 1.0 - 0.2 * (1.0 - lug)
    s.grime(0.30)
    s.rough = (0.42 + 0.2 * (1.0 - lug) * 0.3).astype(np.float32)
    s.nstrength = 3.5
    return s


# ---------------------------------------------------------------- 시트 3: 설비

def strip_vent(h):
    """환기 루버 (무늬): 512 px마다 한 개. 틀과 날개는 페인트(마스크 1), 틈은 어둡다."""
    s = Strip("vent", h, CONC, 0.88)
    s.lowtone(0.03)
    unit = 512.0
    xm = np.mod(s.X, unit)
    outer = boxm(xm, s.Y, 20.0, unit - 20.0, 10.0, h - 10.0)
    inner = boxm(xm, s.Y, 36.0, unit - 36.0, 24.0, h - 24.0)
    paint_set(s, PALE, outer)
    pitch = 11.0
    ym = np.mod(s.Y - 24.0, pitch)
    slat = smooth(ym, 1.5, 4.0) * (1.0 - smooth(ym, pitch - 4.0, pitch - 1.0))
    louver = inner * slat
    gap = inner * (1.0 - slat)
    s.alb = s.alb * (1.0 - gap[..., None]) + c(14, 14, 16) * gap[..., None]
    s.paint = np.maximum(s.paint - gap, 0.0)
    s.alb *= (1.0 - 0.10 * louver * (1.0 - smooth(ym, 1.5, 6.0)))[..., None]
    s.hgt = 0.45 + 0.25 * outer - 0.3 * gap + 0.2 * louver * smooth(ym, 1.5, 8.0)
    s.ao *= 1.0 - 0.6 * gap
    s.rough = np.where(outer > 0.5, 0.55, 0.9).astype(np.float32)
    s.metal = (0.25 * outer).astype(np.float32)
    for px in (28.0, unit - 28.0):
        for py in (18.0, h - 19.0):
            for k in (0, 1):
                r = disc(s.X, s.Y, px + k * unit, py, 3.0)
                s.hgt += 0.3 * r
    s.grime(0.2)
    s.mul(smooth(s.noise(4.0, 24.0), 0.8, 1.8) * s.Eb, 0.2)
    s.nstrength = 3.2
    return s


def strip_pipe_joint(h):
    """배관 이음 (U 방향): 플랜지 고리 + 볼트 줄, 밸브 몸통과 손잡이 바퀴. 페인트 마스크 1 (볼트 제외)."""
    s = Strip("pipe_joint", h, PALE, 0.5, 0.4)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.02)
    for fx in (96.0, 608.0, 160.0 + 512.0 * 0):
        pass
    flanges = [96.0, 160.0, 608.0, 672.0]
    for fx in flanges:
        fl = 1.0 - smooth(np.abs(wrap(s.X - fx)), 17.0, 19.0)
        s.hgt += 0.35 * fl
        s.alb = s.alb * (1.0 - 0.12 * fl[..., None])
        s.ao *= 1.0 - 0.35 * (1.0 - smooth(np.abs(wrap(s.X - fx)), 18.0, 26.0)) * (1.0 - fl)
        for by in np.arange(8.0, h, 16.0):
            b = boxm(wrap(s.X - fx), s.Y, -5.0, 5.0, by - 4.0, by + 4.0, 1.0)
            s.hgt += 0.3 * b
            s.alb = s.alb * (1.0 - 0.45 * b[..., None]) + STEEL_DK * 0.45 * b[..., None]
            s.paint *= 1.0 - 0.7 * b
            s.metal = np.maximum(s.metal, 0.8 * b)
    # 밸브 몸통: 볼록한 띠
    vx = 384.0
    body = boxm(wrap(s.X - vx), s.Y, -68.0, 68.0, 0.0, h, 1.0) * smooth(s.Y, -1.0, 1.0)
    s.hgt += 0.25 * body
    s.alb *= (1.0 - 0.06 * body)[..., None]
    # 손잡이 바퀴: 정면에서 본 고리 + 십자 살
    dx = wrap(s.X - vx)
    dy = s.Y - h * 0.5
    r = np.hypot(dx, dy)
    ring = (1.0 - smooth(np.abs(r - 30.0), 3.0, 4.5))
    spokes = np.maximum(1.0 - smooth(np.abs(dx), 1.5, 3.0), 1.0 - smooth(np.abs(dy), 1.5, 3.0)) * (1.0 - smooth(r, 29.0, 31.0))
    hub = 1.0 - smooth(r, 6.0, 8.0)
    wheel = np.clip(np.maximum(np.maximum(ring, spokes), hub), 0, 1)
    s.hgt += 0.4 * wheel
    s.alb = s.alb * (1.0 - 0.9 * wheel[..., None]) + c(150, 150, 150) * 0.9 * wheel[..., None]
    s.ao *= 1.0 - 0.3 * disc(s.X, s.Y, vx, h * 0.5, 36.0) * (1.0 - wheel)
    s.grime(0.22, top_heavy=False)
    s.nstrength = 3.4
    return s


def strip_cable(h):
    """케이블 다발 (무늬): 5가닥이 U로 나란히. 고무 검정이 대부분, 둘은 색. 케이블 타이 띠."""
    s = Strip("cable", h, c(10, 10, 12), 0.5, 0.0)
    cols = [BLACK, c(116, 48, 38), c(30, 30, 32), c(54, 66, 80), BLACK]
    radius = h / 10.0
    hh = np.zeros((h, W), np.float32)
    alb = np.tile(c(8, 8, 9), (h, W, 1))
    for k in range(5):
        ycs = radius * (2 * k + 1) + 1.2 * np.sin(2.0 * np.pi * (s.X / W) * (k + 1) + k)
        rr = (s.Y - ycs) / (radius - 0.5)
        inside = 1.0 - smooth(np.abs(rr), 0.88, 1.0)
        prof = np.sqrt(np.clip(1.0 - rr * rr, 0.0, 1.0))
        hh = np.maximum(hh, inside * (0.25 + 0.6 * prof))
        shade = 0.55 + 0.45 * prof
        alb = alb * (1.0 - inside[..., None]) + cols[k] * shade[..., None] * inside[..., None]
    s.alb = alb
    s.hgt = hh
    s.ao = 0.3 + 0.7 * smooth(hh, 0.1, 0.6)
    tie = 1.0 - smooth(np.abs(wrap(s.X - 128.0, 256.0)), 4.0, 5.5)
    s.alb = s.alb * (1.0 - 0.7 * tie[..., None]) + c(118, 118, 112) * 0.7 * tie[..., None]
    s.hgt += 0.12 * tie
    s.lowtone(0.03)
    s.rough = (0.45 + 0.1 * (1.0 - hh)).astype(np.float32)
    s.nstrength = 3.0
    s.convex_alb = 0.0
    return s


def strip_cabinet(h):
    """전기함 정면: 1 m 폭 문 두 짝 (512 px마다), 이음선·경첩·걸쇠·환기 슬롯·각인 테두리.
    하드웨어는 몸통과 거의 같은 알베도로 두고 법선·AO·금속성 차이로 읽히게 한다. 페인트 마스크는 몸통 1."""
    s = Strip("cabinet", h, PALE, 0.5, 0.3)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.02)
    xm = np.mod(s.X, 512.0)
    dx = np.minimum(xm, 512.0 - xm)
    seam = 1.0 - smooth(dx, 1.0, 3.0)
    s.hgt = 0.55 - 0.35 * seam
    s.ao *= 1.0 - 0.6 * seam
    s.mul(seam, 0.10)
    # 각인 테두리 (문 안쪽 사각 고리)
    ring_out = boxm(xm, s.Y, 30.0, 482.0, 0.2 * h, 0.8 * h, 1.0)
    ring_in = boxm(xm, s.Y, 36.0, 476.0, 0.2 * h + 6.0, 0.8 * h - 6.0, 1.0)
    ring = ring_out - ring_in
    s.hgt += 0.18 * ring
    s.ao *= 1.0 - 0.2 * ring
    # 경첩 (왼쪽 가장자리)
    for hy in (0.28 * h, 0.5 * h, 0.72 * h):
        hg = boxm(xm, s.Y, 8.0, 20.0, hy - 8.0, hy + 8.0, 0.8)
        s.hgt += 0.3 * hg
        s.alb *= (1.0 - 0.12 * hg)[..., None]
        s.metal = np.maximum(s.metal, 0.85 * hg)
        s.paint *= 1.0 - 0.6 * hg
        s.rough = np.where(hg > 0.5, 0.35, s.rough)
    # 걸쇠 판 + 열쇠 구멍
    lt = boxm(xm, s.Y, 452.0, 472.0, 0.5 * h - 20.0, 0.5 * h + 20.0, 0.8)
    s.hgt += 0.3 * lt
    s.alb *= (1.0 - 0.14 * lt)[..., None]
    s.metal = np.maximum(s.metal, 0.9 * lt)
    s.paint *= 1.0 - 0.6 * lt
    s.rough = np.where(lt > 0.5, 0.3, s.rough)
    key = disc(xm, s.Y, 462.0, 0.5 * h - 6.0, 2.2, 0.6, periodic=False)
    s.hgt -= 0.4 * key
    s.alb *= (1.0 - 0.25 * key)[..., None]
    # 환기 슬롯 (문마다 가는 가로 홈 6개)
    for k in range(6):
        sy = 0.58 * h + k * 5.0
        sl = boxm(xm, s.Y, 150.0, 260.0, sy, sy + 2.2, 0.5)
        s.hgt -= 0.45 * sl
        s.ao *= 1.0 - 0.7 * sl
        s.alb *= (1.0 - 0.18 * sl)[..., None]
    # 경고 라벨 (작은 어두운 판, 약한 대비)
    lab = boxm(xm, s.Y, 330.0, 372.0, 0.3 * h, 0.3 * h + 20.0, 0.6)
    s.alb = s.alb * (1.0 - 0.3 * lab[..., None]) + c(150, 140, 100) * 0.3 * lab[..., None]
    s.paint *= 1.0 - 0.5 * lab
    s.hgt += 0.08 * lab
    s.grime(0.28, scale=(12, 5))
    chip = s.chips(PRIMER, thr=1.70, depth=0.2)
    s.paint *= 1.0 - chip
    s.mul(smooth(s.noise(4.0, 22.0), 0.8, 1.8) * s.Eb, 0.22)
    s.nstrength = 3.4
    return s


def strip_sign(h):
    """표지판 줄 (무늬): 256 px마다 한 장. 판 = 페인트(마스크 1), 그림·글자 = 어두운 블록 도형(마스크 0)."""
    s = Strip("sign", h, METAL * 0.6, 0.5, 0.5)
    unit = 256.0
    xm = np.mod(s.X, unit)
    idx = np.floor(s.X / unit).astype(np.int32)
    plate = boxm(xm, s.Y, 14.0, unit - 14.0, 8.0, h - 8.0, 0.8)
    paint_set(s, PALE, plate)
    s.rough = np.where(plate > 0.5, 0.45, 0.6).astype(np.float32)
    s.hgt = 0.45 + 0.18 * plate
    art = np.zeros((h, W), np.float32)
    cx, cy = unit * 0.5, h * 0.5
    ink = c(30, 30, 32)
    # 0: 경고 삼각형 + 느낌표
    tri_y = (s.Y - 14.0) / (h - 28.0)
    in_tri = (tri_y > 0) * (tri_y < 1) * (np.abs(xm - cx) < tri_y * 40.0 + 1.0)
    in_hole = (np.abs(xm - cx) < tri_y * 40.0 - 8.0) * (tri_y > 0.2)
    tri = np.clip(in_tri * 1.0 - in_hole * 1.0, 0, 1).astype(np.float32)
    bang = np.maximum(boxm(xm, s.Y, cx - 3.0, cx + 3.0, 36.0, 62.0, 0.5), disc(xm, s.Y, cx, 70.0, 3.6, 0.5, periodic=False))
    a0 = np.maximum(tri, bang) * (idx % 4 == 0)
    # 1: 숫자 "07" + 아래 막대
    a1 = np.maximum(digit_mask(xm, s.Y, 52.0, 20.0, 56.0, 56.0, 12.0, 0), digit_mask(xm, s.Y, 128.0, 20.0, 56.0, 56.0, 12.0, 7))
    a1 = np.maximum(a1, boxm(xm, s.Y, 40.0, 216.0, 80.0, 84.0, 0.5)) * (idx % 4 == 1)
    # 2: 화살표 + 줄무늬
    sh = boxm(xm, s.Y, 40.0, 150.0, cy - 9.0, cy + 9.0, 0.5)
    ax = (xm - 150.0) / 56.0
    head = (ax > 0) * (ax < 1) * (np.abs(s.Y - cy) < (1.0 - ax) * 30.0)
    stripes = boxm(xm, s.Y, 40.0, 216.0, 14.0, 22.0, 0.5) + boxm(xm, s.Y, 40.0, 216.0, h - 22.0, h - 14.0, 0.5)
    a2 = np.clip(np.maximum(np.maximum(sh, head.astype(np.float32)), stripes), 0, 1) * (idx % 4 == 2)
    # 3: 금지 원 + 사선 + 글줄 막대
    rr = np.hypot(xm - 86.0, s.Y - cy)
    ring = (1.0 - smooth(np.abs(rr - 30.0), 3.5, 4.8))
    slash = (1.0 - smooth(np.abs((xm - 86.0) + (s.Y - cy)) * 0.7071, 3.5, 4.8)) * (rr < 30.0)
    lines = np.maximum(boxm(xm, s.Y, 134.0, 214.0, cy - 14.0, cy - 8.0, 0.5), boxm(xm, s.Y, 134.0, 200.0, cy + 6.0, cy + 12.0, 0.5))
    a3 = np.clip(np.maximum(np.maximum(ring, slash), lines), 0, 1) * (idx % 4 == 3)
    art = np.maximum(np.maximum(a0, a1), np.maximum(a2, a3)) * plate
    s.alb = s.alb * (1.0 - art[..., None]) + ink * art[..., None]
    s.paint *= 1.0 - art
    s.hgt += 0.06 * art
    for bx in (24.0, unit - 24.0):
        for by in (16.0, h - 17.0):
            b = disc(xm, s.Y, bx, by, 2.8, 0.5, periodic=False)
            s.hgt += 0.3 * b
            s.alb *= (1.0 - 0.4 * b)[..., None]
            s.paint *= 1.0 - 0.6 * b
    s.lowtone(0.03)
    s.grime(0.22)
    chip = s.chips(c(100, 100, 100), thr=1.80, depth=0.1)
    s.paint *= 1.0 - chip
    s.nstrength = 3.0
    return s


def strip_fluoro(h):
    """형광등 줄 (무늬): 2 m 관 두 개 (512 px마다). 관 = 발광 마스크 B 1, 하우징은 페인트(마스크 1)."""
    s = Strip("fluoro", h, PALE, 0.5, 0.3)
    s.paint = np.ones((h, W), np.float32)
    unit = 512.0
    xm = np.mod(s.X, unit)
    cy = h * 0.5
    tube_r = 13.0
    tube = boxm(xm, s.Y, 30.0, unit - 30.0, cy - tube_r, cy + tube_r, 0.8)
    ty = (s.Y - cy) / tube_r
    prof = np.sqrt(np.clip(1.0 - ty * ty, 0.0, 1.0))
    s.emit = tube * (0.55 + 0.45 * prof)
    s.alb = s.alb * (1.0 - tube[..., None]) + c(232, 236, 240) * (0.7 + 0.3 * prof)[..., None] * tube[..., None]
    s.paint *= 1.0 - tube
    s.hgt = 0.4 + 0.3 * tube * prof
    s.rough = np.where(tube > 0.5, 0.2, 0.5).astype(np.float32)
    # 소켓(양 끝) 과 반사판 홈
    for sx in (30.0, unit - 30.0):
        sock = boxm(xm, s.Y, sx - 14.0 if sx < 100 else sx, sx if sx < 100 else sx + 14.0, cy - 9.0, cy + 9.0, 0.6)
        s.alb = s.alb * (1.0 - 0.7 * sock[..., None]) + c(150, 150, 146) * 0.7 * sock[..., None]
        s.paint *= 1.0 - sock
        s.emit *= 1.0 - sock
        s.hgt += 0.2 * sock
    rail = 1.0 - smooth(np.abs(s.Y - cy), tube_r + 3.0, tube_r + 5.0)
    s.ao *= 1.0 - 0.3 * (rail - tube).clip(0, 1)
    s.lowtone(0.02)
    s.grime(0.22)
    s.nstrength = 3.0
    s.convex_alb = 0.0
    return s


def strip_door_hw(h):
    """강철 문 하드웨어 줄 (무늬): 256 px마다 문 한 짝 (푸시바 / 손잡이 번갈아), 아래 킥 플레이트. 문판은 페인트(마스크 1)."""
    s = Strip("door_hw", h, PALE, 0.5, 0.3)
    s.paint = np.ones((h, W), np.float32)
    s.lowtone(0.02)
    unit = 256.0
    xm = np.mod(s.X, unit)
    idx = np.floor(s.X / unit).astype(np.int32)
    seam = 1.0 - smooth(np.minimum(xm, unit - xm), 1.0, 3.0)
    s.hgt = 0.5 - 0.3 * seam
    s.mul(seam, 0.12)
    s.ao *= 1.0 - 0.5 * seam
    steel = c(150, 152, 156)

    def metal_set(m, rough=0.3, lift=0.35):
        s.alb = s.alb * (1.0 - m[..., None]) + steel * m[..., None]
        s.paint *= 1.0 - m
        s.metal = np.maximum(s.metal, 0.9 * m)
        s.rough = np.where(m > 0.5, rough, s.rough)
        s.hgt += lift * m

    kick = boxm(xm, s.Y, 6.0, unit - 6.0, h - 30.0, h - 6.0, 0.8)
    metal_set(kick, 0.35, 0.2)
    for bx in (16.0, unit - 16.0):
        for by in (h - 24.0, h - 12.0):
            b = disc(xm, s.Y, bx, by, 2.4, 0.5, periodic=False)
            s.hgt += 0.3 * b
            s.alb *= (1.0 - 0.3 * b)[..., None]
    push = (idx % 2 == 0)
    bar = boxm(xm, s.Y, 20.0, unit - 20.0, 34.0, 46.0, 0.8) * push
    metal_set(bar, 0.25, 0.4)
    for bx in (24.0, unit - 24.0):
        br = boxm(xm, s.Y, bx - 5.0, bx + 5.0, 26.0, 54.0, 0.6) * push
        metal_set(br, 0.3, 0.3)
    plate = boxm(xm, s.Y, 150.0, 180.0, 14.0, 70.0, 0.8) * (~push)
    metal_set(plate, 0.3, 0.25)
    lever = boxm(xm, s.Y, 130.0, 176.0, 36.0, 44.0, 0.7) * (~push)
    metal_set(lever, 0.25, 0.45)
    lock = disc(xm, s.Y, 165.0, 24.0, 4.0, 0.6, periodic=False) * (~push)
    s.hgt -= 0.3 * lock
    s.alb *= (1.0 - 0.4 * lock)[..., None]
    s.grime(0.28, scale=(12, 5))
    chip = s.chips(PRIMER, thr=1.70, depth=0.2)
    s.paint *= 1.0 - chip
    s.nstrength = 3.4
    return s


def strip_duct(h):
    """HVAC 덕트: 아연도금 판. 가운데는 매끈, 2 m 간격 플랜지 이음과 길이 방향 이음은 법선·AO. 가장자리에 먼지·테이프."""
    s = Strip("duct", h, c(150, 154, 158), 0.5, 0.6)
    s.lowtone(0.03)
    xm = np.mod(s.X, 512.0)
    dx = np.minimum(xm, 512.0 - xm)
    flange = 1.0 - smooth(dx, 9.0, 11.0)
    s.hgt = 0.45 + 0.35 * flange
    s.ao *= 1.0 - 0.4 * (1.0 - smooth(dx, 10.0, 20.0)) * (1.0 - flange)
    s.mul(flange, 0.06)
    for by in np.arange(10.0, h, 28.0):
        for bsgn in (-1, 1):
            b = disc(s.X, s.Y, 0 if bsgn < 0 else 512, by, 0.001)  # 자리 표시 (볼트는 아래에서)
    for sx in (0.0, 512.0):
        for by in np.arange(12.0, h - 6.0, 28.0):
            for ox in (-5.0, 5.0):
                b = disc(s.X, s.Y, sx + ox, by, 2.6, 0.5)
                s.hgt += 0.2 * b
                s.alb *= (1.0 - 0.10 * b)[..., None]
    # 길이 방향 이음 (가는 홈 하나) 과 대각 크로스 브레이크는 높이에만
    cross = np.abs(np.minimum(np.abs((xm - 256.0) - (s.Y - h * 0.5) * 1.6), np.abs((xm - 256.0) + (s.Y - h * 0.5) * 1.6)))
    xb = (1.0 - smooth(cross, 1.0, 3.5)) * smooth(dx, 14.0, 24.0)
    s.hgt += 0.1 * xb
    lseam = 1.0 - smooth(np.abs(s.Y - h * 0.5), 0.6, 1.8)
    s.hgt -= 0.2 * lseam
    s.mul(lseam, 0.05)
    s.grime(0.30, scale=(14, 5), top_heavy=False)
    dust = smooth(s.noise(10, 4), -0.2, 1.4) * s.Et
    s.alb = s.alb * (1.0 - 0.25 * dust[..., None]) + c(120, 112, 100) * 0.25 * dust[..., None]
    s.chips(RUST_B * 0.8, thr=1.90, depth=0.1, amount=0.8)
    s.nstrength = 3.0
    return s


STRIPS1 = {"wall": strip_wall, "panel": strip_panel, "brick": strip_brick, "band": strip_band, "hazard": strip_hazard,
           "window": strip_window, "shutter": strip_shutter, "sill": strip_sill}
STRIPS2 = {"corrugated": strip_corrugated, "plate": strip_plate, "chipped": strip_chipped, "rust": strip_rust,
           "grate": strip_grate, "pipe": strip_pipe, "beam": strip_beam, "tread": strip_tread}
STRIPS3 = {"vent": strip_vent, "pipe_joint": strip_pipe_joint, "cable": strip_cable, "cabinet": strip_cabinet,
           "sign": strip_sign, "fluoro": strip_fluoro, "door_hw": strip_door_hw, "duct": strip_duct}


# ---------------------------------------------------------------- 마무리·조립

def finish(s):
    """높이 공동에서 AO를, 튀어나온 모서리에서 하이라이트를, 줄 위아래 가장자리(바깥 20%)에 AO·하이라이트를 굽는다.
    반환: (albedo, orm, normal, mask) 각 (h, W, 3) 0~1."""
    hb = blur(s.hgt, 6.0)
    cavity = np.clip((hb - s.hgt) * 3.0, 0.0, 1.0)
    convex = np.clip((s.hgt - blur(s.hgt, 2.0)) * 5.0, 0.0, 1.0)
    ao = s.ao * (1.0 - 0.5 * cavity)
    s.alb = s.alb * (1.0 + s.convex_alb * convex)[..., None]
    s.rough = np.clip(s.rough + 0.10 * convex, 0.04, 1.0)
    rim = 1.0 - smooth(s.de, 0.0, 3.0)
    s.alb = s.alb * (1.0 + 0.20 * rim)[..., None]
    s.rough = np.clip(s.rough + 0.12 * rim, 0.04, 1.0)
    ao = ao * (1.0 - 0.40 * s.edge * (1.0 - 0.6 * rim))
    s.alb = s.alb * (1.0 - 0.08 * s.edge)[..., None]
    normal = normal_from_height(s.hgt, s.nstrength)
    alb = np.clip(s.alb, 0.0, 1.0)
    orm = np.stack([np.clip(ao, 0, 1), np.clip(s.rough, 0.04, 1.0), np.clip(s.metal, 0, 1)], axis=-1)
    mask = np.stack([np.clip(s.hgt, 0, 1), np.clip(s.paint, 0, 1), np.clip(s.emit, 0, 1)], axis=-1)
    return alb, orm, normal, mask


def quiet_metric(alb, h):
    """가운데 60% 높이의 알베도 명도 표준편차 / 평균."""
    mid = alb[int(round(h * 0.2)):int(round(h * 0.8))]
    lum = 0.2126 * mid[..., 0] + 0.7152 * mid[..., 1] + 0.0722 * mid[..., 2]
    return float(lum.std() / max(lum.mean(), 1e-6))


def assemble(order, funcs):
    """줄들을 시트에 쌓고 여백을 가장자리 줄 복제로 채운다. 반환: (4개 맵, 레이아웃 dict, 조용함 지표 dict)."""
    sheets = [np.zeros((W, W, 3), np.float32) for _ in range(4)]
    layout = {}
    metrics = {}
    y = GUTTER
    for name, h in order:
        maps = finish(funcs[name](h))
        for i in range(4):
            sheets[i][y:y + h] = maps[i]
            sheets[i][y - GUTTER:y] = maps[i][:1]
            sheets[i][y + h:y + h + GUTTER] = maps[i][-1:]
        layout[name] = {"y": y, "h": h, "v0": y / W, "v1": (y + h) / W}
        if name in SURFACE:
            metrics[name] = quiet_metric(maps[0], h)
            layout[name]["quiet_metric"] = round(metrics[name], 4)
        y += h + GUTTER * 2
    assert y - GUTTER <= W, "줄이 시트(%d)를 넘친다: %d" % (W, y - GUTTER)
    last_end = y - GUTTER
    if last_end < W:
        for i in range(4):
            sheets[i][last_end:] = sheets[i][last_end - 8:last_end].mean(axis=(0, 1), keepdims=True)
    return sheets, layout, metrics


# ---------------------------------------------------------------- 바닥 (양 축 주기)

def crack_field(rng, n, length, branch=0.03, size=W):
    """짧은 균열 n개를 양 축 주기로 그린 0~1 마스크. 한 타일에 흩어 놓아 반복이 드러나지 않게 한다."""
    m = np.zeros((size, size), np.float32)
    for _ in range(n):
        x, y = rng.random() * size, rng.random() * size
        ang = rng.random() * 2.0 * np.pi
        ln = int(length * (0.5 + rng.random()))
        stack = [(x, y, ang, ln)]
        while stack:
            x, y, ang, ln = stack.pop()
            for _i in range(ln):
                ang += rng.normal(0.0, 0.22)
                x += np.cos(ang)
                y += np.sin(ang)
                m[int(y) % size, int(x) % size] = 1.0
                if rng.random() < branch and ln > 20:
                    stack.append((x, y, ang + rng.choice([-1.0, 1.0]) * 0.9, ln // 3))
    return m


def rect_patch(X, Y, cx, cy, w, h, soft=1.5):
    dx = np.abs(wrap(X - cx)) - w * 0.5
    dy = np.abs(wrap(Y - cy)) - h * 0.5
    return (1.0 - smooth(dx, -soft, soft)) * (1.0 - smooth(dy, -soft, soft))


def ground_finish(name, alb, rough, hgt, nstrength, ao_extra=None):
    hb = pblur(hgt, 5.0)
    cavity = np.clip((hb - hgt) * 3.0, 0.0, 1.0)
    ao = 1.0 - 0.5 * cavity
    if ao_extra is not None:
        ao *= ao_extra
    orm = np.stack([np.clip(ao, 0, 1), np.clip(rough, 0.04, 1.0), np.zeros_like(rough)], axis=-1)
    return np.clip(alb, 0, 1), orm, normal_from_height_2d(hgt, nstrength)


def make_asphalt():
    rng = rng_for("ground_asphalt")
    X, Y = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(W, dtype=np.float32))
    base = c(70, 70, 73)
    alb = np.tile(base, (W, W, 1))
    low = fbm(rng, W, W, [140.0, 60.0], [1.0, 0.6])
    alb *= (1.0 + 0.045 * low)[..., None]
    grain = fnoise(rng, W, W, 1.1)
    coarse = fnoise(rng, W, W, 2.4)
    alb *= (1.0 + 0.035 * grain + 0.03 * coarse)[..., None]
    spec = smooth(fnoise(rng, W, W, 1.3), 2.1, 3.2)
    alb = alb * (1.0 - 0.5 * spec[..., None]) + c(120, 118, 114) * 0.5 * spec[..., None]
    hgt = 0.5 + 0.12 * coarse + 0.06 * grain + 0.1 * low
    rough = 0.9 - 0.08 * spec + 0.03 * low
    # 보수 패치 (더 매끈하고 약간 어두운 직사각형) 여러 개를 흩어 둔다
    for i, (px, py, pw, ph) in enumerate(((190, 260, 230, 150), (700, 140, 150, 220), (480, 760, 300, 120), (880, 830, 120, 160))):
        p = rect_patch(X, Y, px, py, pw, ph, 1.8)
        edge = p * (1.0 - smooth(pblur(p, 2.0), 0.0, 0.8))
        alb = alb * (1.0 - 0.45 * p[..., None]) + c(52, 52, 55) * 0.45 * p[..., None] * (1.0 + 0.03 * low[..., None])
        hgt = hgt * (1.0 - 0.6 * p) + 0.5 * 0.6 * p + 0.12 * edge
        rough = rough * (1.0 - 0.5 * p) + 0.78 * 0.5 * p
    # 잔 균열 (한 타일에 흩어진 가는 선)
    cr = pblur(crack_field(rng, 26, 70), 0.7)
    cr = np.clip(cr * 2.5, 0, 1)
    alb *= (1.0 - 0.45 * cr)[..., None]
    hgt -= 0.5 * cr
    # 얕은 얼룩 (기름 자국을 흉내 낸 어두운 저주파)
    stain = smooth(fnoise(rng, W, W, 45.0), 0.9, 2.2)
    alb *= (1.0 - 0.18 * stain)[..., None]
    rough -= 0.1 * stain
    return ground_finish("asphalt", alb, rough, hgt, 3.0)


def make_concrete():
    rng = rng_for("ground_concrete")
    X, Y = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(W, dtype=np.float32))
    base = c(128, 125, 120)
    alb = np.tile(base, (W, W, 1))
    # 슬랩 2 m (512 px) 4장: 장마다 톤이 약간 다르다
    sx = np.floor(X / 512.0).astype(np.int32)
    sy = np.floor(Y / 512.0).astype(np.int32)
    tones = np.array([[1.0, 0.965], [0.975, 1.03]], np.float32)
    alb *= tones[sy, sx][..., None]
    low = fbm(rng, W, W, [130.0, 55.0], [1.0, 0.6])
    alb *= (1.0 + 0.035 * low)[..., None]
    broom = fnoise(rng, W, W, 0.9, 38.0)
    alb *= (1.0 + 0.012 * broom)[..., None]
    mid = fnoise(rng, W, W, 3.0)
    hgt = 0.5 + 0.03 * mid + 0.02 * broom + 0.05 * low
    rough = 0.82 + 0.05 * low
    # 줄눈 (타일 경계 x=0, y=0 과 512 마다): 톱 절단 홈
    jx = np.minimum(np.mod(X, 512.0), 512.0 - np.mod(X, 512.0))
    jy = np.minimum(np.mod(Y, 512.0), 512.0 - np.mod(Y, 512.0))
    jd = np.minimum(jx, jy)
    groove = 1.0 - smooth(jd, 1.5, 3.2)
    cham = (1.0 - smooth(jd, 3.0, 7.0)) * (1.0 - groove)
    spall = smooth(fnoise(rng, W, W, 5.0) + 1.0 * (1.0 - smooth(jd, 2.0, 14.0)) - 0.6, 0.0, 0.8) * (1.0 - smooth(jd, 3.0, 14.0))
    alb *= (1.0 - 0.42 * groove - 0.04 * cham - 0.12 * spall)[..., None]
    hgt += -0.5 * groove + 0.04 * cham - 0.08 * spall
    rough += 0.06 * spall
    ao_extra = 1.0 - 0.5 * groove
    # 보수 패치 둘 (슬랩 안쪽)
    for (px, py, pw, ph, tone) in ((140.0, 140.0, 150.0, 120.0, 1.06), (700.0, 650.0, 180.0, 130.0, 0.93)):
        p = rect_patch(X, Y, px, py, pw, ph, 1.5)
        edge = p * (1.0 - smooth(pblur(p, 1.6), 0.0, 0.8))
        alb = alb * (1.0 - p[..., None]) + alb * tone * p[..., None]
        alb *= (1.0 - 0.12 * edge)[..., None]
        hgt += 0.06 * p - 0.1 * edge
    # 잔 균열: 슬랩마다 몇 개
    cr = np.clip(pblur(crack_field(rng, 18, 55, 0.02), 0.6) * 2.4, 0, 1)
    cr *= 1.0 - groove
    alb *= (1.0 - 0.35 * cr)[..., None]
    hgt -= 0.4 * cr
    stain = smooth(fnoise(rng, W, W, 50.0), 0.9, 2.2)
    alb *= (1.0 - 0.10 * stain)[..., None]
    return ground_finish("concrete", alb, rough, hgt, 2.6, ao_extra)


def make_gravel():
    rng = rng_for("ground_gravel")
    g = 56
    cell = W / g
    jx = 0.15 + 0.7 * rng.random((g, g)).astype(np.float32)
    jy = 0.15 + 0.7 * rng.random((g, g)).astype(np.float32)
    X, Y = np.meshgrid(np.arange(W, dtype=np.float32) + 0.5, np.arange(W, dtype=np.float32) + 0.5)
    ci = np.floor(X / cell).astype(np.int32)
    cj = np.floor(Y / cell).astype(np.int32)
    d1 = np.full((W, W), 1e9, np.float32)
    d2 = np.full((W, W), 1e9, np.float32)
    nid = np.zeros((W, W), np.int32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ii = ci + ox
            jj = cj + oy
            px = (ii + jx[jj % g, ii % g]) * cell
            py = (jj + jy[jj % g, ii % g]) * cell
            d = np.hypot(X - px, Y - py)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            nid = np.where(closer, (jj % g) * g + (ii % g), nid)
            d1 = np.where(closer, d, d1)
    pal = np.array([c(124, 120, 112), c(140, 131, 116), c(100, 96, 92), c(152, 144, 130), c(112, 102, 90), c(126, 124, 122)], np.float32)
    pick = rng.integers(0, len(pal), g * g)
    tone = 0.94 + 0.12 * rng.random(g * g).astype(np.float32)
    col = pal[pick[nid]] * tone[nid][..., None]
    edge = d2 - d1
    dome = smooth(edge, 0.0, 5.0)
    hgt = 0.15 + 0.6 * dome
    # 흙이 덮인 곳 (저주파 임계): 자갈을 덮는 고운 흙
    soil_n = fbm(rng, W, W, [70.0, 28.0], [1.0, 0.6])
    soil = smooth(soil_n, 0.5, 1.4)
    soil_col = c(88, 76, 62) * (1.0 + 0.03 * fnoise(rng, W, W, 60.0))[..., None]
    alb = col * (1.0 - 0.8 * soil[..., None]) + soil_col * 0.8 * soil[..., None]
    alb *= (0.72 + 0.28 * smooth(edge, 0.0, 3.0))[..., None]
    alb *= (1.0 + 0.03 * fnoise(rng, W, W, 120.0))[..., None]
    hgt = hgt * (1.0 - 0.7 * soil) + 0.45 * 0.7 * soil
    rough = 0.9 - 0.06 * dome
    return ground_finish("gravel", alb, rough, hgt, 4.0)


# ---------------------------------------------------------------- 디테일 v2 (선형 데이터)

def make_detail():
    """512 px 주기. 값 0.5 = 중립 (곱셈에서 변화 없음).
    R = 저주파 얼룩 (6 m로 사상), G = 중간 때 (1.5 m로 사상), B = 잔 점 (0.5 m로 사상)."""
    n = 512
    rng = rng_for("detail")
    r = 0.5 + 0.17 * fbm(rng, n, n, [70.0, 36.0], [1.0, 0.5])
    g = 0.5 + 0.14 * fbm(rng, n, n, [20.0, 9.0], [1.0, 0.6])
    b = 0.5 + 0.10 * fnoise(rng, n, n, 1.6)
    return np.clip(np.stack([r, g, b], -1), 0.0, 1.0)


# ---------------------------------------------------------------- 데칼 아틀라스

CELL = 256


def _cell_fade(w, h, m=10.0):
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return smooth(np.minimum(np.minimum(X, w - 1 - X), np.minimum(Y, h - 1 - Y)), 1.0, m)


def _rgba(color, alpha):
    h, w = alpha.shape
    rgb = np.tile(np.asarray(color, np.float32), (h, w, 1))
    return np.concatenate([rgb, alpha[..., None]], axis=-1)


def _nz(rng, h, w, sx, sy=None):
    return fnoise(rng, h, w, sx, sy)


def decal_leak_streak():
    rng = rng_for("decal_leak")
    w, h = CELL, CELL * 2
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    t = Y / h
    a = np.zeros((h, w), np.float32)
    n = _nz(rng, h, w, 2.5, 60.0)
    for cx, wd, s in ((128, 14, 1.0), (96, 7, 0.7), (160, 9, 0.8), (70, 5, 0.5), (190, 6, 0.6)):
        wob = 6.0 * np.sin(Y * 0.02 + cx)
        col = np.exp(-((X - cx - wob) / (wd * (0.6 + 0.8 * (1.0 - t)))) ** 2)
        a = np.maximum(a, col * s * smooth(t, 0.0, 0.08) * (1.0 - smooth(t, 0.55 + 0.4 * rng.random(), 1.0)))
    a = a * (0.65 + 0.35 * smooth(n, -1.0, 1.0))
    top = np.exp(-((X - 128.0) / 90.0) ** 2) * (1.0 - smooth(t, 0.0, 0.18)) * 0.7
    a = np.clip(np.maximum(a, top), 0, 1) * 0.8 * _cell_fade(w, h)
    return _rgba(c(34, 32, 30), a)


def decal_rust_run():
    rng = rng_for("decal_rust")
    w, h = CELL, CELL * 2
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    t = Y / h
    a = np.zeros((h, w), np.float32)
    n = _nz(rng, h, w, 2.0, 50.0)
    for cx, wd in ((110, 9), (150, 6), (80, 4), (178, 5), (128, 18)):
        wob = 5.0 * np.sin(Y * 0.017 + cx * 0.1)
        col = np.exp(-((X - cx - wob) / (wd * (0.5 + 0.7 * (1.0 - t)))) ** 2)
        a = np.maximum(a, col * smooth(t, 0.0, 0.06) * (1.0 - smooth(t, 0.5 + 0.45 * rng.random(), 1.0)))
    a = a * (0.55 + 0.45 * smooth(n, -1.0, 1.0)) * 0.85 * _cell_fade(w, h)
    k = smooth(_nz(rng, h, w, 10.0, 40.0), -1.0, 1.0)[..., None]
    rgb = RUST_A * (1.0 - k) + RUST_B * k
    return np.concatenate([rgb, np.clip(a, 0, 1)[..., None]], axis=-1)


def decal_oil_stain():
    rng = rng_for("decal_oil")
    w = h = CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    n = _nz(rng, h, w, 14.0)
    r = np.hypot((X - 128.0) / 100.0, (Y - 128.0) / 80.0)
    blob = 1.0 - smooth(r + 0.22 * n, 0.55, 1.0)
    core = 1.0 - smooth(r + 0.15 * _nz(rng, h, w, 9.0), 0.2, 0.6)
    a = np.clip(blob * 0.55 + core * 0.35, 0, 1) * _cell_fade(w, h, 14.0)
    return _rgba(c(18, 18, 22), a)


def _crack_img(seed, branchy):
    rng = rng_for(seed)
    ss = 3
    size = CELL * ss
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)

    def walk(x, y, ang, ln, width, depth):
        pts = [(x, y)]
        for _ in range(ln):
            ang += rng.normal(0.0, 0.2)
            x += np.cos(ang) * 2.0 * ss
            y += np.sin(ang) * 2.0 * ss
            pts.append((x, y))
            if depth < 3 and rng.random() < branchy:
                walk(x, y, ang + rng.choice([-1.0, 1.0]) * (0.6 + 0.6 * rng.random()), ln // 2, max(1, width - 1), depth + 1)
        d.line(pts, fill=255, width=max(1, width) * ss // 2 + 1)

    walk(size * 0.15, size * 0.5, rng.normal(0, 0.4), 62, 3, 0)
    img = img.resize((CELL, CELL), Image.LANCZOS)
    a = np.asarray(img, np.float32) / 255.0
    a = pblur(a, 0.5)
    return np.clip(a * 1.6, 0, 1)


def decal_crack(seed, branchy):
    a = _crack_img(seed, branchy)
    rng = rng_for(seed + "_k")
    a *= 0.7 + 0.3 * smooth(_nz(rng, CELL, CELL, 6.0), -1.0, 1.0)
    halo = pblur(a, 3.0)
    a = np.clip(np.maximum(a * 0.9, halo * 0.5), 0, 1) * _cell_fade(CELL, CELL)
    return _rgba(c(22, 20, 18), a)


def decal_soot():
    rng = rng_for("decal_soot")
    w, h = CELL, CELL * 2
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    t = 1.0 - Y / h  # 아래가 1: 불길이 올라오는 자리
    n = _nz(rng, h, w, 14.0, 30.0)
    spread = 22.0 + 70.0 * (1.0 - t) ** 0.9
    a = np.exp(-((X - 128.0 + 10.0 * n) / spread) ** 2) * smooth(t, 0.0, 0.2) ** 0.6 * (1.0 - smooth(t, 0.9, 1.0) * 0.0)
    a = a * (0.7 + 0.3 * smooth(n, -1.0, 1.0)) * (t ** 0.4) * 0.85
    a = a * _cell_fade(w, h, 14.0)
    return _rgba(c(14, 13, 12), np.clip(a, 0, 1))


def decal_tire_marks():
    rng = rng_for("decal_tire")
    w, h = CELL * 2, CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    a = np.zeros((h, w), np.float32)
    for off in (-44.0, 44.0):
        yc = 128.0 + 38.0 * np.sin(X / w * np.pi * 0.9 + 0.2) + off
        band = 1.0 - smooth(np.abs(Y - yc), 15.0, 21.0)
        tread = 0.62 + 0.28 * (np.sin((X + np.abs(Y - yc) * 1.4) * 0.5) > 0.2)
        a = np.maximum(a, band * tread)
    fade = smooth(X, 10.0, 90.0) * (1.0 - smooth(X, w - 120.0, w - 10.0))
    a = a * fade * (0.7 + 0.3 * smooth(_nz(rng, h, w, 6.0, 3.0), -1.0, 1.0)) * 0.7
    a = a * _cell_fade(w, h, 12.0)
    return _rgba(c(20, 19, 19), np.clip(a, 0, 1))


def decal_dirt_corner():
    rng = rng_for("decal_dirt")
    w, h = CELL * 2, CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    n = _nz(rng, h, w, 14.0)
    n2 = _nz(rng, h, w, 4.0)
    a1 = 1.0 - smooth(X + 40.0 * n, 0.0, 190.0)
    a2 = 1.0 - smooth((h - 1 - Y) + 24.0 * n, 0.0, 80.0)
    a = np.clip(np.maximum(a1, a2) * (0.75 + 0.25 * n2 * 0.5) * 0.8, 0, 1)
    a = a * _cell_fade(w, h, 6.0) * smooth(Y, 0.0, 14.0)
    return _rgba(c(52, 44, 36), a)


def _worn(rng, h, w):
    return 0.78 + 0.22 * smooth(_nz(rng, h, w, 5.0, 3.0) + 0.3 * _nz(rng, h, w, 1.4), -1.4, 0.4)


def decal_number(d):
    rng = rng_for("decal_num%d" % d)
    w, h = CELL // 2, CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    m = digit_mask(X, Y, 22.0, 30.0, w - 44.0, h - 60.0, 18.0, d)
    a = m * _worn(rng, h, w) * 0.9 * _cell_fade(w, h, 8.0)
    return _rgba(c(235, 230, 209), a)


def decal_arrow():
    rng = rng_for("decal_arrow")
    w = h = CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    shaft = boxm(X, Y, 104.0, 152.0, 120.0, 232.0, 0.8)
    t = (Y - 24.0) / 100.0
    head = ((t > 0) * (t < 1) * (np.abs(X - 128.0) < t * 70.0)).astype(np.float32)
    m = np.maximum(shaft, pblur(head, 0.6))
    a = m * _worn(rng, h, w) * 0.9 * _cell_fade(w, h, 8.0)
    return _rgba(c(235, 230, 209), a)


def decal_moss():
    rng = rng_for("decal_moss")
    w = h = CELL
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    n = _nz(rng, h, w, 12.0)
    r = np.hypot((X - 128.0) / 112.0, (Y - 128.0) / 100.0)
    blob = 1.0 - smooth(r + 0.30 * n, 0.45, 1.0)
    clump = smooth(_nz(rng, h, w, 4.0), -0.8, 0.9)
    a = blob * (0.55 + 0.45 * clump) * 0.9 * _cell_fade(w, h, 14.0)
    k = smooth(_nz(rng, h, w, 7.0), -1.0, 1.0)[..., None]
    rgb = c(66, 76, 48) * (1.0 - k) + c(88, 98, 62) * k
    return np.concatenate([rgb, np.clip(a, 0, 1)[..., None]], axis=-1)


# 이름 -> (함수, 셀 x, 셀 y, 셀 w, 셀 h). 숫자 두 개는 한 셀을 반씩 나눈다.
DECALS = [
    ("leak_streak", decal_leak_streak, 0, 0, 1, 2),
    ("rust_run", decal_rust_run, 0, 2, 1, 2),
    ("soot", decal_soot, 1, 0, 1, 2),
    ("oil_stain", decal_oil_stain, 1, 2, 1, 1),
    ("moss_patch", decal_moss, 1, 3, 1, 1),
    ("tire_marks", decal_tire_marks, 2, 0, 2, 1),
    ("dirt_corner", decal_dirt_corner, 2, 1, 2, 1),
    ("crack_a", lambda: decal_crack("crack_a", 0.03), 2, 2, 1, 1),
    ("crack_b", lambda: decal_crack("crack_b", 0.07), 3, 2, 1, 1),
    ("stencil_number_1", lambda: decal_number(1), 2, 3, 0.5, 1),
    ("stencil_number_2", lambda: decal_number(2), 2.5, 3, 0.5, 1),
    ("stencil_arrow", decal_arrow, 3, 3, 1, 1),
]


def make_decals():
    atlas = np.zeros((1024, 1024, 4), np.float32)
    atlas[..., :3] = 0.5
    rects = {}
    for name, fn, cx, cy, cw, ch in DECALS:
        img = fn()
        x0, y0 = int(cx * CELL), int(cy * CELL)
        w, h = int(cw * CELL), int(ch * CELL)
        assert img.shape[0] == h and img.shape[1] == w, (name, img.shape, (h, w))
        atlas[y0:y0 + h, x0:x0 + w] = img
        rects[name] = {"cell": [cx, cy, cw, ch], "px": [x0, y0, w, h],
                       "uv": [x0 / 1024.0, y0 / 1024.0, w / 1024.0, h / 1024.0]}
    # 투명한 곳의 RGB를 가까운 불투명 색으로 번지게 해 밉맵 후광을 막는다 (간단히 셀 평균색)
    for name, fn, cx, cy, cw, ch in DECALS:
        x0, y0, w, h = int(cx * CELL), int(cy * CELL), int(cw * CELL), int(ch * CELL)
        blk = atlas[y0:y0 + h, x0:x0 + w]
        a = blk[..., 3:4]
        mean = (blk[..., :3] * a).sum((0, 1)) / max(a.sum(), 1e-6)
        blk[..., :3] = np.where(a > 0.02, blk[..., :3], mean)
    return atlas, rects


# ---------------------------------------------------------------- 저장

def to_u8(a):
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


def save(img, path, lossless):
    if lossless:
        img.save(path, "WEBP", lossless=True, quality=100, method=6, exact=True)
    else:
        img.save(path, "WEBP", quality=90, method=6)


def write_maps(tag, maps):
    paths = []
    for arr, (nm, lossless) in zip(maps, [("albedo", False), ("orm", True), ("normal", True), ("mask", True)]):
        p = os.path.join(OUT, f"{tag}_{nm}.webp")
        save(Image.fromarray(to_u8(arr), "RGB"), p, lossless)
        paths.append(p)
    return paths


def write_ground(name, maps):
    paths = []
    for arr, (nm, lossless) in zip(maps, [("albedo", False), ("orm", True), ("normal", True)]):
        p = os.path.join(OUT, f"ground_{name}_{nm}.webp")
        save(Image.fromarray(to_u8(arr), "RGB"), p, lossless)
        paths.append(p)
    return paths


# ---------------------------------------------------------------- Godot 가져오기 설정

def patch_imports():
    """Godot가 만든 .import의 파라미터를 고친다. 모두 VRAM 압축 + 밉맵. 법선은 RG 법선 압축(compress/normal_map=1).
    ORM·마스크·디테일은 색이 아닌 선형 데이터라 channel_pack=1 (최적화 채널 팩, sRGB 친화 끔). 알베도·데칼은 sRGB 친화(0)."""
    changed = 0
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".import"):
            continue
        params = {"compress/mode": "2", "mipmaps/generate": "true"}
        if "_normal." in fn:
            params["compress/normal_map"] = "1"
        elif "_orm." in fn or "_mask." in fn or fn.startswith("detail_v2"):
            params["compress/channel_pack"] = "1"
        if fn.startswith("decals"):
            params["compress/mode"] = "2"
            params["process/fix_alpha_border"] = "true"
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


# ---------------------------------------------------------------- 미리보기

def preview(sheets_all, grounds, detail, decals, path):
    T = 512
    cols, rows = 4, 5
    canvas = Image.new("RGB", (T * cols, T * rows), (24, 24, 26))
    for r, sheets in enumerate(sheets_all):
        for k, a in enumerate(sheets):
            canvas.paste(Image.fromarray(to_u8(a), "RGB").resize((T, T), Image.LANCZOS), (k * T, r * T))
    for k, (alb, orm, nrm) in enumerate(grounds):
        canvas.paste(Image.fromarray(to_u8(alb), "RGB").resize((T, T), Image.LANCZOS), (k * T, 3 * T))
        canvas.paste(Image.fromarray(to_u8(nrm), "RGB").resize((T, T), Image.LANCZOS), (k * T, 4 * T))
    d = np.tile(detail, (1, 1, 1))
    canvas.paste(Image.fromarray(to_u8(d), "RGB").resize((T, T), Image.LANCZOS), (3 * T, 3 * T))
    chk = np.indices((1024, 1024)).sum(0) // 32 % 2
    bg = np.where(chk[..., None] == 0, 0.45, 0.55).astype(np.float32) * np.ones((1, 1, 3), np.float32)
    a = decals[..., 3:4]
    comp = decals[..., :3] * a + bg * (1.0 - a)
    canvas.paste(Image.fromarray(to_u8(comp), "RGB").resize((T, T), Image.LANCZOS), (3 * T, 4 * T))
    canvas.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="미리보기 PNG 경로 (assets에는 저장하지 않음)")
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
    s1, lay1, m1 = assemble(SHEET1, STRIPS1)
    s2, lay2, m2 = assemble(SHEET2, STRIPS2)
    s3, lay3, m3 = assemble(SHEET3, STRIPS3)
    failed = []
    print("조용함 지표 (가운데 60%% 알베도 명도 표준편차/평균, 한계 %.2f)" % QUIET_LIMIT)
    for tag, ms in (("T1", m1), ("T2", m2), ("T3", m3)):
        for name, v in ms.items():
            ok = v <= QUIET_LIMIT
            print("  %s %-11s %.4f %s" % (tag, name, v, "OK" if ok else "실패"))
            if not ok:
                failed.append(f"{tag}.{name}={v:.4f}")
    grounds = [make_asphalt(), make_concrete(), make_gravel()]
    detail = make_detail()
    decals, rects = make_decals()
    if args.preview:
        preview([s1, s2, s3], grounds, detail, decals, args.preview)
        print("미리보기:", args.preview)
        return 1 if failed else 0
    written = write_maps("t1", s1) + write_maps("t2", s2) + write_maps("t3", s3)
    for name, maps in zip(("asphalt", "concrete", "gravel"), grounds):
        written += write_ground(name, maps)
    p = os.path.join(OUT, "detail_v2.webp")
    save(Image.fromarray(to_u8(detail), "RGB"), p, True)
    written.append(p)
    p = os.path.join(OUT, "decals.webp")
    Image.fromarray(to_u8(decals), "RGBA").save(p, "WEBP", quality=92, method=6, exact=True)
    written.append(p)
    p = os.path.join(OUT, "decals.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump({"size": 1024, "cell": CELL, "grid": 4, "rects": rects}, f, indent=1)
    written.append(p)
    p = os.path.join(OUT, "kit_layout.json")
    with open(p, "w", encoding="utf-8") as f:
        json.dump({"size": W, "texels_per_m": 256, "sheets": {"1": lay1, "2": lay2, "3": lay3}}, f, indent=1)
    written.append(p)
    total = 0
    for p in written:
        sz = os.path.getsize(p)
        total += sz
        print("%8.1f KB  %s" % (sz / 1024.0, os.path.relpath(p, ROOT)))
    print("합계 %.2f MB" % (total / 1048576.0))
    if failed:
        print("조용함 검사 실패:", ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
