# Water V2: reflection, receiver light and falling-film study

Opt-in entry: `godot/courtyard_water_v2.tscn`, F6. Original F5, anime foliage,
and first hero-water entry points and authored assets remain untouched.

## Primary-source research read for this pass
- Godot spatial shader reference: camera-visible layer masks, RADIANCE integration,
  screen/depth restrictions and shader space. https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Godot Camera3D / SubViewport documentation: mirrored scene camera and bounded
  render target. https://docs.godotengine.org/en/stable/classes/class_camera3d.html
  https://docs.godotengine.org/en/stable/classes/class_subviewport.html
- SIsilicon's planar-reflection project README explains a second camera render,
  projection onto the water plane, off-screen coverage and cost. Read as architecture
  reference, not installed or copied. https://github.com/SIsilicon/Godot-Planar-Reflection-Plugin
- Jasper Flick, Catlike Coding, Waves / Looking Through Water: unequal wave
  directions, analytic normals, depth and rejecting invalid refraction samples.
  https://catlikecoding.com/unity/tutorials/flow/waves/
  https://catlikecoding.com/unity/tutorials/flow/looking-through-water/
- Guardado and Sanchez-Crespo, GPU Gems chapter 2: receiver-light caustics and the
  distinction between artistic real-time approximations and physical light transport.
  https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-2-rendering-water-caustics

Written tutorials/docs/READMEs were read. No claim of watching full videos.
All new implementation and procedural patterns are original. No tutorial textures,
models or commercial shader packages were copied.

## Changes and boundaries
The reflected camera follows the viewing camera about the measured water level.
A separate visibility layer excludes water/receivers and clips below-water fragments
in the current architecture/foliage shaders. Foliage card pose stays tied to the main
camera so the reflection does not invent a different canopy. The half-width buffer
is capped at 768 pixels. This is a second scene render, not free or device-certified.
Reflection color uses a linear intermediate tone curve; it is not an HDR transport
or exposure-calibration claim. Future material families must opt into reflection
clipping; unsupported material shaders are not automatically made correct.

Water uses a calmer six-direction slope field and retains measured transmission,
Fresnel, screen-edge/above-water guards, geometry-derived sheet contacts, W and N.
The receiver caustic network is intentionally **artist-directed, not photon tracing**.
It follows the main sun projection, depth, shared water clock, lighting and shadows.
This replaces the previous Hessian approximation only in this new study. There is
no claim that this network is a physical solution of the six-wave optical field.

Falling films flex a few millimetres with pinned slots, irregular advected variation
and localized aeration. This is not volumetric fluid, droplet or spray simulation.
Original basin dimensions are preserved; the roughly 5 cm shelf remains a fixture
limitation, not a swimming-pool design recommendation.

## Validation
New Python checks cover reflection geometry, bounded slopes, isolation, clocks,
source guards and real-scene capture contracts. Actual Godot parsing, shader
compilation and images must come from the Linux job, not those source checks.
Expected set: 22 full-scene frames plus one raw planar-camera image, including
3 matched before/after poses, flow-off, component views, caustics-off, probe fallback,
night and six explicit motion phases. Motion phases are not a frame-rate benchmark.
The runner records every import/capture error and shutdown warning as diagnostic.
No automatic baseline replacement, main merge, final art or Android approval.

Initial status: implemented; runtime/art assessment pending the bounded Linux run.


## First actual run and correction
Run 33972481550 at `a9ff728` produced 22 full-scene images plus the real reflection
buffer, and all script contracts passed. Independent pixel inspection found the
planar/probe comparison was **identical inside the water**. The old reflection
probe was overriding the new RADIANCE source; the raw reflection image alone was
not evidence that the water used it. Godot issue 80665 describes the same override
ordering limitation: https://github.com/godotengine/godot/issues/80665 .

The refinement sets the probe's reflection mask to zero in planar mode and restores
its water layer only in the explicit fallback mode. Actual water-region image
differences are now a required capture assertion, not an informal check. The
receiver pattern is smaller, dimmer and broken into uneven arcs after the first
frames exposed overly bright large cells on the back pool wall.

The first run also proved that using an Xvfb display during import did NOT resolve
the existing popup-parenting errors. It still reported seven leaked texture RIDs
at capture shutdown. These are kept as workflow failures. No cleanliness claim.
