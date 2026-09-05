# Water V2: reflections, receiver light and falling-film study

**Status: actual frames captured and inspected; diagnostic, not final art or device approval.**
Open `godot/courtyard_water_v2.tscn`, F6. W toggles features; N toggles the lighting
study. Original F5, anime foliage, the first hero-water entry and authored assets
remain untouched. Main is unchanged and PR #1 stays draft.

## Actual outcome, September 5, 2026

Rendered source: `546c4e21a4fedd5ec5731f4840878b1490cd1ad8`.
Linux run: https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33973056633
Artifact: `9971591107`, SHA-256
`25626128f055e58cf2763ab3285c5baf0fffdb17d93ac8007c905e49179a6367`.

- **167 combined Python source/math/evidence tests passed**, both in the Linux
  runner and locally after extracting the complete captured source snapshot.
- Actual-script preflight passed. Capture completed with **22 actual 1200 x 900
  scene PNGs plus one 768 x 576 reflected-camera PNG**, and zero capture-contract
  errors. No script or shader errors were logged by capture.
- All 23 PNGs were independently decoded. Three before/after camera, aim,
  dimensions and water-time pairs match. All 11 V2 implementation/review files
  matched the inspected captured-source archive by Git blob hash.
- Runtime checks cover two measured contacts after shader swaps, W flow state,
  mirror plane, isolated reflection masks, shared main-camera foliage pose,
  reflection resolution bound, receiver clock and reflection pixel response.
- The new pixel guard samples 600 points inside unobstructed water. Selecting
  planar instead of the old probe changes 99% of those samples above the guard's
  threshold. This proves a visible mode response, NOT complete projection or
  physical accuracy; camera geometry and the actual frames are checked as well.
- Six explicit water phases and a night study were captured. Motion phases are
  sampled images, not a live frame-rate benchmark or seamless-loop claim.
- Original anime GLB, saved scene and original water shader preservation hashes
  passed. The capture job's tracked-source diff was empty.

**The overall workflow failed diagnostically**, as intended: the existing editor
popup-parenting errors remain and capture shutdown reports **seven leaked Texture
RIDs**. Changing import from headless to an Xvfb display did not fix those errors.
No clean import, renderer lifetime, Android, desktop-GPU timing or final artistic
approval is claimed. This is not a fresh run of the original 48-image acceptance suite.

## Committed actual previews

[Previous water](previews/water-v2-before.png) ·
[V2 daytime](previews/water-v2-day.png) ·
[Low angle](previews/water-v2-low-view.png) ·
[Sheers](previews/water-v2-sheers.png) ·
[Provenance](previews/water-v2-provenance.json).

These four unchanged PNGs and diagnostic provenance were published in
`78e9550682f0022d23157ae518b86ff7ed826239` by bounded publisher run
`33973533628`. It checks the inspected artifact hash, current runtime dependencies
and large assets, creates only new preview paths and refuses a concurrent ref
change. Its success proves publication, not a clean rendering result.

## Artistic assessment

The corrected low-angle frame now contains recognizable reflected pergola posts,
fire bowls, foliage and masonry instead of the earlier broad repeating blobs.
Surface movement is calmer and the first overbright receiver network was reduced.
Those are visible improvements, not final water acceptance.

Remaining weaknesses are explicit: the pool still looks too glassy/flat in places;
the caustic network is visibly geometric rather than fully convincing focused
light; and the sheers remain rectangular translucent films with limited landing
breakup. The source's roughly 5 cm shelf also reads flat. Reflection edges need
higher-quality filtering, and linear/HDR color handling needs comparison against
the separate HDR study. No extra distortion/noise should be added merely to hide
these weaknesses.

Next visual gates: varied gentle surface motion without destroying recognizable
reflections; less cellular, more natural receiver light; richer full-width landing
detail; a clearly labeled shelf/steps/deep-basin fixture; and moving-camera/device
evidence. Consolidate the better verified reflection implementation before
promoting one production water path.

## First run exposed a false-positive

Run `33972481550` at `a9ff728` produced 22 scene frames and a valid reflected-camera
image, and its initial script contracts passed. Independent same-water-region
inspection found **zero pixel difference** between planar and probe modes: the
inherited probe was overriding the shader's RADIANCE source. A valid reflection
buffer alone was not proof that the water actually used it.

Godot issue 80665 describes this override-order limitation:
https://github.com/godotengine/godot/issues/80665 . The refinement sets the probe's
reflection mask to zero in planar mode and restores its water layer only for the
explicit fallback. The actual pixel response is now a required capture assertion.
The first run's bright, oversized cell network was also reduced and broken into
uneven arcs based on its images, not source tests.

## Implementation and boundaries

The reflected camera follows the viewer about the measured horizontal water level.
A separate layer excludes water and receivers. Current architecture and foliage
shaders get reflection-camera-only below-plane clipping. Foliage card orientation
stays tied to the main viewer, so the reflected view sees the same card geometry.
The half-width reflection target is capped at 768 pixels wide. It adds a real
second render; this is not free or device-certified.

Water uses a calmer six-direction analytic slope field while retaining measured
transmission, Fresnel, screen-edge/above-water refraction guards, geometry-derived
sheet contacts and the shared clock. The receiver network is **artist-directed,
not photon tracing or the physical light-transport solution of that wave field**.
It follows the main sun projection, depth, scene lighting and shadows. It replaces
the prior Hessian approximation only in this opt-in scene.

Falling films flex by a few millimetres with pinned slots, irregular advected
variation and localized aeration. This is not volumetric fluid, droplets or spray.
Original basin dimensions are preserved: about 5.25 cm shelf depth and 95.25 cm
flat basin depth are fixture limitations, not recommended pool design dimensions.

Current witnesses use above-water ordinary perspective cameras. Orthographic,
off-axis, underwater and arbitrary pool/feature layouts are not approved by V2.
The intermediate reflection uses a linear tone curve, but no HDR transport or
exposure-calibration claim is made. Future material families must explicitly
support reflection clipping; this is not a universal material converter.

## Concurrent work preserved

A separate HDR/clip-controlled study landed at `610a996` during the first V2 run.
The non-fast-forward guard prevented overwriting it. V2 refinement was rebased
onto that head, preserving all 13 concurrent additions unchanged. Its entry is
`godot/courtyard_water_reflections.tscn`; V2 does not alter or promote that scene.
The 167 Python count includes both sets of checks, but V2 capture results must not
be attributed to the separate HDR scene. Keep both isolated until compared, then
consolidate rather than keep competing water systems indefinitely.

## Primary-source research read

- Godot spatial shader reference: camera masks, RADIANCE, shader coordinates and
  screen/depth constraints. https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Godot Camera3D and SubViewport: mirrored scene camera and bounded target.
  https://docs.godotengine.org/en/stable/classes/class_camera3d.html
  https://docs.godotengine.org/en/stable/classes/class_subviewport.html
- SIsilicon's planar-reflection README: second-camera projection, off-screen
  coverage and cost. Architecture reference, not installed or copied.
  https://github.com/SIsilicon/Godot-Planar-Reflection-Plugin
- Jasper Flick, Catlike Coding, Waves / Looking Through Water: varied wave
  directions, analytic normals, depth and guarded refraction sampling.
  https://catlikecoding.com/unity/tutorials/flow/waves/
  https://catlikecoding.com/unity/tutorials/flow/looking-through-water/
- Guardado and Sanchez-Crespo, GPU Gems chapter 2: receiver-space caustics and the
  distinction between artistic real-time approximation and physical transport.
  https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-2-rendering-water-caustics

Written tutorials, documentation and READMEs were read; no claim of watching full
videos. New code/patterns are original; no tutorial images, models, paid textures
or commercial shader packages were copied. Tutorial-led illustrated environments
remain the project direction, with water under its separate higher quality bar.
