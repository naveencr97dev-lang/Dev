"""Diffusion face generator: SDXL inpainting + IP-Adapter FaceID identity conditioning.

How it works per frame (in the aligned face crop):
  1. init image = current dancer crop, optionally mixed with the flow-warped previous result
  2. masked img2img inpainting at `strength` (~0.6) -> keeps head pose, expression, lighting
  3. identity injected through IP-Adapter FaceID using the reference ArcFace embedding
  4. fixed-seed noise shared across frames -> diffusion makes the *same* choices frame to frame
"""
from __future__ import annotations

import numpy as np
import cv2

from .config import SwapConfig


class FaceGenerator:
    """Interface. Implementations take a BGR crop + float mask and return a BGR crop."""

    def generate(self, init_bgr: np.ndarray, mask: np.ndarray, identity: np.ndarray,
                 strength: float, ip_scale: float) -> np.ndarray:
        raise NotImplementedError


class SDXLFaceIDGenerator(FaceGenerator):
    def __init__(self, cfg: SwapConfig):
        import torch
        from diffusers import AutoPipelineForInpainting, DPMSolverMultistepScheduler

        self.cfg = cfg
        self.torch = torch
        self.dtype = getattr(torch, cfg.dtype)
        self.pipe = AutoPipelineForInpainting.from_pretrained(
            cfg.base_model, torch_dtype=self.dtype, variant="fp16" if cfg.dtype == "float16" else None)
        self.pipe.scheduler = DPMSolverMultistepScheduler.from_config(
            self.pipe.scheduler.config, use_karras_sigmas=True)
        # FaceID adapters take precomputed ArcFace embeddings, so no CLIP image encoder is needed.
        self.pipe.load_ip_adapter(cfg.ip_adapter_repo, subfolder=None,
                                  weight_name=cfg.ip_adapter_weight, image_encoder_folder=None)
        self.pipe.to(cfg.device)
        try:
            self.pipe.enable_xformers_memory_efficient_attention()
        except Exception:
            pass

    def _id_embeds(self, identity: np.ndarray):
        t = self.torch.from_numpy(identity.astype(np.float32)).reshape(1, 1, 1, -1)
        return self.torch.cat([self.torch.zeros_like(t), t]).to(self.cfg.device, self.dtype)

    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        from PIL import Image

        size = self.cfg.crop_size
        self.pipe.set_ip_adapter_scale(ip_scale)
        g = self.torch.Generator(device=self.cfg.device).manual_seed(self.cfg.seed)
        img = Image.fromarray(cv2.cvtColor(init_bgr, cv2.COLOR_BGR2RGB))
        msk = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
        out = self.pipe(
            prompt=self.cfg.prompt, negative_prompt=self.cfg.negative_prompt,
            image=img, mask_image=msk, width=size, height=size,
            strength=strength, num_inference_steps=self.cfg.steps,
            guidance_scale=self.cfg.guidance_scale, generator=g,
            ip_adapter_image_embeds=[self._id_embeds(identity)],
        ).images[0]
        return cv2.cvtColor(np.array(out.resize((size, size))), cv2.COLOR_RGB2BGR)


class PassthroughGenerator(FaceGenerator):
    """CPU stand-in used for tests / dry runs: returns the init crop (lets you check tracking,
    masks, blending and temporal smoothing without a GPU)."""

    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        return init_bgr.copy()
