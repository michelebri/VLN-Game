FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV QT_X11_NO_MITSHM=1
ENV GLOG_minloglevel=2
ENV MAGNUM_LOG=quiet

# Bind-mount the repo from the host at the same absolute path:
#   -v /home/michele/Desktop/Projects/habitat-MP3D:/home/michele/Desktop/Projects/habitat-MP3D
WORKDIR /home/michele/Desktop/Projects/habitat-MP3D/src/baselines/VLN-Game

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    ffmpeg \
    git \
    libegl1 \
    libegl1-mesa-dev \
    libgl1 \
    libgl1-mesa-dev \
    libglib2.0-0 \
    libglvnd0 \
    libglx0 \
    libglfw3 \
    libglfw3-dev \
    libgomp1 \
    libgtk2.0-0 \
    libjpeg-dev \
    libopenexr-dev \
    libosmesa6 \
    libosmesa6-dev \
    libpng-dev \
    libsm6 \
    libtbb-dev \
    libx11-6 \
    libx11-dev \
    libxcursor1 \
    libxi6 \
    libxinerama1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    pkg-config \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (provides python3 + conda for habitat-sim)
RUN wget -qO /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh
ENV PATH=/opt/conda/bin:$PATH

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
# Use Python 3.10 to stay compatible with habitat-sim 0.2.1
RUN conda install -y python=3.10 setuptools wheel pip

RUN pip install \
    torch==2.1.0 \
    torchvision==0.16.0 \
    torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu121

RUN pip install scikit-fmm==2023.4.2\
        scikit-image\
        "numpy>=1.20.2,<2"\
        ifcfg\
        openai==0.28.1\
        tensorboard\
        open3d\
        ultralytics\
        tyro\
        open_clip_torch\
        wandb\
        h5py\
        hydra-core\
        matplotlib

# Grounded-SAM: build GroundingDINO with CUDA support
ENV AM_I_DOCKER=True
ENV BUILD_WITH_CUDA=True
ENV CUDA_HOME=/usr/local/cuda
# No GPU during docker build — specify arch list so PyTorch can compile CUDA extensions
ENV TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"

RUN git clone --recurse-submodules https://github.com/IDEA-Research/Grounded-Segment-Anything.git /opt/Grounded-Segment-Anything && \
    rm -f /opt/Grounded-Segment-Anything/GroundingDINO/pyproject.toml && \
    pip install -e /opt/Grounded-Segment-Anything/segment_anything && \
    pip install --no-build-isolation -e /opt/Grounded-Segment-Anything/GroundingDINO

RUN apt-get update && apt-get install -y --no-install-recommends \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    libxext-dev \
    libxfixes-dev \
    && rm -rf /var/lib/apt/lists/*
# Habitat stack used by VLN-Game (conda is the only reliable way to get 0.2.1)
RUN git clone --branch v0.2.1 --depth 1 https://github.com/facebookresearch/habitat-sim.git /opt/habitat-sim && \
    cd /opt/habitat-sim && \
    python setup.py install

RUN git clone --branch v0.2.1 --depth 1 https://github.com/facebookresearch/habitat-lab.git /opt/habitat-lab && \
    cd /opt/habitat-lab && \
    pip install -e .

ENV GSA_PATH=/opt/Grounded-Segment-Anything/
RUN pip install faiss-gpu recognize-anything "transformers<4.46" fairscale
CMD ["/bin/bash"]
