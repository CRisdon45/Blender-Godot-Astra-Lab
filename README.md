# Blenderâ€“Godot Astra Lab

A backyard courtyard study authored in Blender and rendered in Godot. The visual target is a supplied architectural illustration: warm limestone and timber, a turquoise pool, twin waterfalls, fire bowls, a furnished pergola, and desert planting.

**Godot is the final rendering target.** This is a working first style study, not a finished match to the reference. Vegetation, furniture, water realism, and composition still need refinement.

![Current Godot viewport](godot/captures/godot_courtyard.png)

## Open and run

1. Use **Godot 4.7.1 or newer**. The project was validated with 4.7.1 and the Forward+ Vulkan renderer on an NVIDIA RTX 3070 Ti Laptop GPU.
2. Import `godot/project.godot` into Godot and allow the assets to import.
3. Open `godot/courtyard_editable.tscn` to inspect or edit the scene.
4. Press **F6** to run that scene or **F5** to run the project.

The saved scene contains the meshes, lights, camera, and material overrides. Blender is not required to run it. The illustration contour effect requires Forward+; the mobile Compatibility setting is not the validated visual target.

| Control | Action |
| --- | --- |
| Right mouse drag | Orbit the courtyard |
| Mouse wheel | Zoom |
| R | Reset the reference camera |
| I | Toggle the illustration finish |
| F12 | Save `godot/captures/manual.png` |

## Files

| Path | Purpose |
| --- | --- |
| `pool_godot_source.blend` | Refined Blender authoring scene used for the Godot export |
| `pool_recreation.blend` | Earlier Blender scene used as the export script's starting point |
| `build_scene.py` | Generate the original scene and Blender preview |
| `refine_scene.py` | Reapply the Blender camera and lighting refinement |
| `export_godot.py` | Refine geometry, correct normals, consolidate material groups, and export portable assets |
| `godot/assets/backyard.glb` | Blender geometry in portable glTF form |
| `godot/assets/*_grain.png` | Generated seamless material detail maps |
| `godot/courtyard.gd` | Build the Godot lighting and material setup and save the editable scene |
| `godot/courtyard_editable.tscn` | Ready-to-edit and ready-to-run Godot scene |
| `godot/navigation.gd` | Camera controls and viewport capture |
| `godot/shaders/` | Architectural materials, water, spillways, flames, contours, and paper grain |
| `godot/captures/godot_courtyard.png` | Actual Godot viewport capture |
| `pool_recreation.png` | Earlier Blender preview, not the final renderer target |

All required assets are included. There are no downloaded asset packs, external textures, or Python dependencies beyond Blender's bundled Python/NumPy. Godot regenerates its `.godot` cache; it is intentionally not tracked. Generated Blender backups and runtime logs are also excluded.

## Rebuild

Tested with **Blender 5.2.1 LTS**. Run these commands from the repository root, substituting full executable paths if Blender and Godot are not on `PATH`:

```sh
blender --background --python build_scene.py
blender --background --python export_godot.py
godot --headless --path godot --editor --import
godot --path godot --scene res://courtyard.tscn -- --save-editable --capture
```

The final command needs a graphics-capable desktop. It builds the Godot setup, replaces `godot/courtyard_editable.tscn`, and captures two frames before exiting. The export script also replaces `pool_godot_source.blend` and the GLB. Preserve manual scene edits before regenerating those files.

To validate the saved scene independently:

```sh
godot --path godot -- --capture
```

The water, spillways, fire, and foliage use animated shaders. They are stylized effects, not fluid or combustion simulations. Dimensions and obscured areas were inferred from one image. The source reference image is not included in this repository.
