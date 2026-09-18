# Retained brush planting Android probe

This additive probe packages the two retained planting candidates as a small
Godot Android debug application. It is deliberately separate from the tablet
app: the purpose is to remove the packaging blocker and collect repeatable
renderer evidence before any production integration.

## Workload

- exact retained `fixed-center-brush-card-cloud/2` renderer;
- six `fan-tex-ash-macro-form/2` trees;
- twelve `dense-desert-shrub-mound/2` shrubs;
- 36 visible meshes in one planting-bed view;
- a three-second warm-up followed by a twelve-second deterministic orbit;
- in-app frame-delta samples plus Android `gfxinfo`, `meminfo`, package,
  screenshot, UI-tree, and logcat evidence;
- three fresh app launches on one clean emulator boot.

The debug APK includes `arm64-v8a` for a later physical-device run and
`x86_64` for the hosted emulator. CI obtains the exact Godot 4.7.1 editor and
matching official export templates from the pinned upstream release, verifies
their release digests, and records the resulting APK hash.

## Acceptance boundary

The workflow fails for an export failure, install/launch failure, missing
benchmark report, source/shader error, crash, wrong retained recipe, or an
unexpected workload. It intentionally has no emulator FPS threshold. Hosted
emulator timing is useful for regression plumbing and gross failures, but it
does not establish performance, thermal behavior, touch quality, or S Pen
behavior on the Galaxy Tab S10 FE.

Physical-device acceptance remains a separate gate using the exported APK and
the same fixed flow.
