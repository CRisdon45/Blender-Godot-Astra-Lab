# Second water study: reflected scene, receiver light and falling film

Status: implementation submitted for actual Godot review; do not call this a
visual or device acceptance. Preserve the earlier water study and all baselines.

Open `godot/courtyard_water_reflections.tscn`, F6. F5 and the previous
`courtyard_hero_water.tscn` retain their behavior. W toggles feature flow; N
switches the inherited day/night lighting study.

## Intended improvement

The previous pool reflection broke the environment into repeated blobs. This
study renders the actual surrounding scene from a camera mirrored across the
pool plane. It projects each water point through that camera instead of assuming
that its screen coordinates equal the reflection texture coordinates.

The dedicated reflection layer excludes the pool, basin and canvas finish.
Inspected material shaders receive a reflection-camera-only below-plane clip;
main-camera shading and shadow passes are not clipped. This avoids looking up at
submerged/underside geometry through the water. The source shader resources and
exported geometry are not modified. The adapter fails closed on unsupported
shader families; this is not a universal material converter.

The reflected texture is linear HDR, with a linear/exposure-one camera environment
and no sampler sRGB conversion. Transmission and Fresnel-weighted reflection are
combined before the main view's tonemapping, without a second automatic specular
probe. A half-resolution viewport (600 x 450 for a 1200 x 900 review), capped at
1024 pixels on its longest dimension, renders the additional scene. This adds a
real extra view; there is no performance approval or claim that Android is cheap.

A shared seven-mode analytic wave field and its curvature drive surface shading
and an inverse-refracted, bounded focusing approximation on the basin. The modes
have varied directions/frequencies/phases, not a single regular repeating motif.
They are still deterministic waves, not a fluid simulator. Caustic strength is
art-directed, evaluated on the receiver and gated by actual direct light/shadow,
with screen-derivative filtering. It is not a photon solver or Evan Wallace's
forward wavefront-mesh caustic algorithm.

Falling sheets use a bounded 6 mm visual flutter anchored at their lip/waterline,
geometry-derived top heights, accelerating streaks and broken-up aeration. Their
geometry-derived full-width contact spans and shared clock are retained. This is
not a particle/splash or Navier-Stokes simulation; the existing sheet silhouette
and source basin dimensions still constrain the result.

## Primary references actually read

- Evan Wallace, WebGL Water demo feature description:
  https://madebyevan.com/webgl-water/
- Evan Wallace, *Rendering Realtime Caustics in WebGL* (2014), explanation of
  wavefront area ratios and screen derivatives:
  https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
- Godot Camera3D: mirrored transforms, projection and offset semantics:
  https://docs.godotengine.org/en/stable/classes/class_camera3d.html
- Godot SubViewport and Viewport: update modes and linear HDR texture behavior:
  https://docs.godotengine.org/en/stable/classes/class_subviewport.html
  https://docs.godotengine.org/en/stable/classes/class_viewport.html
- Godot spatial shader reference: camera-visible layers, shadow-pass flag,
  fragment view coordinates and screen/depth texture semantics:
  https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Godot Image: HDR diagnostic presentation conversion:
  https://docs.godotengine.org/en/stable/classes/class_image.html

These are written documentation/tutorial pages, not a claim to have watched
complete videos. No external shader package, artwork or textures were copied.

## Evidence gates

The bounded GitHub Linux workflow `water-reflection-review.yml` preloads the actual
script chain and performs camera-mirror checks before rendering. Its 28 frames
include five pose/time-matched previous/new pairs, reflection and receiver
isolations, flow off, night, six explicitly sampled motion phases, four camera
angles, and two conspicuously labeled clip-control frames.

The raw reflected viewport contains temporary reflection-only emissive controls:
an above-plane green box must remain; a below-plane magenta box must be absent.
Turning its clip off deliberately must reveal that same magenta box. This
positive control rules out passing simply because the test object was off-camera.
Raw HDR pixel values are checked before creating presentation PNGs.

The Python runner checks complete PNG data, exact file names/counts, camera/time
pairs, dimensions and actual runtime assertions. Import errors and renderer
warnings/leaks are recorded and make the workflow diagnostic, not clean success.
No desktop GPU or Android timing/memory approval is inferred from llvmpipe.
The motion phases are a sampled study, not live frame-rate evidence or a seamless
loop. Background fire/sky may continue their own engine-clock animation.

## Boundaries and next artistic judgment

- Above-water perspective and orthographic cameras only. Underwater/off-axis
  frustum cameras disable this reflection path; that fallback is not final art.
- One horizontal water plane; reflected transparent objects and brush-billboard
  foliage remain renderer/representation approximations.
- Plane clipping is per-material and does not cap arbitrary cut geometry.
- Depth, shelf clarity, reflection orientation, caustic noise, falling-film
  silhouette, camera stability and daylight/night balance require real frames.
- Source-model shelf is only about 5.25 cm deep; basin about 95.25 cm. These are
  fixture limitations, not recommended dimensions or construction standards.
- Texture/view lifetime is explicitly broken on shutdown, but only actual engine
  logs can establish whether any previous or new resource warnings remain.
