"""Extra face-swap backends, so you can plug in models you already have (e.g. on RunPod).

  inswapper : InsightFace inswapper_128.onnx (also what roop/FaceFusion/ReActor use). Fast but 128px.
  hybrid    : inswapper first for the identity, then a low-strength SDXL FaceID pass to add back
              resolution, skin texture and lighting. Usually the best quality-for-speed trade-off.
  diffusion : SDXL inpaint + IP-Adapter FaceID only (see diffusion.py).

Every backend uses the same FaceGenerator interface, so tracking, temporal smoothing,
blending and provenance stay the same whichever model you choose.
"""
from __future__ import annotations

from types import SimpleNamespace

import numpy as np

from .diffusion import FaceGenerator


class InswapperGenerator(FaceGenerator):
    def __init__(self, model_path: str, analyzer, providers=None):
        import insightface
        self.analyzer = analyzer  # FaceAnalyzer; its .app gives raw insightface faces (with kps)
        self.model = insightface.model_zoo.get_model(
            model_path, providers=providers or ["CUDAExecutionProvider", "CPUExecutionProvider"])

    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        faces = self.analyzer.app.get(init_bgr)
        if not faces:
            return init_bgr.copy()
        target = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        source = SimpleNamespace(normed_embedding=identity.astype(np.float32))  # all inswapper reads
        return self.model.get(init_bgr, target, source, paste_back=True)


class HybridGenerator(FaceGenerator):
    """`pre` swaps the identity, then `refine` diffuses lightly over it to restore detail."""

    def __init__(self, pre: FaceGenerator, refine: FaceGenerator, refine_strength: float = 0.3):
        self.pre, self.refine, self.refine_strength = pre, refine, refine_strength

    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        swapped = self.pre.generate(init_bgr, mask, identity, strength, ip_scale)
        return self.refine.generate(swapped, mask, identity, self.refine_strength, ip_scale)


BACKENDS = ("diffusion", "inswapper", "hybrid")


def build_generator(backend: str, cfg, analyzer, swap_model: str | None = None,
                    refine_strength: float = 0.3, dry_run: bool = False) -> FaceGenerator:
    from .diffusion import SDXLFaceIDGenerator, PassthroughGenerator
    if dry_run:
        return PassthroughGenerator()
    if backend == "diffusion":
        return SDXLFaceIDGenerator(cfg)
    if not swap_model:
        raise ValueError(f"backend '{backend}' needs --swap-model (path to e.g. inswapper_128.onnx)")
    pre = InswapperGenerator(swap_model, analyzer)
    if backend == "inswapper":
        return pre
    if backend == "hybrid":
        return HybridGenerator(pre, SDXLFaceIDGenerator(cfg), refine_strength)
    raise ValueError(f"unknown backend {backend!r}; choose from {BACKENDS}")
