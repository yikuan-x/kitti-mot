# Third-party sources and distribution boundaries

This repository tracks setup scripts, configuration, documentation and non-content metadata. Data, upstream checkouts, weights, generated models, engines, course slides and raw local logs are excluded.

| Component | Source | Usage / terms |
|---|---|---|
| KITTI Tracking | https://www.cvlibs.net/datasets/kitti/eval_tracking.php | Obtain after official registration/login and applicable download terms; project documents CC BY-NC-SA 3.0, non-commercial. No images or labels committed. |
| KITTI publication | Geiger, Lenz, Urtasun, *Are we ready for Autonomous Driving?*, CVPR 2012 | Attribute the dataset in demonstrations and reports. |
| YOLOX | https://github.com/Megvii-BaseDetection/YOLOX | Upstream Apache-2.0; source tag 0.3.0 is fetched during image build. |
| YOLOX COCO weights | https://github.com/Megvii-BaseDetection/YOLOX/releases/tag/0.1.1rc0 | Official release weights; acquired into the export image, not Git. |
| TrackEval | https://github.com/JonathonLuiten/TrackEval | Upstream MIT; pinned commit in setup_data.sh. Downloaded code remains ignored. |
| TrackEval GT/examples | https://omnomnom.vision.rwth-aachen.de/data/TrackEval/data.zip | Public package linked in upstream README; underlying dataset rights still apply. No contents committed. |
| TensorRT container | https://catalog.ngc.nvidia.com/orgs/nvidia/containers/tensorrt | NVIDIA Deep Learning Container License / applicable NVIDIA terms; installed by the user, not redistributed here. |
| Docker Desktop | https://www.docker.com/legal/docker-subscription-service-agreement/ | User accepted for personal learning; determine applicability for another usage. |

Metadata hashes and reference metrics do not grant rights to redistribute their payloads. No license is invented for the supplied course/project template: confirm the template author's permission before redistribution or changing repository visibility. This handoff is prepared as a private repository. Future vendoring or redistribution requires preserving the corresponding notices and terms.
