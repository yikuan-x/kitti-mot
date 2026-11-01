#!/usr/bin/env python3
"""Run the CIWT/val reference smoke test into a new, explicit output directory."""
import argparse
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    error_log = output.parent / (output.name + '-errors.log')
    if output.exists() or error_log.exists():
        raise FileExistsError('Choose a new output directory; existing results will not be overwritten')
    sys.path.insert(0, str(root / 'third_party/TrackEval'))
    import trackeval

    eval_config = trackeval.Evaluator.get_default_eval_config()
    eval_config.update(USE_PARALLEL=False, PLOT_CURVES=False, BREAK_ON_ERROR=True,
                       RETURN_ON_ERROR=False, LOG_ON_ERROR=str(error_log), PRINT_ONLY_COMBINED=True)
    dataset_config = trackeval.datasets.Kitti2DBox.get_default_dataset_config()
    dataset_config.update(GT_FOLDER=str(root / 'data/trackeval/gt/kitti/kitti_2d_box_train'),
                          TRACKERS_FOLDER=str(root / 'data/trackeval/trackers/kitti/kitti_2d_box_train'),
                          OUTPUT_FOLDER=str(output), SPLIT_TO_EVAL='val',
                          CLASSES_TO_EVAL=['car', 'pedestrian'], TRACKERS_TO_EVAL=['CIWT'])
    dataset = trackeval.datasets.Kitti2DBox(dataset_config)
    metrics = [trackeval.metrics.HOTA(), trackeval.metrics.CLEAR(), trackeval.metrics.Identity()]
    output.parent.mkdir(parents=True, exist_ok=True)
    _, messages = trackeval.Evaluator(eval_config).evaluate([dataset], metrics)
    if messages[dataset.get_name()]['CIWT'] != 'Success':
        raise RuntimeError(str(messages))
    for cls, expected in [('car', 66.985), ('pedestrian', 49.137)]:
        rows = (output / 'CIWT' / (cls + '_summary.txt')).read_text().splitlines()
        values = dict(zip(rows[0].split(), map(float, rows[1].split())))
        if abs(values['HOTA'] - expected) > 0.00001:
            raise RuntimeError('Reference HOTA mismatch: ' + cls)
    print(json.dumps({'status': 'PASS', 'messages': messages,
                      'scope': 'CIWT reference only; not project algorithm accuracy'}, indent=2))


if __name__ == '__main__':
    main()
