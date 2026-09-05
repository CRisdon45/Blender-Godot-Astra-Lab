# Courtyard acceptance gate

## Disposition

**Technical continuation only. Keep PR #1 in draft.** This pass strengthens the
local acceptance command; it does not accept the water design or claim a new render.
It continues water commit `452cbf96d46530d82f37b86a330a1c44807f5aab` on
`work/courtyard-review-pass`. Main is not merged or changed.

The baseline's README calls for Godot **4.7.1 or newer** and Forward+. The runner
now checks that documented minimum within Godot 4. This is not independent
verification of a newly installed engine or of the baseline's GPU results.

## Why this pass

1. The previous runner ran navigation tests but skipped the water runtime suite.
   It also ran navigation tests before importing a fresh checkout's resources.
2. A regression probe replaced all 12 fixture images with only their first 33
   bytes. The old runner still reported a complete manifest. PNG signatures and
   dimensions alone were not evidence of usable image data.
3. Capture records contained water state, but the runner did not validate it or
   compare flow-on/off sets. A complete list of filenames could therefore mask
   missing binding evidence or a mismatched comparison.

These are test-harness findings, not observations of the scene running in Godot.

## Current commands

From a full repository checkout, using Python 3.10+ and the Godot editor executable
(the `_console.exe` executable on Windows):

```sh
python -m unittest discover -s tests -v
python tools/review.py --godot "PATH_TO_GODOT_EXECUTABLE" --scene both
```

The second command is the full desktop gate. It performs:

- engine-version check and headless editor import;
- existing navigation and water runtime tests;
- a new real-scene water/navigation test for each selected entry point;
- Forward+ captures and integrity/metadata checks for each selected flow state.

Import is deliberately before the tests. The real-scene test loads either the
saved editable scene or the builder with the actual imported GLB. It checks the
binding, two distinct contact spans, shared clock and flow uniforms, the W input
handler, visibility restoration, source movement while flow is off, camera views,
orbit limits, reset and the capture input lock. It does not regenerate or save any
scene or asset. Headless success explicitly reports `graphics_validated: false`.

Default scope is the editable scene with both water states: **24 images** (six
views x two illustration states x two flow states). `--scene both` checks both
entry points and requests **48 images**. These are expected output counts, not
images generated during this continuation.

```sh
# Import and run all runtime suites for both entry points, without rendering.
python tools/review.py --godot "PATH_TO_GODOT_EXECUTABLE" --scene both --tests-only

# One entry point and one flow state: 12 images.
python tools/review.py --godot "PATH_TO_GODOT_EXECUTABLE" --scene builder --water off
```

`--output` sets an alternate output root; otherwise unique run directories are
created under `.review-output/`. `--timeout` is a finite, positive per-process
limit. Batch capture never uses `--save-editable` or replaces the tracked baseline.

## What the gate checks

The PNG check reads actual chunks and verifies CRCs, required structure, bounded
size, complete zlib data, scanline lengths and filter-byte ranges. It rejects
header-only files, missing image data, truncation, corrupt CRCs and excess streams.
It deliberately supports only non-interlaced RGB/RGBA8 viewport PNGs, at most
8192 pixels on either axis, 16 Mi pixels total and 64 MiB of file data. It is not a
general-purpose image decoder or a visual-quality judge.

The existing 12 view/style pairs must be present with matching image dimensions.
Water readiness and every capture must identify an active, error-free binding,
finite data, the requested flow state and exactly **two distinct, nonzero spans**.
Within a stationary capture set, contacts must remain stable and time must not
move backward. Illustration pairs and flow pairs must keep the same camera pose,
field of view, image dimensions and contact locations. This is intentionally a
gate for this unchanged twin-sheer courtyard, not arbitrary redesigned scenes.

Reports record source revision/dirty status when Git is available, engine version,
commands, logs and each process's outcome. Runtime and graphics dispositions are
separate. A missing engine also creates a failed report. Per-stage elapsed time
is process wall time, **not GPU or frame-performance evidence**. Successful capture
integrity leaves `visual_acceptance: not_evaluated` and `pixel_deterministic: false`.

## Small source correction

`navigation.gd` now declares `water` as the preloaded `WaterInteraction` script type
rather than leaving the member dynamic. This removes reliance on inferring the
return type of `water.setup()` from a dynamic receiver. It is a source-level
precaution; no Godot compiler success is claimed. All other navigation code,
water binding logic and shader code are unchanged in this continuation.

## Evidence produced here

- **111 Python tests passed:** all 34 original review tests, all 14 original water
  source/interface checks, and 63 new acceptance-gate regressions.
- Python syntax compilation passed for the staged tools/tests.
- PNG tests use synthetic valid/corrupted files. Pipeline tests use mocked engine
  output. Two process tests launch Python, **not Godot**, to exercise log handling.
- Fetched original files were checked against their Git blob SHAs before editing.
- The real missing-engine invocation exits with failure and a report; it cannot
  produce a runtime or graphics pass.

**Not run here:** Godot parsing, any Godot runtime suite, loading the actual saved
scene/GLB, shader compilation, graphics capture, visual review, GPU timing and
Android testing. Godot and Blender were not installed; obtaining a Godot binary
from this environment did not succeed. A partial source staging area was used for
Python/source tests, not a substitute for a complete runtime checkout.

No Blender files, GLB, saved scene, scene geometry, lighting, vegetation, shaders,
water interaction logic or baseline PNG are changed. No merge, CI dispatch,
deployment, paid coding agent or runtime AI is involved.

## What still decides acceptance

Run the full desktop command and inspect its logs and newly produced images.
Compare reference, close, elevated and reverse views with water on/off and
illustration on/off. Exercise live orbit and W in the actual scene. Look for two
full-width contact regions, coherent lighting while orbiting, restrained ripple
scale and no stale contact response when moving a source outside the pool.

Captures use live time. Matching camera metadata is not matched animation phase,
a pixel-diff baseline, proof of animation, or proof that every visual effect is
correct. A clean report does not approve the artistic result. Keep the PR in
draft until runtime and visual review are recorded; tablet performance remains a
separate gate. Preserve the existing baseline until a new one is explicitly
accepted.

`REVIEW_PASS.md` and `WATER_INTERACTION_PASS.md` retain historical implementation
notes. Their older navigation-only runner and separate-water-test instructions
are superseded by this integrated command.
