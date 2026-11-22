"""dancefs CLI.

  python -m dancefs.cli --video dance.mp4 --ref me1.jpg me2.jpg me3.jpg \
      --out out.mp4 --consent --consent-note "self"
"""
from __future__ import annotations

import argparse
import json

import cv2

from .config import SwapConfig
from .provenance import require_consent, write_sidecar


def main(argv=None):
    p = argparse.ArgumentParser(description="Diffusion face swap for dance videos (consenting subjects only).")
    p.add_argument("--video", required=True)
    p.add_argument("--ref", nargs="+", required=True, help="1-10 photos of the consenting person")
    p.add_argument("--out", required=True)
    p.add_argument("--consent", action="store_true", help="I confirm the reference person consented")
    p.add_argument("--consent-note", help="Who consented and how")
    p.add_argument("--model", default=None, help="Override base inpainting model")
    p.add_argument("--sd15", action="store_true", help="Use SD1.5 (lower VRAM, 512px)")
    p.add_argument("--strength", type=float)
    p.add_argument("--id-scale", type=float)
    p.add_argument("--steps", type=int)
    p.add_argument("--seed", type=int)
    p.add_argument("--target", type=int, default=-1, help="Face index left->right in first frame; -1=largest")
    p.add_argument("--max-frames", type=int)
    p.add_argument("--dry-run", action="store_true", help="No diffusion: test tracking/masks/blending on CPU")
    a = p.parse_args(argv)

    require_consent(a.consent, a.consent_note)

    cfg = SwapConfig(target_face_index=a.target)
    if a.sd15:
        cfg.base_model = "stable-diffusion-v1-5/stable-diffusion-inpainting"
        cfg.ip_adapter_weight = "ip-adapter-faceid_sd15.bin"
        cfg.crop_size = 512
    for k, v in {"base_model": a.model, "strength": a.strength, "ip_adapter_scale": a.id_scale,
                 "steps": a.steps, "seed": a.seed}.items():
        if v is not None:
            setattr(cfg, k, v)

    from .faces import FaceAnalyzer, reference_identity
    from .diffusion import SDXLFaceIDGenerator, PassthroughGenerator
    from .pipeline import FrameSwapper, swap_video

    analyzer = FaceAnalyzer()
    identity = reference_identity(analyzer, [cv2.imread(r) for r in a.ref])
    gen = PassthroughGenerator() if a.dry_run else SDXLFaceIDGenerator(cfg)

    stats = swap_video(a.video, a.out, lambda fps: FrameSwapper(cfg, analyzer, gen, identity, fps),
                       cfg, max_frames=a.max_frames)
    sidecar = write_sidecar(a.out, a.video, a.ref, a.consent_note, cfg)
    print(json.dumps({"output": a.out, "provenance": str(sidecar), **stats}, indent=2))


if __name__ == "__main__":
    main()
