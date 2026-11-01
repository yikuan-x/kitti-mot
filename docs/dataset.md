# Dataset: KITTI Tracking (Car + Pedestrian)

## Links

| What | Link | Size |
|---|---|---|
| Benchmark page | https://www.cvlibs.net/datasets/kitti/eval_tracking.php | — |
| Left color images (`data_tracking_image_2.zip`) | from the page above, **login required** | ~15 GB |
| Training labels (`data_tracking_label_2.zip`) | from the page above, login required | ~9 MB |
| TrackEval sample data: KITTI GT, seqmaps, example trackers | https://omnomnom.vision.rwth-aachen.de/data/TrackEval/data.zip | ~150 MB |
| Paper | Geiger, Lenz, Urtasun. *Are we ready for Autonomous Driving? The KITTI Vision Benchmark Suite.* CVPR 2012. https://www.cvlibs.net/publications/Geiger2012CVPR.pdf | — |

- Only the left color images are needed. Right images, Velodyne, GPS/IMU, and calibration are not used because this is a 2D-only project.
- License: CC BY-NC-SA 3.0, non-commercial. Never commit images, labels, or derived videos beyond a short attributed demo GIF.
- The test split has no public labels and is not used. Nothing is submitted to the KITTI server.

## Setup

1. Register on the KITTI site and download `data_tracking_image_2.zip` into `data/downloads/`.
2. Run `bash scripts/setup_data.sh`. The script:
   - unzips the images into `data/kitti_tracking/training/image_02/<seq>/<frame>.png`
   - downloads TrackEval's `data.zip` and extracts the KITTI GT and seqmaps into `data/trackeval/`
   - checks each of the 21 training sequences against the frame count in the seqmap (8,008 frames in total) and stops if the download is incomplete
   - clones TrackEval (pinned commit) into `third_party/TrackEval` and patches its old numpy aliases

   It needs `curl`, `unzip` and `git` on the host. Use an unused data layout; this is **not a general no-overwrite operation**.

### Preserve existing data

The script removes `data/downloads/trackeval_extract/`, copies GT and reference tracker files over same-named targets, and removes `third_party/TrackEval/` if that directory lacks `.git`. It also patches legacy NumPy aliases. Images use `unzip -n`, which preserves existing files but can leave a corrupt file untouched. Inspect all targets before rerunning; never delete accepted inputs to make a check pass.

The accepted run used previously absent targets, checked both ZIPs' paths and CRC, decoded all 8008 training PNGs, compared extracted images byte-for-byte to the archive, and validated all labels and splits. Read-only snapshot verification is available as `python3 scripts/verify_baseline.py`. See [acceptance.md](acceptance.md) for the scope of those checks.

For a fresh checkout, after the manual image download and a ZIP/space audit:

```bash
test ! -e data/trackeval && test ! -e data/kitti_tracking && \
test ! -e data/downloads/trackeval_extract && test ! -e third_party/TrackEval && \
bash scripts/setup_data.sh
```

TrackEval supplies GT, three seqmaps and CIWT reference inputs from its official public package. Code is pinned to `12c8791b303e0a0b50f753af204249e622d0281a`. Use `scripts/check_trackeval.py` with a new output directory to preserve reference inputs (README example). The original `run_trackeval.sh` writes results beside the reference tracker. CIWT metrics are evaluator self-checks, not project algorithm scores.

## Split

The dev / eval split uses the seqmaps that ship with TrackEval (this is also the KITTI MOTS validation split).

| Split | TrackEval seqmap | Sequences | Frames | Car tracks | Ped tracks |
|---|---|---|---|---|---|
| dev | `training_minus_val` | 0000, 0001, 0003, 0004, 0005, 0009, 0011, 0012, 0015, 0017, 0019, 0020 | 5,027 | 428 | 99 |
| eval | `val` | 0002, 0006, 0007, 0008, 0010, 0013, 0014, 0016, 0018 | 2,981 | 151 | 68 |
| quick (subset of dev) | — | 0000, 0012, 0017 | 377 | — | — |

Tune only on dev. Run eval once with frozen parameters and report those numbers.
Note that Pedestrian results are dominated by a few sequences: 0019 in dev, and 0013 and 0016 in eval.

## File formats

### Labels: `label_02/<seq>.txt` (space-separated, frames are 0-based)
```
frame track_id type truncated occluded alpha x1 y1 x2 y2 h w l X Y Z rotation_y
```
- `type` is one of: Car, Van, Truck, Pedestrian, Person_sitting, Cyclist, Tram, Misc, DontCare (DontCare rows have `track_id = -1`).
- The 2D box is `x1 y1 x2 y2` in pixels. The 3D fields are unused.
- `truncated` takes values 0–2 and `occluded` takes values 0–3.

### Tracker output (what `KittiWriter` must produce): one `<seq>.txt` per sequence
```
frame id type -1 -1 -10 x1 y1 x2 y2 -1 -1 -1 -1000 -1000 -1000 -10 score
```
- `type` is `Car` or `Pedestrian`, `frame` is 0-based, and `id` is unique across both classes.
- TrackEval reads columns 0 (frame), 1 (id), 2 (type), 6–9 (box), and 17 (score).

## How TrackEval scores KITTI (checked against `trackeval/datasets/kitti_2d_box.py`)

- Only `car` and `pedestrian` are scored.
- Van is a distractor for Car and Person_sitting is a distractor for Pedestrian. A prediction matched to a distractor is removed, so it counts as neither TP nor FP.
- A prediction matched to a GT box with `truncated > 0` or `occluded > 2` is also removed.
- An unmatched prediction that is 25 px tall or less is removed.
- An unmatched prediction that lies more than 50% inside a DontCare region is removed.
- Cyclist is not a distractor for Pedestrian, so a cyclist detected as a COCO `person` becomes a Pedestrian FP.

## Class mapping (COCO → KITTI)

| COCO id | COCO name | KITTI |
|---|---|---|
| 0 | person | Pedestrian |
| 2 | car | Car |
| 1, 3, 5, 7 | bicycle, motorcycle, bus, truck | dropped |
| others | — | dropped |

## Optional second dataset

MOT17 (https://motchallenge.net/data/MOT17/, Pedestrian only, no registration) can be added later to check that the Pedestrian tracker generalizes. It is out of scope for the core project.
