# Canopy art research: three actual VM iterations

Date: 2026-09-05. Branch: `work/plant-canopy-art-study`.

## Decision

The representation and comparison infrastructure are useful. **The current art is not approved and must not replace the baseline by default.** The dense shrub retains its volume across LODs, but its close view is still too smooth/solid. The tree is still dominated by rounded canopy groups rather than a sufficiently convincing palo verde crown. A successful software test is not an artistic sign-off.

Keep the four-component option and the A/B scene. The next art change should make the opaque interior a support for a better authored foliage surface, not the dominant visible object. Use different coverage/detail balances for dense shrubs and open tree crowns. Do not respond to the smooth-core problem by adding arbitrary noise or increasing every plant's polygon count.

## Actual run history

| Pass | Code commit | GitHub Actions run | Result and visual interpretation |
| --- | --- | --- | --- |
| 1 | `30968127f1f48a50fe1f60a947652a1766de966d` | https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33979490112 | Build/tests/capture passed. The opaque bodies looked balloon-like and the tree's edge sprays visibly separated from undersized cores. Not approved. |
| 2 | `7ffaad541c02aad035ae7fd086fb88ff68141239` | https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33979801454 | Build/tests/capture passed. Increased tree core contact, irregularity and painted surface marks. Better connected edges, but some surface patches looked spotted rather than convincingly leafy. Not approved. |
| 3 | `90f6e9055a01cc43944dbc06b9b83260e6b3b0ba` | https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33980050614 | Build/tests/capture passed. Shared narrower tonal bands and restrained marks produced clearer shadow groups, but do not solve the remaining silhouette/surface-art problem. Not approved. |

The final code is the third commit above. This review is a subsequent documentation-only change, not additional untested code. Main and the courtyard/water scene files were not changed. The original three-component catalog and scene remain available, with their engine tests passing.

Final artifact: `canopy-art-3-1`, ID `9973500446`, job `101343554179`.
Artifact SHA-256: `64bcd4022601409b33a77a54b02e4c9a8cc023b42195a8189b1006c1ebe804d5`.
The downloaded ZIP digest was verified and all 72 model binaries were independently rechecked in the analysis container. The complete VM artifact was supplied in the conversation as `Canopy-Study-VM-Tested.zip`. GitHub artifact retention is seven days.

## What was actually exercised in the final run

- Blender 5.2.1 rebuilt 36 baseline GLBs and 36 new canopy GLBs, plus both sets of authoring files. The supplied bundle contains the 12 new canopy `.blend` files and both sets of GLBs.
- 107 Python tests passed with zero failures, errors or skips.
- Independent binary audits passed for all 36 baseline and 36 canopy GLBs. Checks include component counts, indices, normal lengths, finite positions, cull bounds, fixed-center spray reconstruction and non-degenerate core faces.
- Godot 4.7.1 imported the project and executed the 93-assertion baseline smoke suite and the 338-assertion canopy suite. Both passed. Assertions are not 431 independent end-user scenarios.
- The new suite checks four-component layouts, core-aware budget accounting, the 108-plant scene, cached assets during orbit changes, all forced detail levels, bloom costs, growth identity, the core-only view and switching back to the baseline.
- Two fresh software-Vulkan processes each captured 22 views at 1280 x 800. All 22 paired images had zero mean and maximum RGB pixel differences. This establishes reproducibility for this fixture/run, not arbitrary renderer/platform determinism.
- The adapter was `llvmpipe (LLVM 20.1.2, 256 bits)` using the Mobile renderer. **No Galaxy Tab S10 FE frame rate, thermal, power or Android driver claim is supported.**
- The old Blender adapter still emits its `Material.use_nodes` deprecation warning. Logs are unfiltered; this is not called a warning-free build.

The fixture uses a shared controlled ground receiver, camera and sun for baseline and canopy captures. This makes the new A/B comparison repeatable. It does not establish the root cause of the earlier separate-run ground-lighting discrepancy or certify production courtyard lighting.

## Geometry and drawing tradeoffs

Mature seed 41, source triangles including full flower meshes:

| Plant / treatment | Close LOD0 | Medium LOD1 | Far LOD2 |
| --- | ---: | ---: | ---: |
| Palo verde, earlier | 4504 | 2080 | 1132 |
| Palo verde, new study | 3482 | 1628 | 940 |
| Texas sage, earlier | 1692 | 992 | 562 |
| Texas sage, new study | 1920 | 1130 | 656 |

The palo verde is lower in triangles; the sage spends more triangles on real interior volume. Neither observation is a tablet speed measurement.

Leaf spray counts at close detail changed from 1207 to 457 for the palo verde and from 386 to 149 for sage. The sum of leaf-card rectangle areas decreased by approximately 84% and 89%, respectively. These are object-space geometry proxies, **not measured screen overdraw or GPU savings**. Opaque core triangles and an extra material/component draw are the other side of that trade.

The final 108-plant garden capture reported 137448 estimated primary-model triangles across all groups against the 140000 target, 32 spatial/variant groups, 128 component nodes and 169 whole-scene draw calls. Detail population was 9 close, 84 medium, 15 far. Scene primitive counters included additional rendering work; the primary-model budget excludes shadow/reflection repetition. It is not a frame-time governor.

## Visual inspection and remaining work

The actual baseline/new comparisons, reverse views, elevated views, all LODs, core-only shrub, growth scenes and garden contact sheets were inspected. Original captures were not painted over, recolored or replaced by generated concept art.

The new sage avoids the old distant holes but still has an overly large simple lit area. Its surface and bloom distribution are not yet convincing. The palo verde's edge sprays are better connected than in pass 1, but several crown masses are still too round and obvious. Some far-LOD faceting remains. These problems need authored silhouette and foliage-module work, not claims that a normal-transfer technique automatically creates the target style.

Current materials use art-directed sun-tone shading and restrained surface masks. They are not a validated general-purpose day/night or local-light solution. Small sprays face the main camera at fixed 3D centers; reflection/shadow behavior still needs production-scene testing. Far-LOD shadows retain the inherited off policy. There is no wind simulation in this pass.

The new geometry is an art-composition module over the existing two-family grammar, not proof of a universal recipe for every species. Growth remains illustrative installed/growing/mature state; calendar ages, sage cultivar and litter rates are not calibrated. No new seasonal/litter simulation was added.

## Review without installed engines

The conversation includes `Canopy-Study-Review.html`, a self-contained gallery of actual frames, plus `Canopy-Study-Comparison.png`, `Canopy-Study-All-Views.png` and `Canopy-Study-Validation.json`. The gallery is not an interactive 3D viewer.

The gallery's inline content passed 29 Chromium checks across comparisons, viewpoints, growth/garden views and responsive layout, with no JavaScript errors or external network requests. Direct file navigation was blocked by the browser test environment's administrator policy; that route was not certified here. No rendering-engine installation is required to view the embedded images.

To use the generated Godot project later, open `bundle/plant_lab/canopy_study.tscn` and run it with F6. The baseline and canopy buttons are research controls, not production UX. The `.blend` files provide editable geometry; the final custom material look is implemented in Godot shaders.

## Research and licensing

See [CANOPY_RESEARCH.md](CANOPY_RESEARCH.md) for primary sources, access limits, adaptations and the decision not to transfer engine-specific desktop effects blindly to Mobile. All new code, geometry and texture masks are original project implementations. No third-party tutorial asset, texture or shader snippet was copied into this pass. No runtime AI service is used.
