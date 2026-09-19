# Retained brush planting Android probe

This additive probe packages the two retained planting candidates as a small
Godot Android debug application. It is deliberately separate from the tablet
app: the purpose is to remove the packaging blocker and collect repeatable
renderer evidence before any production integration.

## Workload

- exact retained `fixed-center-brush-card-cloud/2` renderer;
- three `fan-tex-ash-macro-form/2` trees;
- three `desert-museum-palo-verde-macro-form/2` trees;
- twelve `dense-desert-shrub-mound/2` shrubs;
- 36 visible meshes in one planting-bed view;
- a three-second warm-up followed by a twelve-second deterministic orbit;
- in-app frame-delta samples plus Android `gfxinfo`, `meminfo`, package,
  screenshot, UI-tree, and logcat evidence;
- three fresh app launches on one clean emulator boot.

The probe uses Godot's Compatibility renderer through OpenGL ES. Its positional
light budget is set to two lights per object and four renderable lights because
this fixed scene uses one directional light and no positional lights. The
hosted AVD uses the current non-deprecated `swangle` software mode (SwiftShader
drivers through the ANGLE backend). This avoids a known native SwiftShader GLES
uniform-limit failure in Godot's Compatibility base shader while preserving a
software-rendered CI environment. CI rejects shader compilation/linking errors
and blank or low-color-diversity screenshots before reporting success. Visual
evidence is read back from Godot's own viewport; a separate Android device
screenshot records orientation and foreground-window state.

The scene itself renders at the fixed 1920 by 1200 tablet viewport. For
artifact size and deterministic software-emulator runtime, only the saved
evidence copies are reduced to 960 by 600. Ready and measuring captures finish
before timed sampling starts, so PNG compression is excluded from the render
loop measurements.

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
the same fixed flow. The APK artifact now includes `run_physical_device.py` and
`DEVICE_TEST.md`. The runner verifies a real device, can require the exact model,
performs three fresh measurements without changing global display settings, and
packages screenshots, logs, frame data, memory, battery, and thermal evidence.
Its provisional 30 FPS / 50 ms p95 result is kept separate from the required
human visual review and from later touch, S Pen, full-app, and sustained-thermal
testing.
