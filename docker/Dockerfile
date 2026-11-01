# GPU-only image with two targets:
#   export   YOLOX .pth -> .onnx (CPU PyTorch is enough; runs once)
#   runtime  TensorRT + CUDA + C++ build tools; mount the repo at /workspace and build/run inside
#
#   docker build -f docker/Dockerfile --target export  -t kitti-mot:export  .
#   docker build -f docker/Dockerfile --target runtime -t kitti-mot:runtime .
#
# TRT_TAG: the host driver must support the container's CUDA version
# (`nvidia-smi` -> "CUDA Version" must be >= 12.9 for 25.06, >= 12.6 for 24.12).
#   docker build ... --build-arg TRT_TAG=24.12-py3
ARG TRT_TAG=25.06-py3

# ---------------------------------------------------------------- export
FROM python:3.10-slim-bookworm AS export
ARG YOLOX_REF=0.3.0
# Every pip install below obeys this lock so rebuilds on any machine resolve the same versions.
COPY docker/constraints-export.txt /opt/constraints.txt
ENV PIP_CONSTRAINT=/opt/constraints.txt
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget build-essential libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*
# CPU-only PyTorch keeps the image small; export does not need a GPU.
# onnxruntime (CPU) runs the single-image reference inference (demo/ONNXRuntime).
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir "numpy<2" torch==2.2.2 torchvision==0.17.2 \
        --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir onnx onnxruntime
# --no-build-isolation: YOLOX's setup.py imports torch to compile an op.
# YOLOX pins onnx==1.8.1 / onnxruntime==1.8.0 (no py3.10 wheels) and onnx-simplifier==0.3.5
# (uses np.bool, gone in numpy>=1.24): drop the first two, swap the simplifier for onnxsim 0.4.
RUN git clone --depth 1 --branch ${YOLOX_REF} https://github.com/Megvii-BaseDetection/YOLOX.git /opt/YOLOX \
    && cd /opt/YOLOX && sed -i -E '/^onnx(runtime)?==/d; s/^onnx-simplifier==.*/onnxsim/' requirements.txt \
    && pip install --no-cache-dir --no-build-isolation -v -e .
RUN mkdir -p /weights && cd /weights \
    && wget -q https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_s.pth \
    && wget -q https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_nano.pth
WORKDIR /opt/YOLOX
# Writes /out/yolox_s.onnx and /out/yolox_nano.onnx; mount ./models at /out.
# If onnx-simplifier fails, run with:  -e EXPORT_FLAGS=--no-onnxsim
ENV EXPORT_FLAGS=""
CMD ["bash", "-c", "python tools/export_onnx.py --output-name /out/yolox_s.onnx -n yolox-s -c /weights/yolox_s.pth $EXPORT_FLAGS && python tools/export_onnx.py --output-name /out/yolox_nano.onnx -n yolox-nano -c /weights/yolox_nano.pth $EXPORT_FLAGS"]

# ---------------------------------------------------------------- runtime
FROM nvcr.io/nvidia/tensorrt:${TRT_TAG} AS runtime
ENV DEBIAN_FRONTEND=noninteractive PIP_BREAK_SYSTEM_PACKAGES=1
# trtexec ships under /opt/tensorrt/bin (already on PATH) or /usr/src/tensorrt/bin.
# The repo is mounted over the image's /workspace, which hides NVIDIA's samples there.
ENV PATH="${PATH}:/usr/src/tensorrt/bin"
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git pkg-config \
        libopencv-dev libeigen3-dev libyaml-cpp-dev libgtest-dev \
    && rm -rf /var/lib/apt/lists/*
# Python side: ONNX Runtime (CPU) as the reference for consistency checks; numpy / scipy for tools and tests.
# Pinned to the versions verified with both supported TRT images (Python 3.12).
RUN pip install --no-cache-dir onnxruntime==1.31.0 numpy==2.5.4 scipy==1.18.1 pytest==9.1.1 pycocotools==2.0.11 tabulate==0.10.0
WORKDIR /workspace
CMD ["bash"]
