#!/usr/bin/env bash
# Usage: bash scripts/run_trackeval.sh <training_minus_val|val|training> <tracker_name>
#   training_minus_val = dev, val = eval. Run scripts/prepare_trackeval.py first for your own tracker.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPLIT="${1:?split}"; TRACKER="${2:?tracker name}"
TE="$ROOT/data/trackeval"

python3 "$ROOT/third_party/TrackEval/scripts/run_kitti.py" \
  --GT_FOLDER "$TE/gt/kitti/kitti_2d_box_train" \
  --TRACKERS_FOLDER "$TE/trackers/kitti/kitti_2d_box_train" \
  --SPLIT_TO_EVAL "$SPLIT" \
  --CLASSES_TO_EVAL car pedestrian \
  --TRACKERS_TO_EVAL "$TRACKER" \
  --METRICS HOTA CLEAR Identity \
  --USE_PARALLEL False \
  --PLOT_CURVES False
# Summaries: data/trackeval/trackers/kitti/kitti_2d_box_train/<tracker>/{car,pedestrian}_summary.txt
