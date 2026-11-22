"""RunPod Serverless worker for dancefs.

Job input:
{
  "video_url": "https://.../dance.mp4",
  "ref_urls": ["https://.../me1.jpg", "https://.../me2.jpg"],
  "consent": true,
  "consent_note": "self",
  "backend": "hybrid",                       # diffusion | inswapper | hybrid
  "swap_model": "inswapper_128.onnx",        # file name under $MODELS_DIR (your network volume)
  "options": {"strength": 0.6, "ip_adapter_scale": 0.8, "steps": 25, "seed": 1234,
              "refine_strength": 0.3, "target_face_index": -1, "max_frames": null, "sd15": false},
  "output_upload_url": "https://<presigned S3/R2 PUT url>"   # optional
}
Output: stats + provenance, plus "output_url" if you passed an upload URL, otherwise
"output_base64" (only for small clips: RunPod limits the size of results).
"""
from __future__ import annotations

import base64
import json
import os
import sys
import tempfile
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dancefs.config import SwapConfig  # noqa: E402
from dancefs.provenance import ConsentError  # noqa: E402

MODELS_DIR = Path(os.environ.get("MODELS_DIR", "/runpod-volume/models"))
MAX_INLINE_BYTES = int(os.environ.get("MAX_INLINE_BYTES", 15 * 1024 * 1024))
OPTION_KEYS = {"strength", "ip_adapter_scale", "steps", "seed", "guidance_scale", "target_face_index",
               "temporal_init_weight", "temporal_blend_weight", "keyframe_interval", "base_model"}


class InputError(ValueError):
    pass


def resolve_model(name: str | None) -> str | None:
    """Only allow model files that are inside MODELS_DIR (no path traversal)."""
    if not name:
        return None
    p = (MODELS_DIR / name).resolve()
    if MODELS_DIR.resolve() not in p.parents or not p.is_file():
        raise InputError(f"swap_model {name!r} not found under {MODELS_DIR}")
    return str(p)


def resolve_dir(name: str | None, sub: str = "loras") -> str | None:
    if not name:
        return None
    base = (MODELS_DIR / sub).resolve()
    p = (base / name).resolve()
    if base not in p.parents or not p.is_dir():
        raise InputError(f"{sub[:-1]} {name!r} not found under {base}")
    return str(p)


def download(url: str, dest: Path) -> str:
    if not url.startswith(("https://", "http://")):
        raise InputError(f"only http(s) URLs are accepted: {url!r}")
    with urllib.request.urlopen(url, timeout=120) as r, open(dest, "wb") as f:
        while chunk := r.read(1 << 20):
            f.write(chunk)
    return str(dest)


def upload(path: str, url: str):
    data = Path(path).read_bytes()
    req = urllib.request.Request(url, data=data, method="PUT", headers={"Content-Type": "video/mp4"})
    urllib.request.urlopen(req, timeout=300).read()


def build_config(opts: dict) -> SwapConfig:
    cfg = SwapConfig()
    if opts.get("sd15"):
        cfg.base_model = "stable-diffusion-v1-5/stable-diffusion-inpainting"
        cfg.ip_adapter_weight = "ip-adapter-faceid_sd15.bin"
        cfg.crop_size = 512
    for k in OPTION_KEYS & opts.keys():
        setattr(cfg, k, opts[k])
    return cfg


def handler(job: dict, runner=None) -> dict:
    inp = job.get("input") or {}
    try:
        if not inp.get("consent") or not inp.get("consent_note"):
            raise ConsentError("consent=true and consent_note are required")
        opts = inp.get("options") or {}
        if inp.get("task") == "train_identity":
            return train_identity(inp, opts)
        if not inp.get("video_url") or not inp.get("ref_urls"):
            raise InputError("video_url and ref_urls are required")
        cfg = build_config(opts)
        cfg.identity_lora = resolve_dir(inp.get("identity_lora"))
        swap_model = resolve_model(inp.get("swap_model"))
        backend = inp.get("backend", "hybrid" if swap_model else "diffusion")

        if runner is None:
            from dancefs.job import run_job as runner

        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            video = download(inp["video_url"], td / "in.mp4")
            refs = [download(u, td / f"ref{i}.jpg") for i, u in enumerate(inp["ref_urls"][:10])]
            out = str(td / "out.mp4")
            result = runner(video, refs, out, True, inp["consent_note"], cfg, backend, swap_model,
                            opts.get("refine_strength", 0.3), False, opts.get("max_frames"), False)
            result["provenance"] = json.loads(Path(result["provenance"]).read_text())
            if inp.get("output_upload_url"):
                upload(out, inp["output_upload_url"])
                result["output_url"] = inp["output_upload_url"].split("?")[0]
            elif os.path.getsize(out) <= MAX_INLINE_BYTES:
                result["output_base64"] = base64.b64encode(Path(out).read_bytes()).decode()
            else:
                raise InputError("output too large to return inline; pass output_upload_url")
            result.pop("output", None)
            return result
    except (ConsentError, InputError) as e:
        return {"error": str(e)}


LORA_NAME_OK = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")


def train_identity(inp: dict, opts: dict, trainer=None) -> dict:
    """Train an identity LoRA from ref_urls and store it at $MODELS_DIR/loras/<lora_name>."""
    name = inp.get("lora_name", "")
    if not name or not set(name) <= LORA_NAME_OK or len(name) > 64:
        raise InputError("lora_name is required (letters, digits, - and _ only)")
    if not inp.get("ref_urls"):
        raise InputError("ref_urls are required")
    from dancefs.train_identity import TrainConfig
    cfg = TrainConfig()
    for k in ("steps", "rank", "lr", "resolution", "trigger", "base_model"):
        if k in opts:
            setattr(cfg, k, opts[k])
    import cv2
    if trainer is None:
        from dancefs.train_identity import train as trainer
    analyzer = None
    if not opts.get("no_detector"):
        from dancefs.faces import FaceAnalyzer
        analyzer = FaceAnalyzer()
    out = MODELS_DIR / "loras" / name
    with tempfile.TemporaryDirectory() as td:
        refs = [download(u, Path(td) / f"ref{i}.jpg") for i, u in enumerate(inp["ref_urls"][:40])]
        res = trainer([cv2.imread(r) for r in refs], str(out), cfg, analyzer,
                      consent_note=inp["consent_note"], ref_paths=refs, log_every=50)
    res.pop("loss_history", None)
    res["identity_lora"] = name
    return res


if __name__ == "__main__":
    import runpod
    runpod.serverless.start({"handler": handler})
