"""CPU tests: run the whole pipeline with a fake face detector and fake generators."""
import json
import os
import sys

import cv2
import numpy as np
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from dancefs.config import SwapConfig
from dancefs.faces import Face, TargetTracker
from dancefs.geometry import crop_transform, warp_to_crop, warp_from_crop, OneEuroFilter, face_mask
from dancefs.diffusion import FaceGenerator, PassthroughGenerator
from dancefs.pipeline import FrameSwapper, swap_video
from dancefs.provenance import require_consent, ConsentError, write_sidecar

ID = np.ones(512, np.float32) / np.sqrt(512)


def draw_frame(t, w=320, h=240):
    img = np.full((h, w, 3), 60, np.uint8)
    cx, cy = int(100 + 60 * np.sin(t / 6)), int(120 + 20 * np.cos(t / 5))
    cv2.ellipse(img, (cx, cy), (28, 36), 0, 0, 360, (140, 170, 210), -1)
    return img, (cx, cy)


class FakeAnalyzer:
    """Finds the drawn ellipse; jitters bbox like a real detector would."""
    def __init__(self, jitter=2.0, seed=0):
        self.rng = np.random.default_rng(seed); self.jitter = jitter

    def __call__(self, img):
        m = cv2.inRange(img, (130, 160, 200), (150, 180, 220))
        ys, xs = np.nonzero(m)
        if len(xs) < 50:
            return []
        j = self.rng.normal(0, self.jitter, 4)
        bbox = np.array([xs.min(), ys.min(), xs.max(), ys.max()], np.float32) + j
        cx, cy = (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2
        ang = np.linspace(0, 2 * np.pi, 20, endpoint=False)
        lms = np.stack([cx + 26 * np.cos(ang), cy + 34 * np.sin(ang)], 1).astype(np.float32)
        return [Face(bbox, lms, ID.copy(), 0.99)]


class NoisyGenerator(FaceGenerator):
    """Simulates diffusion flicker: shifts colour randomly per frame inside the mask."""
    def __init__(self): self.rng = np.random.default_rng(1)
    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        tint = np.array([0, 0, 255], np.float32) * 0.5 + self.rng.normal(0, 25, 3)
        out = init_bgr.astype(np.float32) * 0.5 + tint
        return np.clip(out + self.rng.normal(0, 10, out.shape), 0, 255).astype(np.uint8)


def small_cfg(**kw):
    c = SwapConfig(crop_size=128, crop_scale=2.0, watermark=False, max_retries=0, **kw)
    return c


def test_crop_roundtrip():
    img, _ = draw_frame(0)
    M = crop_transform(np.array([70, 80, 130, 160], np.float32), 128, 2.0)
    back = warp_from_crop(warp_to_crop(img, M, 128), M, img.shape)
    region = (slice(95, 145), slice(80, 120))
    assert np.abs(back[region].astype(int) - img[region].astype(int)).mean() < 3


def test_mask_soft_and_covers_face():
    ang = np.linspace(0, 2 * np.pi, 20)
    lms = np.stack([64 + 20 * np.cos(ang), 64 + 25 * np.sin(ang)], 1)
    m = face_mask(lms, 128, 0.05, 0.05)
    assert m[64, 64] > 0.99 and m[0, 0] < 0.01
    assert ((m > 0.05) & (m < 0.95)).sum() > 100  # feathered edge


def test_one_euro_reduces_jitter():
    rng = np.random.default_rng(0)
    f = OneEuroFilter(30, min_cutoff=1.0, beta=0.0)
    raw = 100 + rng.normal(0, 3, 200)
    sm = np.array([f(np.array([x]))[0] for x in raw])
    assert np.std(np.diff(sm[20:])) < 0.5 * np.std(np.diff(raw[20:]))


def test_tracker_sticks_to_target():
    a = Face(np.array([0, 0, 50, 50], np.float32), np.zeros((5, 2)), ID, 1)
    other = np.zeros(512, np.float32); other[0] = 1
    b = Face(np.array([200, 0, 280, 80], np.float32), np.zeros((5, 2)), other, 1)
    t = TargetTracker(index=0)
    assert t.select([a, b]) is a
    a2 = Face(np.array([5, 2, 55, 52], np.float32), np.zeros((5, 2)), ID, 1)
    assert t.select([b, a2]) is a2  # even when larger face present


def run(cfg, gen, n=40):
    sw = FrameSwapper(cfg, FakeAnalyzer(), gen, ID, fps=30)
    sw._identity_sim = lambda crop: None
    frames, centers = [], []
    for t in range(n):
        f, c = draw_frame(t); frames.append(sw(f)); centers.append(c)
    return frames, centers, sw


def face_color_series(frames, centers):
    return np.array([f[c[1] - 8:c[1] + 8, c[0] - 8:c[0] + 8].reshape(-1, 3).mean(0)
                     for f, c in zip(frames, centers)])


def test_swap_changes_face_not_background():
    frames, centers, sw = run(small_cfg(), NoisyGenerator(), n=10)
    src, c = draw_frame(9)
    out = frames[-1]
    assert np.abs(out[5:30, 250:310].astype(int) - src[5:30, 250:310].astype(int)).max() == 0  # background
    assert np.abs(out[c[1], c[0]].astype(int) - src[c[1], c[0]].astype(int)).sum() > 0  # face edited
    assert sw.stats["swapped"] == 10


def test_temporal_consistency_reduces_flicker():
    off = small_cfg(temporal_init_weight=0.0, temporal_blend_weight=0.0)
    on = small_cfg(temporal_init_weight=0.6, temporal_blend_weight=0.6, flow_error_threshold=40)
    s_off = face_color_series(*run(off, NoisyGenerator())[:2])
    s_on = face_color_series(*run(on, NoisyGenerator())[:2])
    flick_off = np.abs(np.diff(s_off, axis=0)).mean()
    flick_on = np.abs(np.diff(s_on, axis=0)).mean()
    print(f"flicker off={flick_off:.2f} on={flick_on:.2f}")
    assert flick_on < 0.8 * flick_off


def test_consent_gate():
    with pytest.raises(ConsentError):
        require_consent(False, "self")
    with pytest.raises(ConsentError):
        require_consent(True, None)
    require_consent(True, "self")


def test_end_to_end_video(tmp_path):
    src = str(tmp_path / "dance.mp4")
    vw = cv2.VideoWriter(src, cv2.VideoWriter_fourcc(*"mp4v"), 30, (320, 240))
    for t in range(30):
        vw.write(draw_frame(t)[0])
    vw.release()
    ref = str(tmp_path / "ref.png"); cv2.imwrite(ref, draw_frame(0)[0])
    out = str(tmp_path / "out.mp4")
    cfg = small_cfg(); cfg.watermark = True
    stats = swap_video(src, out, lambda fps: _sw(cfg, fps), cfg, progress=False)
    assert os.path.getsize(out) > 0 and stats["swapped"] == 30
    side = write_sidecar(out, src, [ref], "self", cfg)
    d = json.loads(side.read_text())
    assert d["ai_generated"] is True and d["consent_note"] == "self"


def _sw(cfg, fps):
    s = FrameSwapper(cfg, FakeAnalyzer(), PassthroughGenerator(), ID, fps)
    s._identity_sim = lambda crop: None
    return s
