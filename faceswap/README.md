# dancefs: diffusion face swap for AI dance videos

Replaces the dancer's face in a video with a **consenting** person's identity using
SDXL inpainting + IP-Adapter FaceID, with optical-flow temporal smoothing so the face
doesn't flicker between frames.

## How it works

```
frame ─► InsightFace detect ─► track target dancer (ArcFace + IoU)
      ─► one-euro smoothed bbox/landmarks ─► aligned 1024px crop + soft face mask
      ─► init = crop ⊕ flow-warped previous result (where flow is reliable)
      ─► SDXL inpaint (strength≈0.6, fixed seed) + IP-Adapter FaceID(reference embedding)
      ─► identity check (ArcFace cos-sim) → retry with stronger adapter if weak
      ─► LAB colour match ─► temporal blend ─► paste back ─► "AI-GENERATED" label
      ─► ffmpeg H.264 + original audio + provenance.json sidecar
```

| Problem in dance videos | Fix |
|---|---|
| Face flicker / identity drift | fixed-seed noise, flow-warped init, flow-confidence temporal blend |
| Jittery crops from fast motion | one-euro filter on bbox + landmarks |
| Multiple dancers | appearance + IoU tracker locks onto one person |
| Head turns away / occlusion | frame left untouched, temporal state reset (no hallucinated faces) |
| Lost expression / lip shape | masked img2img at moderate strength, not full generation |
| Skin-tone seams | Reinhard LAB colour transfer + feathered mask |

## Install & run (NVIDIA GPU, ≥12 GB VRAM for SDXL; use `--sd15` for ~6 GB)

```bash
pip install -r requirements.txt
python -m dancefs.cli --video dance.mp4 --ref me1.jpg me2.jpg me3.jpg \
    --out dance_swapped.mp4 --consent --consent-note "self"
```

Tips: use 3–10 sharp, front-lit reference photos. `--strength 0.5` keeps more of the dancer's
expression; `0.7` gives stronger identity. `--id-scale 1.0` pushes identity further.
`--dry-run` runs everything except diffusion (CPU) to check tracking and masks.
Speed: about 1–2 s/frame on an RTX 4090 at 25 steps (SDXL).

## Responsible use

* The CLI refuses to run without `--consent` and a `--consent-note`.
* Outputs carry a visible `AI-GENERATED` label, an MP4 metadata comment and a
  `.provenance.json` sidecar with input/output hashes.
* Do not use this on anyone who hasn't agreed to it. Non-consensual intimate or deceptive
  deepfakes are illegal in many places and violate the model licences.

## Tests

`python -m pytest -q tests` runs the full pipeline on CPU with a synthetic video and a fake
detector/generator. It covers alignment round-trip, masks, landmark smoothing, tracking, the consent
gate, end-to-end video I/O, and checks that temporal smoothing reduces flicker.
