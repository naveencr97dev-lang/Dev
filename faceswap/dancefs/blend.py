"""Colour matching and compositing of the generated face back into the frame."""
from __future__ import annotations

import numpy as np
import cv2


def match_color(src: np.ndarray, ref: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Reinhard LAB transfer: make `src` stats match `ref` inside mask (both uint8 BGR)."""
    m = mask > 0.5
    if m.sum() < 16:
        return src
    s = cv2.cvtColor(src, cv2.COLOR_BGR2LAB).astype(np.float32)
    r = cv2.cvtColor(ref, cv2.COLOR_BGR2LAB).astype(np.float32)
    for c in range(3):
        sm, ss = s[..., c][m].mean(), s[..., c][m].std() + 1e-6
        rm, rs = r[..., c][m].mean(), r[..., c][m].std() + 1e-6
        s[..., c] = (s[..., c] - sm) * (rs / ss) + rm
    return cv2.cvtColor(np.clip(s, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)


def alpha_composite(base: np.ndarray, over: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    a = alpha[..., None].astype(np.float32)
    return np.clip(base.astype(np.float32) * (1 - a) + over.astype(np.float32) * a, 0, 255).astype(np.uint8)


def add_label(frame: np.ndarray, text: str) -> np.ndarray:
    """Visible, non-removable-by-default disclosure label (bottom-right)."""
    out = frame.copy()
    h, w = out.shape[:2]
    scale = max(0.4, w / 1600)
    th = max(1, int(scale * 2))
    (tw, tht), base = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, scale, th)
    x, y = w - tw - 12, h - 12
    cv2.rectangle(out, (x - 6, y - tht - 6), (x + tw + 6, y + base + 2), (0, 0, 0), -1)
    cv2.putText(out, text, (x, y), cv2.FONT_HERSHEY_SIMPLEX, scale, (255, 255, 255), th, cv2.LINE_AA)
    return out
