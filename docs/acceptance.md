# Lesson 1 engineering acceptance

Accepted locally on 2026-10-31. This is a sanitized summary of Phase 1-4 evidence, with final handoff checks in Phase 5. The repository includes metadata and verification code, not licensed data, model binaries, personal setup records or raw local logs.

## Verified scope

| Phase | Verified result | Evidence scope |
|---|---|---|
| 1: diagnosis | Windows 11 (rather than the initially reported Windows 10), WSL2 Ubuntu, RTX 4060 Laptop, driver 560.94, storage and existing packages identified | Read-only system inspection; existing WSL Linux NVIDIA packages/Toolkits were retained |
| 2: Docker | Desktop 4.97.0 current-user installation, Engine 29.9.2, Ubuntu Integration and data disk on the selected data drive | Official installer checksum/signature passed; hello-world, GPU query and CUDA nbody GPU/CPU comparison passed |
| 3: models | Both images built; all 13 environment checks and both pip checks passed; two ONNX models valid; FP16 engine built and independently reloaded for actual GPU inference | Complete logs, exit codes, file sizes and hashes recorded locally |
| 4: data | All 21 sequences / 8008 training frames, 21 labels / 65,301 rows and three seqmaps verified; TrackEval fixed commit and reference evaluation passed | ZIP CRC/path audit, full PNG decoding, extracted-byte comparison, continuous frame names, label structure and split checks |
| 5: handoff | Documentation and ignores reviewed, current metadata checked, portable read-only baseline verifier added, local Git prepared | No reinstall, model regeneration, Docker rebuild, dataset download or cache cleanup |

Raw evidence remains local: Docker installation/test records outside the repository; Phase 3/4 reports and per-step command/exit-code records under ignored `outputs/phase3/` and `outputs/phase4/`. Phase 1 was an interactive read-only diagnosis rather than a separately saved raw report. The tracked manifest carries only relative paths, software/image identities and non-content hashes/counts. It is not an independent third-party certification.

## Numerical and functional checks

- YOLOX-S / Nano: ONNX full_check passed; opset 11, static batch 1; real ONNX Runtime CPU inference produced finite outputs.
- Same-weight PyTorch vs ONNX Runtime maximum raw-output absolute errors: S `6.1184168e-5`, Nano `1.9550323e-5`; both passed rtol=1e-3, atol=1e-4 on the same seeded synthetic input.
- YOLOX-S FP16 engine: 21,018,556 bytes, independently deserialized in a new container, executed on the GPU and produced identical outputs on repeated input. Float32 input/output shapes: 1x3x640x640 and 1x8400x85.
- FP16 vs ONNX Runtime raw-output max/mean absolute error: 0.13915849 / 0.00022728265. Recorded as numerical drift, not a detector-accuracy pass criterion.
- GT/CIWT files: 46 selected files matched the TrackEval download byte-for-byte; code commit `12c8791b303e0a0b50f753af204249e622d0281a` verified. Setup's NumPy alias compatibility substitutions affected 19 files; no metric formula or threshold changes.
- dev: 12 sequences / 5027 frames; val: 9 / 2981. Disjoint and jointly cover the 8008-frame training split.

## Performance scope

Observed RTX 4060 Laptop engine-only benchmark, batch 1, random input, one inference stream, 500 ms warmup and >=5 s measurement:

| Metric | Observed |
|---|---:|
| Throughput | 407.735 queries/s |
| Mean GPU compute | 1.76664 ms |
| GPU compute P95 / P99 | 2.12085 / 2.30908 ms |
| Mean latency including H2D/D2H | 2.37614 ms |
| Latency P95 / P99 | 2.72852 / 2.92041 ms |
| Sampled whole-GPU VRAM peak, build / reload benchmark | 2608 / 2102 MiB |

VRAM samples include Windows desktop and other applications, and can miss instantaneous peaks. The initial build's short benchmark warned of timing variance (13.4698%); no driver/power/clock settings were changed to suppress it. These results exclude preprocessing, decode, NMS, tracking and storage I/O and are not application FPS.

## Evaluator reference only

| CIWT / val | HOTA | MOTA | IDF1 |
|---|---:|---:|---:|
| Car | 66.985 | 78.474 | 82.802 |
| Pedestrian | 49.137 | 48.593 | 68.883 |

This evaluates upstream CIWT reference predictions. It establishes evaluator/data usability, **not YOLOX or project algorithm accuracy**. Outputs were isolated from read-only input data using the official TrackEval Python API. The CLI's custom-output parser limitation is documented in [reproducibility.md](reproducibility.md).

## Recheck and reproduction boundaries

`python3 scripts/verify_baseline.py` rechecks current model hashes, all frame names/counts, labels and seqmaps against [validated-baseline.json](validated-baseline.json), without writing data. `--archives` additionally hashes retained large ZIPs. It does not decode images or run GPU inference; those are historical Phase 3/4 checks. Rebuilding an engine on another machine will normally change its hash.

The original Dockerfile, model behavior and original run/setup scripts were kept unchanged during handoff. Documentation and ignore rules were improved, and two verification helpers added. A fresh build is not bit-for-bit guaranteed: apt packages, Python base tag and runtime transitive dependencies can change. The image identities and tested versions are recorded for comparison, not presented as a fully hermetic lock.

The current machine retains pre-existing WSL Linux NVIDIA packages and multiple host Toolkits; successful container tests do not certify that host package configuration as clean. It was deliberately left untouched.

## Future work, not accepted as implemented

No C++ executable/CMake project, detector preprocessing/postprocessing integration, tracker, end-to-end video pipeline, project KITTI AP/HOTA, INT8 calibration or real-frame FP32/FP16 accuracy evaluation exists yet. Future work should first establish the image/tensor contract and numerical consistency, then add tracking and dev/eval measurement. No CIWT reference score should be used as a project result.

Course slides and upstream payloads are not committed. Template redistribution rights have not been inferred; remote handoff is intended to be private and still requires explicit creation/push approval.
