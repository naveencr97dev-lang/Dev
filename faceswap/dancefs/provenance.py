"""Consent gate + provenance sidecar. Swaps are only for people who agreed to it."""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
from pathlib import Path


class ConsentError(RuntimeError):
    pass


def require_consent(attested: bool, subject_note: str | None):
    if not attested:
        raise ConsentError(
            "Refusing to run: pass --consent to confirm the person whose face is used "
            "(the reference) has given permission. Non-consensual deepfakes are harmful "
            "and illegal in many jurisdictions.")
    if not subject_note:
        raise ConsentError("Pass --consent-note describing who consented and how (e.g. 'self', "
                           "'written release from J. Doe 2026-11-01').")


def sha256(path: str | Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_sidecar(out_video: str, src_video: str, refs: list[str], consent_note: str, cfg) -> Path:
    data = {
        "generator": "dancefs",
        "ai_generated": True,
        "technique": "diffusion face replacement (SDXL inpaint + IP-Adapter FaceID)",
        "created_utc": _dt.datetime.now(_dt.timezone.utc).isoformat(),
        "source_video_sha256": sha256(src_video),
        "reference_images_sha256": [sha256(r) for r in refs],
        "output_video_sha256": sha256(out_video),
        "consent_note": consent_note,
        "settings": {k: v for k, v in vars(cfg).items() if k != "extra"},
    }
    p = Path(out_video).with_suffix(".provenance.json")
    p.write_text(json.dumps(data, indent=2))
    return p
