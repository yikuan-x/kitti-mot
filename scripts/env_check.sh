#!/usr/bin/env bash
# Run INSIDE the runtime container to confirm the environment is ready:
#   docker run --rm --gpus all -v "$PWD:/workspace" -w /workspace kitti-mot:runtime bash scripts/env_check.sh
set -uo pipefail
ok=0
check() {  # check "<name>" <command...>
  local name="$1"; shift
  if out=$("$@" 2>&1); then printf "  [OK]   %-16s %s\n" "$name" "$(echo "$out" | head -1)"
  else printf "  [FAIL] %-16s %s\n" "$name" "$(echo "$out" | head -1)"; ok=1; fi
}
echo "== GPU"
check "nvidia-smi" nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo "== TensorRT / CUDA"
check "trtexec" bash -c 'command -v trtexec'
check "tensorrt (py)" python3 -c 'import tensorrt; print("TensorRT", tensorrt.__version__)'
check "nvcc" bash -c 'nvcc --version | tail -1'
echo "== C++ toolchain"
check "g++" bash -c 'g++ --version | head -1'
check "cmake" bash -c 'cmake --version | head -1'
check "opencv" pkg-config --modversion opencv4
check "eigen" pkg-config --modversion eigen3
check "yaml-cpp" pkg-config --modversion yaml-cpp
check "gtest" bash -c 'ls /usr/src/googletest >/dev/null && echo "googletest sources present"'
echo "== Python tools"
check "onnxruntime" python3 -c 'import onnxruntime as o; print("onnxruntime", o.__version__)'
check "numpy/scipy" python3 -c 'import numpy, scipy; print("numpy", numpy.__version__, "scipy", scipy.__version__)'
check "pycocotools" python3 -c 'import pycocotools.mask, importlib.metadata as m; print("pycocotools", m.version("pycocotools"))'
echo
if [[ $ok -eq 0 ]]; then echo "Environment OK."; else echo "Some checks failed - see docs/environment.md (Troubleshooting)."; fi
exit $ok
