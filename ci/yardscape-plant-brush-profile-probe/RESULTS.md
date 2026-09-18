# Profile-driven brush-cloud checkpoint

Checkpoint time: 2026-09-18 20:46 UTC

## Identity

- Repository: `CRisdon45/Blender-Godot-Astra-Lab`
- Base branch: `ci/yardscape-renderer-slice`
- Experiment branch: `experiment/profile-brush-cloud-v1`
- Current remote revision: `2574cf93d29f36a0e6520d92f30e7dcd4c086371`
- Current tree: `e085b199921d2ef7349a707ebf0bcee665b923ba`
- Content-equivalent local revision before this ledger update: `a5e17df`
- Current workflow run: [Profile-driven plant brush-card proof #35393143038](https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/35393143038)

## Outcome

Retain `fixed-center-brush-card-cloud/2` as the best card-based Perspective
challenger and the comparison control for the next representation. Do not adopt
or merge it as the production planting renderer yet.

This fourth pass is the first experiment in the branch that resolves the
original crown-fullness failure without replacing the profile/layout authority,
adding a solid core, or making the whole plant face the camera. It also keeps
Fan-Tex Ash visually full while allowing Desert Museum Palo Verde to remain
open and structurally distinct. At courtyard distance it is more legible than
the retained dab baseline. The result remains visibly card-derived. Three
subsequent art passes showed that changing atlas shape and card scale does not
close the Northstar gap; this card family has reached a useful local ceiling.
The next visual experiment should use stable profile-driven 3D wash volumes
rather than more card tuning.

## Experiment decisions

| Pass | Revision / run | Visual result | Decision |
| --- | --- | --- | --- |
| Opaque bowed facets | `0419e4f5` / `35387830925` | Filled the crown and cut triangles, but read as hard polygon leaves; Palo formed ring-like clumps. | Reject. Preserve only as negative evidence. |
| Simple oval alpha cards | `aec76859` / `35388433488` | Proved the fixed-center alpha-scissor path, but read as literal leaf confetti and overfilled Palo. | Reject. |
| Broad cluster cards | `0bbfc481` / `35388837365` | Restored airy-profile density and calmed color, but repeated horizontal marks stacked like shingles. | Reject visual surface; retain its density rule. |
| Four cluster silhouettes | `4fdeb0e1` / `35389229276` | Full Fan-Tex crown, open Palo crown, card artifacts subordinate to the overall form at working distance. | Retain as current challenger; human art review still required. |
| Authored connected marks | `6a8a78a` / `35392065500` | Connected broad masks read as long caterpillar strokes. The render completed, but an added stats assertion failed. | Reject visually. |
| Compact authored wash marks | `fbab9dc` / `35392527552` | Passed 43 checks but still read as repeated leaf-like patches, with no meaningful hierarchy gain over pass four. | Reject. |
| Fewer, larger wash cards | `a74bac6` / `35392776037` | Passed 43 checks and reduced Fan-Tex to 128 cards and Palo to 70, but exposed obvious flat paddles and degraded Palo's open branching. | Reject. Stop card-size tuning. |
| Restore retained pass four | `2574cf9` / `35393143038` | Returned the exact retained source tree after preserving the rejected attempts in history. | Current branch head. |

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

- Brush artifact `10566520765` —
  `sha256:b2a32f81b5ddbe7c932f85a04123dfb37198f730e965b863e7af9080ac4f97aa`
- Direct Plan regression artifact `10567135335` —
  `sha256:87de6da6e1661a0ac75e84062d05b823aff19e57c2b71fda9357e4ccf5cc6b4e`

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
  production planting style. Authored-mask and broader-card variants did not
  materially improve the result and should not be resumed as the next step.
- Alpha-scissor overdraw and shader cost have not been measured on the target
  tablet; the lower triangle counts do not answer that question.
- The probe covers two tree profiles. It does not prove a shrub schema or a
  broader planting library.
- The Plan proof remains the structurally correct direct 2D consumer, but its
  current surface treatment is still a prototype rather than final art.
- No full Yard-Scape interaction, selection, transform, save/load, or export
  path has been exercised with this renderer.

## Resume point and next gate

1. Keep pass four unchanged as the card-based control.
2. Build one isolated, profile-driven 3D wash-volume challenger: several
   overlapping closed lobe volumes, one merged foliage mesh, stable object-space
   pigment, broad custom normals, and no alpha cards or whole-plant billboard.
3. Compare that challenger against pass four for Fan-Tex and Palo before adding
   a shrub. Reject it if it reads as rocks, plastic balloons, or a solid blob.
4. Add one shrub-specific normalized profile/recipe only after one Perspective
   surface family survives the tree comparison.
5. Run the surviving representation on the target tablet, measuring frame time
   and overdraw during orbit, zoom, selection, and transform.
6. Only after art and tablet review, integrate the challenger behind an opt-in
   Yard-Scape renderer switch. Keep the dab path as the fallback until then.

The adoption gate remains: an accepted visual surface + one shrub profile +
target-tablet A/B evidence. Pass four is useful enough to keep, but the card
architecture itself is no longer the preferred place to spend the next art pass.
