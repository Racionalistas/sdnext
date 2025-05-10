# ----------------------------------------------------------------------
# Dockerfile (at /app/Dockerfile)
# ----------------------------------------------------------------------
FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# install system deps and python venv support
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git wget curl libgl1-mesa-glx libglib2.0-0 jq \
    python3-venv python3-dev build-essential cmake ninja-build \
    google-perftools ffmpeg && \
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
ENV LD_PRELOAD=libtcmalloc_minimal.so.4

# ──────────────────────────────────────────────────────────────────────────
# Скачиваем Photon-v1 (веса) в правильную папку моделей
# ──────────────────────────────────────────────────────────────────────────
RUN mkdir -p /mnt/models/Stable-diffusion && \
    wget -q -O /mnt/models/Stable-diffusion/photon_v1.safetensors \
    https://huggingface.co/sam749/Photon-v1/resolve/main/photon_v1.safetensors

RUN mkdir -p /mnt/models/Diffusers \
    && git clone \
    https://huggingface.co/sam749/Photon-v1 \
    /mnt/models/Diffusers/Photon-v1

# ----------------------------------------------------------------------
#  INSTALL CONTROLNET
# ----------------------------------------------------------------------
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet.git extensions/sd-webui-controlnet && \
    pip install -r extensions/sd-webui-controlnet/requirements.txt

# Download ControlNet models
RUN mkdir -p extensions/sd-webui-controlnet/models && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth \
    -o extensions/sd-webui-controlnet/models/control_v11p_sd15_canny.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth \
    -o extensions/sd-webui-controlnet/models/control_v11p_sd15_openpose.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge.pth \
    -o extensions/sd-webui-controlnet/models/control_v11p_sd15_softedge.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth \
    -o extensions/sd-webui-controlnet/models/control_v11f1p_sd15_depth.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_pose.pth \
    -o extensions/sd-webui-controlnet/models/control_v11p_sd15_pose.pth
# ──────────────────────────────────────────────────────────────────────────
# СНАЧАЛА настраиваем venv и ставим ВСЕ Python пакеты
# ──────────────────────────────────────────────────────────────────────────

# create & activate venv, install Python deps
RUN python3 -m venv venv \
    && . venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir \
    runpod \
    opencv-python-headless \
    mediapipe \
    numpy \
    pillow \
    boto3 \
    fastapi \
    uvicorn \
    onnxruntime-gpu \
    basicsr \
    facexlib \
    gfpgan \
    realesrgan \
    open_clip_torch \
    clip \
    xformers \
    nncf==2.16.0 \
    optimum-quanto==0.2.7 \
    torchao==0.10.0 \
    pillow-jxl-plugin==1.3.2 \
    clean-fid \
    bitsandbytes==0.45.5 \
    pynvml \
    ultralytics==8.3.40 \
    Cython \
    albumentations==1.4.3 \
    gguf \
    av \
    greenlet sqlalchemy PyMatting pooch rembg \
    && pip install --no-cache-dir pydantic==1.10.21

# ──────────────────────────────────────────────────────────────────────────
# ТЕПЕРЬ, когда все пакеты Python установлены,
# запускаем launch.py для предварительной проверки и настройки
# ──────────────────────────────────────────────────────────────────────────
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
