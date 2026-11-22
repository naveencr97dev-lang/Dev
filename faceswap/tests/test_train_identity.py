"""Real (tiny) SDXL training + inference smoke tests on CPU.

Uses hf-internal-testing/tiny-stable-diffusion-xl-pipe: the same architecture as SDXL, just
very small, so the actual training loop, the LoRA save format and pipeline loading are all tested.
"""
import json
import os
import sys

import cv2
import numpy as np
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
torch = pytest.importorskip("torch")
pytest.importorskip("diffusers")
pytest.importorskip("peft")

from dancefs.train_identity import TrainConfig, train, load_components, prepare_examples, augment  # noqa: E402
from dancefs.diffusion import load_identity_lora  # noqa: E402

TINY = "hf-internal-testing/tiny-stable-diffusion-xl-pipe"
RES = 64


def faces(n=4):
    rng = np.random.default_rng(0)
    out = []
    for i in range(n):
        img = np.full((96, 96, 3), rng.integers(40, 90), np.uint8)
        cv2.ellipse(img, (48, 48), (20, 27), 0, 0, 360, (120 + 5 * i, 150, 200), -1)
        cv2.circle(img, (40, 42), 3, (20, 20, 20), -1); cv2.circle(img, (56, 42), 3, (20, 20, 20), -1)
        out.append(img)
    return out


def cfg(**kw):
    return TrainConfig(base_model=TINY, resolution=RES, steps=4, rank=4, grad_accum=1, lr=1e-3,
                       device="cpu", gradient_checkpointing=False, **kw)


@pytest.fixture
def comps():
    try:
        return load_components(TINY, "cpu", torch.float32)
    except Exception as e:  # no network / HF down
        pytest.skip(f"tiny SDXL unavailable: {e}")


def test_data_prep_and_augment():
    ex = prepare_examples(faces(2), RES, 2.0)
    import random
    c, m = augment(*ex[0], random.Random(0), 0.0)
    assert c.shape == (RES, RES, 3) and m.shape == (RES, RES) and 0 < m.mean() < 1


def test_train_and_load_text2img(comps, tmp_path):
    from diffusers import StableDiffusionXLPipeline
    res = train(faces(), str(tmp_path / "lora"), cfg(), components=comps, consent_note="self", log_every=0)
    assert np.isfinite(res["loss_history"]).all() and not res["inpaint_unet"]
    assert (tmp_path / "lora" / "pytorch_lora_weights.safetensors").stat().st_size > 0
    meta = json.loads((tmp_path / "lora" / "dancefs_lora.json").read_text())
    assert meta["trigger"] == "ohwx" and meta["consent_note"] == "self"

    pipe = StableDiffusionXLPipeline.from_pretrained(TINY)
    kw = dict(num_inference_steps=2, height=RES, width=RES, output_type="np")
    base = pipe("photo", generator=torch.Generator().manual_seed(0), **kw).images
    prompt = load_identity_lora(pipe, str(tmp_path / "lora"), 1.0, "photo")
    assert prompt.startswith("photo of ohwx person")
    with_lora = pipe("photo", generator=torch.Generator().manual_seed(0), **kw).images
    assert np.abs(with_lora - base).max() > 0  # the trained LoRA actually changes the model


def test_train_inpaint_unet_and_inpaint_pipeline(comps, tmp_path):
    from diffusers import UNet2DConditionModel, StableDiffusionXLInpaintPipeline
    from PIL import Image
    comps["unet"] = UNet2DConditionModel.from_config({**comps["unet"].config, "in_channels": 9})
    comps["unet"].requires_grad_(False)
    res = train(faces(), str(tmp_path / "lora"), cfg(), components=comps, log_every=0)
    assert res["inpaint_unet"] and np.isfinite(res["loss_history"]).all()

    pipe = StableDiffusionXLInpaintPipeline(
        vae=comps["vae"], text_encoder=comps["te1"], text_encoder_2=comps["te2"],
        tokenizer=comps["tok1"], tokenizer_2=comps["tok2"],
        unet=UNet2DConditionModel.from_config(comps["unet"].config), scheduler=comps["scheduler"])
    load_identity_lora(pipe, str(tmp_path / "lora"), 0.9, "photo")
    img = Image.fromarray(faces(1)[0]).resize((RES, RES))
    mask = Image.fromarray((np.ones((RES, RES)) * 255).astype(np.uint8))
    out = pipe("photo of ohwx person", image=img, mask_image=mask, num_inference_steps=2, strength=0.6,
               height=RES, width=RES, output_type="np").images
    assert out.shape == (1, RES, RES, 3) and np.isfinite(out).all()
