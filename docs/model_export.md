# Model: YOLOX → ONNX → TensorRT

**Milestone status:** YOLOX-S/Nano export, ONNX validation and YOLOX-S FP16 engine inference are verified. C++ inference and image-based accuracy/consistency checks below describe future work. No C++ detector or CMake project exists yet. Follow [reproducibility.md](reproducibility.md) for the pinned Docker process instead of installing host YOLOX dependencies.

## Model choice

| Model | Input | License | Role |
|---|---|---|---|
| YOLOX-S | 640×640 | Apache-2.0 | Main detector |
| YOLOX-Nano | 416×416 | Apache-2.0 | Speed ablation; CI smoke test (CPU) |
| YOLOX-M | 640×640 | Apache-2.0 | Accuracy ablation (GPU) |
| YOLOv8n/s (Ultralytics) | 640×640 | AGPL-3.0 | Fallback only if the YOLOX export environment cannot be installed |

- Repo: https://github.com/Megvii-BaseDetection/YOLOX
- COCO-pretrained weights (release `0.1.1rc0`): https://github.com/Megvii-BaseDetection/YOLOX/releases/tag/0.1.1rc0
- ONNX export guide: https://github.com/Megvii-BaseDetection/YOLOX/tree/main/demo/ONNXRuntime
- YOLOX's own TensorRT demo, for reference only (it uses torch2trt; we use `trtexec` instead): https://github.com/Megvii-BaseDetection/YOLOX/tree/main/demo/TensorRT/cpp

Use COCO-pretrained weights only. Weights fine-tuned on KITTI would leak training data into the evaluation.

## Step 1: export ONNX (Docker `export` stage)

```bash
git clone https://github.com/Megvii-BaseDetection/YOLOX && cd YOLOX
pip install -v -e .           # Python 3.8–3.10; the repo pins older dependencies
wget https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_s.pth
python tools/export_onnx.py --output-name yolox_s.onnx -n yolox-s -c yolox_s.pth
```

Script defaults (checked against `tools/export_onnx.py`): opset 11, input name `images`, output name `output`, batch size 1, static shape, `decode_in_inference` off (so the output holds raw grid offsets), and `onnxsim` runs by default (pass `--no-onnxsim` if it isn't installed).
Record the opset version, the input/output names and shapes, whether the shape is static or dynamic, and whether `decode_in_inference` is on.
Start with a static 1×3×640×640 shape. It makes the TensorRT engine simpler.

## Step 2: build the TensorRT engine (Docker `runtime` stage, on the target GPU)

```bash
bash scripts/build_engine.sh models/yolox_s.onnx fp16   # -> models/yolox_s_fp16.engine
bash scripts/build_engine.sh models/yolox_s.onnx fp32   # -> models/yolox_s_fp32.engine
```

This wraps `trtexec --onnx=... --saveEngine=... [--fp16]`. Record the build time and the `trtexec` throughput.

- Docs: https://docs.nvidia.com/deeplearning/tensorrt/ (see the `trtexec` section and the C++ API)
- Container (CUDA + cuDNN + TensorRT + trtexec): https://catalog.ngc.nvidia.com/orgs/nvidia/containers/tensorrt
- An engine is tied to the GPU architecture and TensorRT version. Always rebuild it from ONNX on the machine that runs it, and never commit or copy `.engine` files.

## Step 3: C++ inference (TensorRT only)

| Component | Key API | Notes |
|---|---|---|
| `TrtDetector` | `IRuntime::deserializeCudaEngine` → `IExecutionContext` → `setTensorAddress(name, ptr)` → `enqueueV3(stream)` | TensorRT 10 API. The old `bindings` array and `enqueueV2` were removed, so most older tutorials no longer apply. You manage the device buffers and CUDA stream yourself. |

ONNX Runtime is used only in Python (CPU package `pip install onnxruntime`), as the reference output for the consistency checks below. It is not a C++ backend.

## Pre- / post-processing contract (YOLOX)

| Step | YOLOX | Common mistake (YOLOv8 conventions) |
|---|---|---|
| Color order | BGR (as read by OpenCV) | converting to RGB |
| Scaling | 0–255, no /255, no mean/std | dividing by 255 |
| Letterbox | resize by `r = min(H_in/h, W_in/w)`, pad with 114, top-left aligned | centered padding |
| Layout | NCHW float32 | NHWC |
| Output | `(1, N, 85)`: `cx, cy, w, h, obj, 80 class scores`, raw grid offsets | treating it as `(1, 84, N)` with no objectness |
| Decode | per stride 8/16/32: `xy = (out_xy + grid) * stride`, `wh = exp(out_wh) * stride` | skipping the decode step, which produces garbage boxes |
| Score | `obj * cls_score[c]` for c ∈ {person, car} | using `obj` alone |
| Back to image | divide by `r`; no offset, because the padding is top-left | subtracting a centered pad offset |

KITTI frames are about 1242×375. At 640×640 the image is scaled by about 0.515, leaving an image region about 193 px tall. Small and distant objects suffer, so try larger input widths in the ablations.

## Consistency checks (required)

Run these on the same 20 dev frames:
1. PyTorch vs ONNX Runtime (Python), same preprocessed tensor: max absolute difference of the raw output. This checks the export.
2a. ONNX Runtime (Python) vs TensorRT FP32 (C++), same input tensor (saved from Python as `.bin`): max absolute difference of the raw output. This checks the engine.
2b. ONNX Runtime (Python, full pipeline) vs TensorRT FP32 (C++, full pipeline), same image: post-NMS box match rate at IoU > 0.99. This checks the C++ pre-/post-processing.
3. TensorRT FP16 vs FP32: box match rate and the change in AP / HOTA on dev.

Put these numbers in the README. Common causes of a mismatch are BGR/RGB order, letterbox alignment, resize rounding, and wrong output tensor names or ordering in TensorRT.

## INT8 (optional)

TensorRT INT8 needs a calibrator (`IInt8EntropyCalibrator2`). Calibrate on dev images only and evaluate on eval. Report the accuracy drop and the speedup.
