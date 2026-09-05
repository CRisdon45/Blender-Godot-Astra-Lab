#!/usr/bin/env python3
"""Bounded real-engine evidence runner. Errors and renderer warnings remain visible."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path
from tools import review

POSES = ('courtyard', 'pool', 'grazing', 'shelf', 'sheer')
EXPECTED = ({f'{version}-{pose}.png' for version in ('before', 'after') for pose in POSES}
            | {'diagnostic-reflection.png', 'diagnostic-no-reflection.png',
               'diagnostic-receiver.png', 'diagnostic-receiver-no-caustics.png',
               'after-flow-off.png', 'night-pool.png',
               'diagnostic-clip-on.png', 'diagnostic-clip-off.png',
               'variant-calmer.png', 'variant-livelier.png'}
            | {f'motion-{n:02}.png' for n in range(6)}
            | {f'orbit-{n:02}.png' for n in range(4)})


def validate_manifest(directory: Path) -> dict:
    """Reject incomplete, mismatched, path-escaping or unpaired frame evidence."""
    data = json.loads((directory / 'water-reflection-review.json').read_text())
    rows = data.get('images', [])
    names = [row['file'] for row in rows]
    if len(names) != 30 or set(names) != EXPECTED or len(set(names)) != len(names):
        raise ValueError('Expected exactly 30 uniquely named real captures')
    if {p.name for p in directory.glob('*.png')} != EXPECTED:
        raise ValueError('Manifest differs from actual PNG set')
    if data.get('errors'):
        raise ValueError(f'Runtime contract errors: {data["errors"]}')
    by_name = {row['file']: row for row in rows}
    for row in rows:
        path = directory / row['file']
        width, height = review.validate_png(path)
        if (width, height) != (row['width'], row['height']):
            raise ValueError(f'Image dimensions disagree: {path.name}')
        expected_size = (600, 450) if row['file'].startswith('diagnostic-clip-') else (1200, 900)
        if (width, height) != expected_size:
            raise ValueError(f'Unexpected render size: {path.name}: {(width, height)}')
    for pose in POSES:
        a, b = (by_name[f'{v}-{pose}.png'] for v in ('before', 'after'))
        for key in ('camera', 'aim'):
            if a.get(key) != b.get(key):
                raise ValueError(f'Camera mismatch: {pose}/{key}')
        for key in ('time_seconds', 'flow_enabled', 'impact_segments_xz'):
            if a['water'][key] != b['water'][key]:
                raise ValueError(f'Water state mismatch: {pose}/{key}')
        if not b['study'].get('reflection_ready'):
            raise ValueError(f'Reflection not initialized: {pose}')
    witnesses = data.get('witnesses', {})
    surface = witnesses.get('final_surface', {})
    if surface.get('mean_rgb_difference', 0) <= .006 or surface.get('changed_pixels', 0) <= 2420:
        raise ValueError('Reflected scene does not affect the final water pixels')
    clip = witnesses.get('clip_and_hdr', {})
    on, off = clip.get('diagnostic-clip-on', {}), clip.get('diagnostic-clip-off', {})
    if on.get('below_magenta_pixels') != 0 or off.get('below_magenta_pixels', 0) <= 4:
        raise ValueError('Reflection clipping lacks a valid GPU positive control')
    if min(on.get('above_green_pixels', 0), off.get('above_green_pixels', 0)) <= 4:
        raise ValueError('Above-water reflection control missing')
    if off.get('maximum_linear_value', 0) <= 1.1:
        raise ValueError('Linear HDR range not demonstrated')
    return data


def engine_warnings(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines()
            if 'WARNING:' in line or 'leaked' in line.lower() or 'RID allocations' in line]


def run(godot: str, output: Path) -> int:
    root = Path(__file__).resolve().parents[1]
    project = root / 'godot'
    output.mkdir(parents=True, exist_ok=True)
    config = project / 'project.godot'
    original = config.read_bytes()
    errors, warnings = [], []
    stages = [
        ('import', [godot, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--editor', '--import'], None),
        ('preflight', [godot, '--headless', '--audio-driver', 'Dummy', '--path', str(project), '--script', 'res://tests/test_reflection_preflight.gd'], 'REFLECTION_PREFLIGHT_PASSED'),
        ('capture', [godot, '--audio-driver', 'Dummy', '--path', str(project), '--rendering-method', 'forward_plus', '--script', 'res://tests/capture_water_reflections.gd', '--', '--output=' + str(output / 'images')], 'REFLECTION_REVIEW_DONE ')]
    for name, command, marker in stages:
        if name == 'capture' and any(e['stage'] == 'preflight' for e in errors):
            errors.append({'stage': name, 'error': 'Skipped after failed actual-script preflight'})
            break
        log = output / (name + '.log')
        try:
            review.run_stage(command, log, 450 if name == 'capture' else (30 if name == 'preflight' else 90), marker)
        except Exception as exc:
            errors.append({'stage': name, 'error': str(exc)})
        finally:
            if config.read_bytes() != original:
                (output / 'editor-rewritten-project.txt').write_bytes(config.read_bytes())
                config.write_bytes(original)
            if log.exists():
                warnings.extend({'stage': name, 'warning': line} for line in engine_warnings(log.read_text(errors='replace')))
    count = len(list((output / 'images').glob('*.png')))
    try:
        validate_manifest(output / 'images')
    except Exception as exc:
        errors.append({'stage': 'evidence', 'error': str(exc)})
    report = {'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'images': count, 'errors': errors, 'warnings': warnings,
              'status': 'diagnostic' if errors or warnings else 'captured',
              'visual_acceptance': 'pending_review', 'performance_certified': False}
    (output / 'runner-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 1 if errors or warnings else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    raise SystemExit(run(args.godot, args.output.resolve()))
