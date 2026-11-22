"""dancefs: diffusion-based, temporally-consistent face swapping for dance videos.

Intended for consenting subjects only (your own face, or people who have agreed).
Every output is visibly labelled and ships with a provenance sidecar.
"""
from .config import SwapConfig

__all__ = ["SwapConfig"]
__version__ = "0.1.0"
