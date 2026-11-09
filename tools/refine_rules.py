# -*- coding: utf-8 -*-
"""
精修规则（供 build_redraw_frames.py 重建与 refine_frames.py 就地精修共用，保证可复现）。

三类规则：
1) 飞白偏亮帧高光压缩 TONE_FIX_FRAMES：只压高光段（<= TONE_PIVOT 的暗部不动），
   降低水墨留白与亮灰边缘的刺眼度，同时保住暗墨衣身层次。
2) bust 半身帧头部宽对齐 BUST_HEAD_MATCH：以全身 stand 组的头部宽中位数为目标，
   让半身特写与全身帧切换时头身比例一致；不拉伸、不裁切，只等比缩放后重锚点。
3) 测量函数 metrics()：包围盒、前景占比、主体亮度、亮像素占比、头部宽。
"""
import hashlib

import numpy as np
from PIL import Image

CANVAS_W, CANVAS_H = 512, 640
CENTER_X = CANVAS_W // 2
BUST_ANCHOR_Y_OFFSET = -24   # 与 build_redraw_frames.py 一致：垂直居中偏上
STAND_TOP_Y = 132            # 全身 stand 组顶边实测中位数（alpha>0 口径）：bust 顶边对齐目标

# ---- 1) 飞白偏亮帧 ----
TONE_FIX_FRAMES = {
    "punch-start.png", "crouch-punch.png", "crouch.png", "headbutt.png",
    "rising-punch.png", "uppercut-start.png", "dash.png", "hurt-head.png",
}
TONE_PIVOT = 0.60      # 0-1 归一化亮度：该值以下不动
TONE_HI_GAIN = 0.78    # 高光段压缩系数：1.0 -> 0.912，0.85 -> 0.795（亮像素占比约减半）

# ---- 3) 头部宽测量 ----
HEAD_TOP_FRAC = 0.16   # 取包围盒顶部 16% 行带（头/发髻区域）
HEAD_SOLID_ALPHA = 32


def sha1_bytes(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def load_rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).copy()


def metrics(arr: np.ndarray) -> dict:
    a = arr[..., 3]
    # 包围盒与管线 getbbox 同口径（alpha>0），锚点核对才与合成位置一致；
    # 前景占比另用 alpha>8，避免极淡边缘把占比抬高。
    box = a > 0
    ys, xs = np.where(box)
    if len(xs) == 0:
        return dict(bw=0, bh=0, fg=0.0, mean_l=0.0, bright=0.0, head_w=0.0, x0=0, y0=0)
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    bw, bh = x1 - x0 + 1, y1 - y0 + 1

    rgb = arr[..., :3].astype(np.float32)
    lum = rgb.mean(axis=2)
    solid = a > 128
    mean_l = float(lum[solid].mean()) if solid.any() else 0.0
    fg = a > 8
    bright_mask = (a > 64) & (lum > 200.0)
    bright = float(bright_mask.sum() / max(1, int(fg.sum())))

    band = max(1, int(round(bh * HEAD_TOP_FRAC)))
    head_rows = slice(y0, min(y1 + 1, y0 + band))
    solid_band = a[head_rows, :] > HEAD_SOLID_ALPHA
    widths = []
    for r in range(solid_band.shape[0]):
        idx = np.where(solid_band[r])[0]
        if idx.size:
            widths.append(float(idx.max() - idx.min() + 1))
    head_w = max(widths) if widths else 0.0
    return dict(bw=bw, bh=bh, fg=float(fg.mean()), mean_l=mean_l,
                bright=bright, head_w=head_w, x0=x0, y0=y0)


def apply_tone(arr: np.ndarray, gain: float = None, pivot: float = None) -> np.ndarray:
    """高光肩部压缩：只动 > pivot 的亮度，暗部与 alpha 不变。"""
    g = TONE_HI_GAIN if gain is None else gain
    p = TONE_PIVOT if pivot is None else pivot
    out = arr.copy()
    rgb = out[..., :3].astype(np.float32) / 255.0
    over = rgb > p
    compressed = p + (rgb - p) * g
    rgb = np.where(over, compressed, rgb)
    out[..., :3] = np.clip(np.round(rgb * 255.0), 0, 255).astype(np.uint8)
    return out


def refit_bust(arr: np.ndarray, scale: float) -> np.ndarray:
    """按比例缩放 bust 内容后按管线锚点重新合成到 512x640（等比、不裁切主体）。"""
    if abs(scale - 1.0) < 0.005:
        return arr
    im = Image.fromarray(arr, "RGBA")
    bbox = im.getbbox()
    if bbox is None:
        return arr
    body = im.crop(bbox)
    bw, bh = body.size
    nw, nh = max(1, int(round(bw * scale))), max(1, int(round(bh * scale)))
    if nw > CANVAS_W or nh > CANVAS_H:
        shrink = min(CANVAS_W / nw, CANVAS_H / nh)
        nw, nh = max(1, int(round(nw * shrink))), max(1, int(round(nh * shrink)))
        scale *= shrink
    body = body.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ox = CENTER_X - nw // 2
    oy = (CANVAS_H - nh) // 2 + BUST_ANCHOR_Y_OFFSET
    canvas.alpha_composite(body, (ox, oy))
    return np.asarray(canvas).copy()


def paste_at_top(arr: np.ndarray, top_y: int) -> np.ndarray:
    """不缩放、只平移 bust 内容，使其包围盒顶边落在 top_y（保持水平居中）。"""
    im = Image.fromarray(arr, "RGBA")
    bbox = im.getbbox()
    if bbox is None:
        return arr
    body = im.crop(bbox)
    bw, bh = body.size
    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ox = CENTER_X - bw // 2
    oy = max(0, min(CANVAS_H - bh, int(top_y)))
    canvas.alpha_composite(body, (ox, oy))
    return np.asarray(canvas).copy()
