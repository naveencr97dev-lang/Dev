"""End-to-end video face swap with temporal consistency."""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile

import numpy as np
import cv2

from .config import SwapConfig
from .geometry import crop_transform, warp_to_crop, warp_from_crop, transform_points, face_mask, OneEuroFilter
from .blend import match_color, alpha_composite, add_label
from .temporal import TemporalState
from .faces import TargetTracker


class FrameSwapper:
    def __init__(self, cfg: SwapConfig, analyzer, generator, identity: np.ndarray, fps: float):
        self.cfg, self.analyzer, self.gen, self.identity = cfg, analyzer, generator, identity
        self.tracker = TargetTracker(cfg.target_face_index)
        self.bbox_f = OneEuroFilter(fps, cfg.landmark_min_cutoff, cfg.landmark_beta)
        self.lm_f = OneEuroFilter(fps, cfg.landmark_min_cutoff, cfg.landmark_beta)
        self.temporal = TemporalState()
        self.n = 0
        self.stats = {"frames": 0, "swapped": 0, "skipped": 0, "retries": 0, "id_sim": []}

    def __call__(self, frame: np.ndarray) -> np.ndarray:
        cfg = self.cfg
        self.stats["frames"] += 1
        face = self.tracker.select(self.analyzer(frame))
        if face is None:
            # Lost the dancer (turned away / occluded): don't hallucinate, reset temporal priors.
            self.stats["skipped"] += 1
            self.temporal.reset(); self.bbox_f.reset(); self.lm_f.reset()
            return frame

        bbox = self.bbox_f(face.bbox)
        lms = self.lm_f(face.landmarks)
        M = crop_transform(bbox, cfg.crop_size, cfg.crop_scale)
        src = warp_to_crop(frame, M, cfg.crop_size)
        mask = face_mask(transform_points(lms, M), cfg.crop_size, cfg.mask_dilate, cfg.mask_feather)

        # Temporal prior: warp last output into this frame and mix into the diffusion init.
        keyframe = cfg.keyframe_interval > 0 and self.n % cfg.keyframe_interval == 0
        prior, conf = (None, None) if keyframe else self.temporal.prior(src, cfg.flow_error_threshold)
        init = src
        if prior is not None:
            w = (cfg.temporal_init_weight * conf * mask)
            init = alpha_composite(src, prior, w)

        out, ip = None, cfg.ip_adapter_scale
        for attempt in range(cfg.max_retries + 1):
            out = self.gen.generate(init, mask, self.identity, cfg.strength, ip)
            sim = self._identity_sim(out)
            if sim is None or sim >= cfg.min_identity_sim:
                break
            self.stats["retries"] += 1
            ip = min(1.2, ip + 0.15)  # identity too weak -> push adapter harder
        if sim is not None:
            self.stats["id_sim"].append(sim)

        out = match_color(out, src, mask)
        if prior is not None:
            out = alpha_composite(out, prior, cfg.temporal_blend_weight * conf * mask)
        self.temporal.update(src, out)

        # Composite back into the full frame.
        h, w = frame.shape[:2]
        full = warp_from_crop(out, M, frame.shape)
        full_mask = warp_from_crop(mask, M, (h, w))
        self.n += 1
        self.stats["swapped"] += 1
        return alpha_composite(frame, full, full_mask)

    def _identity_sim(self, crop: np.ndarray):
        if self.analyzer is None or not hasattr(self.analyzer, "__call__"):
            return None
        faces = self.analyzer(crop)
        if not faces:
            return None
        best = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        return float(best.embedding @ self.identity)


def swap_video(src_path: str, out_path: str, swapper_factory, cfg: SwapConfig,
               max_frames: int | None = None, progress=True) -> dict:
    cap = cv2.VideoCapture(src_path)
    if not cap.isOpened():
        raise FileNotFoundError(src_path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w, h = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    swapper = swapper_factory(fps)

    tmp = tempfile.mkdtemp(prefix="dancefs_")
    silent = os.path.join(tmp, "video.mp4")
    vw = cv2.VideoWriter(silent, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok or (max_frames and i >= max_frames):
            break
        out = swapper(frame)
        if cfg.watermark:
            out = add_label(out, cfg.watermark_text)
        vw.write(out)
        i += 1
        if progress and i % 10 == 0:
            print(f"\r{i}/{total or '?'} frames", end="", flush=True)
    cap.release(); vw.release()
    if progress:
        print()
    _mux(silent, src_path, out_path)
    shutil.rmtree(tmp, ignore_errors=True)
    s = dict(swapper.stats)
    sims = s.pop("id_sim")
    s["mean_identity_sim"] = float(np.mean(sims)) if sims else None
    return s


def _mux(video: str, audio_src: str, out: str):
    """H.264 encode + copy original music track, with an AI-disclosure metadata tag."""
    if shutil.which("ffmpeg") is None:
        shutil.copy(video, out); return
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", video, "-i", audio_src,
           "-map", "0:v:0", "-map", "1:a:0?", "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-shortest", "-metadata", "comment=AI-generated face replacement (dancefs)", out]
    if subprocess.run(cmd).returncode != 0:
        shutil.copy(video, out)
