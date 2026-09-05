"""Audit baked assets and publish the foundation catalog. Blender is not required."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
from plant_engine.catalog import build_catalog


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        catalog = build_catalog(args.root)
    except (ValueError, OSError, AssertionError, KeyError, TypeError) as exc:
        print(f'PLANT_CATALOG_FAILED: {exc}', file=sys.stderr)
        return 2
    print(json.dumps({'status': 'passed', 'generation': catalog['generation'],
                      **catalog['validation']}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
