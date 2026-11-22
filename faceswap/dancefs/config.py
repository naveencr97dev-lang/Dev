from dataclasses import dataclass, field


@dataclass
class SwapConfig:
    # --- diffusion backend ---
    base_model: str = "diffusers/stable-diffusion-xl-1.0-inpainting-0.1"
    ip_adapter_repo: str = "h94/IP-Adapter-FaceID"
    ip_adapter_weight: str = "ip-adapter-faceid_sdxl.bin"
    ip_adapter_scale: float = 0.8          # identity strength
    prompt: str = "photo of a person's face, natural skin texture, sharp focus, high detail"
    negative_prompt: str = "blurry, deformed, extra eyes, cartoon, lowres, watermark, text"
    steps: int = 25
    guidance_scale: float = 5.0
    strength: float = 0.6                  # 0.5-0.7 keeps expression/pose of the dancer
    seed: int = 1234                       # fixed seed => shared noise across frames => less flicker
    device: str = "cuda"
    dtype: str = "float16"

    # --- face crop / mask ---
    crop_size: int = 1024                  # SDXL native; use 512 for SD1.5
    crop_scale: float = 2.0                # crop = bbox * scale (context around face)
    mask_dilate: float = 0.06              # fraction of crop size
    mask_feather: float = 0.05

    # --- temporal consistency ---
    landmark_min_cutoff: float = 1.0       # one-euro filter params for crop stability
    landmark_beta: float = 0.02
    temporal_init_weight: float = 0.35     # mix flow-warped previous result into diffusion init
    temporal_blend_weight: float = 0.25    # post-blend of warped previous output (low-motion areas)
    flow_error_threshold: float = 12.0     # px-intensity; above this, trust current frame only
    keyframe_interval: int = 0             # >0: re-run full-strength diffusion every N frames

    # --- identity check ---
    min_identity_sim: float = 0.45         # cosine sim vs reference; retry if below
    max_retries: int = 1

    # --- target selection ---
    target_face_index: int = -1            # -1 = auto (largest face in first frame, then track)

    # --- provenance ---
    watermark_text: str = "AI-GENERATED"
    watermark: bool = True

    extra: dict = field(default_factory=dict)
