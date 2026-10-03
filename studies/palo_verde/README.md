# Authored palo verde · Blender → Godot

A self-contained flowering palo verde on a meadow, reconstructed as real 3D
geometry from Cody's photographic and stylized-tree references. The low green
trunk, spreading irregular crown, small folded leaflets and five-petalled yellow
flowers are authored by a deterministic Blender script. No generated image is
used as a billboard or backdrop. The supplied reference images are not published.

## Get the built scene

The **Authored Palo Verde** GitHub Actions run publishes two artifacts:

- **palo-verde-source-and-evidence**: `PaloVerde_Blender_Godot.zip`, editable
  `.blend`, GLB tree, complete Godot project, real Blender/Godot captures and logs.
- **palo-verde-windows**: extract and double-click `PaloVerde.exe`.

In the source ZIP, open `godot/project.godot` using **Godot 4.7.2 Standard** and
press F5. Open `godot/palo_verde.tscn` for the lighting, asset placement and camera.
Open `generated/palo_verde_authored.blend` in **Blender 4.5.3 LTS** to edit the tree
meshes, meadow, camera and lights. Blender is not needed to run the Godot project.

Right-drag or touch-drag to orbit, scroll to zoom, **R** to reset, **W** to toggle
gentle wind, **F12** to save a capture in Godot's application user-data directory.
Wind starts disabled so the fixed-view scene is reproducible.

## Asset contract

| Item | Contract |
|---|---|
| Authority | `build_tree.py`, fixed seed `452603`; the generated `.blend` is editable source delivery |
| Identity | `palo_verde_authored_452603` |
| Scale | Meters; artistic reference reconstruction, not surveyed botanical dimensions |
| Blender | 4.5.3 LTS, Z up |
| Godot | 4.7.2 Standard, Y up; conversion performed by Blender glTF exporter |
| Pivot | Trunk ground contact at origin |
| Tree export | Only root plus `PV_Bark`, `PV_Leaves`, `PV_Blossoms`; no ground/lights/camera |
| Meadow export | Separate `meadow.glb` |
| Materials | Three tree roles; linear vertex colors, rough matte surfaces, no image maps or alpha cards |
| Runtime overrides | `scene.gd` reapplies shaders by role; safe across clean GLB reimports |
| Fixture | `godot/palo_verde.tscn`, fixed 1200 × 900 Godot capture suite |
| Budget | Desktop hero study, fewer than 450,000 tree triangles, three tree mesh submissions |
| Target limits | Compatibility renderer for software CI and desktop portability; tablet performance and LODs not yet measured |

The current result is an artistic study, not a claim of exact style parity. CI
images prove the rendering route and reveal the remaining artistic differences.
The scene has no dependency on AI, a service connection or a marketplace pack.

## Rebuild

From the repository root with the pinned tools available:

```sh
blender --background --python studies/palo_verde/build_tree.py -- --render
godot --headless --path studies/palo_verde/godot --editor --import
godot --path studies/palo_verde/godot -- --validate --capture
```

The build creates `generated/palo_verde_authored.blend`, two GLBs and a source
manifest. It overwrites generated files; preserve manual `.blend` edits before
rerunning. Export changes from Blender using selection-only glTF to the same
asset roles, or transfer the edits into the script for reproducible builds.

Actions regenerates twice and compares geometry and GLB hashes, validates glTF
structure and vertex colors, imports and runs Godot, verifies imported bounds
and polygon count, captures front/side/detail/two sun states/fixed wind, then
deletes the import cache, reimports and checks identical hero pixels. It scans
logs for engine and shader errors even if the process exits with zero status.

## Provenance

Meshes and shaders are newly authored for this study. No third-party art or
textures are included. The references guide the species silhouette and shading
style; they are not redistributed. Blender and Godot are build tools downloaded
from their official release endpoints, with archive checksums verified. The
Windows executable uses the official Godot export template (Godot is MIT-licensed).
See `godot/COPYING-GODOT.txt` for the engine notice supplied by the CI build.
