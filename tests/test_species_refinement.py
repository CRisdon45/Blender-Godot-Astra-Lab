import unittest
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from species_lab_core import PROFILES, compile_plant
class RefinementTests(unittest.TestCase):
    def test_branch_radius_fits_parent_at_joint(self):
        for name in PROFILES:
            p=compile_plant(name)
            branches={b.id:b for b in p.branches}
            for b in p.branches:
                if b.parent:
                    parent=branches[b.parent]
                    self.assertLessEqual(b.radius,parent.radius*(1-parent.taper*b.attach_t))
    def test_sage_canopy_reaches_near_ground(self):
        p=compile_plant('texas_sage')
        self.assertLess(min(l.center[2]-l.radii[2] for l in p.lobes),p.height*.10)
    def test_import_preserves_authored_lods(self):
        s=(ROOT/'plant_lab/project.godot').read_text()
        self.assertIn('"meshes/generate_lods": false',s)
        self.assertIn('"mipmaps/generate": true',s)
