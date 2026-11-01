#!/usr/bin/env bash
# Build a TensorRT engine from an ONNX model. Run INSIDE the runtime container, on the GPU that will use it.
# Usage: bash scripts/build_engine.sh models/yolox_s.onnx <fp32|fp16>
set -euo pipefail
ONNX="${1:?onnx path}"; PREC="${2:-fp16}"
ENGINE="${ONNX%.onnx}_${PREC}.engine"
LOG="${ENGINE%.engine}_build.log"

FLAGS=()
case "$PREC" in
  fp32) ;;
  fp16) FLAGS+=(--fp16) ;;
  *) echo "precision must be fp32 or fp16 (int8 needs a calibrator, see docs/model_export.md)"; exit 1 ;;
esac

command -v trtexec >/dev/null || { echo "trtexec not found; run inside the runtime container"; exit 1; }
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | tee "$LOG"

start=$(date +%s)
trtexec --onnx="$ONNX" --saveEngine="$ENGINE" "${FLAGS[@]}" 2>&1 | tee -a "$LOG"
echo ">> built $ENGINE in $(( $(date +%s) - start )) s (log: $LOG)"
# trtexec's "Throughput" / "GPU Compute Time" lines are a useful upper bound for the pipeline's inference stage.
