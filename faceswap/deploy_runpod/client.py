"""Submit a dancefs job to your RunPod Serverless endpoint and save the result.

  export RUNPOD_API_KEY=...            # RunPod console > Settings > API Keys
  python deploy_runpod/client.py --endpoint <ENDPOINT_ID> --video-url https://... \
      --ref-url https://.../me1.jpg --ref-url https://.../me2.jpg \
      --backend hybrid --swap-model inswapper_128.onnx --consent-note self --out out.mp4
"""
import argparse
import base64
import json
import os
import time
import urllib.request

API = "https://api.runpod.ai/v2"


def call(method, url, key, body=None):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--endpoint", required=True)
    p.add_argument("--video-url", required=True)
    p.add_argument("--ref-url", action="append", required=True)
    p.add_argument("--consent-note", required=True, help="Who consented and how")
    p.add_argument("--backend", default="hybrid")
    p.add_argument("--swap-model")
    p.add_argument("--options", default="{}", help='JSON, e.g. \'{"strength":0.55,"max_frames":120}\'')
    p.add_argument("--upload-url", help="Pre-signed PUT URL for the output (needed for long clips)")
    p.add_argument("--out", default="out.mp4")
    a = p.parse_args()
    key = os.environ["RUNPOD_API_KEY"]

    body = {"input": {"video_url": a.video_url, "ref_urls": a.ref_url, "consent": True,
                      "consent_note": a.consent_note, "backend": a.backend, "swap_model": a.swap_model,
                      "options": json.loads(a.options), "output_upload_url": a.upload_url}}
    job = call("POST", f"{API}/{a.endpoint}/run", key, body)
    print("job", job["id"])
    while True:
        st = call("GET", f"{API}/{a.endpoint}/status/{job['id']}", key)
        if st["status"] in ("COMPLETED", "FAILED", "CANCELLED", "TIMED_OUT"):
            break
        print(st["status"]); time.sleep(10)
    out = st.get("output") or {}
    if st["status"] != "COMPLETED" or "error" in out:
        raise SystemExit(json.dumps(st, indent=2))
    if "output_base64" in out:
        open(a.out, "wb").write(base64.b64decode(out.pop("output_base64")))
        print("saved", a.out)
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
