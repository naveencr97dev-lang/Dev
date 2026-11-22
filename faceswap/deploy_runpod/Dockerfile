# Build from the faceswap/ directory:  docker build -f deploy_runpod/Dockerfile -t <you>/dancefs:0.2 .
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libgl1 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt runpod
COPY dancefs ./dancefs
COPY deploy_runpod ./deploy_runpod

# Attach a Network Volume so model weights download once and are reused by every worker.
ENV MODELS_DIR=/runpod-volume/models \
    HF_HOME=/runpod-volume/models/hf \
    INSIGHTFACE_ROOT=/runpod-volume/models/insightface \
    PYTHONUNBUFFERED=1
CMD ["python", "-u", "deploy_runpod/handler.py"]
