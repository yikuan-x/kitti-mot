#!/usr/bin/env python3
"""Read-only verification of the recorded lesson 1 snapshot; standard library only."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archives', action='store_true', help='also hash the retained large ZIPs')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    baseline = json.loads((root / 'docs/validated-baseline.json').read_text(encoding='utf-8'))
    checks = []

    def require(condition, message):
        if not condition:
            raise RuntimeError(message)
        checks.append(message)

    def local(relative):
        path = root / relative
        require(path.resolve().is_relative_to(root), 'path contained: ' + relative)
        return path

    for artifact in baseline['models']:
        path = local(artifact['path'])
        require(path.is_file() and path.stat().st_size == artifact['bytes'], 'size: ' + artifact['path'])
        require(digest(path) == artifact['sha256'], 'SHA-256: ' + artifact['path'])
    data = baseline['dataset']
    images = local('data/kitti_tracking/training/image_02')
    require({p.name for p in images.iterdir()} == {s['sequence'] for s in data['sequences']}, '21 sequence directories')
    total = 0
    labels = local('data/trackeval/gt/kitti/kitti_2d_box_train/label_02')
    require({p.name for p in labels.iterdir()} == {s['sequence'] + '.txt' for s in data['sequences']}, '21 label files')
    for sequence in data['sequences']:
        directory = images / sequence['sequence']
        require({p.name for p in directory.iterdir()} == {f'{i:06d}.png' for i in range(sequence['frames'])}, 'frames: ' + sequence['sequence'])
        require(digest(labels / (sequence['sequence'] + '.txt')) == sequence['label_sha256'], 'labels: ' + sequence['sequence'])
        total += sequence['frames']
    require(total == data['training_frames'] == 8008, '8008 total frames')
    for item in data['seqmaps']:
        require(digest(local(item['path'])) == item['sha256'], 'seqmap: ' + item['split'])
    if args.archives:
        for item in data['archives']:
            require(digest(local(item['path'])) == item['sha256'], 'archive SHA-256: ' + item['path'])
    print(json.dumps({'status': 'PASS', 'checks': len(checks), 'frames': total,
                      'scope': 'Historical hashes and file layout; no PNG decode, inference or accuracy test'}, indent=2))


if __name__ == '__main__':
    main()
