# Navigation and review continuation

Date: September 4, 2026 (America/Phoenix)
Base: `b7b3624e013b2a70274588ad23c25399e69e3532`
Disposition: **Technical only; desktop runtime and visual acceptance pending.**

## Scope and authority

One repository, one base, one outcome: make the existing courtyard easier to inspect
without destroying its baseline or confusing successful file writes with visual
acceptance. The Blender authoring files and existing GLB/editable scene remain unchanged.
This lab is a rendering study; it does not acquire product geometry, placement,
quantity, botanical, or pricing authority. No production integration is changed.

The reviewed source includes the repository inventory, README, material/export script,
scene builder, navigation, water shader, and project settings. This was a source review,
not a visual inspection of a freshly rendered scene. The README explicitly says the
original reference image is not in the repository. No exact style-match claim is made.

## Implemented

- Shared navigation/capture code for the generated and saved scene. Both illustration
  passes now toggle together, including in the generator.
- Pole-safe orbit, bounded zoom, focus-loss drag release, ignored key repeats, and
  input lock while capturing. Reset restores the original reference transform.
- Six repeatable camera presets, available through keys 1–6. They are inspection
  candidates, not visually accepted camera compositions.
- `--review`: 12 images, six angles with illustration on/off. Existing `--capture`
  remains a two-frame reference-camera capture. F12 captures the current view.
- Unique writable output directories. Routine captures never target the tracked PNG.
  `--capture-dir` accepts absolute paths or `user://`; `res://` is rejected.
- Failed writes or scene saves abort batch operation. `REVIEW_OK` requires all intended
  writes to succeed. Headless capture fails immediately rather than awaiting a draw.
- A local Python runner with per-stage logs, subprocess timeouts, explicit Forward+
  rendering, Git provenance, and manifest/PNG-header validation. Godot error output is
  treated as failure even with exit code zero. Neither review entry point regenerates
  the editable scene. Regeneration still requires the existing `--save-editable` flag.

## Validation actually performed

`python -m unittest discover -s tests -v`: **34 tests passed.** These are Python unit
and source-contract tests, using synthetic file/process fixtures. They cover missing
and duplicate images, bad PNG headers/dimensions, malformed manifests, path traversal,
false determinism/acceptance claims, missing executables, failed processes, timeouts,
zero-exit Godot errors, both review commands, and shared-source integration contracts.
Python compilation of the runner also passed.

The scene-builder and README source transcriptions were checked against the original
Git blob SHA before editing. The builder's complete `apply_materials` body was retained
byte-for-byte. No shader, material values, lighting values, geometry source, imported
asset, saved scene, or baseline PNG was changed in this pass.

**Not run:** Godot parsing/runtime tests, scene import, Forward+ rendering, Blender
export, GPU timings, or Android device testing. Godot and Blender were not installed
in the execution environment. `godot/tests/test_navigation.gd` exercises the actual
GDScript controller (including a synthetic scene fixture), but has not been executed.
The branch therefore remains a draft rather than an accepted rendered improvement.

## Desktop acceptance

Run both commands in the README on a graphics-capable desktop. Each should produce a
runner report with `status: capture_complete` and 12 view/style PNGs. Inspect both
`navigation.log` and `render.log`, then inspect the actual images and exercise mouse
orbit/zoom/reset and I/F12 interactively. Verify the tracked baseline and editable scene
remain unchanged. A builder review uses the imported GLB; an editable review preserves
manual scene edits, so those two scene outputs are not assumed identical.

Capture manifests deliberately say `visual_acceptance: not_evaluated` and
`pixel_deterministic: false`. Shader TIME is live. On/off pairs can have different water,
fire, or foliage phases; they are not exact pixel comparisons. A two-frame capture does
not by itself prove the animation is correct. PNG header checks are not full image
content, black-frame, or visual-quality validation. Draw-call counts are observations,
not a frame-time benchmark. The current Forward+ desktop study is not Android-qualified.

## Next visual work, after the desktop witness

The water shader currently uses an opaque procedural surface and a world-Z color ramp,
not pool-depth measurement or a flow model coupled to the sheers. Work next on the
water/spillway meeting point as one bounded visual pass, using the actual source
reference and a fixed camera. Keep it stylized and inspect real Godot output rather
than claiming physical simulation.

The exporter constructs 24 clusters × 380 individual leaf polygons per broadleaf tree
before export triangulation. That is a source-code observation, not a measured GPU
bottleneck, but it is a clear place to challenge the high-frequency foliage approach.
A later plant pass should prioritize full 3D silhouette, coherent canopy masses and
negative space, not add still more small leaf detail. Do not replace plants blindly
without inspecting the reference and multiple actual camera views.

The saved editable TSCN is about 38 MB and the GLB about 23 MB in the base tree. Investigate
what geometry is duplicated before choosing a production packaging strategy; do not
turn this lab's convenient editable export into an authoritative product scene format.
No asset simplification, runtime shader changes, CI workflows, paid coding agents,
automatic merge, or deployment were introduced here.
