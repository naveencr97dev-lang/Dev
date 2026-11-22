"""Train a personal *identity LoRA* for SDXL (inpainting) — consenting subjects only.

Why: IP-Adapter FaceID alone gives a "looks related" likeness. A small LoRA trained on 10-30
photos of the person teaches SDXL that exact face, so the swap holds identity through
head turns, expressions and motion blur. It plugs straight into dancefs (`--identity-lora`).

Design choices that matter for face swapping:
  * Trains on the SAME aligned face crops (crop_transform + crop_scale) the swap pipeline uses,
    so train and inference see identical framing.
  * Inpainting-aware: if the base UNet has 9 input channels (SDXL inpaint), it trains with the
    real inpaint inputs (noisy latents + face mask + masked-image latents), using face-shaped masks.
  * Loss is up-weighted inside the face mask so capacity goes to identity, not background.
  * Only LoRA attention weights train (rank 16 default, ~25-50 MB file); text encoders frozen,
    prompt embeddings computed once.

  python -m dancefs.train_identity --refs photos/me/*.jpg --out models/loras/me \
      --consent --consent-note "self"
"""
from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass, asdict
from pathlib import Path

import cv2
import numpy as np

from .geometry import crop_transform, warp_to_crop, transform_points, face_mask
from .provenance import require_consent, sha256


@dataclass
class TrainConfig:
    base_model: str = "diffusers/stable-diffusion-xl-1.0-inpainting-0.1"
    trigger: str = "ohwx"                 # rare token that will mean "this person"
    resolution: int = 1024
    crop_scale: float = 2.0               # keep equal to SwapConfig.crop_scale
    rank: int = 16
    steps: int = 1200
    lr: float = 1e-4
    batch_size: int = 1
    grad_accum: int = 2
    face_loss_weight: float = 2.0         # extra loss weight inside the face mask
    random_mask_prob: float = 0.2         # sometimes use a random mask for robustness
    seed: int = 42
    gradient_checkpointing: bool = True
    save_every: int = 0                   # 0 = only at the end
    device: str = "cuda"

    @property
    def prompt(self) -> str:
        return f"photo of {self.trigger} person's face, natural skin texture, sharp focus"


# ---------------------------------------------------------------- data

def prepare_examples(images: list[np.ndarray], size: int, crop_scale: float, analyzer=None):
    """-> list of (crop_bgr uint8 [size,size,3], mask float [size,size]) aligned like the swap pipeline."""
    out = []
    for img in images:
        if img is None:
            continue
        if analyzer is not None:
            faces = analyzer(img)
            if not faces:
                continue
            f = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
            M = crop_transform(f.bbox, size, crop_scale)
            crop = warp_to_crop(img, M, size)
            mask = face_mask(transform_points(f.landmarks, M), size, 0.06, 0.05)
        else:  # no detector (tests / pre-cropped faces): centre crop + centred ellipse
            h, w = img.shape[:2]
            s = min(h, w)
            crop = cv2.resize(img[(h - s) // 2:(h + s) // 2, (w - s) // 2:(w + s) // 2], (size, size))
            mask = _ellipse_mask(size)
        out.append((crop, mask))
    if not out:
        raise ValueError("No usable face found in the reference images.")
    return out


def _ellipse_mask(size, cx=0.5, cy=0.5, rx=0.22, ry=0.3):
    m = np.zeros((size, size), np.uint8)
    cv2.ellipse(m, (int(cx * size), int(cy * size)), (int(rx * size), int(ry * size)), 0, 0, 360, 255, -1)
    return cv2.GaussianBlur(m, (0, 0), size * 0.03).astype(np.float32) / 255.0


def augment(crop: np.ndarray, mask: np.ndarray, rng: random.Random, random_mask_prob: float):
    size = crop.shape[0]
    if rng.random() < 0.5:
        crop, mask = crop[:, ::-1].copy(), mask[:, ::-1].copy()
    # small scale / rotation / shift (dancers' faces are never perfectly centred)
    ang, sc = rng.uniform(-8, 8), rng.uniform(0.92, 1.08)
    tx, ty = rng.uniform(-0.04, 0.04) * size, rng.uniform(-0.04, 0.04) * size
    A = cv2.getRotationMatrix2D((size / 2, size / 2), ang, sc)
    A[:, 2] += (tx, ty)
    crop = cv2.warpAffine(crop, A, (size, size), borderMode=cv2.BORDER_REFLECT)
    mask = cv2.warpAffine(mask, A, (size, size), borderMode=cv2.BORDER_CONSTANT)
    # photometric jitter (stage lighting, colour grading)
    a, b = rng.uniform(0.85, 1.15), rng.uniform(-15, 15)
    crop = np.clip(crop.astype(np.float32) * a + b, 0, 255).astype(np.uint8)
    if rng.random() < random_mask_prob:
        mask = _ellipse_mask(size, rng.uniform(0.35, 0.65), rng.uniform(0.35, 0.65),
                             rng.uniform(0.15, 0.35), rng.uniform(0.15, 0.4))
    return crop, mask


# ---------------------------------------------------------------- model

def load_components(base_model: str, device: str, dtype):
    from diffusers import AutoencoderKL, DDPMScheduler, UNet2DConditionModel
    from transformers import CLIPTextModel, CLIPTextModelWithProjection, CLIPTokenizer
    c = dict(
        tok1=CLIPTokenizer.from_pretrained(base_model, subfolder="tokenizer"),
        tok2=CLIPTokenizer.from_pretrained(base_model, subfolder="tokenizer_2"),
        te1=CLIPTextModel.from_pretrained(base_model, subfolder="text_encoder", torch_dtype=dtype),
        te2=CLIPTextModelWithProjection.from_pretrained(base_model, subfolder="text_encoder_2", torch_dtype=dtype),
        vae=AutoencoderKL.from_pretrained(base_model, subfolder="vae"),  # fp32: SDXL VAE overflows in fp16
        unet=UNet2DConditionModel.from_pretrained(base_model, subfolder="unet", torch_dtype=dtype),
        scheduler=DDPMScheduler.from_pretrained(base_model, subfolder="scheduler"),
    )
    for k in ("te1", "te2", "vae", "unet"):
        c[k].to(device).requires_grad_(False)
    return c


def encode_prompt(c, prompt: str, device):
    import torch
    hidden, pooled = [], None
    with torch.no_grad():
        for tok, te in ((c["tok1"], c["te1"]), (c["tok2"], c["te2"])):
            ids = tok(prompt, padding="max_length", max_length=tok.model_max_length,
                      truncation=True, return_tensors="pt").input_ids.to(device)
            o = te(ids, output_hidden_states=True)
            hidden.append(o.hidden_states[-2])
            pooled = o[0]  # text_encoder_2 projection output
    return torch.cat(hidden, dim=-1), pooled


def train(images: list[np.ndarray], out_dir: str, cfg: TrainConfig, analyzer=None,
          components=None, consent_note: str = "", ref_paths: list[str] | None = None,
          log_every: int = 25) -> dict:
    import torch
    import torch.nn.functional as F
    from peft import LoraConfig
    from peft.utils import get_peft_model_state_dict
    from diffusers import StableDiffusionXLPipeline
    from diffusers.utils import convert_state_dict_to_diffusers

    rng = random.Random(cfg.seed)
    torch.manual_seed(cfg.seed)
    device = cfg.device if (cfg.device != "cuda" or torch.cuda.is_available()) else "cpu"
    wdtype = torch.bfloat16 if device == "cuda" and torch.cuda.is_bf16_supported() else torch.float32
    c = components or load_components(cfg.base_model, device, wdtype)
    unet, vae, sched = c["unet"], c["vae"], c["scheduler"]
    inpaint = unet.config.in_channels == 9

    examples = prepare_examples(images, cfg.resolution, cfg.crop_scale, analyzer)
    prompt_embeds, pooled = encode_prompt(c, cfg.prompt, device)
    r = cfg.resolution
    time_ids = torch.tensor([[r, r, 0, 0, r, r]], device=device, dtype=prompt_embeds.dtype)

    unet.add_adapter(LoraConfig(r=cfg.rank, lora_alpha=cfg.rank, init_lora_weights="gaussian",
                                target_modules=["to_k", "to_q", "to_v", "to_out.0"]))
    params = [p for p in unet.parameters() if p.requires_grad]
    for p in params:
        p.data = p.data.float()  # LoRA weights train in fp32 even if the UNet is bf16
    if cfg.gradient_checkpointing and device == "cuda":
        unet.enable_gradient_checkpointing()
    opt = torch.optim.AdamW(params, lr=cfg.lr, weight_decay=1e-2)
    warm = max(1, cfg.steps // 20)
    lr_sched = torch.optim.lr_scheduler.LambdaLR(
        opt, lambda s: min(1.0, (s + 1) / warm) * 0.5 * (1 + math.cos(math.pi * min(s, cfg.steps) / cfg.steps)))
    sf = vae.config.scaling_factor
    pred_type = sched.config.prediction_type
    unet.train()

    def to_tensor(crop):
        x = torch.from_numpy(cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)).permute(2, 0, 1).float() / 127.5 - 1
        return x

    history = []
    for step in range(cfg.steps):
        for _ in range(cfg.grad_accum):
            batch = [augment(*rng.choice(examples), rng, cfg.random_mask_prob) for _ in range(cfg.batch_size)]
            x = torch.stack([to_tensor(b[0]) for b in batch]).to(device)
            m = torch.stack([torch.from_numpy(b[1]) for b in batch])[:, None].to(device)
            with torch.no_grad():
                lat = vae.encode(x).latent_dist.sample() * sf
                m_lat = F.interpolate(m, size=lat.shape[-2:], mode="bilinear")
                if inpaint:
                    masked = vae.encode(x * (m < 0.5)).latent_dist.sample() * sf
            noise = torch.randn_like(lat)
            t = torch.randint(0, sched.config.num_train_timesteps, (lat.shape[0],), device=device).long()
            noisy = sched.add_noise(lat, noise, t)
            inp = torch.cat([noisy, (m_lat > 0.5).float(), masked], 1) if inpaint else noisy
            bs = lat.shape[0]
            with torch.autocast(device_type="cuda" if device == "cuda" else "cpu", dtype=wdtype,
                                enabled=wdtype != torch.float32):
                pred = unet(inp.to(wdtype), t, encoder_hidden_states=prompt_embeds.repeat(bs, 1, 1),
                            added_cond_kwargs={"text_embeds": pooled.repeat(bs, 1),
                                               "time_ids": time_ids.repeat(bs, 1)}).sample
            target = sched.get_velocity(lat, noise, t) if pred_type == "v_prediction" else noise
            w = 1.0 + cfg.face_loss_weight * m_lat
            loss = ((pred.float() - target.float()) ** 2 * w).mean() / w.mean()
            (loss / cfg.grad_accum).backward()
        torch.nn.utils.clip_grad_norm_(params, 1.0)
        opt.step(); lr_sched.step(); opt.zero_grad(set_to_none=True)
        history.append(float(loss.detach()))
        if log_every and (step + 1) % log_every == 0:
            print(f"step {step + 1}/{cfg.steps} loss {np.mean(history[-log_every:]):.4f}", flush=True)
        if cfg.save_every and (step + 1) % cfg.save_every == 0 and step + 1 < cfg.steps:
            _save(unet, Path(out_dir) / f"checkpoint-{step + 1}", get_peft_model_state_dict,
                  convert_state_dict_to_diffusers, StableDiffusionXLPipeline)

    out = Path(out_dir)
    _save(unet, out, get_peft_model_state_dict, convert_state_dict_to_diffusers, StableDiffusionXLPipeline)
    meta = {"type": "dancefs-identity-lora", "trigger": cfg.trigger, "prompt": cfg.prompt,
            "inpaint_unet": inpaint, "num_images": len(examples), "final_loss": history[-1],
            "consent_note": consent_note,
            "reference_images_sha256": [sha256(p) for p in (ref_paths or [])],
            "config": asdict(cfg)}
    (out / "dancefs_lora.json").write_text(json.dumps(meta, indent=2))
    return {"out_dir": str(out), "loss_history": history, **meta}


def _save(unet, path, get_sd, convert, pipe_cls):
    path.mkdir(parents=True, exist_ok=True)
    pipe_cls.save_lora_weights(str(path), unet_lora_layers=convert(get_sd(unet)), safe_serialization=True)


def main(argv=None):
    p = argparse.ArgumentParser(description="Train an SDXL identity LoRA (consenting subject only).")
    p.add_argument("--refs", nargs="+", required=True, help="10-30 varied photos of the person")
    p.add_argument("--out", required=True)
    p.add_argument("--consent", action="store_true")
    p.add_argument("--consent-note")
    p.add_argument("--base-model")
    p.add_argument("--steps", type=int)
    p.add_argument("--rank", type=int)
    p.add_argument("--lr", type=float)
    p.add_argument("--resolution", type=int)
    p.add_argument("--trigger")
    p.add_argument("--no-detector", action="store_true", help="photos are already face crops")
    a = p.parse_args(argv)
    require_consent(a.consent, a.consent_note)
    cfg = TrainConfig()
    for k in ("base_model", "steps", "rank", "lr", "resolution", "trigger"):
        if getattr(a, k) is not None:
            setattr(cfg, k, getattr(a, k))
    analyzer = None
    if not a.no_detector:
        from .faces import FaceAnalyzer
        analyzer = FaceAnalyzer()
    res = train([cv2.imread(r) for r in a.refs], a.out, cfg, analyzer, consent_note=a.consent_note,
                ref_paths=a.refs)
    res.pop("loss_history")
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
