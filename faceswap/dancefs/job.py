"""One function that runs a full job; shared by the CLI and the RunPod handler."""
from __future__ import annotations

import cv2

from .config import SwapConfig
from .provenance import require_consent, write_sidecar

_CACHE: dict = {}


def run_job(video: str, refs: list[str], out: str, consent: bool, consent_note: str | None,
            cfg: SwapConfig, backend: str = "diffusion", swap_model: str | None = None,
            refine_strength: float = 0.3, dry_run: bool = False, max_frames: int | None = None,
            progress: bool = True) -> dict:
    require_consent(consent, consent_note)

    from .faces import FaceAnalyzer, reference_identity
    from .backends import build_generator
    from .pipeline import FrameSwapper, swap_video

    # Cache models across jobs: a warm RunPod worker skips the 20-60 s model load.
    if "analyzer" not in _CACHE:
        _CACHE["analyzer"] = FaceAnalyzer()
    analyzer = _CACHE["analyzer"]
    key = (backend, swap_model, cfg.base_model, cfg.ip_adapter_weight, refine_strength, dry_run)
    if _CACHE.get("gen_key") != key:
        _CACHE.pop("gen", None)  # free VRAM before loading another model
        _CACHE["gen"] = build_generator(backend, cfg, analyzer, swap_model, refine_strength, dry_run)
        _CACHE["gen_key"] = key
    gen = _CACHE["gen"]
    if hasattr(gen, "cfg"):
        gen.cfg = cfg  # per-job steps/seed/strength without reloading weights
    identity = reference_identity(analyzer, [cv2.imread(r) for r in refs])
    stats = swap_video(video, out, lambda fps: FrameSwapper(cfg, analyzer, gen, identity, fps),
                       cfg, max_frames=max_frames, progress=progress)
    sidecar = write_sidecar(out, video, refs, consent_note, cfg)
    return {"output": out, "provenance": str(sidecar), "backend": backend, **stats}
