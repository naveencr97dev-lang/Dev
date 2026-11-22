import base64
import functools
import http.server
import json
import os
import sys
import threading
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "deploy_runpod"))

from dancefs.backends import HybridGenerator, build_generator  # noqa: E402
from dancefs.diffusion import FaceGenerator  # noqa: E402
import handler as rp  # noqa: E402


class Rec(FaceGenerator):
    def __init__(self, tag, log): self.tag, self.log = tag, log
    def generate(self, init_bgr, mask, identity, strength, ip_scale):
        self.log.append((self.tag, strength)); return init_bgr + 1


def test_hybrid_runs_swap_then_light_refine():
    log = []
    g = HybridGenerator(Rec("swap", log), Rec("refine", log), refine_strength=0.25)
    out = g.generate(np.zeros((4, 4, 3), np.uint8), None, None, 0.6, 0.8)
    assert log == [("swap", 0.6), ("refine", 0.25)] and out.max() == 2


def test_backend_needs_model_file():
    with pytest.raises(ValueError):
        build_generator("hybrid", None, None, swap_model=None)


@pytest.fixture
def server(tmp_path):
    (tmp_path / "v.mp4").write_bytes(b"video")
    (tmp_path / "r.jpg").write_bytes(b"img")
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(tmp_path))
    h.log_message = lambda *a: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_port}"
    srv.shutdown()


@pytest.fixture
def models(tmp_path, monkeypatch):
    d = tmp_path / "models"; d.mkdir()
    (d / "inswapper_128.onnx").write_bytes(b"x")
    monkeypatch.setattr(rp, "MODELS_DIR", d)
    return d


def fake_runner(calls):
    def run(video, refs, out, consent, note, cfg, backend, swap_model, refine, dry, maxf, progress):
        calls.append(dict(backend=backend, swap_model=swap_model, strength=cfg.strength, refine=refine,
                          refs=len(refs), consent=consent, video=Path(video).read_bytes()))
        Path(out).write_bytes(b"OUTVIDEO")
        side = Path(out).with_suffix(".provenance.json"); side.write_text('{"ai_generated": true}')
        return {"output": out, "provenance": str(side), "swapped": 3}
    return run


def test_handler_happy_path(server, models):
    calls = []
    res = rp.handler({"input": {
        "video_url": f"{server}/v.mp4", "ref_urls": [f"{server}/r.jpg"] * 2,
        "consent": True, "consent_note": "self", "swap_model": "inswapper_128.onnx",
        "options": {"strength": 0.5, "refine_strength": 0.2}}}, runner=fake_runner(calls))
    assert "error" not in res, res
    c = calls[0]
    assert c["backend"] == "hybrid" and c["swap_model"].endswith("inswapper_128.onnx")
    assert c["strength"] == 0.5 and c["refine"] == 0.2 and c["refs"] == 2 and c["video"] == b"video"
    assert base64.b64decode(res["output_base64"]) == b"OUTVIDEO"
    assert res["provenance"]["ai_generated"] is True


@pytest.mark.parametrize("inp,msg", [
    ({"consent": False, "consent_note": "x"}, "consent"),
    ({"consent": True}, "consent"),
    ({"consent": True, "consent_note": "self", "video_url": "file:///etc/passwd", "ref_urls": ["x"]}, "http"),
    ({"consent": True, "consent_note": "self", "video_url": "http://x", "ref_urls": ["x"],
      "swap_model": "../../etc/passwd"}, "not found"),
])
def test_handler_rejects_bad_input(inp, msg, models):
    res = rp.handler({"input": inp}, runner=fake_runner([]))
    assert msg in res["error"]


def test_handler_train_identity(server, models):
    seen = {}
    def fake_trainer(images, out_dir, cfg, analyzer, consent_note, ref_paths, log_every):
        seen.update(n=len(images), out=out_dir, steps=cfg.steps, note=consent_note)
        return {"out_dir": out_dir, "loss_history": [0.1], "trigger": cfg.trigger}
    inp = {"task": "train_identity", "lora_name": "me", "ref_urls": [f"{server}/r.jpg"] * 3,
           "consent": True, "consent_note": "self"}
    res = rp.train_identity(inp, {"steps": 10, "no_detector": True}, trainer=fake_trainer)
    assert seen == {"n": 3, "out": str(models / "loras" / "me"), "steps": 10, "note": "self"}
    assert res["identity_lora"] == "me" and "loss_history" not in res


@pytest.mark.parametrize("name", ["", "../evil", "a/b", "x" * 65])
def test_handler_train_rejects_bad_names(name, models):
    res = rp.handler({"input": {"task": "train_identity", "lora_name": name, "ref_urls": ["http://x"],
                                "consent": True, "consent_note": "self"}})
    assert "lora_name" in res["error"]


def test_handler_train_requires_consent(models):
    res = rp.handler({"input": {"task": "train_identity", "lora_name": "me", "ref_urls": ["http://x"]}})
    assert "consent" in res["error"]


def test_swap_rejects_missing_lora(models):
    res = rp.handler({"input": {"video_url": "http://x", "ref_urls": ["http://x"], "consent": True,
                                "consent_note": "self", "identity_lora": "nope"}})
    assert "not found" in res["error"]
