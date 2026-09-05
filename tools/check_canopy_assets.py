"""Independent binary GLB audit for opaque-core + brush components.
No imports of the generator, Blender, or shader math from the authoring code.
"""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys


def check(path, expected):
    raw=Path(path).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==expected['sha256'],'hash mismatch'
    assert struct.unpack_from('<4sII',raw)==(b'glTF',2,len(raw)),'GLB header'
    pos=12;document=None;binary=None
    while pos<len(raw):
        size,kind=struct.unpack_from('<II',raw,pos);chunk=raw[pos+8:pos+8+size]
        assert len(chunk)==size
        if kind==0x4e4f534a:document=json.loads(chunk)
        elif kind==0x004e4942:binary=chunk
        pos+=8+size
    assert document and binary and pos==len(raw)
    def stream(index):
        accessor=document['accessors'][index];view=document['bufferViews'][accessor['bufferView']]
        fmt,width={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[accessor['componentType']]
        cols={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']]
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        stride=view.get('byteStride',cols*width)
        result=[struct.unpack_from('<'+fmt*cols,binary,offset+i*stride) for i in range(accessor['count'])]
        if accessor.get('normalized'):
            maximum={5121:255,5123:65535}[accessor['componentType']]
            result=[tuple(x/maximum for x in row) for row in result]
        return result
    counts={};center_error=0.0
    low=expected['render_aabb_y_up']['min'];high=expected['render_aabb_y_up']['max']
    for node in document['nodes']:
        assert node.get('scale',[1,1,1])==[1,1,1], 'unexpected node scale'
        assert node.get('translation',[0,0,0])==[0,0,0], 'unexpected node translation'
    for mesh in document['meshes']:
        assert len(mesh['primitives'])==1
        primitive=mesh['primitives'][0];attrs=primitive['attributes']
        component=document['materials'][primitive['material']]['name'].rsplit('_',1)[-1].split('.')[0]
        assert component in ('wood','core','leaf','flower') and component not in counts
        vertices=stream(attrs['POSITION']);normals=stream(attrs['NORMAL']);indices=[v[0] for v in stream(primitive['indices'])]
        assert len(indices)%3==0 and min(indices)>=0 and max(indices)<len(vertices)
        counts[component]=len(indices)//3
        assert counts[component]==expected['triangles'][component]
        assert all(all(math.isfinite(x) for x in row) for row in vertices+normals)
        assert all(abs(sum(x*x for x in n)-1)<.012 for n in normals)
        assert all(all(low[k]-1e-4<=p[k]<=high[k]+1e-4 for k in range(3)) for p in vertices),'cull bounds'
        if component in ('leaf','flower'):
            uv=stream(attrs['TEXCOORD_0']);size=stream(attrs['TEXCOORD_1']);color=stream(attrs['COLOR_0']);centers=[]
            for p,t,s,c in zip(vertices,uv,size,color):
                assert all(min(abs(x),abs(x-1))<1e-5 for x in t)
                assert min(s)>0 and all(-.001<=x<=1.001 for x in c)
                centers.append((p[0]-(t[0]-.5)*s[0],p[1]-(.5-t[1])*s[1],p[2]))
            for i in range(0,len(indices),3):
                a,b,c=[centers[k] for k in indices[i:i+3]]
                center_error=max(center_error,math.dist(a,b),math.dist(a,c))
            assert center_error<1e-4,'billboard center reconstruction'
        if component=='core':
            assert 'TEXCOORD_0' in attrs
            for i in range(0,len(indices),3):
                a,b,c=[vertices[k] for k in indices[i:i+3]]
                u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                cr=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                assert sum(x*x for x in cr)>1e-18,'degenerate core triangle'
    assert set(counts)=={'wood','core','leaf','flower'}
    assert sum(counts.values())==expected['triangles']['total']
    return {'file':Path(path).name,'triangles':counts,'center_error':center_error}

if __name__=='__main__':
    project=Path(sys.argv[1] if len(sys.argv)>1 else 'plant_lab')
    catalog=json.loads((project/'engine_data/canopy_catalog.json').read_text())
    reports=[check(project/level['path'],level) for plant in catalog['variants'] for level in plant['lods']]
    assert len(reports)==36
    print(json.dumps({'passed':True,'assets':reports,'tablet_tested':False},indent=2))
