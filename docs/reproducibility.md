# Reproduce lesson 1

This guide describes a new-machine workflow. No commands below were rerun to rebuild/download during final handoff. Use an unused checkout and preserve existing outputs. All host paths are relative to the checkout; `/workspace` and `/results` are container mount conventions.

## Recorded identities and versions

See [validated-baseline.json](validated-baseline.json) for exact model/weight hashes, image identities, sequence counts, seqmap hashes and source refs. Observed local image IDs:

| Image | Digest / local image ID |
|---|---|
| NVIDIA TensorRT 24.12 | `sha256:611db29a3f616636065e96819ed1aea7ec0913bf14d97a80718e641cd685a021` |
| kitti-mot:export | `sha256:145c57aa2d8877a95542169fb6d145d48eb59ab8be912ebbdea8c001a2c700f3` |
| kitti-mot:runtime | `sha256:8b5f60d00e798da3093f474996b74329265f8564233aad5b08a066bda746c4d5` |

Only the NVIDIA image has an upstream pullable reference, `nvcr.io/nvidia/tensorrt@sha256:611db29a3f616636065e96819ed1aea7ec0913bf14d97a80718e641cd685a021`. Project images are local build identities, not published image-registry downloads.

| Export environment | Version |
|---|---|
| Python / PyTorch / torchvision | 3.10.22 / 2.2.2+cpu / 0.17.2+cpu |
| ONNX / ONNX Runtime / onnxsim | 1.14.1 / 1.16.3 / 0.4.36 |
| NumPy / SciPy | 1.26.4 / 1.15.3 |
| YOLOX | 0.3.0, commit `419778480ab6ec0590e5d3831b3afb3b46ab2aa3` |

| Runtime environment | Version |
|---|---|
| Python / CUDA / nvcc | 3.12.3 / 12.6.3 / 12.6.85 |
| TensorRT | Python 10.7.0, release build 10.7.0.23 |
| ONNX Runtime / NumPy / SciPy | 1.31.0 / 2.5.4 / 1.18.1 |
| pytest / pycocotools / tabulate | 9.1.1 / 2.0.11 / 0.10.0 |
| OpenCV / Eigen / yaml-cpp | 4.6.0 / 3.4.0 / 0.8.0 |
| g++ / CMake | 13.2.0 / 3.24.0 |

## 1. Host and storage

Follow [environment.md](environment.md). Reuse compatible components; verify Windows driver and WSL GPU access, Desktop's Ubuntu integration and the physical data drive. Reserve roughly 80-100 GB total free space. Do not copy one person's Windows drive or profile paths to a new machine.

## 2. Validate base and build stages

From the repository root in Linux/WSL:

```bash
export TRT_TAG=24.12-py3
docker run --rm --gpus all nvcr.io/nvidia/tensorrt:$TRT_TAG nvidia-smi
docker build --progress=plain -f docker/Dockerfile --target export \
  --build-arg TRT_TAG="$TRT_TAG" -t kitti-mot:export .
docker build --progress=plain -f docker/Dockerfile --target runtime \
  --build-arg TRT_TAG="$TRT_TAG" -t kitti-mot:runtime .
bash run.sh env
```

Preserve each command's exit code and complete output. All 13 checks must pass. Also run `python -m pip check` inside each image. The export stage uses a CPU-only PyTorch index and `docker/constraints-export.txt`; runtime pins direct dependencies in the Dockerfile. Apt repositories, the Python base-image tag and runtime transitive dependencies are not fully locked. This establishes a tested configuration, not byte-identical future builds. Record new resolved versions and image IDs when rebuilding.

## 3. Export and verify ONNX

Only with the target files absent:

```bash
test ! -e models/yolox_s.onnx && test ! -e models/yolox_nano.onnx && bash run.sh export
docker run --pull=never --rm --entrypoint python \
  -v "$PWD/models:/models:ro" kitti-mot:export -c \
  'import onnx; [onnx.checker.check_model(onnx.load(p), full_check=True) for p in ["/models/yolox_s.onnx", "/models/yolox_nano.onnx"]]; print("ONNX full check passed")'
```

Require nonempty output and inspect `outputs/env_test/export.log` for exceptions even when the container exits zero. Do not replace weights, architecture or preprocessing to work around an error. The accepted export used simplification; no fallback export flags were required.

| Model | images input | output tensor |
|---|---|---|
| YOLOX-S | float32 1x3x640x640 | float32 1x8400x85 |
| YOLOX-Nano | float32 1x3x416x416 | float32 1x3549x85 |

Both are opset 11, static batch 1, raw grid outputs with decode off. Acceptance additionally ran real ONNX Runtime inference and compared raw output to the same-weight PyTorch model (rtol=1e-3, atol=1e-4). Hash checks alone cannot replace this comparison.

## 4. Build and reload the engine

Only when no accepted engine occupies the target path:

```bash
test ! -e models/yolox_s_fp16.engine && bash run.sh engine
docker run --pull=never --rm --gpus all \
  -v "$PWD:/workspace:ro" -w /workspace kitti-mot:runtime \
  trtexec --loadEngine=models/yolox_s_fp16.engine --warmUp=500 --duration=5 --iterations=100
```

Require engine deserialization, actual inference and trtexec PASSED. An engine is specific to GPU architecture, TensorRT version and build settings. Rebuild it on the deployment machine; do not commit/copy a binary engine as a universal deployment artifact. A newly built engine need not match this historical engine hash. FP16 internal execution still uses float32 input/output in this model.

## 5. Data and evaluator

Follow [dataset.md](dataset.md). Download only from official KITTI after login/license confirmation; use TrackEval's published public GT/example package and the pinned source commit. Check ZIP CRC, paths, actual disk requirements and existing output targets before setup. Validate all 21 sequences, 8008 decoded frames and continuous filenames, labels, three seqmaps and dev/val separation. The snapshot verifier checks historical hashes/layout without extracting or touching data.

The README provides a read-only-input CIWT example using `scripts/check_trackeval.py`. It retains the project's evaluation settings but isolates outputs. This pinned TrackEval CLI parses a custom `--OUTPUT_FOLDER` as a list despite the dataset expecting a string; the helper uses the official Python API with a string. It does not change metrics or thresholds. Legacy NumPy aliases are patched by the original setup script; the observed patch touched 19 upstream files.

## Known limits

- Current run.sh export/engine and data setup can replace/delete same-named generated outputs; use a fresh layout and audit before retries.
- The host's old WSL Linux driver packages and two CUDA Toolkits were preserved. They are not required to reproduce the container build and should not be installed as part of it.
- Only 24.12 was tested; no claim is made for the Dockerfile's default 25.06 image.
- Engine throughput excludes image preprocessing, decode, NMS, tracking and disk I/O. Desktop applications and laptop power/clock state affect timing and VRAM samples.
- C++ pipeline, association/tracking, AP/HOTA for the project model, FP32/FP16 image-based accuracy comparisons and INT8 remain future work.
- Fresh-machine commands are documented but were not rerun during Phase 5. Original raw logs are intentionally local under ignored outputs, not published evidence containing user paths.
