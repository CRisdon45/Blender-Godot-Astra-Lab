# Water reflections: actual HDR scene and receiver-light study

**Status: 30 actual Godot frames captured and inspected; diagnostic, not final art or device approval.**

Open `godot/courtyard_water_reflections.tscn`, F6. W toggles the features; N toggles
study lighting. Original F5, anime foliage, prior hero-water and concurrent V2
entry points remain unchanged. Keep PR #1 draft and do not merge to main.

## Latest actual result, September 5, 2026

Rendered source: `1fb69a1ea69fdd54c72219f5fb633a3119c5a5c2`.
Linux run: https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33974408630
Artifact: `9971950580`, SHA-256
`8d45f8bf28d5b8d8c488d240c03f9390b9be5555cbf2dce64c7b261c6f9de84d`.
Godot 4.7.1, Forward+, Ubuntu 24.04, llvmpipe software Vulkan.

- All **170 combined Python source/math/evidence tests passed** locally and in
  Linux. These include preserved V2 checks; they are not shader or artistic proof.
- Actual-script preflight passed. Capture produced **30 PNGs and zero runtime
  contract errors**. No script or shader errors were logged by capture.
- All 30 PNGs were independently decoded. Five before/after camera, aim, time,
  flow and contact-span pairs match. All 13 HDR-study source/review files matched
  the captured source archive byte-for-byte.
- The reflection buffer is now verified at **600 x 450**, exactly half each
  dimension of the **1200 x 900** scene output. Physical source size, clipping,
  mirror-camera geometry, two contact spans, shared water/receiver clock, twelve
  fixed foliage materials and day/night restoration passed their assertions.
- Disabling reflection on the final pool surface changes **24,015 of 24,200**
  pixels above the defined threshold in an unobstructed water rectangle. Mean
  normalized RGB difference is **0.0393856**, independently reproduced from the
  PNGs. This proves the buffer affects actual water, not complete optical accuracy.
- GPU clipping control: the submerged magenta marker is **0 pixels with clipping,
  626 without**; the above-water green marker remains **703 pixels in both**.
  Raw linear HDR maximum is **3.0**, measured before presentation conversion.
- Six explicit motion phases change a water-only region independently of fire
  animation. They are sampled images, not live frame-rate evidence or a seamless
  loop. Four additional camera angles and a night study were captured.
- Preservation hashes passed for the anime GLB, original saved scene, original
  water shader, prior hero-water shader and prior hero-water script. The capture
  job's tracked-source diff was empty.

**The overall workflow remains failed/diagnostic:** existing editor popup-parenting
errors persist, and capture shutdown reports **seven leaked Texture RIDs**. They
remain in the runner report; no clean import, lifetime, Android, desktop-GPU or
final visual acceptance is claimed. This is not a new full execution of the
original 48-image acceptance runner.

## Artistic assessment

The matched frames show recognizable reflected pergola posts, fire bowls and
foliage instead of the former broad repeated blobs. Underwater light is visible
on the basin walls and floor, and the pool remains transparent. The middle
reflection-distortion setting, 0.09, adds movement without breaking the larger
reflected shapes as strongly as the 0.16 alternative. The 0.035 alternative is
also preserved in the review bundle.

This is **not yet the top-notch water requested**. The shallow foreground still
looks glassy and flat in places. Reflection edges need better filtering and the
focused-light pattern remains an approximation. The sheers are the weakest
close-up: their rectangular film silhouettes remain too rigid despite the
subtle flutter and transparent streaks. The next artistic priority is more
natural falling-film and full-width landing detail, not more global distortion
or noise. The source fixture's roughly 5.25 cm shelf and 95.25 cm flat basin are
limitations, not recommended construction dimensions.

## Implementation and limits

One extra camera reflects the actual surrounding scene across the measured
horizontal water plane. Each water point is projected with that reflected
camera's matrix. A dedicated visibility layer excludes water, basin and canvas
finish, preventing recursive pool capture. Inspected shader families receive
reflection-camera-only below-plane clipping; main views and shadow passes are
not clipped. Unsupported material families fail closed. This is not a universal
material converter and does not cap arbitrary cut geometry.

The reflected texture uses linear HDR, a linear/exposure-one intermediate camera
environment and no sampler sRGB decode. Transmission and Fresnel-weighted
reflection are combined before main-view tonemapping, without a second automatic
probe/sky reflection. Twelve foliage materials share the primary camera's card
pose in both views rather than inventing a new reflected canopy. The half-size
viewport is capped at 1024 pixels on its longest dimension and adds a real scene
render. Its target-device cost and sustained memory behavior are not approved.

A shared seven-mode analytic wave field and its curvature drive surface normals
and a bounded receiver focusing approximation. Receiver samples follow the sun,
depth and shared clock; actual direct light and shadow attenuation gate their
brightness. Screen derivatives filter the focusing pattern. This is an
art-directed inverse-ray/Hessian approximation, **not** a photon/fluid solver or
Evan Wallace's full forward wavefront-mesh caustic method.

Falling films use geometry-derived top heights, accelerating streaks, broken-up
aeration and at most 6 mm visual flutter pinned to the lip and waterline. Two
measured full-width contacts and the shared water clock remain authoritative.
This is not particle spray, volumetric splashing or computational fluid dynamics.
Measured transmission and foreground/screen-edge refraction guards are retained.

The current reflection path supports above-water ordinary perspective and
orthographic camera math; the captured courtyard witnesses use perspective.
Underwater and off-axis frustum views disable this path and are not final-art
fallbacks. There is one horizontal water plane; multi-level pools need separate
handling. Original source geometry, material assets, lighting and foliage models
are not reauthored by this pass.

## Real render failures were not waived

First run `33972760077`, source `610a996`, produced 28 intact PNGs and passed 165
combined Python tests, preflight, clipping and HDR witnesses. It nevertheless
failed the exact buffer-size check: the logical 1600 x 1200 window produced an
800 x 600 reflection despite a 1200 x 900 main framebuffer.

Second run `33973822493`, source `8eb8ec6`, produced 30 intact PNGs, passed 170
Python tests and the final-water pixel/foliage controls, but a stretched texture
size reported 900 x 675 and produced a 450 x 338 reflection. The expected
600 x 450 assertion was deliberately retained, not weakened.

The final correction uses physical `Window.size` or `SubViewport.size`, not
logical visible rectangles or stretched texture size. Actual-engine preflight
separately tests content-scale and 2D-override cases. The third run above passes
the runtime buffer-size assertion and exact PNG evidence validation. It still
retains the unrelated import errors and seven texture leaks.

## Primary written references read

- Evan Wallace, WebGL Water and its feature description:
  https://madebyevan.com/webgl-water/
- Evan Wallace, Rendering Realtime Caustics in WebGL (2014): wavefront area ratios
  and screen derivatives, adapted conceptually rather than copied wholesale.
  https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
- Godot Camera3D: transform, projection and offset semantics.
  https://docs.godotengine.org/en/stable/classes/class_camera3d.html
- Godot Viewport/SubViewport: linear HDR textures and render-target updates.
  https://docs.godotengine.org/en/stable/classes/class_viewport.html
  https://docs.godotengine.org/en/stable/classes/class_subviewport.html
- Godot Window: physical pixel size versus content scaling.
  https://docs.godotengine.org/en/stable/classes/class_window.html
- Godot spatial shaders: camera layers, shadow passes and coordinate semantics.
  https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Godot Image: HDR diagnostic presentation conversion.
  https://docs.godotengine.org/en/stable/classes/class_image.html

Written tutorials/documentation were read; this is not a claim of watching full
videos. No external artwork, models, texture packs or commercial shaders were
copied. Tutorial-led illustrated environments remain the project-wide direction,
with water under a separate, higher quality bar.

## Concurrent work and publication

Non-fast-forward guards preserved concurrent V2 implementation and evidence at
`a9ff728`, `546c4e2` and `f0a8473`. This HDR study is separately named; its capture
results must not be attributed to the V2 entry point. Before/after comparisons
here are against the prior hero-water scene, not a claimed head-to-head against
the latest V2. Consolidate the best verified approach before production rather
than maintain competing implementations indefinitely.

The bounded `publish-water-reflections.yml` workflow is designed to publish five
unchanged actual PNGs and diagnostic provenance to new `docs/previews/water-reflections-*`
paths. It checks the inspected artifact digest, runtime source equality and
current branch head, and refuses a concurrent ref change or existing preview
replacement. Publication success means the evidence was saved, not art, device
or import/shutdown approval. No merge or automatic baseline replacement.
