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

# clone SD.Next
RUN git clone https://github.com/vladmandic/sdnext.git .

# Инициализация submodules
RUN git submodule update --init --recursive

# Переменные для пропуска проверок и установки при запуске
ENV SD_NOHASHING=true
ENV SD_SKIP_REQUIREMENTS=true
ENV SD_SKIP_SUBMODULES=true
ENV SD_DISABLE_UPDATE=true
ENV SD_SKIP_EXTENSIONS=true
ENV SD_QUICK_START=true

# create & activate venv, install Python deps
RUN python3 -m venv venv \
    && . venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    # Установка дополнительных модулей для function_handler.py
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
    python launch.py --debug --test --uv --use-cuda --optional --log "sdnext.log" --requirements --reinstall && \
    # Установка зависимостей расширений
    python -m pip install greenlet sqlalchemy PyMatting pooch rembg

# copy your custom handler and the new entrypoint script
COPY function_handler.py /app/function_handler.py
COPY start.sh   /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 7860

ENTRYPOINT ["/app/start.sh"]
