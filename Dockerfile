# ----------------------------------------------------------------------
# Dockerfile (at /app/Dockerfile)
# ----------------------------------------------------------------------
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

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

# create & activate venv, install Python deps
RUN python3 -m venv venv \
    && . venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# copy your custom handler and the new entrypoint script
COPY function_handler.py /app/function_handler.py
COPY wait_for_webui.sh   /app/wait_for_webui.sh
RUN chmod +x /app/wait_for_webui.sh

EXPOSE 7860

ENTRYPOINT ["/app/start.sh"]
