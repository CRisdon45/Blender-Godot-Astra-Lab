# Courtyard visual evidence protocol

## Visual target registration

Before claiming visual convergence, identify a target by stable ID, revision/hash, accessible file or private package location, provenance/use rights, and the properties to match (composition, water, material scale, planting silhouette, line/shadow treatment). Use owned/generated images or authorized references; do not publish a private source just to make it accessible to an agent. Record Cody's acceptance status separately from the agent's comparison.

The original courtyard illustration is currently unavailable in the repository. Work on independently testable improvements may continue, but mark source-image comparison blocked/unverified until the image is accessible. Product-facing experiments should link the applicable Design-Platform Perspective charter and visual authority. Images constrain visual comparison within those requirements; they never override geometry or architecture.

## Named scenario registry

These are stable evidence IDs, not new command-line switches. Only the first row has an existing capture path. Other rows are proposed fixtures to implement and validate when that subsystem is being changed.

| ID | Status / purpose |
| --- | --- |
| `courtyard_reference` | Existing `godot/courtyard_editable.tscn`, saved reference camera, `godot --path godot -- --capture` |
| `pool_water_close` | Planned fixed camera for water depth/color and pool-edge readability |
| `coping_waterline` | Planned fixed detail view for edge scale, joins and water contact |
| `sheer_descent_running` | Planned fixed-time sequence for waterfall motion and temporal stability |
| `planting_mid_distance` | Planned fixed view for silhouettes, repetition and wind |
| `pergola_shadow` | Planned fixed sun/camera for timber, furniture and shadow structure |
| `night_lighting` | Planned explicit lighting preset for water, flames and exposure |

Register each implemented fixture's scene path, camera transform/projection, seed (or explicit no-randomness statement), sun/environment, animation time, viewport resolution, renderer/quality settings, and warm-up/capture schedule. Do not label a proposed fixture as passing.

## Existing capture limitations

The current navigation script captures after 45 process frames, then another 40 frames, and logs PNG save results. Animated shader time is not fixed by that frame count. It does not emit state/performance sidecars, enforce a failed-save exit status, or guarantee pixel-identical output. Check actual files and save-result logs; the final success message alone is insufficient. Resetting the camera with R does not reset shader time.

The README's regeneration command also replaces the editable scene. Preserve manual work before using it. Headless import validates resource loading only; captures need a graphics-capable desktop. No new capture automation is implied by this documentation.

## Evidence packet for a visual change

Keep a baseline and candidate packet keyed by source commit and scenario ID. Re-run the same configuration, inspect both outputs, and record the comparison and remaining defects. Freeze or explicitly control animation time before claiming deterministic animated captures; otherwise label the comparison approximate and record the limitation.

Each packet should contain:

- actual PNGs and, for motion, a fixed-time sequence or clip;
- `state.json`: source commit/dirty state, scenario and target IDs, scene/asset/generator hashes, tool versions, device/OS/GPU/driver, camera, seed, lighting, animation time, resolution and render settings;
- `performance.json`: measurement tool, units, warm-up and sample duration, frame-time distribution (including p50/p95), FPS, draw calls, primitives/triangles, visible instances, CPU/process and GPU memory where available;
- runtime/import logs, exact reproduction command, observed results, inferences, limitations, and pending verdict.

These sidecar names describe the evidence contract; the current script does not generate them. Measurements may be gathered with existing profilers and saved with the packet. Use `null` plus a reason for unsupported metrics rather than zero or estimates. Record shader-variant counts only when measurable. Do not compare desktop GPU timing with software rendering or tablet results as if conditions match.

## Promotion to Design-Platform

Record the candidate commit, exact reusable assets/shaders/code, provenance and hashes, receiving renderer-neutral descriptor/scene seam, target IDs, before/after evidence, correctness checks, and target Samsung tablet Mobile/Vulkan measurements against the receiving task's agreed budgets. Include motion, full-scene load and lifecycle evidence where relevant, plus Cody's visual verdict and the receiving integration decision.

Until those gates pass, results remain research candidates. Do not copy lab camera controls, capture tooling, inferred dimensions, or scene state into authoritative project storage. Lab success cannot reopen native Plan or move commercial truth into Godot.
