"""Validate the baked glTF attributes the foliage shader actually depends on."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import struct


def validate(path: Path) -> dict:
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw)
    if magic != b'glTF' or version != 2 or length != len(raw):
        raise ValueError('Invalid GLB header')
    pos, data, binary = 12, None, None
    while pos < len(raw):
        n, kind = struct.unpack_from('<II', raw, pos)
        chunk = raw[pos+8:pos+8+n]
        if len(chunk) != n:
            raise ValueError('Truncated GLB chunk')
        if kind == 0x4E4F534A: data = json.loads(chunk)
        if kind == 0x004E4942: binary = chunk
        pos += n+8
    if not isinstance(data, dict) or binary is None:
        raise ValueError('Missing GLB JSON or binary')
    def accessor(index):
        a = data['accessors'][index]
        view = data['bufferViews'][a['bufferView']]
        types = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
        code, size = types[a['componentType']]
        count = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        stride = view.get('byteStride', count*size)
        base = view.get('byteOffset',0)+a.get('byteOffset',0)
        rows=[]
        for i in range(a['count']):
            row=struct.unpack_from('<'+code*count,binary,base+i*stride)
            if a.get('normalized'):
                maxval={5120:127,5121:255,5122:32767,5123:65535}[a['componentType']]
                row=tuple(max(-1,v/maxval) for v in row)
            rows.append(row)
        return rows
    records=[]
    for mesh in data['meshes']:
        for prim in mesh['primitives']:
            mat=data['materials'][prim['material']]
            if not mat.get('name','').startswith('Anime foliage'): continue
            attrs=prim['attributes']
            required={'POSITION','NORMAL','TEXCOORD_0','TEXCOORD_1','COLOR_0'}
            if not required <= attrs.keys():
                raise ValueError(f'{mesh["name"]}: missing {required-attrs.keys()}')
            vertices=accessor(attrs['POSITION']); normals=accessor(attrs['NORMAL'])
            uv=accessor(attrs['TEXCOORD_0']); sizes=accessor(attrs['TEXCOORD_1']); colors=accessor(attrs['COLOR_0'])
            indices=[x[0] for x in accessor(prim['indices'])]
            centers=[]
            for p,n,t,s,c in zip(vertices,normals,uv,sizes,colors):
                if not all(math.isfinite(v) for row in (p,n,t,s,c) for v in row):
                    raise ValueError('Nonfinite shader input')
                if min(s)<=0 or abs(sum(v*v for v in n)-1)>.01 or abs(c[2])>.005:
                    raise ValueError('Invalid card size, normal or color stream')
                centers.append((p[0]-(t[0]-.5)*s[0],p[1]-(.5-t[1])*s[1],p[2]))
            error=0.0
            for i in range(0,len(indices),3):
                error=max(error,math.dist(centers[indices[i]],centers[indices[i+1]]),math.dist(centers[indices[i]],centers[indices[i+2]]))
            if error>.005:raise ValueError(f'Card center mismatch: {error}')
            spans=[max(p[k] for p in centers)-min(p[k] for p in centers) for k in range(3)]
            if min(spans)<.3:raise ValueError('Crown anchors are not volumetric')
            variants=sorted(set(round(c[0]*7) for c in colors))
            if variants!=list(range(8)):raise ValueError(f'Lost brush variants: {variants}')
            records.append({'mesh':mesh['name'],'vertices':len(vertices),'triangles':len(indices)//3,
                            'maximum_center_error':error,'anchor_span':spans,'atlas_variants':variants})
    total=sum(r['triangles'] for r in records)
    if len(records)!=12 or total!=14300:
        raise ValueError(f'Expected 12 foliage meshes / 14300 triangles, got {len(records)} / {total}')
    return {'status':'passed','foliage_meshes':len(records),'triangles':total,'meshes':records,
            'visual_acceptance':False,'performance_certified':False}


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('glb',type=Path);args=ap.parse_args()
    print(json.dumps(validate(args.glb),indent=2))
