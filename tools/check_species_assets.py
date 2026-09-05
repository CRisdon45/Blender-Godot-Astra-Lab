"""Independent GLB shader-stream / index budget check; no Blender dependency."""
import hashlib, json, math, struct, sys
from pathlib import Path


def check(path, expected):
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == expected['sha256'], 'asset hash'
    assert struct.unpack_from('<4sII', raw) == (b'glTF', 2, len(raw)), 'GLB header'
    pos = 12
    document = binary = None
    while pos < len(raw):
        n, kind = struct.unpack_from('<II', raw, pos)
        chunk = raw[pos+8:pos+8+n]
        assert len(chunk) == n
        if kind == 0x4E4F534A: document = json.loads(chunk)
        if kind == 0x004E4942: binary = chunk
        pos += n+8
    assert document and binary
    def accessor(index):
        a = document['accessors'][index]
        b = document['bufferViews'][a['bufferView']]
        code, width = {5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
        cols = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        start = b.get('byteOffset',0)+a.get('byteOffset',0)
        stride = b.get('byteStride',cols*width)
        rows = [struct.unpack_from('<'+code*cols,binary,start+i*stride) for i in range(a['count'])]
        if a.get('normalized'):
            maximum = {5121:255,5123:65535}[a['componentType']]
            rows = [tuple(x/maximum for x in row) for row in rows]
        return rows
    total = 0
    parts = []
    max_error = 0.0
    for mesh in document['meshes']:
        for primitive in mesh['primitives']:
            attrs = primitive['attributes']
            indices = [row[0] for row in accessor(primitive['indices'])]
            assert len(indices)%3 == 0
            vertices = accessor(attrs['POSITION'])
            assert max(indices) < len(vertices)
            total += len(indices)//3
            name = document['materials'][primitive['material']]['name']
            part = 'leaf' if '_leaf' in name else ('flower' if '_flower' in name else 'wood')
            parts.append(part)
            if part == 'wood':
                assert len(indices)//3 == expected['wood_triangles']
                continue
            assert len(indices)//3 == 2*expected[part+'_cards']
            streams = [accessor(attrs[k]) for k in ('NORMAL','TEXCOORD_0','TEXCOORD_1','COLOR_0')]
            centers = []
            for p,n,uv,size,color in zip(vertices,*streams):
                assert all(math.isfinite(x) for row in (p,n,uv,size,color) for x in row)
                assert min(size)>0 and abs(sum(x*x for x in n)-1)<.01
                assert all(min(abs(x),abs(x-1))<1e-5 for x in uv), 'UV0 was reordered'
                assert all(-.001<=x<=1.001 for x in color)
                centers.append((p[0]-(uv[0]-.5)*size[0],p[1]-(.5-uv[1])*size[1],p[2]))
            for i in range(0,len(indices),3):
                a,b,c = [centers[k] for k in indices[i:i+3]]
                max_error = max(max_error,math.dist(a,b),math.dist(a,c))
            assert max_error < 1e-4, 'billboard center reconstruction'
            assert min(max(p[k] for p in centers)-min(p[k] for p in centers) for k in range(3))>.05
    assert sorted(parts)==['flower','leaf','wood'], parts
    assert total==expected['total_triangles'], (total,expected)
    return {'file':path.name,'triangles':total,'max_center_error':max_error}


if __name__=='__main__':
    folder=Path(sys.argv[1] if len(sys.argv)>1 else 'plant_lab/assets')
    manifest=json.loads((folder/'manifest.json').read_text())
    reports=[check(folder/entry['file'],entry) for entry in manifest['assets']]
    assert len(reports)==36
    print(json.dumps({'status':'passed','assets':reports,'visual_acceptance':False,'tablet_tested':False},indent=2))
