#!/usr/bin/env bash
# One entry point for the project's Docker images. Run on a Linux host with an NVIDIA GPU.
#
#   bash run.sh            everything: check -> build -> env check -> export ONNX -> TensorRT engine
#   bash run.sh check      host prerequisites only (driver, Docker, GPU visible in containers)
#   bash run.sh build      build kitti-mot:export and kitti-mot:runtime
#   bash run.sh export     YOLOX .pth -> models/yolox_s.onnx, models/yolox_nano.onnx
#   bash run.sh engine     models/yolox_s.onnx -> models/yolox_s_fp16.engine
#   bash run.sh shell      interactive shell in the runtime container (repo mounted at /workspace)
#   bash run.sh clean      remove the two images (code, models and outputs are kept)
#
# Optional environment variables:
#   TRT_TAG=24.12-py3      force a TensorRT image (default: picked from the driver's CUDA version)
#   EXPORT_FLAGS=--no-onnxsim   if the ONNX export fails inside onnx-simplifier
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
LOG_DIR="$ROOT/outputs/env_test"
mkdir -p "$LOG_DIR" "$ROOT/models"
# run containers as the current user so files written to the repo are not owned by root
AS_ME=(--user "$(id -u):$(id -g)" -e HOME=/tmp)

say() { echo; echo "==== $*"; }
die() { echo; echo "ERROR: $*" >&2; exit 1; }
# run "$@" with all output to log $1; on failure print the error lines and the log path
logged() {
  local log=$1; shift
  if "$@" >"$log" 2>&1; then return 0; fi
  echo "---- last error lines from $log"
  grep -nE 'ERROR|Error|error:|Traceback|No matching|Could not' "$log" | tail -n 15 || tail -n 30 "$log"
  die "step failed, full log: $log"
}
ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2" ]]; }   # $1 >= $2

pick_trt_tag() {
  [[ -n "${TRT_TAG:-}" ]] && return
  local cuda
  cuda=$(nvidia-smi 2>/dev/null | grep -o 'CUDA Version: [0-9.]*' | awk '{print $3}') || true
  [[ -n "$cuda" ]] || die "cannot read 'CUDA Version' from nvidia-smi"
  if ver_ge "$cuda" 12.9; then TRT_TAG=25.06-py3
  elif ver_ge "$cuda" 12.6; then TRT_TAG=24.12-py3
  else die "the driver supports CUDA $cuda, but at least 12.6 is needed: update the NVIDIA driver"; fi
}

check() {
  say "Host check"
  [[ "$(uname -m)" == x86_64 ]] || die "only x86_64 hosts are supported (found $(uname -m))"
  command -v nvidia-smi >/dev/null || die "nvidia-smi not found: install the NVIDIA driver (docs/environment.md)"
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
  command -v docker >/dev/null || die "docker not found: install Docker Engine (docs/environment.md)"
  docker info >/dev/null 2>&1 || die "cannot reach Docker: start it, or run 'sudo usermod -aG docker \$USER' and log in again"
  local free_gb
  free_gb=$(df -BG --output=avail "$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /)" 2>/dev/null | tail -n 1 | tr -dc 0-9) || true
  [[ -z "$free_gb" || "$free_gb" -ge 30 ]] || die "Docker's disk has ${free_gb} GB free; the images need about 30 GB"
  pick_trt_tag
  echo "TensorRT image: nvcr.io/nvidia/tensorrt:$TRT_TAG (first pull is several GB)"
  docker run --rm --gpus all "nvcr.io/nvidia/tensorrt:$TRT_TAG" nvidia-smi -L \
    || die "containers cannot see the GPU: install the NVIDIA Container Toolkit and restart Docker"
}

build() {
  pick_trt_tag
  say "Build kitti-mot:export"
  logged "$LOG_DIR/build_export.log" docker build -f docker/Dockerfile --target export -t kitti-mot:export .
  echo "ok"
  say "Build kitti-mot:runtime (TensorRT $TRT_TAG)"
  logged "$LOG_DIR/build_runtime.log" \
    docker build -f docker/Dockerfile --target runtime --build-arg TRT_TAG="$TRT_TAG" -t kitti-mot:runtime .
  echo "ok"
}

need_images() {
  docker image inspect kitti-mot:export kitti-mot:runtime >/dev/null 2>&1 || build
}

envcheck() {
  need_images
  say "Environment check inside the runtime container"
  docker run --rm --gpus all "${AS_ME[@]}" -v "$ROOT:/workspace" -w /workspace kitti-mot:runtime \
    bash scripts/env_check.sh | tee "$LOG_DIR/env_check.log"
}

export_onnx() {
  need_images
  say "Export YOLOX to ONNX"
  rm -f models/yolox_s.onnx models/yolox_nano.onnx
  logged "$LOG_DIR/export.log" \
    docker run --rm "${AS_ME[@]}" -e EXPORT_FLAGS="${EXPORT_FLAGS:-}" -v "$ROOT/models:/out" kitti-mot:export
  # YOLOX's logger catches exceptions and still exits 0, so check the log as well
  if grep -q Traceback "$LOG_DIR/export.log"; then
    grep -E 'Error|generated' "$LOG_DIR/export.log" | tail -n 10
    die "ONNX export raised an exception, full log: $LOG_DIR/export.log"
  fi
  ls -lh models/*.onnx
}

engine() {
  need_images
  [[ -f models/yolox_s.onnx ]] || export_onnx
  say "Build the TensorRT FP16 engine on this GPU"
  rm -f models/yolox_s_fp16.engine
  logged "$LOG_DIR/engine.log" docker run --rm --gpus all "${AS_ME[@]}" -v "$ROOT:/workspace" -w /workspace kitti-mot:runtime \
    bash scripts/build_engine.sh models/yolox_s.onnx fp16
  grep -E "Throughput|GPU Compute Time|>> built" "$LOG_DIR/engine.log" || true
  [[ -s models/yolox_s_fp16.engine ]] || die "no engine was written, full log: $LOG_DIR/engine.log"
  ls -lh models/yolox_s_fp16.engine
}

shell() {
  need_images
  docker run --rm -it --gpus all "${AS_ME[@]}" -v "$ROOT:/workspace" -w /workspace kitti-mot:runtime bash
}

clean() {
  docker rmi kitti-mot:export kitti-mot:runtime || true
}

case "${1:-all}" in
  all)    check; build; envcheck; export_onnx; engine
          say "All steps passed. Logs: $LOG_DIR"
          echo "Next: bash run.sh shell" ;;
  check)  check ;;
  build)  build ;;
  env)    envcheck ;;
  export) export_onnx ;;
  engine) engine ;;
  shell)  shell ;;
  clean)  clean ;;
  *)      sed -n '2,13p' "$0"; exit 1 ;;
esac
