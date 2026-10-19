"""Validate actual build evidence and create the source/project handoff."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile
import zlib

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


def png_pixels(path):
    """Decode Godot RGB/RGBA PNGs using only the Python standard library."""
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    cursor, compressed = 8, bytearray()
    while cursor < len(data):
        size = struct.unpack_from('>I',data,cursor)[0]
        tag = data[cursor+4:cursor+8]
        payload = data[cursor+8:cursor+8+size]
        if tag == b'IHDR':
            width,height,bits,kind,_,_,interlace = struct.unpack('>IIBBBBB',payload)
            assert bits == 8 and kind in (2,6) and interlace == 0
        elif tag == b'IDAT':
            compressed.extend(payload)
        cursor += size+12
    channels = 3 if kind == 2 else 4
    stride = width*channels
    raw = zlib.decompress(compressed)
    pixels, previous = bytearray(), bytearray(stride)
    for row in range(height):
        start = row*(stride+1)
        filtering = raw[start]
        current = bytearray(raw[start+1:start+1+stride])
        for i in range(stride):
            a = current[i-channels] if i >= channels else 0
            b = previous[i]
            c = previous[i-channels] if i >= channels else 0
            if filtering == 1:
                predictor = a
            elif filtering == 2:
                predictor = b
            elif filtering == 3:
                predictor = (a+b)//2
            elif filtering == 4:
                estimate = a+b-c
                distances = (abs(estimate-a),abs(estimate-b),abs(estimate-c))
                predictor = (a,b,c)[distances.index(min(distances))]
            else:
                assert filtering == 0
                predictor = 0
            current[i] = (current[i]+predictor)&255
        pixels.extend(current)
        previous = current
    return (width,height,channels),pixels


def pixel_difference(a,b):
    shape,first = png_pixels(a)
    other_shape,second = png_pixels(b)
    assert shape == other_shape
    histogram = [0]*256
    for x,y in zip(first,second):
        histogram[abs(x-y)] += 1
    mean = sum(i*n for i,n in enumerate(histogram))/len(first)
    significant = sum(histogram[5:])/len(first)
    return {'mean_channel_error_255':round(mean,6),'fraction_channels_error_over_4':round(significant,6)}


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
        fixed = pixel_difference(capture_dir/'01_hero.png',capture_dir/'02_hero_repeat.png')
        reimport = pixel_difference(capture_dir/'01_hero.png',HERE/'generated/hero_before_reimport.png')
        # SSIL samples previous frames. Measure settled visual stability instead
        # of requiring identical bytes from different temporal sample phases.
        for label,result in [('fixed',fixed),('reimport',reimport)]:
            assert result['mean_channel_error_255'] <= .75 and result['fraction_channels_error_over_4'] <= .025, (label,result)
        wind = pixel_difference(capture_dir/'05_second_sun.png',capture_dir/'06_fixed_wind.png')
        assert wind['mean_channel_error_255'] > fixed['mean_channel_error_255']+.10, ('Wind does not exceed temporal noise',wind,fixed)
        assert runtime['renderer'] == 'forward_plus', runtime['renderer']
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
            'fixed_view_visual_stability':fixed, 'clean_reimport_visual_stability':reimport,
            'wind_changes_pixels':wind, 'renderer':runtime['renderer'], 'tree_triangles': runtime['tree_triangles'],
            'tree_meshes':runtime['tree_meshes'], 'archive_sha256':hashlib.sha256(bundle.read_bytes()).hexdigest()}
        (HERE/'generated/verification.json').write_text(json.dumps(proof,indent=2)+'\n')
        print('PALO_VERDE_PACKAGE_OK '+json.dumps(proof))
    print('PALO_VERDE_GLB_VALIDATION_OK')


if __name__ == '__main__':
    main()
