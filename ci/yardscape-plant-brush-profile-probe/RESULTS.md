# Profile-driven brush-cloud checkpoint

Checkpoint time: 2026-09-18 20:06 UTC

## Identity

- Repository: `CRisdon45/Blender-Godot-Astra-Lab`
- Base branch: `ci/yardscape-renderer-slice`
- Experiment branch: `experiment/profile-brush-cloud-v1`
- Tested remote revision: `4fdeb0e17291ab562d9b6044ff4455cb1f2683a5`
- Tested tree: `5f8d02243750e041409a0e0297ec75d96702404b`
- Content-equivalent local revision at checkpoint: `7e27a17`
- Workflow run: [Profile-driven plant brush-card proof #35389229276](https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/35389229276)

## Outcome

Retain `fixed-center-brush-card-cloud/2` as the preferred Perspective
challenger for another design and target-device round. Do not adopt or merge it
as the production planting renderer yet.

This fourth pass is the first experiment in the branch that resolves the
original crown-fullness failure without replacing the profile/layout authority,
adding a solid core, or making the whole plant face the camera. It also keeps
Fan-Tex Ash visually full while allowing Desert Museum Palo Verde to remain
open and structurally distinct. At courtyard distance it is more legible than
the retained dab baseline. The result remains visibly card-derived and needs
an authored atlas, shrub coverage, and tablet evidence before adoption.

## Experiment decisions

| Pass | Revision / run | Visual result | Decision |
| --- | --- | --- | --- |
| Opaque bowed facets | `0419e4f5` / `35387830925` | Filled the crown and cut triangles, but read as hard polygon leaves; Palo formed ring-like clumps. | Reject. Preserve only as negative evidence. |
| Simple oval alpha cards | `aec76859` / `35388433488` | Proved the fixed-center alpha-scissor path, but read as literal leaf confetti and overfilled Palo. | Reject. |
| Broad cluster cards | `0bbfc481` / `35388837365` | Restored airy-profile density and calmed color, but repeated horizontal marks stacked like shingles. | Reject visual surface; retain its density rule. |
| Four cluster silhouettes | `4fdeb0e1` / `35389229276` | Full Fan-Tex crown, open Palo crown, card artifacts subordinate to the overall form at working distance. | Retain as current challenger; human art review still required. |

## Evidence ledger

| Claim | Evidence | Result |
| --- | --- | --- |
| Implemented | Additive workflow, runner, scene, shared-profile consumer, brush group, batched shader, and profiled tree builder in this directory. | Yes. Existing profile/layout sources are unchanged. |
| Built and rendered | GitHub-hosted Ubuntu worker, Godot `4.7.1-stable`, Compatibility renderer, `llvmpipe (LLVM 20.1.2, 256 bits)`. | Yes, at the tested remote revision. |
| Automated | Brush report: 41 checks and 14 fixed captures; direct Plan regression: 18 checks and 5 captures. | All checks passed. No runtime AI and no 3D mesh readback for Plan. |
| Deterministic | Geometry signatures, exact normalized Plan-layout signatures, fixed capture hashes, morning/afternoon response, and exact morning-return hash. | Passed for both profiles. |
| Visually inspected | Front, side, top, and courtyard A/B captures for Fan-Tex; front and top A/B plus time-of-day captures for Palo. | Current pass retained as a challenger, not accepted as final art. |
| Device verified | No target Android/tablet run and no sustained interaction or thermal test. | Not verified. |
| Integrated | Isolated public worker probe only; Yard-Scape production scene and tools are untouched. | Not integrated. |
| Pushed | Remote experiment branch at the tested revision. | Yes. |

### Artifacts

- Brush artifact `10565380350` —
  `sha256:6e8655da3e10b5610f8cd5bef0e762f77d5180c6063bbb57b7c6eac4d5eba449`
- Direct Plan regression artifact `10565400323` —
  `sha256:86a747df35879690d2cb1b474d75c6a648e8b794f686028922cfc28ea95557e8`

## Measured geometry

| Profile / renderer | Cards | Foliage triangles | Visible indexed triangles | Foliage width | Foliage height | Visible meshes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Fan-Tex retained dabs | n/a | 4,608 | 6,614 | 2.0335 | 1.2302 | 2 |
| Fan-Tex brush cards | 288 | 576 | 2,582 | 2.7565 | 1.8030 | 2 |
| Palo retained dabs | n/a | 4,032 | 5,792 | 2.0901 | 1.1581 | 2 |
| Palo brush cards | 154 | 308 | 2,068 | 2.7553 | 1.5685 | 2 |

The current challenger reduces visible indexed triangles by 4,032 (61.0%) for
Fan-Tex and 3,724 (64.3%) for Palo relative to the retained dab renderer. These
are geometry counts, not GPU-time or overdraw measurements.

Both brush trees use one merged wood mesh and one merged foliage mesh,
alpha-scissor rather than alpha blend, fixed 3D card centers, and no visible
solid core. Only the small cards face the camera; the plant and its lobe
envelopes do not.

## Known limits

- The generated atlas is intentionally procedural test art, not an approved
  production planting style.
- Alpha-scissor overdraw and shader cost have not been measured on the target
  tablet; the lower triangle counts do not answer that question.
- The probe covers two tree profiles. It does not prove a shrub schema or a
  broader planting library.
- The Plan proof remains the structurally correct direct 2D consumer, but its
  current surface treatment is still a prototype rather than final art.
- No full Yard-Scape interaction, selection, transform, save/load, or export
  path has been exercised with this renderer.

## Resume point and next gate

1. Replace the generated atlas with one restrained, authored multi-lobed brush
   atlas while keeping card count, centers, batching, and layout inputs fixed.
2. Add one shrub-specific normalized profile/recipe instead of forcing shrub
   behavior into the tree schema.
3. Run retained-dab versus brush-card A/Bs on the target tablet, measuring
   frame time and overdraw during orbit, zoom, selection, and transform.
4. Only after art and tablet review, integrate the challenger behind an opt-in
   Yard-Scape renderer switch. Keep the dab path as the fallback until then.

The adoption gate is therefore: authored visual surface + one shrub profile +
target-tablet A/B evidence. Until all three pass, this branch is a promising
candidate rather than the product renderer.
