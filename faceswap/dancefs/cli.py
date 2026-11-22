"""dancefs CLI.

  # diffusion only
  python -m dancefs.cli --video dance.mp4 --ref me1.jpg me2.jpg --out out.mp4 --consent --consent-note self
  # your existing inswapper model + diffusion refine (recommended)
  python -m dancefs.cli ... --backend hybrid --swap-model /workspace/models/inswapper_128.onnx
"""
from __future__ import annotations

import argparse
import json

from .config import SwapConfig
from .backends import BACKENDS
from .job import run_job


def main(argv=None):
    p = argparse.ArgumentParser(description="Diffusion face swap for dance videos (consenting subjects only).")
    p.add_argument("--video", required=True)
    p.add_argument("--ref", nargs="+", required=True, help="1-10 photos of the consenting person")
    p.add_argument("--out", required=True)
    p.add_argument("--consent", action="store_true", help="I confirm the reference person consented")
    p.add_argument("--consent-note", help="Who consented and how")
    p.add_argument("--backend", choices=BACKENDS, default="diffusion")
    p.add_argument("--swap-model", help="Path to an inswapper-compatible .onnx (inswapper/hybrid)")
    p.add_argument("--refine-strength", type=float, default=0.3, help="Hybrid: diffusion strength over the swap")
    p.add_argument("--identity-lora", help="Dir of a LoRA from `python -m dancefs.train_identity`")
    p.add_argument("--lora-scale", type=float)
    p.add_argument("--model", default=None, help="Override base inpainting model (HF id or local path)")
    p.add_argument("--sd15", action="store_true", help="Use SD1.5 (lower VRAM, 512px)")
    p.add_argument("--strength", type=float)
    p.add_argument("--id-scale", type=float)
    p.add_argument("--steps", type=int)
    p.add_argument("--seed", type=int)
    p.add_argument("--target", type=int, default=-1, help="Face index left->right in first frame; -1=largest")
    p.add_argument("--max-frames", type=int)
    p.add_argument("--dry-run", action="store_true", help="No generation: test tracking/masks/blending on CPU")
    a = p.parse_args(argv)
    print(json.dumps(run_job(a.video, a.ref, a.out, a.consent, a.consent_note, config_from_args(a),
                             a.backend, a.swap_model, a.refine_strength, a.dry_run, a.max_frames), indent=2))


def config_from_args(a) -> SwapConfig:
    cfg = SwapConfig(target_face_index=a.target)
    if a.sd15:
        cfg.base_model = "stable-diffusion-v1-5/stable-diffusion-inpainting"
        cfg.ip_adapter_weight = "ip-adapter-faceid_sd15.bin"
        cfg.crop_size = 512
    for k, v in {"base_model": a.model, "strength": a.strength, "ip_adapter_scale": a.id_scale,
                 "steps": a.steps, "seed": a.seed,
                 "identity_lora": a.identity_lora, "identity_lora_scale": a.lora_scale}.items():
        if v is not None:
            setattr(cfg, k, v)
    return cfg


if __name__ == "__main__":
    main()
