# Plant Engine Foundation: VM review branch

This opt-in study runs on GitHub Actions so the reviewer does not need Blender or Godot installed.

## Review without installing software

Open the latest **Plant foundation VM build and Mobile-renderer review** run on branch `work/plant-engine-vm-validation`. The artifact contains `images/` with actual Godot PNGs, unfiltered logs, test reports, the source commit, and a generated `bundle/` with Blender authoring files and a runnable Godot project.

A completed workflow is not automatically an artistic approval. Software Vulkan on Linux is not the Galaxy Tab S10 FE GPU. Calendar years and litter rates are not calibrated.

## Run the generated project later

Import `bundle/plant_lab/project.godot` using Godot 4.7.1. Open `engine_lab.tscn` and press F6. F5 deliberately retains the original viewer. The new scene includes the pair, growth stages, 108-plant garden, mature-footprint toggle, triangle-target toggle, and diagnostics export.

## Build from a source checkout

The GLBs and Blender files are generated, not committed on this branch. Install Blender 5.2.1 and Godot 4.7.1, then run:

```sh
python3 tools/make_lod_contract.py
blender --background --factory-startup --python-exit-code 1 --python tools/build_species_lab.py
python3 -m unittest discover -s tests -p 'test_plant_*.py' -v
godot --headless --path plant_lab --editor --import
godot --headless --path plant_lab --script res://engine/tests/plant_runtime_smoke.gd
```

See `docs/PLANT_ENGINE_FOUNDATION.md` for implementation boundaries. Nothing here changes the courtyard scene or merges into main.
