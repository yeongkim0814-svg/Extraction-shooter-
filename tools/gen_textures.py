#!/usr/bin/env python3
"""스타일 A("반실사") 타일형 PBR 텍스처를 절차적으로 만든다 (numpy + Pillow, 시드 고정 -> 결정적).

출력: assets/textures/semireal/<세트>_{albedo,normal,rough}.<확장자> 1024px 타일.
  concrete  얼룩진 콘크리트: 머리카락 균열 + 물 흐른 자국
  asphalt   젖은 갈라진 아스팔트: 어두운 습기 얼룩 (거칠기가 낮은 자리)
  paint     페인트 금속: 벗겨진 도장 + 녹물 번짐 (albedo_red / albedo_teal 두 변형이 법선·거칠기를 공유)
  corrugated 컨테이너 골판: 법선 맵에 주름 (albedo_red / albedo_teal)
  brick     어두운 공장 벽돌 파사드
  steel     녹슨 어두운 강판 (패널 이음매·리벳)
  wood      풍화된 팔레트 목재
  decal_*   그라임·얼룩·녹물 데칼 (RGBA 512), weed 잡초 알파 (RGBA 256)

기법: 스펙트럼 합성 노이즈(주기적이라 이음매 없음) 다중 옥타브, 도메인 워프, 보로노이 균열 마스크,
높이 -> 법선 변환. 법선은 OpenGL(Y+) 규약 (Godot 기본).

사용법: python3 tools/gen_textures.py [--only 세트이름 ...] [--preview 경로]
"""
import argparse
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFile

ImageFile.MAXBLOCK = 1 << 26  # JPEG optimize가 큰 버퍼를 쓰게 한다

N = 1024
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "textures", "semireal")

_FX, _FY = np.meshgrid(np.fft.fftfreq(N) * N, np.fft.fftfreq(N) * N)
_YY, _XX = np.mgrid[0:N, 0:N].astype(np.float32)


# ---------------------------------------------------------------- 기본 도구

def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()) & 0xFFFFFFFF)


def noise(rng, beta=2.0, fmin=1.0, fmax=None, ax=1.0, ay=1.0):
    """주기적 1/f^beta 노이즈, 평균 0 표준편차 1. ay가 크면 세로로 길게 늘어난다."""
    spec = np.fft.fft2(rng.standard_normal((N, N)))
    f = np.sqrt((_FX * ax) ** 2 + (_FY * ay) ** 2)
    amp = np.where(f > 0, np.maximum(f, 1e-6) ** (-beta / 2.0), 0.0)
    amp[f < fmin] = 0.0
    if fmax is not None:
        amp[f > fmax] = 0.0
    out = np.fft.ifft2(spec * amp).real
    return ((out - out.mean()) / (out.std() + 1e-9)).astype(np.float32)


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def warp(img, dx, dy):
    """주기 경계의 쌍선형 샘플링으로 이미지를 (dx, dy) 픽셀만큼 비튼다."""
    sx = (_XX + dx) % N
    sy = (_YY + dy) % N
    x0 = np.floor(sx).astype(np.int32)
    y0 = np.floor(sy).astype(np.int32)
    fx = sx - x0
    fy = sy - y0
    x1 = (x0 + 1) % N
    y1 = (y0 + 1) % N
    x0 %= N
    y0 %= N
    if img.ndim == 3:
        fx = fx[..., None]
        fy = fy[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    b = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return a * (1 - fy) + b * fy


def smear_down(a, length):
    """아래(+y) 방향으로 지수 감쇠 커널을 합성곱 (녹물·물 자국이 흘러내리는 느낌). 주기 경계."""
    k = np.exp(-np.arange(N) / float(length))
    k /= k.sum()
    return np.fft.ifft(np.fft.fft(a, axis=0) * np.fft.fft(k)[:, None], axis=0).real.astype(np.float32)


def blur(a, px):
    """주기 경계 가우시안 블러 (FFT)."""
    g = np.exp(-(_FX ** 2 + _FY ** 2) * (2.0 * np.pi ** 2 * (px / N) ** 2))
    return np.fft.ifft2(np.fft.fft2(a) * g).real.astype(np.float32)


def voronoi(rng, cells, wx=None, wy=None):
    """주기적 보로노이: (f1, f2, 가장 가까운 셀 번호). 거리는 셀 단위. wx/wy로 좌표를 비튼다."""
    jit = rng.random((cells, cells, 2)).astype(np.float32)
    px = (_XX + (0 if wx is None else wx)) / N * cells
    py = (_YY + (0 if wy is None else wy)) / N * cells
    cx = np.floor(px).astype(np.int32)
    cy = np.floor(py).astype(np.int32)
    f1 = np.full((N, N), 9.0, np.float32)
    f2 = np.full((N, N), 9.0, np.float32)
    ids = np.zeros((N, N), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx = cx + dx
            ny = cy + dy
            jx = jit[ny % cells, nx % cells, 0]
            jy = jit[ny % cells, nx % cells, 1]
            d = np.hypot(px - (nx + jx), py - (ny + jy))
            closer = d < f1
            ids = np.where(closer, (ny % cells) * cells + (nx % cells), ids)
            f2 = np.minimum(f2, np.maximum(f1, d))
            f1 = np.minimum(f1, d)
    return f1, f2, ids


def cell_random(rng, cells, ids):
    return rng.random(cells * cells).astype(np.float32)[ids]


def ramp(v, stops):
    """스칼라(0..1) -> RGB. stops = [(위치, (r,g,b)), ...] (값은 0..1)."""
    pos = np.array([s[0] for s in stops], np.float32)
    out = np.empty(v.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(v, pos, [s[1][c] for s in stops])
    return out


def rgb(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


def normal_from_height(h, strength):
    """높이 -> 법선(OpenGL Y+). strength는 기울기 배율 (높이 1.0이 몇 픽셀에 걸쳐 변하는지의 역수 정도)."""
    h = blur(h.astype(np.float32), 0.9)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(h)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx * inv, ny * inv, nz * inv], axis=-1)
    return n * 0.5 + 0.5


def hairline_cracks(rng, cells, width, gate_lo, gate_hi, jag=14.0, seed_tag=0):
    """보로노이 경계를 머리카락 균열로 쓴다. 게이트 노이즈로 일부 구간만 나타나고 끝이 가늘어진다. (마스크, 깊이)"""
    wx = noise(rng, 2.0, 6, 90) * jag
    wy = noise(rng, 2.0, 6, 90) * jag
    f1, f2, _ = voronoi(rng, cells, wx, wy)
    edge = (f2 - f1) * cells  # 대략 픽셀 비례하게 쓰려면 셀 크기를 곱한다
    gate = smooth(noise(rng, 2.6, 1, 10), gate_lo, gate_hi)
    w = width * (0.35 + 0.65 * gate)
    mask = 1.0 - smooth(edge, 0.0, w * cells * 0.01)
    mask = mask * gate
    return mask.astype(np.float32), (1.0 - smooth(edge, 0.0, w * cells * 0.03)) * gate


def to_u8(a):
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- 세트

def make_concrete():
    r = rng_for("concrete")
    low = noise(r, 3.0, 1, 8)
    mid = noise(r, 2.2, 6, 70)
    fine = noise(r, 1.0, 70)
    grit = noise(r, 0.5, 150)
    pits = smooth(grit, 2.0, 3.0)
    base = 0.46 + 0.045 * low + 0.03 * mid + 0.022 * fine
    tint = noise(r, 3.0, 1, 6)
    col = base[..., None] * (np.array([1.0, 0.99, 0.965], np.float32) + 0.03 * tint[..., None] * np.array([1, 0, -1], np.float32))
    # 젖은 얼룩 (도메인 워프)
    wx = noise(r, 2.5, 2, 25) * 28
    wy = noise(r, 2.5, 2, 25) * 28
    blot = warp(noise(r, 2.8, 1, 14), wx, wy)
    stain = smooth(blot, 0.5, 1.9)
    col *= (1.0 - 0.28 * stain)[..., None] * np.array([1.0, 1.0, 1.04], np.float32)
    # 물 흐른 자국: 세로로 늘어진 노이즈를 문턱값으로 잘라 위에서 아래로 번지게
    st = noise(r, 2.0, 4, None, 1.0, 14.0)
    st2 = noise(r, 2.4, 2, 40, 1.0, 6.0)
    streak = smooth(st, 0.9, 2.3) * smooth(low + 0.6 * st2, -0.3, 1.2)
    streak = np.maximum(streak, 0.6 * smooth(smear_down(smooth(grit, 2.2, 3.2), 120.0) * 40.0, 0.2, 1.0) * smooth(st2, 0.0, 1.5))
    col *= (1.0 - 0.34 * streak)[..., None] * np.array([1.0, 0.985, 0.95], np.float32)
    edge_hl = smooth(np.abs(st - 1.6), 0.0, 0.25)
    col += (0.035 * (1.0 - edge_hl) * smooth(st, 0.9, 1.5))[..., None]
    # 균열 (큰 것 + 잔 균열)
    c1, d1 = hairline_cracks(r, 5, 0.55, 0.35, 1.4, 22.0)
    c2, d2 = hairline_cracks(r, 13, 0.35, 0.9, 1.9, 10.0)
    cracks = np.maximum(c1, 0.8 * c2)
    col *= (1.0 - 0.72 * cracks)[..., None]
    col *= (1.0 - 0.55 * pits)[..., None]
    # 높이: 입자 + 구멍 + 균열 골
    h = 0.5 * fine + 0.25 * grit + 0.35 * mid - 1.2 * pits - 2.0 * np.maximum(d1, d2) * 0.7 - 0.5 * cracks
    rough = 0.86 + 0.05 * noise(r, 1.8, 3) - 0.13 * streak - 0.10 * stain + 0.05 * cracks
    return {"albedo": col, "normal": normal_from_height(h, 0.22), "rough": rough}


def make_asphalt():
    r = rng_for("asphalt")
    low = noise(r, 3.0, 1, 8)
    mid = noise(r, 2.0, 8, 80)
    fine = noise(r, 0.9, 60)
    grit = noise(r, 0.3, 200)
    stones = smooth(grit, 1.8, 2.8)
    dark = smooth(grit, -3.2, -1.8)
    base = 0.17 + 0.02 * low + 0.018 * mid + 0.03 * fine
    col = base[..., None] * np.array([1.0, 1.0, 1.03], np.float32)
    # 밝은 골재 알갱이 (회색/갈색 섞임)
    stone_col = ramp(noise(r, 0.2, 0) * 0.3 + 0.5, [(0.0, rgb(95, 92, 88)), (0.5, rgb(120, 118, 112)), (1.0, rgb(150, 140, 125))])
    col = col * (1 - stones[..., None]) + stone_col * 0.55 * stones[..., None] * (0.7 + 0.3 * smooth(fine, -1, 1))[..., None]
    col *= (1.0 - 0.25 * dark)[..., None]
    # 균열: 악어 균열 + 큰 균열
    c1, d1 = hairline_cracks(r, 6, 1.5, 0.0, 1.0, 30.0)
    c2, d2 = hairline_cracks(r, 16, 0.9, 0.4, 1.5, 14.0)
    cracks = np.maximum(c1, 0.75 * c2)
    col *= (1.0 - 0.80 * cracks)[..., None]
    # 습기 얼룩: 큰 불규칙 패치 (어둡고 매끈)
    damp_n = noise(r, 2.6, 1, 7) + 0.45 * noise(r, 2.0, 5, 30)
    damp = smooth(damp_n, 0.15, 1.1)
    col *= (1.0 - 0.38 * damp)[..., None] * np.array([0.96, 0.98, 1.04], np.float32)
    wy = wx = None
    # 기름 얼룩 (푸르스름한 광택)
    oil = smooth(noise(r, 3.0, 1, 7), 1.2, 2.1)
    col += (oil * 0.012)[..., None] * np.array([0.6, 0.9, 1.4], np.float32)
    # 보수 자국 (직선 패치) 한 줄
    seam = smooth(np.abs((_XX - 340.0 + 14.0 * noise(r, 2.5, 3, 20)) / 5.0), 0.4, 1.0)
    col *= (0.88 + 0.12 * seam)[..., None]
    h = 0.55 * fine + 0.8 * stones + 0.3 * mid - 0.6 * dark - 2.4 * np.maximum(d1, d2) * 0.6 - 0.6 * cracks
    h = h - 0.0
    rough = 0.9 - 0.5 * damp - 0.12 * oil + 0.06 * noise(r, 1.5, 3) + 0.08 * cracks
    return {"albedo": col, "normal": normal_from_height(h, 0.28), "rough": rough}


def paint_masks(name, corrugation=None):
    """페인트 금속의 공통 마스크: 벗겨짐·녹 번짐·먼지. 빨강/청록 변형이 공유한다."""
    r = rng_for(name)
    low = noise(r, 3.0, 1, 8)
    mid = noise(r, 2.2, 6, 80)
    fine = noise(r, 1.2, 80)
    peel = noise(r, 0.8, 100)  # 오렌지 필
    # 벗겨짐: 보로노이 셀 경계 + 노이즈 문턱 -> 불규칙 칩 모양
    wx = noise(r, 2.0, 8, 120) * 16
    wy = noise(r, 2.0, 8, 120) * 16
    f1, f2, ids = voronoi(r, 22, wx, wy)
    cellv = cell_random(r, 22, ids)
    chip_n = noise(r, 2.6, 1, 22) + 0.5 * noise(r, 1.8, 14, 90) + 0.6 * (cellv - 0.5) * 2.0
    if corrugation is not None:
        # 주름 마루(볼록)가 먼저 벗겨진다
        chip_n = chip_n + 1.1 * (corrugation - 0.5) * 2.0
    chip = smooth(chip_n, 1.45, 1.7)
    chip_rim = smooth(chip_n, 1.1, 1.3) * (1.0 - chip)  # 가장자리의 밝은 프라이머/단면
    # 녹 번짐: 칩 위치에서 아래로 흘러내림
    drip = np.clip(smear_down(chip.astype(np.float32), 90.0) * 5.0, 0, 1)
    drip *= smooth(noise(r, 2.0, 3, 60, 1.0, 5.0), -0.5, 1.0)
    drip_big = smooth(noise(r, 2.2, 2, 40, 1.0, 12.0), 0.9, 2.1) * smooth(low, -0.3, 1.0)
    rustbleed = np.clip(drip + 0.6 * drip_big, 0, 1) * (1.0 - chip)
    dirt = smooth(noise(r, 2.6, 1, 18), 0.3, 2.0)
    grime_lo = smooth(noise(r, 2.0, 2, 30, 1.0, 9.0), 1.0, 2.2)
    scratch = smooth(noise(r, 1.4, 90, None, 1.0, 0.02) * 1.0, 2.2, 3.4)  # 가로 긁힘
    scratch = np.maximum(scratch, smooth(noise(r, 1.4, 90, None, 0.03, 1.0), 2.5, 3.5) * 0.6)
    return dict(r=r, low=low, mid=mid, fine=fine, peel=peel, chip=chip, chip_rim=chip_rim, bleed=rustbleed,
                dirt=dirt, grime=grime_lo, scratch=scratch)


def paint_albedo(m, paint_color, sun_fade):
    r = m["r"]
    tone = 1.0 + 0.07 * m["low"] + 0.045 * m["mid"] + 0.02 * m["peel"]
    col = paint_color[None, None, :] * tone[..., None]
    col = col * (1.0 - 0.35 * m["grime"])[..., None]
    col = col * (1.0 - 0.22 * m["dirt"])[..., None]
    # 햇빛 바랜 정도 (밝고 채도 낮게)
    lum = col.mean(axis=-1, keepdims=True)
    col = col + (lum - col) * (sun_fade * smooth(m["low"], -0.5, 1.5))[..., None] + 0.04 * sun_fade * smooth(m["low"], 0.0, 1.5)[..., None]
    col += (m["scratch"] * 0.06)[..., None]
    # 벗겨진 곳: 녹슨 금속 (노이즈로 녹 색 변화)
    rust_n = smooth(noise(r, 2.0, 4, 150), -1.0, 1.6)
    rust_col = ramp(rust_n, [(0.0, rgb(92, 48, 30)), (0.5, rgb(140, 72, 34)), (1.0, rgb(178, 98, 44))])
    rust_col *= (0.85 + 0.15 * m["fine"])[..., None]
    metal = rgb(70, 66, 62)[None, None, :] * (0.9 + 0.1 * m["fine"])[..., None]
    under = rust_col * 0.85 + metal * 0.15 * (1.0 - rust_n)[..., None]
    col = col * (1.0 - m["chip"])[..., None] + under * m["chip"][..., None]
    # 칩 가장자리: 얇은 밝은 단면
    col += (0.10 * m["chip_rim"])[..., None] * paint_color[None, None, :]
    # 녹 번짐 (주황~갈색 반투명)
    bleed_col = rgb(125, 62, 30) * (0.8 + 0.3 * smooth(m["mid"], -1, 1.5))[..., None]
    col = col * (1.0 - 0.7 * m["bleed"])[..., None] + bleed_col * (0.7 * m["bleed"])[..., None]
    return col


def paint_height(m, ribs=None):
    h = 0.35 * m["fine"] + 0.2 * m["mid"] + 0.25 * m["peel"]
    h = h - 2.2 * m["chip"] - 0.4 * m["bleed"] + 0.5 * m["chip_rim"] - 0.3 * m["scratch"]
    rust_pit = noise(m["r"], 0.8, 90)
    h += (0.8 * rust_pit - 0.4) * m["chip"]
    if ribs is not None:
        h = h + ribs * 14.0
    return h


def paint_rough(m, base):
    r = m["r"]
    rough = base + 0.08 * noise(r, 1.5, 2) + 0.15 * m["dirt"] + 0.1 * m["grime"] - 0.05 * m["scratch"]
    rough = rough * (1.0 - m["chip"]) + (0.86 + 0.08 * m["fine"]) * m["chip"]
    rough = rough * (1.0 - 0.6 * m["bleed"]) + 0.78 * 0.6 * m["bleed"]
    return rough


RED = rgb(142, 34, 26)
TEAL = rgb(48, 96, 98)


def make_paint():
    m = paint_masks("paint")
    h = paint_height(m)
    out = {"albedo_red": paint_albedo(m, RED, 0.25), "albedo_teal": paint_albedo(m, TEAL, 0.25),
           "normal": normal_from_height(h, 0.15), "rough": paint_rough(m, 0.52)}
    return out


def make_corrugated():
    ribs_n = 12
    ph = (_XX / N * ribs_n) % 1.0
    # 사다리꼴 파형: 마루와 골을 평평하게 하고 비탈은 곡선으로
    tri = np.abs(ph * 2.0 - 1.0)
    rib = smooth(tri, 0.18, 0.82)  # 0 = 골 (가운데), 1 = 마루 아님... 비탈 모양
    rib = 1.0 - rib
    m = paint_masks("corrugated", corrugation=rib)
    # 골에는 먼지가 낀다
    valley = 1.0 - rib
    h = paint_height(m, rib)
    r = m["r"]

    def alb(color):
        c = paint_albedo(m, color, 0.2)
        c = c * (1.0 - 0.28 * valley * smooth(m["dirt"] + 0.5, 0.0, 1.5))[..., None]
        # 마루 모서리는 약간 밝게 (페인트 두께 반사)
        edge = smooth(np.abs(tri - 0.5), 0.0, 0.5) * 0.0
        return c
    out = {"albedo_red": alb(RED), "albedo_teal": alb(TEAL),
           "normal": normal_from_height(h, 0.2), "rough": paint_rough(m, 0.55) + 0.05 * valley}
    return out


def make_brick():
    r = rng_for("brick")
    cols, rows = 9, 26
    u = _XX / N * cols
    v = _YY / N * rows
    row = np.floor(v).astype(np.int32)
    uo = u + (row % 2) * 0.5
    col_i = np.floor(uo).astype(np.int32)
    fu = uo - col_i
    fv = v - row
    # 벽돌 하나의 안쪽 거리 (모르타르 두께)
    mortar_x = 0.045
    mortar_y = 0.12
    dx = np.minimum(fu, 1.0 - fu) / mortar_x
    dy = np.minimum(fv, 1.0 - fv) / mortar_y
    d = np.minimum(dx, dy)
    brick = smooth(d, 0.9, 1.6)
    bevel = smooth(d, 0.8, 3.2)
    brick_id = (row * 131 + (col_i % cols) * 17) % 1000
    brick_r = rng_for("brick_ids").random(1000).astype(np.float32)[brick_id]
    brick_r2 = rng_for("brick_ids2").random(1000).astype(np.float32)[brick_id]
    low = noise(r, 3.0, 1, 8)
    mid = noise(r, 2.2, 6, 70)
    fine = noise(r, 1.0, 70)
    grit = noise(r, 0.4, 150)
    base_col = ramp(brick_r * 0.7 + 0.3 * smooth(mid, -1, 1.5),
                    [(0.0, rgb(58, 40, 36)), (0.4, rgb(78, 52, 44)), (0.75, rgb(92, 64, 52)), (1.0, rgb(104, 80, 66))])
    base_col = base_col * (0.88 + 0.12 * brick_r2)[..., None]
    # 일부 벽돌은 그을려 거의 검다
    sooty = smooth(brick_r2, 0.8, 1.0)
    base_col *= (1.0 - 0.45 * sooty)[..., None]
    base_col *= (1.0 + 0.1 * fine - 0.05 * np.abs(fu - 0.5))[..., None] if False else (1.0 + 0.09 * fine)[..., None]
    mortar_col = ramp(0.5 + 0.2 * fine + 0.1 * grit, [(0.0, rgb(70, 68, 64)), (1.0, rgb(112, 108, 100))])
    col = base_col * brick[..., None] + mortar_col * (1.0 - brick)[..., None]
    # 그을음 세로 줄무늬 + 백화 (흰 가루)
    soot = smooth(noise(r, 2.1, 3, None, 1.0, 12.0), 0.5, 2.0) * smooth(low, -0.8, 1.2)
    col *= (1.0 - 0.45 * soot)[..., None]
    efflo = smooth(smear_down(smooth(grit, 2.0, 3.0), 60.0) * 25.0, 0.2, 1.0) * smooth(noise(r, 2.2, 3, 30, 1.0, 6.0), 0.3, 1.8)
    col += (0.10 * efflo * brick)[..., None] * np.array([1.0, 1.0, 0.95], np.float32)
    # 벽돌 모서리 마모
    col *= (0.9 + 0.1 * bevel)[..., None]
    # 균열 (모르타르 라인을 따라가는 것 대신 일반 헤어라인)
    c1, d1 = hairline_cracks(r, 6, 0.5, 0.7, 1.7, 20.0)
    col *= (1.0 - 0.6 * c1)[..., None]
    col *= (1.0 - 0.35 * smooth(grit, 2.2, 3.4))[..., None]
    h = 0.55 * bevel + 0.15 * fine + 0.08 * grit - 1.0 * d1 * 0.6 + 0.12 * mid
    h = h * 3.0
    rough = 0.9 + 0.05 * noise(r, 1.5, 3) - 0.04 * soot - 0.08 * (1.0 - brick) * 0 + 0.03 * (1 - brick)
    return {"albedo": col, "normal": normal_from_height(h, 0.35), "rough": rough}


def make_steel():
    r = rng_for("steel")
    low = noise(r, 3.0, 1, 8)
    mid = noise(r, 2.2, 6, 70)
    fine = noise(r, 1.0, 70)
    brushed = noise(r, 0.8, 30, None, 0.04, 1.0)   # 가로 결
    brushed2 = noise(r, 0.8, 30, None, 1.0, 0.04)
    base = 0.14 + 0.02 * low + 0.015 * mid + 0.012 * brushed
    col = base[..., None] * np.array([0.95, 1.0, 1.08], np.float32) + 0.0
    # 판 이음매: 타일을 가로세로 2칸으로 나누고 리벳 줄
    px = 512.0
    seam_x = np.abs(((_XX + 256.0) % px) - px * 0.5) # 이음선이 격자 중앙에
    seam_x = np.minimum(np.abs(((_XX) % px)), np.abs(px - ((_XX) % px)))
    seam_y = np.minimum(np.abs(((_YY) % px)), np.abs(px - ((_YY) % px)))
    seam = np.maximum(1.0 - smooth(seam_x, 1.5, 4.0), 1.0 - smooth(seam_y, 1.5, 4.0))
    rivets = np.zeros((N, N), np.float32)
    for off in (24.0,):
        gx = np.minimum(np.abs(((_XX + 32.0) % 64.0) - 32.0), 99)
        for line_x in (off, px - off, px + off, 2 * px - off):
            pass
    # 리벳: 이음선에서 24px 떨어진 줄에 64px 간격
    def rivet_row(dist_from_seam, along, across, spacing=64.0, rad=5.0):
        a = np.abs(((along + spacing * 0.5) % spacing) - spacing * 0.5)
        cd = np.minimum(np.abs(((across) % px) - dist_from_seam), np.abs(((across) % px) - (px - dist_from_seam)))
        dd = np.hypot(a, cd)
        return 1.0 - smooth(dd, rad * 0.55, rad)
    rivets = np.maximum(rivet_row(26.0, _YY, _XX), rivet_row(26.0, _XX, _YY))
    # 녹 번짐
    wx = noise(r, 2.5, 2, 20) * 9
    wy = noise(r, 2.5, 2, 20) * 9
    rust_n = warp(noise(r, 2.6, 1, 12) + 0.6 * noise(r, 1.8, 8, 60), wx, wy)
    rust = smooth(rust_n, 0.2, 1.4)
    rust_core = smooth(rust_n, 0.9, 1.8)
    bleed = np.clip(smear_down(rivets + seam * 0.3, 70.0) * 4.0, 0, 1) * smooth(noise(r, 2.0, 3, 50, 1.0, 6.0), -0.3, 1.0)
    rust = np.clip(rust + 0.5 * bleed, 0, 1)
    rust_col = ramp(smooth(noise(r, 2.0, 4, 150), -1.0, 1.6) * 0.8 + 0.2 * rust_core,
                    [(0.0, rgb(52, 28, 20)), (0.45, rgb(104, 52, 26)), (1.0, rgb(150, 82, 38))]) * (0.8 + 0.2 * fine)[..., None]
    col = col * (1.0 - rust)[..., None] + rust_col * rust[..., None]
    col *= (1.0 - 0.35 * seam)[..., None]
    col += (0.04 * rivets)[..., None]
    scr = smooth(brushed + 0.6 * brushed2, 2.4, 3.4)
    col += (0.05 * scr * (1.0 - rust))[..., None]
    grime = smooth(noise(r, 2.0, 2, 30, 1.0, 9.0), 1.0, 2.2)
    col *= (1.0 - 0.25 * grime)[..., None]
    h = 0.25 * fine + 0.3 * brushed - 1.0 * seam + 2.2 * rivets + 0.8 * rust * noise(r, 0.8, 80) - 0.4 * rust
    rough = 0.52 + 0.1 * noise(r, 1.5, 3) + 0.4 * rust + 0.05 * grime - 0.08 * scr
    return {"albedo": col, "normal": normal_from_height(h, 0.18), "rough": rough}


def make_wood():
    r = rng_for("wood")
    boards = 8
    bi = np.floor(_YY / N * boards).astype(np.int32)
    fv = (_YY / N * boards) - bi
    b_r = np.random.default_rng(77).random(boards).astype(np.float32)
    b_r2 = np.random.default_rng(78).random(boards).astype(np.float32)
    bt = b_r[bi]
    bt2 = b_r2[bi]
    # 결: 가로로 길고 세로로 촘촘, 판마다 위상 이동 + 휨
    grain_warp = noise(r, 2.6, 1, 14, 0.25, 1.0) * 14
    yy = _YY + grain_warp + bt * 400.0
    xx = _XX + bt2 * 700.0
    # 나이테 선: 노이즈 + 사인
    rings_n = noise(r, 1.6, 2, 120, 0.05, 1.0)
    rings = np.sin((_YY + 10.0 * noise(r, 2.4, 1, 10, 0.2, 1.0) + bt * 70.0) / 5.2 + 3.0 * rings_n)
    fibre = noise(r, 0.9, 20, None, 0.02, 1.0)
    fibre2 = noise(r, 0.9, 40, None, 0.035, 1.0)
    # 옹이 몇 개
    knots = np.zeros((N, N), np.float32)
    kr = np.random.default_rng(79)
    for _ in range(5):
        kx, ky = kr.random() * N, kr.random() * N
        rad = 14 + kr.random() * 16
        dxk = (((_XX - kx + N / 2) % N) - N / 2) / 2.4
        dyk = ((_YY - ky + N / 2) % N) - N / 2
        d = np.hypot(dxk, dyk)
        knots = np.maximum(knots, 1.0 - smooth(d, rad * 0.35, rad))
        ring_k = np.sin(d / 3.0) * np.exp(-d / (rad * 2.0))
        rings = rings + 1.2 * ring_k
    low = noise(r, 3.0, 1, 8)
    wear = smooth(noise(r, 2.2, 3, 60, 0.3, 1.0), 0.0, 1.8)
    base_col = ramp(0.5 + 0.18 * rings + 0.25 * fibre + 0.3 * (bt - 0.5), [
        (0.0, rgb(78, 58, 40)), (0.45, rgb(122, 96, 68)), (0.75, rgb(146, 120, 88)), (1.0, rgb(168, 146, 112))])
    # 풍화: 회은색으로 바램
    gray = rgb(128, 120, 108)[None, None, :] * (0.85 + 0.15 * fibre2)[..., None]
    wthr = smooth(low + 0.5 * bt2 * 2 - 0.5 + wear * 0.6, 0.0, 1.6)
    col = base_col * (1.0 - 0.55 * wthr)[..., None] + gray * (0.55 * wthr)[..., None]
    col *= (1.0 - 0.55 * knots)[..., None]
    # 판 사이 틈 (어두움)
    gap = 1.0 - smooth(np.minimum(fv, 1.0 - fv), 0.0, 0.035)
    col *= (1.0 - 0.85 * gap)[..., None]
    # 균열 (결 방향)
    crack_n = noise(r, 1.2, 25, None, 0.03, 1.0)
    crack = smooth(crack_n, 2.7, 3.5) * smooth(noise(r, 2.4, 2, 20), 0.2, 1.4)
    col *= (1.0 - 0.7 * crack)[..., None]
    # 얼룩/젖음
    stain = smooth(warp(noise(r, 2.8, 1, 12), noise(r, 2.4, 2, 20) * 30, noise(r, 2.4, 2, 20) * 30), 0.6, 1.8)
    col *= (1.0 - 0.3 * stain)[..., None]
    # 못 구멍 (판마다 양 끝)
    nails = np.zeros((N, N), np.float32)
    for bx in (60.0, 540.0, 910.0):
        for b in range(boards):
            cy = (b + 0.5 + 0.0) * N / boards
            d = np.hypot(((_XX - bx + N / 2) % N) - N / 2, ((_YY - cy + N / 2) % N) - N / 2)
            nails = np.maximum(nails, 1.0 - smooth(d, 3.0, 6.0))
    col *= (1.0 - 0.6 * nails)[..., None]
    h = 0.4 * rings + 0.5 * fibre + 0.25 * fibre2 - 1.2 * gap - 1.4 * crack - 0.8 * knots + 0.3 * wear * noise(r, 0.7, 60) - 1.0 * nails
    rough = 0.86 + 0.06 * fibre - 0.1 * stain + 0.05 * wear - 0.0
    return {"albedo": col, "normal": normal_from_height(h, 0.25), "rough": rough}


# ---------------------------------------------------------------- 데칼 / 알파 스프라이트

def make_decal_grime():
    """벽 데칼: 위쪽이 진하고 아래로 흘러내리는 그을음/때 (RGBA 512)."""
    r = rng_for("decal_grime")
    n1 = noise(r, 2.6, 1, 10)
    streak = noise(r, 2.0, 3, None, 1.0, 12.0)
    ph = _YY / N
    top = np.clip(1.0 - ph * 1.1, 0, 1) ** 1.2
    x = (_XX / N - 0.5) * 2
    shape = np.clip(1.0 - np.abs(x) ** 2.0, 0, 1)
    a = smooth(0.6 * top * shape + 0.22 * streak + 0.12 * n1 + 0.1, 0.35, 0.95) * smooth(ph, 0.0, 0.05) * smooth(1 - np.abs(x), 0.0, 0.15) * smooth(1 - ph, 0.0, 0.18)
    return a.astype(np.float32), rgb(24, 20, 17)


def make_decal_stain():
    """바닥 데칼: 마른 기름/물 얼룩 불규칙 덩어리 + 가장자리 고리 (RGBA 512)."""
    r = rng_for("decal_stain")
    wx = noise(r, 2.4, 2, 14) * 30
    wy = noise(r, 2.4, 2, 14) * 30
    x = ((_XX / N) - 0.5) * 2
    y = ((_YY / N) - 0.5) * 2
    d = np.hypot(x, y) + 0.25 * warp(noise(r, 2.6, 1, 10), wx, wy) * 0.5
    core = 1.0 - smooth(d, 0.3, 0.8)
    ring = smooth(np.abs(d - 0.62), 0.0, 0.06)
    a = np.clip(core * 0.85 + (1.0 - ring) * 0.35 * (1.0 - smooth(d, 0.62, 0.8)), 0, 1) * (0.7 + 0.3 * smooth(noise(r, 1.8, 6, 80), -1, 1))
    a *= 1.0 - smooth(np.hypot(x, y), 0.85, 1.0)
    return a.astype(np.float32), rgb(14, 14, 15)


def make_decal_rust():
    """녹물 데칼: 위에서 아래로 흐르는 주황 갈색 줄 (RGBA 512)."""
    r = rng_for("decal_rust")
    x = ((_XX / N) - 0.5) * 2
    ph = _YY / N
    s = noise(r, 2.0, 3, None, 1.0, 25.0)
    streak = smooth(s, 0.3, 1.8)
    head = smooth(noise(r, 2.4, 6, 60), 0.3, 1.8) * smooth(0.45 - ph, 0.0, 0.2)
    drip = np.clip(smear_down(head.astype(np.float32), 80.0) * 6.0, 0, 1)
    a = np.clip(streak * 0.6 * smooth(ph, 0.0, 0.08) * (1 - smooth(ph, 0.55, 1.0)) + drip * 0.7, 0, 1)
    a *= smooth(1 - np.abs(x), 0.0, 0.2) * smooth(1 - ph, 0.0, 0.1)
    return a.astype(np.float32), rgb(112, 54, 24)


def make_weed():
    """잡초 교차 판 알파 스프라이트 (RGBA 256). 휜 잎 여러 장."""
    S = 4
    W = 256
    img = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rg = np.random.default_rng(1234)
    for i in range(34):
        bx = W * S * (0.5 + rg.normal(0, 0.12))
        height = W * S * rg.uniform(0.35, 0.97)
        lean = rg.normal(0, 0.28)
        width = W * S * rg.uniform(0.012, 0.03)
        shade = rg.uniform(0.45, 1.0)
        tip = rg.uniform(0.0, 0.5)
        col = (int(70 * shade + 40 * tip), int(100 * shade + 30 * tip), int(38 * shade), 255)
        pts_l, pts_r = [], []
        steps = 18
        for k in range(steps + 1):
            t = k / steps
            cx = bx + lean * height * (t ** 1.7)
            cy = W * S - 2 - t * height
            w = width * (1.0 - t) ** 0.8 * (0.5 + t * 0.8) if t < 0.95 else 0.0
            pts_l.append((cx - w, cy))
            pts_r.append((cx + w, cy))
        d.polygon(pts_l + pts_r[::-1], fill=col)
    img = img.resize((W, W), Image.LANCZOS)
    arr = np.array(img).astype(np.float32)
    a = (arr[..., 3] > 110).astype(np.uint8) * 255
    rgb_arr = arr[..., :3]
    # 투명 영역에도 평균 잎 색을 깔아 밉맵에서 검게 번지지 않게 한다
    fill = np.array([62, 88, 34], np.float32)
    mask = arr[..., 3:4] / 255.0
    rgb_arr = np.where(mask > 0.05, rgb_arr / np.maximum(mask, 0.05), fill)
    return Image.fromarray(np.dstack([np.clip(rgb_arr, 0, 255).astype(np.uint8), a]), "RGBA")


# ---------------------------------------------------------------- 저장

def save_rgb(arr, path, fmt):
    img = Image.fromarray(to_u8(arr), "RGB")
    save_img(img, path, fmt)


def save_img(img, path, fmt):
    if fmt == "webp":
        img.save(path, "WEBP", quality=88, method=6)
    elif fmt == "webp_rough":
        img.save(path, "WEBP", quality=50, method=6)
    elif fmt == "webp_hq":
        img.save(path, "WEBP", quality=96, method=6)
    elif fmt == "jpg444":
        img.save(path, "JPEG", quality=86, subsampling=0, optimize=True)
    else:
        img.save(path, "PNG", optimize=True)


# 세트별 저장 형식: 법선은 4:4:4 JPEG (WebP 손실 압축은 색차 4:2:0이라 법선 R/G 디테일을 뭉갠다)
NORMAL_FMT = "jpg444"
EXT = {"webp": "webp", "webp_rough": "webp", "webp_hq": "webp", "jpg444": "jpg", "png": "png"}


def write_set(name, maps, only_preview):
    paths = []
    for key, arr in maps.items():
        if key == "rough":
            rough = np.clip(arr, 0.04, 1.0)
            img = Image.fromarray(to_u8(rough), "L").convert("RGB")
            fmt = "webp_rough"
            sub = "rough"
        elif key == "normal":
            img = Image.fromarray(to_u8(arr), "RGB")
            fmt = NORMAL_FMT
            sub = "normal"
        else:
            img = Image.fromarray(to_u8(arr), "RGB")
            fmt = "webp"
            sub = key  # albedo / albedo_red / albedo_teal
        p = os.path.join(OUT, f"{name}_{sub}.{EXT[fmt]}")
        if not only_preview:
            save_img(img, p, fmt)
        paths.append(p)
    return paths


def write_decal(name, alpha, color):
    h, w = alpha.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., 0:3] = to_u8(np.broadcast_to(color, (h, w, 3)))
    rgba[..., 3] = to_u8(alpha)
    # 엄밀히 가장자리 알파가 0이어야 데칼이 사각형 윤곽을 안 남긴다
    rgba[0, :, 3] = rgba[-1, :, 3] = 0
    rgba[:, 0, 3] = rgba[:, -1, 3] = 0
    img = Image.fromarray(rgba, "RGBA").resize((512, 512), Image.LANCZOS) if (w, h) != (512, 512) else Image.fromarray(rgba, "RGBA")
    p = os.path.join(OUT, f"{name}.webp")
    img.save(p, "WEBP", quality=90, method=6, exact=True)
    return [p]


def downsize(alpha):
    return np.array(Image.fromarray(alpha.astype(np.float32), "F").resize((512, 512), Image.BILINEAR))


SETS = {
    "concrete": make_concrete,
    "asphalt": make_asphalt,
    "paint": make_paint,
    "corrugated": make_corrugated,
    "brick": make_brick,
    "steel": make_steel,
    "wood": make_wood,
}
DECALS = {
    "decal_grime": make_decal_grime,
    "decal_stain": make_decal_stain,
    "decal_rust": make_decal_rust,
}


IMPORT_PARAMS = {
    "compress/mode": "2",            # VRAM 압축 (모바일 ETC2/ASTC, 데스크톱 S3TC/BPTC)
    "mipmaps/generate": "true",
}


def patch_imports():
    """Godot가 만든 .import의 파라미터를 모바일용으로 고친다 (VRAM 압축 + 밉맵, 법선은 RG 법선 압축).
    순서: 이 스크립트로 텍스처 생성 -> godot --headless --import (.import 생성) -> --patch-import -> 다시 --import."""
    changed = 0
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".import"):
            continue
        path = os.path.join(OUT, fn)
        params = dict(IMPORT_PARAMS)
        if "_normal." in fn:
            params["compress/normal_map"] = "1"
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="만들 세트 이름 (기본: 전부)")
    ap.add_argument("--preview", help="미리보기 PNG 경로 (저장은 하지 않음)")
    ap.add_argument("--patch-import", action="store_true", help=".import 파라미터를 모바일용으로 고친다")
    ap.add_argument("--out", help="출력 폴더 (기본: assets/textures/semireal)")
    args = ap.parse_args()
    global OUT
    if args.out:
        OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    if args.patch_import:
        patch_imports()
        return 0
    wanted = args.only or (list(SETS) + list(DECALS) + ["weed"])
    written = []
    sheets = []
    for name in wanted:
        if name in SETS:
            maps = SETS[name]()
            written += write_set(name, maps, bool(args.preview))
            first = [k for k in maps if k.startswith("albedo")][0]
            sheets.append((name, maps[first], maps["normal"], maps["rough"]))
            print("세트", name)
        elif name in DECALS:
            alpha, color = DECALS[name]()
            if not args.preview:
                written += write_decal(name, downsize(alpha), color)
            print("데칼", name)
        elif name == "weed":
            img = make_weed()
            p = os.path.join(OUT, "weed.png")
            if not args.preview:
                img.save(p, "PNG", optimize=True)
                written.append(p)
            print("잡초")
        else:
            print("알 수 없는 이름:", name, file=sys.stderr)
            return 2
    if args.preview:
        t = 384
        sheet = Image.new("RGB", (t * 3, t * len(sheets)))
        for i, (_, a, n, ro) in enumerate(sheets):
            for j, m in enumerate((a, n, ro)):
                if m.ndim == 2:
                    m = np.repeat(np.clip(m, 0, 1)[..., None], 3, axis=-1)
                sheet.paste(Image.fromarray(to_u8(m)).resize((t, t), Image.LANCZOS), (j * t, i * t))
        sheet.save(args.preview)
    total = 0
    for p in written:
        sz = os.path.getsize(p)
        total += sz
        print(f"  {os.path.relpath(p, ROOT)}  {sz / 1024:.0f} KB")
    if written:
        print(f"합계 {total / 1024 / 1024:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
