#!/usr/bin/env bash
# ----------------------------------------------------------------------
# start.sh (at /app/start.sh)
# ----------------------------------------------------------------------
set -e

# Активация виртуальной среды
source venv/bin/activate

# 1) start SD.Next WebUI in API‑only mode (no UI)
echo "==== Starting SD.Next WebUI (API only) ===="
bash webui.sh --api --listen --port 7860 --debug --use-cuda --models-dir "/mnt/models" \
  --ckpt "/mnt/models/Stable-diffusion/photon_v1.safetensors" \
  --api-log \
  --log sdnext.log &
WEBUI_PID=$!

# 2) wait for the /sdapi/v1/txt2img endpoint
echo "==== Waiting for WebUI API to become available ===="
for i in {1..60}; do
  status=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7860/sdapi/v1/models)
  if [ "$status" -eq 200 ]; then
    echo "→ WebUI API is ready (after $i checks)."
    break
  fi
  sleep 2
done
curl -s http://127.0.0.1:7860/controlnet/detect 2>/dev/null || echo "API endpoint not available"
# 3) launch your RunPod / FastAPI handler
echo "==== Starting function_handler.py ===="
# Запускаем с активированной виртуальной средой
python function_handler.py &
HANDLER_PID=$!

# 4) clean up both processes on exit
cleanup() {
  echo "==== Stopping processes ===="
  kill "$HANDLER_PID" "$WEBUI_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# 5) wait on your handler (so container stays alive)
wait "$HANDLER_PID"
