"""Validate actual build evidence and create the source/project handoff."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

HERE = Path(__file__).resolve().parent


def glb_json(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and length == len(data)
    chunk_length, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(data[20:20+chunk_length])
    assert not doc.get('images'), 'Asset must have no missing/external textures'
    assert all('uri' not in b for b in doc.get('buffers', []))
    return doc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--package', action='store_true')
    parser.add_argument('--compare', type=Path)
    args = parser.parse_args()
    manifest = json.loads((HERE/'generated/asset_manifest.json').read_text())
    doc = glb_json(HERE/'godot/assets/palo_verde.glb')
    glb_json(HERE/'godot/assets/meadow.glb')
    assert len(doc['meshes']) == 3, len(doc['meshes'])
    assert len(doc['materials']) == 3
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert 'COLOR_0' in primitive['attributes'], mesh['name']
            assert 'NORMAL' in primitive['attributes'], mesh['name']
    if args.compare:
        old = json.loads(args.compare.read_text())
        for key in ('geometry_sha256', 'glb_sha256', 'meshes', 'bounds_blender'):
            assert old[key] == manifest[key], f'Rebuild changed {key}'
        print('PALO_VERDE_REBUILD_DETERMINISM_OK')
    if args.package:
        capture_dir = HERE/'godot/captures'
        runtime = json.loads((capture_dir/'runtime_validation.json').read_text())
        assert runtime['passed']
        assert runtime['tree_triangles'] == sum(m['triangles'] for m in manifest['meshes'].values())
        for name in ['01_hero.png','02_hero_repeat.png','03_side.png','04_foliage_detail.png','05_second_sun.png','06_fixed_wind.png']:
            assert (capture_dir/name).stat().st_size > 20000, name
        assert (capture_dir/'01_hero.png').read_bytes() == (capture_dir/'02_hero_repeat.png').read_bytes(), 'Fixed scene is not pixel stable'
        assert (capture_dir/'01_hero.png').read_bytes() == (HERE/'generated/hero_before_reimport.png').read_bytes(), 'Clean reimport changed fixed-view pixels'
        assert (capture_dir/'05_second_sun.png').read_bytes() != (capture_dir/'06_fixed_wind.png').read_bytes(), 'Wind did not move foliage'
        bundle = HERE/'generated/PaloVerde_Blender_Godot.zip'
        with zipfile.ZipFile(bundle, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(HERE.rglob('*')):
                if not path.is_file() or path == bundle:
                    continue
                relative = path.relative_to(HERE)
                if any(p in ('.godot','__pycache__','windows') for p in relative.parts):
                    continue
                if path.suffix in ('.log','.pyc') or path.name.endswith('.blend1'):
                    continue
                archive.write(path, str(Path('PaloVerde')/relative))
        proof = {'build_geometry_sha256': manifest['geometry_sha256'],
            'fixed_view_pixel_stability': True, 'clean_reimport_pixel_stability': True,
            'wind_changes_pixels': True, 'tree_triangles': runtime['tree_triangles'],
            'tree_meshes':runtime['tree_meshes'], 'archive_sha256':hashlib.sha256(bundle.read_bytes()).hexdigest()}
        (HERE/'generated/verification.json').write_text(json.dumps(proof,indent=2)+'\n')
        print('PALO_VERDE_PACKAGE_OK '+json.dumps(proof))
    print('PALO_VERDE_GLB_VALIDATION_OK')


if __name__ == '__main__':
    main()
