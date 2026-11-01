# GPU and Docker environment

The verified route is **Windows NVIDIA driver + Docker Desktop Linux containers + WSL2 Ubuntu integration**. Native Linux is a separate alternative; do not mix installation procedures.

## Windows / WSL2

1. Reuse a compatible Windows NVIDIA driver. Accepted: 560.94, reporting CUDA support 12.6. This is driver capability, not an installed Toolkit version.
2. Reuse WSL2 Ubuntu. Accepted: Ubuntu 24.04.1, WSL 2.3.26, kernel 5.15.167.4. No WSL upgrade was needed for these tests.
3. Obtain Desktop from the [official Windows installer source](https://docs.docker.com/desktop/setup/install/windows-install/). Verify its published checksum and publisher signature, choose a suitable install mode, and accept the applicable license yourself. Current-user mode was used here.
4. Select the WSL2 backend and enable Ubuntu Integration. Do not install another Docker Engine or NVIDIA Container Toolkit inside Ubuntu for this route.
5. Choose the Docker data disk on a drive with adequate physical free space before pulling images. Installer option `--wsl-default-data-root=<chosen-directory>` worked here. Program, settings and log files can still use the Windows profile drive.

Do not install a Linux NVIDIA display driver in WSL. Existing Linux driver/Toolkit packages on the accepted machine were left untouched; they are not a project prerequisite. The container Toolkit is used. Driver cleanup, updates and system restarts require separate review.

Official references: [Docker WSL integration](https://docs.docker.com/desktop/features/wsl/), [Docker GPU support](https://docs.docker.com/desktop/features/gpu/), [NVIDIA CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/).

## Native Linux alternative (not installed in this acceptance)

Use the host NVIDIA driver, one Docker Engine and NVIDIA Container Toolkit following the official [Docker Ubuntu](https://docs.docker.com/engine/install/ubuntu/) and [NVIDIA Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) instructions. Audit existing installations first. These steps do not apply inside Desktop-integrated WSL.

## Requirements and capacity

- x86_64 NVIDIA GPU; accepted hardware has 8188 MiB VRAM.
- Fixed image: `nvcr.io/nvidia/tensorrt:24.12-py3`, CUDA 12.6.3 / TensorRT 10.7.0.23.
- The script can select 25.06 when a driver reports CUDA >=12.9; that image was not tested. Explicitly use `TRT_TAG=24.12-py3` for this milestone.
- Accepted host RAM: 32 GB; WSL/Docker saw about 15.5 GiB. No global memory setting was changed.
- Budget 80-100 GB physical free space across Docker and project storage. Observed Docker VHDX: about 38.76 GiB; dataset/archives: about 20.96 GiB. Image/cache layers are shared and should not simply be added.
- WSL virtual filesystem capacity is not the backing Windows drive's available space. `run.sh check` uses the daemon's `/var/lib/docker` path on the client; in Desktop this cannot establish actual physical free space. Check the real drive and VHDX separately.

## Verify access

From a Linux/WSL shell:

```bash
nvidia-smi
docker version
docker info
docker run --rm hello-world
docker run --rm --gpus all nvcr.io/nvidia/tensorrt:24.12-py3 nvidia-smi
docker run --rm --gpus all nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -gpu -compare -numbodies=1024
```

The last command performs CUDA computation and compares GPU/CPU results; enumeration alone is insufficient. Initial runs may pull images. Use `--pull=never` to require already-present images.

## Project use

```bash
export TRT_TAG=24.12-py3
bash run.sh check
bash run.sh env
bash run.sh shell
```

`env` and `shell` build missing project images. For strict reuse, use the direct `docker run --pull=never` examples in the README. There is no C++ application to compile yet.

## Troubleshooting

| Symptom | Investigation |
|---|---|
| Ubuntu cannot find docker | Check Desktop and Ubuntu Integration; do not install a second daemon immediately. |
| Windows CLI cannot find credential helper after installation | Open a new terminal to inherit PATH, or adjust only that process. |
| GPU runtime selection fails | Confirm Linux containers, WSL2 backend and integration; distinguish Desktop from native Linux before changing packages. |
| CUDA/driver mismatch | Record the exact image/driver and check compatibility; do not automatically upgrade the driver. |
| Missing ONNX/engine | Check exit code, logs, nonempty files and actual inference. YOLOX can log exceptions yet return zero. |
| NVIDIA samples hidden | The repo mount hides base image /workspace; trtexec is at /opt/tensorrt/bin/trtexec. |
| cgroup/blkio warnings | The accepted WSL kernel uses cgroup v1 and lacks some blkio throttle features. Tests passed; migration is a separate task. |

Do not use broad Docker prune commands to solve storage issues. Inspect first and preserve accepted artifacts.
