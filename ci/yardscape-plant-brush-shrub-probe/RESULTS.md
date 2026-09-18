# Retained brush shrub checkpoint

Checkpoint time: 2026-09-18 21:16 UTC

## Identity

- Repository: `CRisdon45/Blender-Godot-Astra-Lab`
- Stacked base branch: `experiment/profile-brush-cloud-v1`
- Experiment branch: `experiment/profile-brush-shrub-v1`
- Tested remote revision: `4ca62f7b27f720e387c5d9ccc361083a740ddab9`
- Workflow run: [Brush-card shrub generality proof #35395504515](https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/35395504515)

## Decision

Retain `dense-desert-shrub-mound/2` as evidence that the exact retained v4
brush renderer and shared profile/layout path can represent both a tree and a
low shrub class. Do not call it final shrub art or production-ready.

The first profile pass failed: its higher anchors and longer scaffold gesture
made it an obvious miniature umbrella tree. A single profile-only revision
lowered the anchors, shortened the trunk and scaffold rise, reduced seven radial
families to six, and increased near-ground group overlap. The renderer, atlas,
shader, layout code, and retained Fan-Tex control were unchanged.

The second pass reads as a low planting-bed mound in front, side, top, low, and
courtyard views. It remains visibly card-derived and generic, but it no longer
looks like the retained tree scaled down. This clears the schema/generality gate
for further review; it does not clear Northstar art acceptance or the target-
tablet performance gate.

## Experiment decisions

| Pass | Revision / run | Visual result | Decision |
| --- | --- | --- | --- |
| Higher seven-family shrub | `d896c06` / `35395206141` | Exposed a tall multi-stem scaffold with foliage perched above it; read as a small umbrella tree. | Reject profile v1. |
| Lower six-family mound | `4ca62f7` / `35395504515` | Foliage overlaps near the bed, wood becomes subordinate, and the tree/shrub pair stays visibly distinct in context. | Retain as architecture evidence. |

## Evidence ledger

| Claim | Evidence | Result |
| --- | --- | --- |
| Implemented | Additive workflow, runner, shrub scene, profile, immutable shrub record, dab A/B, direct-Plan check, and retained Fan-Tex control. | Yes. Retained brush v4 sources are unchanged. |
| Built and rendered | GitHub-hosted Ubuntu worker, Godot `4.7.1-stable`, Compatibility renderer, `llvmpipe (LLVM 20.1.2, 256 bits)`. | Yes, at the tested revision. |
| Automated | 33 checks and 12 fixed captures, plus the unchanged direct-Plan regression. | Passed with no reported failures. |
| Deterministic | Exact geometry signature, shared layout signature, stable morning return, immutable instance record, and no runtime AI. | Passed. |
| Visually inspected | Tree control; shrub dab/brush front, side, and top; shrub low view; two tree/shrub courtyard views; morning/afternoon. | Profile v2 retained as class-distinct prototype art. |
| Device verified | Local environment has no `adb`, attached Android target, Android export preset, or installable build for this slice. | Not verified; no FPS, frame-time, overdraw, memory, thermal, or sustained-orbit claim. |
| Integrated | Isolated public worker probe only; production Yard-Scape scenes and tools are untouched. | Not integrated. |

### Artifacts

- Shrub evidence artifact `10567154871` —
  `sha256:b0547d072ae31109ad7da4dc9453796332baabc80fce3ac518b1444b8a57b06e`
- Direct Plan regression artifact `10567995208` —
  `sha256:2eef5cf7ad95e947a8d33e504a229cd48d94722143a4ac2d34e53a871043035a`

## Measured geometry

| Profile / renderer | Groups | Cards | Foliage triangles | Visible indexed triangles | Foliage width | Foliage height | Visible meshes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Shrub dab baseline | 17 | n/a | 4,896 | 7,018 | 1.3252 | 0.3703 | 2 |
| Shrub retained brush v4 | 17 | 221 | 442 | 2,564 | 1.5927 | 0.6278 | 2 |
| Fan-Tex retained brush v4 | 16 | 288 | 576 | 2,582 | 2.7565 | 1.8030 | 2 |

The brush shrub reduces visible indexed triangles by 4,454 (63.5%) relative to
the shrub dab baseline. Its foliage envelope is 2.54 times wider than tall. The
2,122 wood triangles dominate its remaining geometry cost; these are geometry
counts, not target-device GPU-time or overdraw measurements.

## Known limits

- The shrub is a generic normalized mound archetype, not a certified or
  species-specific asset.
- The retained procedural brush atlas still produces elongated repeated marks.
  The profile solves class/form distinction, not final surface art.
- Alpha-scissor overdraw and camera-facing card behavior have not been profiled
  on the target tablet.
- There is no full-app selection, transform, save/load, export, or mixed-
  planting stress test.
- The current generic builder emits tree-style wood geometry for every profile;
  a shrub-specific wood recipe could reduce the 2,122-triangle scaffold cost,
  but should be attempted only after target-device measurement shows it matters.

## Resume point and next gate

1. Keep the exact retained v4 tree renderer and shrub profile v2 unchanged as
   the review pair.
2. Produce an installable, profileable Android build containing an opt-in
   planting test scene; do not replace the production renderer yet.
3. On the actual target tablet, compare retained dabs versus brush cards during
   a focused orbit/zoom/selection/transform flow. Capture `gfxinfo` frame stats,
   a Perfetto trace, memory snapshots, and visual screenshots.
4. Stress a representative mixed planting bed rather than a single isolated
   plant, because alpha-scissor overdraw is the unresolved risk.
5. Only if art review and target-tablet evidence both pass, integrate behind an
   opt-in renderer switch while retaining the dab renderer as fallback.

