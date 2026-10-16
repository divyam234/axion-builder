#!/usr/bin/env python3
"""Apply the ordered patch series without resets or partially applied conflicts."""
import argparse
import json
import subprocess
from pathlib import Path


def apply_series(tree, root, check_only=False):
    series = json.loads((root / 'patches/series.json').read_text())
    for entry in series:
        project = tree / entry['project']
        patch = root / 'patches' / entry['patch']
        if not project.is_dir():
            raise RuntimeError(f'Missing project: {project}')
        command = ['git', 'apply', '--check', str(patch)]
        forward = subprocess.run(command, cwd=project, capture_output=True, text=True)
        if forward.returncode == 0:
            if not check_only:
                subprocess.run(['git', 'apply', str(patch)], cwd=project, check=True)
            print(f'{"CHECK" if check_only else "APPLY"} {entry["patch"]}')
            continue
        reverse = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch)],
                                 cwd=project, capture_output=True, text=True)
        if reverse.returncode == 0:
            print(f'PRESENT {entry["patch"]}')
            continue
        raise RuntimeError(f'Conflict in {entry["patch"]}; no reset attempted.\n{forward.stderr}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tree', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    apply_series(args.tree.resolve(), Path(__file__).resolve().parent.parent, args.check)
