#!/usr/bin/env bash
# ----------------------------------------------------------------------
# start.sh (at /app/start.sh)
# ----------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# Активация виртуальной среды
source venv/bin/activate

# 1) стартуем SD.Next WebUI в API‑only режиме
echo "==== Starting SD.Next WebUI (API only) ===="
bash webui.sh \
  --api --listen --port 7860 --debug --use-cuda --models-dir /mnt/models \
  --ckpt /mnt/models/Stable-diffusion/photon_v1.safetensors --disable-console-progressbars --disable-safe-unpickle \
  --api-log --log sdnext.log --quick --extensions-dir /mnt/extensions &
WEBUI_PID=$!

# 2) ждём, пока поднимутся модели
echo "==== Waiting for /sdapi/v1/sd-models to return non-empty array ===="
ready=false
for i in {1..60}; do
  # если нет jq, можно заменить на grep -qE '\[[^]]+\]'
  if curl -sf http://127.0.0.1:7860/sdapi/v1/sd-models \
       | jq 'length > 0' --exit-status; then
    echo "→ Models are loaded (after $i checks)."
    ready=true
    break
  fi
  printf "→ still waiting for models… (%d/60)\r" "$i"
  sleep 2
done
if [ "$ready" != true ]; then
  echo "ERROR: sd-models did not load in time."
  tail -n50 sdnext.log || true
  exit 1
fi

# 3) ждём, пока заработает /txt2img
echo "==== Waiting for /sdapi/v1/txt2img endpoint ===="
for i in {1..30}; do
  if curl -s -o /dev/null http://127.0.0.1:7860/sdapi/v1/txt2img; then
    echo "→ /txt2img is reachable (after $i checks)."
    break
  fi
  printf "→ still waiting for txt2img… (%d/30)\r" "$i"
  sleep 2
done

echo "Проверка доступных API эндпоинтов..."
curl -s http://127.0.0.1:7860/docs | grep -o '/sdapi/v1/[^"]*' || true

sleep 2

# 5) стартуем наш handler
echo "==== Starting function_handler.py ===="
python function_handler.py &
HANDLER_PID=$!

# 6) ловим SIGTERM/SIGINT, чтобы корректно убить оба процесса
cleanup() {
  echo "==== Stopping processes ===="
  kill -TERM "$HANDLER_PID" "$WEBUI_PID" 2>/dev/null || true
  wait
}
trap cleanup SIGINT SIGTERM EXIT

# 7) держим контейнер живым
wait "$HANDLER_PID"
