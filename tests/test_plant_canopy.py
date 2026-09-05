from pathlib import Path
import sys
import math
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from plant_engine.canopy import compose, core_mesh, foliage_mesh, selected, bounds
from species_lab_core import bezier, wood_mesh

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

    def test_finite_surfaces_and_unit_normals(self):
        for p in self.plants:
            for lod in range(3):
                for surface in (core_mesh(p,lod), foliage_mesh(p,lod)):
                    self.assertEqual(len(surface.vertices),len(surface.normals))
                    self.assertEqual(len(surface.vertices),len(surface.uv))
                    for point in surface.vertices:self.assertTrue(all(math.isfinite(x) for x in point))
                    for n in surface.normals:self.assertAlmostEqual(sum(x*x for x in n),1,places=7)
                    for face in surface.triangles:self.assertTrue(min(face)>=0 and max(face)<len(surface.vertices))

    def test_no_degenerate_opaque_faces(self):
        for p in self.plants:
            for lod in range(3):
                for surface in (core_mesh(p,lod), foliage_mesh(p,lod)):
                    for face in surface.triangles:
                        a,b,c=[surface.vertices[i] for i in face]
                        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
                        cr=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                        self.assertGreater(sum(x*x for x in cr),1e-18)

    def test_nested_flower_identities(self):
        for p in self.plants:
            previous={c.id for c in p.flowers}
            for lod in range(3):
                ids={c.id for c in selected(p.flowers,lod)}
                self.assertTrue(ids<=previous);previous=ids

    def test_primary_triangle_caps(self):
        for p in self.plants:
            last=100000
            for lod in range(3):
                _,wood=wood_mesh(p,lod)
                total=len(wood)+len(core_mesh(p,lod).triangles)+len(foliage_mesh(p,lod).triangles)+2*len(selected(p.flowers,lod))
                caps=(7000,2000,1200) if p.species=='desert_museum' else (8500,2600,1200)
                self.assertLessEqual(total,caps[lod],(p.species,p.seed,p.maturity,lod,total));self.assertLess(total,last);last=total

    def test_visible_modules_dominate_support_geometry_close(self):
        for p in self.plants:
            self.assertGreater(len(foliage_mesh(p,0).triangles),len(core_mesh(p,0).triangles))

    def test_visible_modules_remain_volumetric(self):
        for p in self.plants:
            points=foliage_mesh(p,2).vertices
            for axis in range(3):
                self.assertGreater(max(v[axis] for v in points)-min(v[axis] for v in points),.1)

    def test_tree_uses_many_separate_open_masses(self):
        p=compose('desert_museum',41,1)
        self.assertGreater(len(p.lobes),10)
        centers={tuple(round(x,3) for x in l.center) for l in p.lobes}
        self.assertEqual(len(centers),len(p.lobes))
        self.assertGreater(len(foliage_mesh(p,0).triangles),700)

    def test_invalid_lod_fails(self):
        for bad in (-1,3,True,1.0):
            with self.assertRaises(ValueError):core_mesh(self.plants[0],bad)
            with self.assertRaises(ValueError):foliage_mesh(self.plants[0],bad)

    def test_opaque_shader_has_no_discard_or_alpha(self):
        root=Path(__file__).resolve().parents[1]/'plant_lab/shaders'
        for name in ('canopy_core.gdshader','canopy_leaf.gdshader'):
            code=(root/name).read_text(); body=code[code.index('render_mode'):]
            for forbidden in ('discard','ALPHA','SCREEN_TEXTURE','DEPTH_TEXTURE','TIME'):
                self.assertNotIn(forbidden,body,name)

if __name__=='__main__':unittest.main()
