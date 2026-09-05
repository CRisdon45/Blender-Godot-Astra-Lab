# Water / sheer interaction pass

Status: **implemented, not runtime- or visually accepted**. Continuation of draft PR #1,
on top of `b227dd7042bd42db3463d550aaf3574bfac362f7`.

## Changes

The saved scene and builder both reach the same `navigation.gd` water binding.
`water_interaction.gd` duplicates only the active pool/spill ShaderMaterials at runtime,
then calculates contact spans from the cascading sheet triangles. It does not rewrite
the saved scene, GLB, Blender assets, source geometry, lighting, vegetation, or baseline PNG.

The pool shader adds a restrained contact foam band and outward capsule-shaped ripple
highlights/normals across the width of each falling sheet. These are art-directed
surface effects, not simulated fluid dynamics. Existing pool color/caustic styling
remains; the shelf gradient is still a world-position tint, **not measured depth**.
The normal perturbation is now built in world space and transformed to view space
before writing fragment `NORMAL`, rather than mixing those coordinate systems.

Pool, sheets, and their existing glint geometry share `water_time` and a flow switch.
**W** toggles falling water and its impact response together. Ambient pool motion stays
on. `--water-off` starts in the off state for comparisons. W respects the existing
capture lock and ignores key repeats. Each captured image record now includes the
flow state, water clock, contact band, water level, and world-XZ impact spans.
Captures remain live and **not pixel-deterministic**; no baseline is automatically replaced.

## Geometry handling and limits

This is deliberately a narrow lab implementation, not an application-wide water model.
It supports **one upright horizontal rectangular pool material surface**, using its
local bounds for footprint clipping. Exported sheet node names must begin with
`Cascading water sheet` (underscores are normalized to spaces). Existing silver glints
share animation/visibility, but do not independently generate impact sources.

Pool/sheers are transformed into pool-local coordinates. Triangle intersections are
clipped to the pool footprint, and adjacent fragments are joined by shared endpoints,
including unwelded faces. Each connected impact is reduced to its longest contact span.
The shader supports at most **four** spans. Missing/unsupported bindings, non-finite
vertices, invalid indices, tilted pools, and capacity overflow report errors rather
than claiming success or silently truncating sources. Moving a sheet outside the pool
is valid and removes that impact, including clearing old shader values.

The original sheet formula has small vertical variations at its lower edge. An
independent float32 **source-formula** probe found eight disconnected intersections
at the exact pool top (0.3225), despite only two actual sheets. The binding therefore
intersects at the upper edge of a **0.012 scene-unit contact band** above that plane.
The same probe yielded two approximately 0.94-unit-wide spans for either diagonal
used to triangulate the source quads. This tolerates the existing 0.007-unit surface
motion and small endpoint variations. It is not proof that the imported GLB or saved
scene binds correctly; those require the runtime tests and real scene inspection.

Transform and source visibility changes trigger contact rebuilding, not a mesh scan
every animation frame. The off switch remembers authored visibility instead of
erasing sources or repeatedly overriding visibility while flow is on. In-place mesh
geometry changes require `water.rebuild_contacts()`; adding/removing/replacing bound
mesh nodes requires restarting/rebinding the scene. There is no per-sheer hydraulic
flow model, splash simulation, delayed foam decay, depth/refraction solution, or
Android performance claim in this pass.

## Validation performed in this continuation

- `python -m unittest discover -s tests -p test_water_contracts.py -v`: **14 passed**.
  These are source/interface checks, not a GDScript parser, shader compiler, or renderer.
- Python compilation of that test file passed.
- The independent source-formula probe described above passed for both triangle diagonals.
- The original navigation transcription matched its Git blob SHA before editing.
  Ten existing navigation/capture helper bodies were unchanged after adding water setup,
  ticking, the W key, and per-image water metadata.
- The earlier 34-test Python review suite was **not rerun in this continuation**.
- Godot/Blender were not installed in the execution environment. Godot parsing,
  the new GDScript tests, real GLB/saved-scene binding, Forward+ rendering, shader
  compilation, GPU timings, and Android checks remain **unrun**. No new render or
  visual improvement is claimed.

## Desktop acceptance commands

Run from the repository root using the Godot editor binary; on Windows prefer its
console executable. The water tests exercise the actual implementation and include
coplanar/edge/point cases, clipping, unwelded groups, both source triangulations,
indexed/non-indexed inputs, material isolation, shared time, flow-off transforms,
translation/yaw, out-of-pool cleanup, tilted surfaces, and capacity overflow.

```sh
python -m unittest discover -s tests -v
godot --headless --path godot --script res://tests/test_water_interaction.gd
godot --headless --path godot --script res://tests/test_navigation.gd
python tools/review.py --godot "PATH_TO_GODOT_EXECUTABLE"
python tools/review.py --godot "PATH_TO_GODOT_EXECUTABLE" --scene builder
```

The existing Python review runner still runs its navigation tests. Run the separate
water-test command above as well; it is not silently included in that runner.
For an off-state capture after asset import:

```sh
godot --path godot --rendering-method forward_plus --scene res://courtyard_editable.tscn -- --water-off --review
```

Check `WATER_READY` and the per-image `water` records: the unchanged courtyard should
report **two** full-width impact spans. Inspect reference/close/elevated/reverse views,
with illustration both on and off. Verify that the foam stays under the sheers, the
ripples fade locally rather than filling the pool, the highlights remain attached to
the water as the camera orbits, W removes/restores sheets and response together, and
moving a sheet moves/removes/restores its impact. Compare actual frame timings and
inspect small glints before judging visual quality. Keep this draft until those pass.

## API references consulted

- Godot spatial shader reference: world/model normal matrices and view-space fragment NORMAL.
  https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Godot ArrayMesh: indexed arrays and `surface_get_primitive_type` (an ArrayMesh method).
  https://docs.godotengine.org/en/stable/classes/class_arraymesh.html
- Godot MeshInstance3D: active materials and surface overrides.
  https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html
