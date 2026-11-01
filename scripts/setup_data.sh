#!/usr/bin/env bash
# Prepare KITTI Tracking + TrackEval.
# Prerequisite: register at https://www.cvlibs.net/datasets/kitti/eval_tracking.php and put
#   data_tracking_image_2.zip  (~15 GB, left color images)  into  data/downloads/
# Usage: bash scripts/setup_data.sh [--gt-only] [-h]
#   --gt-only : skip images; only fetch TrackEval GT + seqmaps (~150 MB). Useful for eval-only work.
#   -h, --help: show this help
set -euo pipefail

GT_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --gt-only) GT_ONLY=1 ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see: bash $0 --help)" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/data"; DL="$DATA/downloads"
mkdir -p "$DL" "$ROOT/third_party"

TRACKEVAL_DATA_URL="https://omnomnom.vision.rwth-aachen.de/data/TrackEval/data.zip"  # ~150 MB, public
TRACKEVAL_REPO="https://github.com/JonathonLuiten/TrackEval.git"
TRACKEVAL_SHA="12c8791b303e0a0b50f753af204249e622d0281a"
SEQS=$(printf "%04d " $(seq 0 20))

die() { echo "ERROR: $*" >&2; exit 1; }
for tool in curl unzip git; do
  command -v "$tool" >/dev/null || die "'$tool' not found: sudo apt-get install -y $tool"
done

# 1. GT + seqmaps (+ example trackers) from TrackEval's public data.zip
echo ">> downloading TrackEval data"
curl -L --fail --retry 5 -C - -o "$DL/trackeval_data.zip" "$TRACKEVAL_DATA_URL"
TMP="$DL/trackeval_extract"; rm -rf "$TMP"; mkdir -p "$TMP"
unzip -q "$DL/trackeval_data.zip" "data/gt/kitti/kitti_2d_box_train/*" "data/trackers/kitti/kitti_2d_box_train/*" -d "$TMP" \
  || die "cannot unzip $DL/trackeval_data.zip (incomplete download?): delete it and re-run"
mkdir -p "$DATA/trackeval"
cp -r "$TMP/data/gt" "$TMP/data/trackers" "$DATA/trackeval/"
rm -rf "$TMP"
GT="$DATA/trackeval/gt/kitti/kitti_2d_box_train"
for s in $SEQS; do [[ -f "$GT/label_02/$s.txt" ]] || die "missing label $s"; done
for m in training val training_minus_val; do [[ -f "$GT/evaluate_tracking.seqmap.$m" ]] || die "missing seqmap $m"; done
echo ">> GT + seqmaps OK: $GT"

# 2. Images (manual download, login required)
if [[ $GT_ONLY -eq 0 ]]; then
  IMG_ZIP="$DL/data_tracking_image_2.zip"
  [[ -f "$IMG_ZIP" ]] || die "missing $IMG_ZIP — download it from the KITTI site first (login required)"
  unzip -q -n "$IMG_ZIP" "training/*" -d "$DATA/kitti_tracking" \
    || die "cannot unzip $IMG_ZIP (incomplete download?): check its size (~15 GB) and download again"
  IMG="$DATA/kitti_tracking/training/image_02"
  total=0
  while read -r s _ _ n; do
    n=$((10#$n))
    got=$(find "$IMG/$s" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l)
    [[ "$got" -eq "$n" ]] || die "sequence $s has $got images, expected $n (incomplete download?)"
    total=$((total + n))
  done < "$GT/evaluate_tracking.seqmap.training"
  echo ">> images OK: 21 sequences, $total frames in $IMG"
fi

# 3. TrackEval code
TE="$ROOT/third_party/TrackEval"
if [[ ! -d "$TE/.git" ]]; then
  rm -rf "$TE"; mkdir -p "$TE"
  git -C "$TE" init -q
  git -C "$TE" fetch -q --depth 1 "$TRACKEVAL_REPO" "$TRACKEVAL_SHA"
  git -C "$TE" checkout -q FETCH_HEAD
fi
{ grep -rlE 'np\.(float|int|bool)\)' "$TE" --include='*.py' || true; } | xargs -r sed -i -E 's/np\.(float|int|bool)\)/\1)/g'
echo ">> TrackEval OK. Sanity check (inside 'bash run.sh shell'): bash scripts/run_trackeval.sh val CIWT"
