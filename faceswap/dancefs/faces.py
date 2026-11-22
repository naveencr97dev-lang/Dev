"""Face detection, landmarks, identity embeddings and target tracking via InsightFace."""
from __future__ import annotations

from dataclasses import dataclass
import numpy as np


@dataclass
class Face:
    bbox: np.ndarray        # x1,y1,x2,y2
    landmarks: np.ndarray   # (N,2) dense landmarks (106 pts when available, else 5)
    embedding: np.ndarray   # L2-normalised ArcFace (512,)
    score: float


class FaceAnalyzer:
    def __init__(self, providers=None, det_size=(640, 640), root=None):
        import os
        from insightface.app import FaceAnalysis  # lazy: heavy import
        root = root or os.environ.get("INSIGHTFACE_ROOT", "~/.insightface")
        self.app = FaceAnalysis(name="buffalo_l", root=root, providers=providers or
                                ["CUDAExecutionProvider", "CPUExecutionProvider"])
        self.app.prepare(ctx_id=0, det_size=det_size)

    def __call__(self, bgr: np.ndarray) -> list[Face]:
        out = []
        for f in self.app.get(bgr):
            lm = getattr(f, "landmark_2d_106", None)
            if lm is None:
                lm = f.kps
            out.append(Face(np.asarray(f.bbox, np.float32), np.asarray(lm, np.float32),
                            np.asarray(f.normed_embedding, np.float32), float(f.det_score)))
        return out


def reference_identity(analyzer: FaceAnalyzer, images: list[np.ndarray]) -> np.ndarray:
    """Average ArcFace embedding over several reference photos (more photos => more robust ID)."""
    embs = []
    for img in images:
        faces = analyzer(img)
        if not faces:
            continue
        best = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        embs.append(best.embedding)
    if not embs:
        raise ValueError("No face found in any reference image.")
    e = np.mean(embs, axis=0)
    return e / np.linalg.norm(e)


def iou(a: np.ndarray, b: np.ndarray) -> float:
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    ua = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / ua if ua > 0 else 0.0


class TargetTracker:
    """Keeps swapping the same dancer: matches by appearance (embedding) + position (IoU)."""

    def __init__(self, index: int = -1, w_emb: float = 0.6, w_iou: float = 0.4, min_score: float = 0.3):
        self.index, self.w_emb, self.w_iou, self.min_score = index, w_emb, w_iou, min_score
        self.emb = None
        self.bbox = None

    def select(self, faces: list[Face]) -> Face | None:
        if not faces:
            return None
        if self.emb is None:
            if 0 <= self.index < len(faces):
                f = sorted(faces, key=lambda f: f.bbox[0])[self.index]  # left-to-right index
            else:
                f = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        else:
            scored = [(self.w_emb * float(f.embedding @ self.emb) + self.w_iou * iou(f.bbox, self.bbox), f)
                      for f in faces]
            s, f = max(scored, key=lambda t: t[0])
            if s < self.min_score:
                return None  # target left frame / occluded: leave frame untouched
        self.emb = f.embedding if self.emb is None else _norm(0.9 * self.emb + 0.1 * f.embedding)
        self.bbox = f.bbox
        return f


def _norm(v):
    return v / (np.linalg.norm(v) + 1e-8)
