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
    google-perftools ffmpeg g++ cmake && \
    rm -rf /var/lib/apt/lists/*

# clone SD.Next (включая папку configs/)
RUN git clone https://github.com/vladmandic/sdnext.git . \
    && git submodule update --init --recursive

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

# # Segment‑Anything (ViT‑B)
# RUN curl -L https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth \
#         -o /mnt/sam_vit_b_01ec64.pth

# ----------------------------------------------------------------------
#  INSTALL CONTROLNET
# ----------------------------------------------------------------------
RUN mkdir -p /mnt/extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet.git /mnt/extensions/controlnet

# Download ControlNet models
RUN mkdir -p /mnt/extensions/controlnet/models && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth \
    -o /mnt/extensions/controlnet/models/control_v11p_sd15_canny.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth \
    -o /mnt/extensions/controlnet/models/control_v11p_sd15_openpose.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge.pth \
    -o /mnt/extensions/controlnet/models/control_v11p_sd15_softedge.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth \
    -o /mnt/extensions/controlnet/models/control_v11f1p_sd15_depth.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_pose.pth \
    -o /mnt/extensions/controlnet/models/control_v11p_sd15_pose.pth

# Download ControlNet Annotator Models
RUN mkdir -p /mnt/extensions/controlnet/annotator/downloads/sam && \
    mkdir -p /mnt/extensions/controlnet/annotator/downloads/midas && \
    mkdir -p /mnt/extensions/controlnet/annotator/downloads/openpose && \
    curl -L https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth \
    -o /mnt/extensions/controlnet/annotator/downloads/sam/sam_vit_b_01ec64.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet/resolve/main/annotator/ckpts/dpt_hybrid-midas-501f0c75.pt \
    -o /mnt/extensions/controlnet/annotator/downloads/midas/dpt_hybrid-midas-501f0c75.pt && \
    curl -L https://huggingface.co/lllyasviel/Annotators/resolve/main/body_pose_model.pth \
    -o /mnt/extensions/controlnet/annotator/downloads/openpose/body_pose_model.pth && \
    curl -L https://huggingface.co/lllyasviel/Annotators/resolve/main/hand_pose_model.pth \
    -o /mnt/extensions/controlnet/annotator/downloads/openpose/hand_pose_model.pth && \
    curl -L https://huggingface.co/lllyasviel/Annotators/resolve/main/facenet.pth \
    -o /mnt/extensions/controlnet/annotator/downloads/openpose/facenet.pth

RUN mkdir -p /mnt/models/ControlNet && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth \
    -o /mnt/models/ControlNet/control_v11p_sd15_canny.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth \
    -o /mnt/models/ControlNet/control_v11p_sd15_openpose.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge.pth \
    -o /mnt/models/ControlNet/control_v11p_sd15_softedge.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth \
    -o /mnt/models/ControlNet/control_v11f1p_sd15_depth.pth && \
    curl -L https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_pose.pth \
    -o /mnt/models/ControlNet/control_v11p_sd15_pose.pth

# сразу патчим main-контролнет
RUN sed -i \
    -e 's/sd_ldm\.model\.diffusion_model/sd_ldm.unet/g' \
    -e 's/sd_ldm\.model\.first_stage_model/sd_ldm.vae/g' \
    /mnt/extensions/controlnet/scripts/controlnet.py

# СНАЧАЛА настраиваем venv и ставим ВСЕ Python пакеты
# ──────────────────────────────────────────────────────────────────────────

# create & activate venv, install Python deps
RUN python3 -m venv venv \
    && . venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir \
    runpod \
    opencv-python \
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
    git+https://github.com/facebookresearch/segment-anything.git \
    triton \
    greenlet sqlalchemy PyMatting pooch rembg \
    fvcore svglib addict yapf matplotlib controlnet_aux[sam,segment-anything] annotator \
    && pip install --no-cache-dir pydantic==1.10.21 \
    && pip install --no-cache-dir -e /mnt/extensions/controlnet 

# ставим зависимости аннотаторов ControlNet
RUN . /app/venv/bin/activate \
    && pip install --no-cache-dir \
    -r /mnt/extensions/controlnet/requirements.txt \
    controlnet_aux[sam,segment-anything]

# ──────────────────────────────────────────────────────────────────────────
# ТЕПЕРЬ, когда все пакеты Python установлены,
# запускаем launch.py для предварительной проверки и настройки
# ──────────────────────────────────────────────────────────────────────────
RUN . venv/bin/activate && \
    python /app/launch.py --debug --uv --use-cuda --log sdnext.log --test --optional

# Предварительная загрузка моделей MediaPipe, чтобы избежать их загрузок в рантайме
RUN . venv/bin/activate && \
    echo "import mediapipe as mp; \
    mp.solutions.selfie_segmentation.SelfieSegmentation(model_selection=1).close(); \
    mp.solutions.face_mesh.FaceMesh(static_image_mode=True,max_num_faces=1,refine_landmarks=True,min_detection_confidence=0.5).close()" \
    > /tmp/init_mediapipe.py && \
    python /tmp/init_mediapipe.py && \
    rm /tmp/init_mediapipe.py

RUN sed -i \
    -e 's/sd_ldm\.model\.diffusion_model/sd_ldm.unet/g' \
    -e 's/sd_ldm\.model\.first_stage_model/sd_ldm.vae/g' \
    /mnt/extensions/controlnet/scripts/controlnet.py

# copy your custom handler and the new entrypoint script
COPY function_handler.py /app/function_handler.py
COPY start.sh           /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860
ENTRYPOINT ["/app/start.sh"]
