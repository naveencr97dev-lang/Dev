"""Optical-flow based temporal coherence for per-frame diffusion output."""
from __future__ import annotations

import numpy as np
import cv2


def flow(prev_bgr: np.ndarray, cur_bgr: np.ndarray) -> np.ndarray:
    """Backward flow: for each pixel in `cur`, where it came from in `prev`."""
    p = cv2.cvtColor(prev_bgr, cv2.COLOR_BGR2GRAY)
    c = cv2.cvtColor(cur_bgr, cv2.COLOR_BGR2GRAY)
    return cv2.calcOpticalFlowFarneback(c, p, None, 0.5, 4, 21, 5, 7, 1.5, 0)


def warp(img: np.ndarray, fl: np.ndarray) -> np.ndarray:
    h, w = fl.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return cv2.remap(img, gx + fl[..., 0], gy + fl[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def confidence(prev_src: np.ndarray, cur_src: np.ndarray, fl: np.ndarray, threshold: float) -> np.ndarray:
    """Per-pixel [0,1] trust in the warp, from photometric error of the *source* frames."""
    err = np.abs(warp(prev_src, fl).astype(np.float32) - cur_src.astype(np.float32)).mean(-1)
    err = cv2.GaussianBlur(err, (0, 0), 3)
    return np.clip(1.0 - err / max(threshold, 1e-6), 0.0, 1.0)


class TemporalState:
    """Tracks previous source/output crops so each new frame starts from a warped prior."""

    def __init__(self):
        self.prev_src = None
        self.prev_out = None

    def prior(self, cur_src: np.ndarray, threshold: float):
        """Returns (warped_prev_out, confidence_map) or (None, None) on the first frame."""
        if self.prev_src is None or self.prev_src.shape != cur_src.shape:
            return None, None
        fl = flow(self.prev_src, cur_src)
        return warp(self.prev_out, fl), confidence(self.prev_src, cur_src, fl, threshold)

    def update(self, src: np.ndarray, out: np.ndarray):
        self.prev_src, self.prev_out = src, out

    def reset(self):
        self.prev_src = self.prev_out = None
