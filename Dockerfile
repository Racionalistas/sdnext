# ----------------------------------------------------------------------
# Dockerfile (at /app/Dockerfile)
# ----------------------------------------------------------------------
FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# install system deps and python venv support
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git wget curl libgl1-mesa-glx libglib2.0-0 \
    python3-venv python3-dev build-essential cmake ninja-build && \
    rm -rf /var/lib/apt/lists/*

# clone SD.Next (включая папку configs/)
RUN git clone https://github.com/vladmandic/sdnext.git .

# инициализация submodules
RUN git submodule update --init --recursive

# Переменные для пропуска проверок и установки при запуске
# ENV SD_SKIP_REQUIREMENTS=true
# ENV SD_SKIP_SUBMODULES=true
# ENV SD_DISABLE_UPDATE=true
# ENV SD_SKIP_EXTENSIONS=true
# ENV SD_QUICK_START=true

# Переменные окружения, перенесенные из configs/Dockerfile.cuda
# stop pip and uv from caching
ENV PIP_NO_CACHE_DIR=true
ENV UV_NO_CACHE=true
ENV PIP_ROOT_USER_ACTION=ignore
# disable model hashing for faster startup
ENV SD_NOHASHING=true
# set data directories
ENV SD_DATADIR="/mnt/data"
ENV SD_MODELSDIR="/mnt/models"
ENV SD_DOCKER=true

# tcmalloc is not required but it is highly recommended
ENV LD_PRELOAD=libtcmalloc.so.4  

# ──────────────────────────────────────────────────────────────────────────
# "хак", который прочитает ТОЛЬКО configs/Dockerfile.cuda,
# вытащит из него строки RUN … и выполнит их прямо внутри этого образа.

RUN set -eux; \
    DF_TARGET="configs/Dockerfile.cuda"; \
    if [ -f "$DF_TARGET" ]; then \
      echo "→ Applying RUN steps from $DF_TARGET"; \
      # для каждой строки, начинающейся на RUN, убираем префикс и исполняем
      awk '/^RUN /{ sub(/^RUN[ ]*/,""); print }' "$DF_TARGET" \
      | while IFS= read -r cmd; do \
        echo "+ $cmd"; \
        bash -eux -c "$cmd"; \
      done; \
    else \
      echo "→ WARNING: $DF_TARGET not found. Skipping application of its RUN steps."; \
    fi

# ──────────────────────────────────────────────────────────────────────────

# Теперь ваш уже существующий venv / pip / launch.py и т.п.
# create & activate venv, install Python deps
RUN python3 -m venv venv \
    && . venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir pydantic==1.10.21 \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir \
    runpod \
    opencv-python-headless \
    mediapipe \
    numpy \
    pillow \
    boto3 \
    fastapi \
    uvicorn

# Предустановка всех модулей SD.Next и расширений
RUN . venv/bin/activate && \
    python -m pip install greenlet sqlalchemy PyMatting pooch rembg

# Предварительная загрузка моделей MediaPipe, чтобы избежать их загрузок в рантайме
RUN . venv/bin/activate && \
    echo "import mediapipe as mp; \
    mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=1).close(); \
    mp.solutions.face_mesh.FaceMesh(static_image_mode=True,max_num_faces=1,refine_landmarks=True,min_detection_confidence=0.5).close()" \
    > /tmp/init_mediapipe.py && \
    python /tmp/init_mediapipe.py && \
    rm /tmp/init_mediapipe.py

# copy your custom handler and the new entrypoint script
COPY function_handler.py /app/function_handler.py
COPY start.sh           /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860
ENTRYPOINT ["/app/start.sh"]
