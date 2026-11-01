# KITTI MOT: GPU environment and model deployment

A perception engineering project targeting car and pedestrian detection and multi-object tracking on KITTI Tracking.

**Current milestone: lesson 1 infrastructure is verified.** Docker GPU access, YOLOX ONNX export, a TensorRT FP16 engine, KITTI training data integrity, and the TrackEval reference example have passed local acceptance. The C++ detector, preprocessing/postprocessing, tracker, application executable, and project AP/HOTA evaluation are **not implemented yet**. There is no CMake project at this milestone.

## Architecture

```text
Windows NVIDIA driver -> WSL2 -> Docker Desktop Linux engine
                                  |
           +----------------------+----------------------+
           |                                             |
    kitti-mot:export                              kitti-mot:runtime
    CPU PyTorch + YOLOX                          CUDA + TensorRT + C++ tools
    official COCO .pth -> ONNX -----------------> GPU-specific FP16 engine
                                                         |
                                              future C++ detection/tracking

KITTI official training images + TrackEval GT -> data checks / reference evaluation
```

Native Linux can use Docker Engine and NVIDIA Container Toolkit instead of Desktop. Project CUDA and TensorRT live in containers; the host CUDA compiler is not used.

## Repository layout

| Path | Purpose | Committed? |
|---|---|---|
| `docker/` | Image definitions and export dependency constraints | Yes |
| `scripts/`, `run.sh` | Environment, model, data and verification entry points | Yes |
| `docs/` | Setup, deployment, reproducibility, acceptance metadata | Yes |
| `models/` | Generated ONNX and engine files | No |
| `data/` | Licensed images, labels, archives, reference inputs | No |
| `third_party/` | Downloaded TrackEval checkout | No |
| `outputs/`, `build/` | Local logs, test tensors, results and future builds | No |

## Verified environment

| Component | Observed version |
|---|---|
| GPU / Windows driver | RTX 4060 Laptop, 8188 MiB / 560.94 |
| Host / WSL distribution | Windows 11 25H2 / Ubuntu 24.04.1, WSL2 |
| Docker Desktop / Engine | 4.97.0 / 29.9.2 |
| TensorRT container | `nvcr.io/nvidia/tensorrt:24.12-py3` |
| Container CUDA / TensorRT | 12.6.3 / 10.7.0 (build 10.7.0.23) |
| Export PyTorch / ONNX | 2.2.2+cpu / 1.14.1 |

Use `TRT_TAG=24.12-py3` for this milestone. See [environment setup](docs/environment.md) before changing drivers or Docker installations. In WSL2, do not install a Linux NVIDIA display driver or another Docker Engine alongside Desktop.

## Use the existing environment

Run from the repository root in a Linux/WSL shell with Docker Desktop running:

```bash
export TRT_TAG=24.12-py3
bash run.sh shell
```

`shell` reuses existing images but builds missing ones. For strict reuse only:

```bash
docker run --pull=never --rm -it --gpus all \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/workspace" -w /workspace kitti-mot:runtime bash
```

## Fresh-machine setup

Follow [the reproducibility guide](docs/reproducibility.md). These commands are for a **fresh checkout without model outputs**, not a daily start command:

```bash
export TRT_TAG=24.12-py3
bash run.sh check
bash run.sh build
bash run.sh env
test ! -e models/yolox_s.onnx && test ! -e models/yolox_nano.onnx && bash run.sh export
test ! -e models/yolox_s_fp16.engine && bash run.sh engine
```

`run.sh export` and `run.sh engine` remove same-named outputs. Preserve accepted artifacts and use a separate checkout for rebuilding. Logs are in `outputs/env_test/`.

## Data and validation

Register/log in at the [official KITTI Tracking page](https://www.cvlibs.net/datasets/kitti/eval_tracking.php), accept its download terms, and save **left color tracking images** as `data/downloads/data_tracking_image_2.zip`. Do not use the Object Detection image package. Follow [the data guide](docs/dataset.md) before running setup.

Accepted data contains **21 training sequences and 8008 frames**, with dev/val counts of 5027/2981. GT, seqmaps and CIWT come from the [TrackEval project's public package](https://github.com/JonathonLuiten/TrackEval#quickly-evaluate-on-supported-benchmarks).

```bash
# Read-only check against the recorded local snapshot; no builds/downloads.
python3 scripts/verify_baseline.py
```

This checks model hashes, frame names/counts, label hashes and seqmap hashes. It does not replace PNG decoding or numerical inference, which were performed during acceptance. The historical engine hash applies to this accepted binary; a new engine on another GPU is expected to differ.

To test TrackEval without overwriting inputs, choose a new output directory:

```bash
mkdir -p outputs
docker run --pull=never --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$PWD:/workspace:ro" -v "$PWD/outputs:/results" -w /workspace \
  --entrypoint python3 kitti-mot:runtime \
  scripts/check_trackeval.py --output /results/ciwt-val-new
```

The helper refuses existing output. CIWT HOTA (Car 66.985, Pedestrian 49.137) checks the evaluator/data setup; **these are not this project's algorithm results**.

## Evidence and limits

- [Unified acceptance](docs/acceptance.md): capabilities, checks and benchmark scope.
- [Reproducibility](docs/reproducibility.md): versions, image identities, commands and limitations.
- [Model contract](docs/model_export.md): tensors, preprocessing and future work.
- [Metadata manifest](docs/validated-baseline.json): hashes/counts, no model or dataset payloads.
- [Third-party sources](docs/third-party.md).

Observed engine-only throughput was 407.735 queries/s at batch 1; mean GPU compute time was 1.76664 ms. It excludes preprocessing, decode, NMS, tracking and I/O. Dataset accuracy remains unmeasured.

Keep raw reports/logs in ignored `outputs/`. Course slides, data, weights, model binaries, credentials and machine-specific settings are excluded from Git.
