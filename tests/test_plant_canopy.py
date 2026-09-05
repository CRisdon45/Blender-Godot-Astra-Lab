from pathlib import Path
import sys
import math
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from plant_engine.canopy import compose, core_mesh, selected, bounds
from species_lab_core import bezier, wood_mesh
from plant_engine.recipe import canonical_bytes

class CanopyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plants=[compose(s,seed,m) for s in ('desert_museum','texas_sage') for seed in (41,73) for m in (0,.5,1)]

    def test_deterministic(self):
        from dataclasses import asdict
        for p in self.plants:
            self.assertEqual(asdict(p),asdict(compose(p.species,p.seed,p.maturity)))

    def test_attached_branches(self):
        for p in self.plants:
            lookup={b.id:b for b in p.branches}
            for b in p.branches:
                if b.parent:
                    self.assertLess(math.dist(b.points[0],bezier(lookup[b.parent].points,b.attach_t)),1e-9)
                    self.assertLessEqual(b.radius,lookup[b.parent].radius*(1-lookup[b.parent].taper*b.attach_t)+1e-9)

    def test_lifetime_branch_identity(self):
        for s in ('desert_museum','texas_sage'):
            old={b.id for b in compose(s,41,0).branches};new={b.id for b in compose(s,41,1).branches}
            self.assertTrue(old<=new)

    def test_finite_surface_and_unit_normals(self):
        for p in self.plants:
            for lod in range(3):
                core=core_mesh(p,lod)
                self.assertEqual(len(core.vertices),len(core.normals))
                for point in core.vertices:self.assertTrue(all(math.isfinite(x) for x in point))
                for n in core.normals:self.assertAlmostEqual(sum(x*x for x in n),1,places=7)
                for face in core.triangles:self.assertTrue(min(face)>=0 and max(face)<len(core.vertices))

    def test_no_degenerate_core_faces(self):
        for p in self.plants:
            for lod in range(3):
                core=core_mesh(p,lod)
                for face in core.triangles:
                    a,b,c=[core.vertices[i] for i in face]
                    u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
                    cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                    self.assertGreater(sum(x*x for x in cross),1e-18)

    def test_nested_spray_identities(self):
        for p in self.plants:
            previous={c.id for c in p.cards}
            for lod in range(3):
                ids={c.id for c in selected(p.cards,lod)}
                self.assertTrue(ids<=previous);previous=ids

    def test_primary_triangle_caps(self):
        for p in self.plants:
            last=100000
            for lod in range(3):
                v,f=wood_mesh(p,lod)
                total=len(f)+len(core_mesh(p,lod).triangles)+2*len(selected(p.cards,lod))+2*len(selected(p.flowers,lod))
                caps=(4200,2100,1300) if p.species=='desert_museum' else (2300,1400,900)
                self.assertLessEqual(total,caps[lod]);self.assertLess(total,last);last=total

    def test_core_and_sprays_remain_volumetric(self):
        for p in self.plants:
            for axis in range(3):
                points=core_mesh(p,2).vertices
                self.assertGreater(max(v[axis] for v in points)-min(v[axis] for v in points),.1)

    def test_tree_uses_separate_open_masses(self):
        p=compose('desert_museum',41,1)
        self.assertGreater(len(p.lobes),10)
        centers={tuple(round(x,3) for x in l.center) for l in p.lobes}
        self.assertEqual(len(centers),len(p.lobes))

    def test_invalid_lod_fails(self):
        for bad in (-1,3,True,1.0):
            with self.assertRaises(ValueError):core_mesh(self.plants[0],bad)

    def test_opaque_shader_has_no_discard_or_alpha(self):
        code=(Path(__file__).resolve().parents[1]/'plant_lab/shaders/canopy_core.gdshader').read_text()
        body=code[code.index('render_mode'):]
        for forbidden in ('discard','ALPHA','SCREEN_TEXTURE','DEPTH_TEXTURE','TIME'):
            self.assertNotIn(forbidden,body)

if __name__=='__main__':unittest.main()
