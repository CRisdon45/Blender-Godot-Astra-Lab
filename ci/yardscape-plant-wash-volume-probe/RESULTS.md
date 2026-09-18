# Profile-driven wash-volume checkpoint

Checkpoint time: 2026-09-18 21:04 UTC

## Identity

- Repository: `CRisdon45/Blender-Godot-Astra-Lab`
- Base branch: `experiment/profile-brush-cloud-v1`
- Experiment branch: `experiment/profile-wash-volume-v1`
- Tested remote revision: `b5641c6f6b4d7951b5d63b67f7d53fc0ee651b1c`
- Workflow run: [Profile-driven wash-volume proof #35394220215](https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/35394220215)

## Decision

Reject `profile-lobe-wash-volume/1` as a planting-surface direction. Preserve the
branch as negative evidence, but do not merge it into the retained brush-card
candidate and do not spend another pass tuning the same closed-volume primitive.

The experiment answered its falsifiable question cleanly. It preserved the
shared profile and layout, remained deterministic, used two opaque meshes, and
rendered without alpha cards. However, the closed lobes read as hard broccoli or
plastic balloons rather than connected watercolor foliage. Fan-Tex became a
solid crown with heavy blob shadows. Palo Verde lost the airy branching that
distinguishes it from Fan-Tex. Top and courtyard views confirmed that the issue
is the representation itself, not one camera angle.

The retained `fixed-center-brush-card-cloud/2` v4 pass remains the stronger
Perspective candidate and the correct control for the next generality test.

## Evidence ledger

| Claim | Evidence | Result |
| --- | --- | --- |
| Implemented | Isolated workflow, runner, comparison scene, generic closed-volume builder, shader, and probe. | Yes. Shared profile/layout sources are unchanged. |
| Built and rendered | GitHub-hosted Ubuntu worker, Godot `4.7.1-stable`, Compatibility renderer, `llvmpipe (LLVM 20.1.2, 256 bits)`. | Yes. |
| Automated | Fourteen fixed A/B captures, deterministic geometry checks, exact Plan-layout checks, light-response checks, and retained direct-Plan regression. | Passed with no reported failures. |
| Visually inspected | Fan-Tex front/side/top/courtyard A/B; Palo front/top A/B and time-of-day captures. | Failed the explicit rocks/balloons/solid-blob rejection gate. |
| Device verified | No target Android/tablet run, sustained orbit, thermal test, or GPU timing. | Not verified. |
| Integrated | Isolated public worker probe only; production Yard-Scape scenes and tools are untouched. | Not integrated. |

### Artifact

- Evidence artifact `10567132673` —
  `sha256:e003e8dcc144ae30025d0841139700b398cc3f134ef52be1461ab80a02be815b`
- Direct Plan regression artifact digest —
  `sha256:b1fc1ba6a4ff781f848dbaab0b9f84595bbaa488a0edd248a2e894d35fe82b06`

## Geometry comparison

| Profile / renderer | Foliage primitive count | Foliage triangles | Visible indexed triangles | Visible meshes |
| --- | ---: | ---: | ---: | ---: |
| Fan-Tex retained brush v4 | 288 cards | 576 | 2,582 | 2 |
| Fan-Tex closed volumes | 32 volumes | 3,840 | 4,598 | 2 |
| Palo retained brush v4 | 154 cards | 308 | 2,068 | 2 |
| Palo closed volumes | 28 volumes | 3,360 | 4,028 | 2 |

The wash volumes add 2,016 visible triangles for Fan-Tex and 1,960 for Palo
while producing the weaker image. These are geometry counts, not target-device
frame-time measurements.

## Resume point

1. Keep the exact retained brush v4 source unchanged as the current visual and
   geometry control.
2. Do not resume authored-card-mask, larger-card, or closed-volume tuning; each
   direction has now failed its own visual gate.
3. Test whether the retained brush renderer and shared layout can represent one
   genuinely shrub-like profile without turning it into a short tree. This is a
   schema/generality test, not a claim that the brush surface is final art.
4. If the shrub test survives visual review, take the retained tree and shrub
   pair to a target-tablet A/B performance run before production integration.
5. Keep all production integration behind an opt-in renderer switch with the
   retained dab path available as fallback until art and device review pass.

