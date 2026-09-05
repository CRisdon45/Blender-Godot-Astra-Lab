# Plant Engine Foundation: actual VM review, 2026-09-05

## Tested source and evidence

Branch: `work/plant-engine-vm-validation`.
Tested code commit: `6b38499ee027d587198116d6fa5ed435a48e6471`.
Successful GitHub Actions run: https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33977822635
Job: `101337530471`. Artifact: `9972855264`, `plant-foundation-vm-2-1`.
Artifact SHA-256: `43e8274878653c8ead3fa87e7a23e7b7b356f18b92c775935c84bb0dbda003a1`.
The complete artifact was downloaded and its digest verified. Retention on GitHub is seven days; a copy was supplied in the conversation.

This document is a subsequent documentation-only commit, not a claim that untested code ran. No merge to main was performed. Courtyard and water scene files were not modified.

## Actual successful run

- Blender 5.2.1 LTS rebuilt 36 GLB files and 12 editable Blender files.
- All 96 Python tests passed: zero failures, errors or skips.
- All 36 GLBs passed the independent exported-geometry checks.
- Godot 4.7.1 imported the foundation project without script/parse/shader errors.
- The actual Godot runtime smoke test passed 93 checks, with zero failures.
- The Mobile renderer produced all 17 expected 1280 x 800 PNGs, including the 12-tree / 96-shrub garden. Capture errors were empty.
- Rendering used Linux software Vulkan, adapter `llvmpipe (LLVM 20.1.2, 256 bits)`. This is NOT Android GPU or Galaxy Tab S10 FE performance evidence.
- Blender emitted a `Material.use_nodes` deprecation warning; the unfiltered log retains it. This is not described as a warning-free build.

The smoke tests exercise fixture parity, persistent placement identities, direct growth-stage changes, asynchronous loading, cache reuse during camera movement, latest-request preparation, mature footprints and an orthographic camera update. They do not certify the entire future application or all possible input sequences.

## Iteration 1: resolve an actual engine-test failure

Initial VM run: https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33977445226
Initial commit: `d3fd387e4728d5c5cb75f07f87464d282b6c5f2b`.

That run rebuilt the assets, passed 88 Python tests and captured all 17 views, but failed three of 86 engine checks. Each failure was the test harness comparing integer-valued result dictionaries directly with JSON-parsed float-valued expected dictionaries. Budget totals and other checks passed.

The corrected comparator validates identical keys, actual integer LODs and finite integral expectations in range 0..2 before comparison. Seven negative/positive regression assertions reject fractional expectations, wrong LODs, float-valued actual results and missing/extra/wrong group identities. The successful report retains the actual and expected budget dictionaries; no production budget check was removed to obtain a pass.

## Iteration 2: distribute low-detail foliage more evenly

The old compiler selected every Nth randomly ranked foliage piece within each canopy group. The revised compiler uses a deterministic, normalized-space farthest-point prefix. This keeps reductions nested and retains the same number of pieces while spreading the selected anchors through the group. It runs at compile time, not while orbiting the camera.

Eight new Python regression tests check counts, nesting, group retention, unchanged LOD0 order, reproducibility, geometric gap reduction and invalid inputs.

Independent comparison of the two downloaded run catalogs verified:

- All 36 per-component and total triangle-count records are unchanged.
- All 12 high-detail GLB hashes are identical across the two runs.
- The shader files, atlases and scene implementation were not changed by the foliage-sampling iteration.

Mature seed-41 source triangles, including full flower meshes:

| Species | LOD0 | LOD1 | LOD2 |
| --- | ---: | ---: | ---: |
| Desert Museum palo verde | 4504 | 2080 | 1132 |
| Texas sage | 1692 | 992 | 562 |

These are model triangle counts, not a GPU timing measurement or a total including shadow/reflection passes.

## Visual assessment: still a study, not accepted artwork

Actual captures from both runs were inspected, including both far-LOD views, the high-detail pair and the complete 17-view contact sheet. The tree's reduced-detail coverage improved modestly in the inspected view. Sage results are mixed; the far-detail color-mask overlap proxy slightly regressed. The new sampling is an experiment on this opt-in branch, not universal artistic acceptance.

Single-camera diagnostic green-foliage mask intersection-over-union against that run's high-detail bloom image:

| Species / detail | Initial run | Revised run |
| --- | ---: | ---: |
| Tree / medium | 0.8898 | 0.9009 |
| Tree / far | 0.8185 | 0.8468 |
| Sage / medium | 0.8767 | 0.8784 |
| Sage / far | 0.8282 | 0.8262 |

This mask is only a color-segmentation proxy, not a botanical, silhouette or artistic score. Ground illumination differs visibly between runs despite unchanged scene source. The cause is not established, so these are not pixel-matched lighting comparisons. No image was retouched to conceal that discrepancy.

Remaining issues:

1. Palo verde crown groups remain too tiered and regular, with a conspicuous upper opening in the elevated view.
2. Sage foliage stamps are too individually readable and its distant representation still develops holes.
3. Capture lighting repeatability needs a separate check before broad pixel-based visual regression gates can be trusted.
4. Far-LOD dynamic shadows retain the legacy off policy, not a final presentation decision.
5. Growth is illustrative installed/growing/mature state, not calibrated calendar years. Texas sage cultivar and litter rates remain unspecified/uncalibrated.
6. The full backyard, water, editing UI, sustained tablet performance and thermal behavior remain untested here.

## Review without Blender or Godot

The conversation delivery includes a self-contained HTML review with the actual 17 PNGs and before/after comparisons. It is a screenshot gallery, not interactive 3D. It requires no rendering-engine installation or remote image service.

The HTML was exercised in Chromium with inline content: all five sections, seven view choices, four comparison combinations, desktop/mobile layout and no JavaScript errors. Direct `file:` navigation was blocked by the test environment's browser policy, so that particular opening path was not certified there.

The GitHub artifact contains the runnable generated project under `bundle/plant_lab`, editable source models under `bundle/authoring/species_lab`, and the original logs and reports. Actual images remain in `images/`.

## Next acceptance gate

Keep the cloud build/test/capture loop. Before adding species, refine the sage foliage representation and palo verde crown structure, and make matched capture lighting repeatable. Device performance and calibrated growth remain separate gates. All art, Android, calendar-growth and production approval flags remain false.
