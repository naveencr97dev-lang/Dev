"""Face alignment, masks and temporal landmark smoothing (CPU, numpy/OpenCV only)."""
from __future__ import annotations

import math
import numpy as np
import cv2


def crop_transform(bbox: np.ndarray, size: int, scale: float) -> np.ndarray:
    """2x3 affine mapping frame -> square crop centred on bbox (x1,y1,x2,y2)."""
    x1, y1, x2, y2 = bbox
    cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
    side = max(x2 - x1, y2 - y1) * scale
    s = size / max(side, 1e-6)
    return np.array([[s, 0, size / 2 - s * cx], [0, s, size / 2 - s * cy]], dtype=np.float32)


def warp_to_crop(frame: np.ndarray, M: np.ndarray, size: int) -> np.ndarray:
    return cv2.warpAffine(frame, M, (size, size), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def warp_from_crop(crop: np.ndarray, M: np.ndarray, frame_shape) -> np.ndarray:
    h, w = frame_shape[:2]
    Minv = cv2.invertAffineTransform(M)
    return cv2.warpAffine(crop, Minv, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)


def transform_points(pts: np.ndarray, M: np.ndarray) -> np.ndarray:
    pts = np.asarray(pts, dtype=np.float32)
    return pts @ M[:, :2].T + M[:, 2]


def face_mask(landmarks_crop: np.ndarray, size: int, dilate: float, feather: float,
              forehead_lift: float = 0.25) -> np.ndarray:
    """Soft [0,1] float mask covering the face (convex hull of landmarks, extended to forehead)."""
    pts = np.asarray(landmarks_crop, dtype=np.float32)
    # Landmark sets stop at the brows; mirror the lower face upward to cover the forehead.
    top = pts[:, 1].min()
    bottom = pts[:, 1].max()
    lift = (bottom - top) * forehead_lift
    upper = pts[pts[:, 1] < (top + (bottom - top) * 0.35)].copy()
    upper[:, 1] -= lift
    hull = cv2.convexHull(np.concatenate([pts, upper]).astype(np.int32))
    m = np.zeros((size, size), np.uint8)
    cv2.fillConvexPoly(m, hull, 255)
    k = max(1, int(size * dilate)) | 1
    m = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    f = max(1, int(size * feather)) | 1
    m = cv2.GaussianBlur(m, (f * 2 + 1, f * 2 + 1), 0)
    return (m.astype(np.float32) / 255.0)


class OneEuroFilter:
    """One-euro filter (Casiez et al. 2012) for jitter-free landmarks/bboxes across frames."""

    def __init__(self, freq: float, min_cutoff: float = 1.0, beta: float = 0.0, d_cutoff: float = 1.0):
        self.freq, self.min_cutoff, self.beta, self.d_cutoff = freq, min_cutoff, beta, d_cutoff
        self.x_prev = None
        self.dx_prev = None

    @staticmethod
    def _alpha(cutoff: float, freq: float) -> float:
        tau = 1.0 / (2 * math.pi * cutoff)
        return 1.0 / (1.0 + tau * freq)

    def reset(self):
        self.x_prev = self.dx_prev = None

    def __call__(self, x: np.ndarray) -> np.ndarray:
        x = np.asarray(x, dtype=np.float64)
        if self.x_prev is None:
            self.x_prev, self.dx_prev = x, np.zeros_like(x)
            return x.astype(np.float32)
        dx = (x - self.x_prev) * self.freq
        a_d = self._alpha(self.d_cutoff, self.freq)
        dx_hat = a_d * dx + (1 - a_d) * self.dx_prev
        cutoff = self.min_cutoff + self.beta * np.abs(dx_hat)
        a = 1.0 / (1.0 + (1.0 / (2 * math.pi * cutoff)) * self.freq)
        x_hat = a * x + (1 - a) * self.x_prev
        self.x_prev, self.dx_prev = x_hat, dx_hat
        return x_hat.astype(np.float32)
