# Project direction: illustrated environments, hero water

Owner direction, September 5, 2026: extend the approved anime-foliage approach
through the whole project, studying artist tutorials for each material family.
**Water is the star and has a separate, higher acceptance standard.** Do not
flatten it with a universal toon preset or hide it under illustrative noise.

## Working method

Study a relevant artist's process, identify what creates the result, implement an
isolated real-time study, and inspect matched actual Godot views before promotion.
Use geometry, grouped normals, selective material marks and lighting deliberately;
a full-screen filter is not a substitute for appropriate materials.

Keep architectural precision, full plant volume, clear silhouettes, broad coherent
shadow groups and restrained warm ink. Avoid photographic texture noise, repeated
tiny foliage edges, fine stripes everywhere, universal heavy grain and blur as a
shortcut. No runtime AI dependencies. Standing implementation guidance is also in
[AGENTS.md](../AGENTS.md).

## Primary research ledger

The following sources informed the studies. No third-party preview image, paid
asset, texture pack or tutorial project is copied into this runtime. The water
implementation is an original bounded study, not a claim to have ported a donor
shader or reproduced its full solver.

| Source | Useful principle | Treatment here |
| --- | --- | --- |
| [Malido: Absorption Based Stylized Water](https://godotshaders.com/shader/absorption-based-stylized-water/) | Depth-dependent transmission, refracted receiver sampling, foreground and viewport guards | Adapted conceptually. No SSR ray-march dependency. |
| [binbun: Water with Caustics](https://godotshaders.com/shader/water-with-caustics/) | Underwater receiver-space light patterns and separate optical controls | Shared analytic ripple phase/spectrum and a bounded focusing approximation, not copied shader code. |
| [Evan Wallace: WebGL Water](https://madebyevan.com/webgl-water/) | Reflections, refraction, caustics and interaction must work together in a pool | Quality benchmark only; its solver is not implemented. |
| [Godot: Advanced post-processing](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html) | Reverse-Z depth reconstruction, different Compatibility NDC convention | Explicit inverse-projection paths. Only Forward+ has actual capture evidence. |
| [Godot: Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) | Opaque/transparent screen-copy ordering | Omit the old spatial screen copy that overwrites transparent water; retain the later canvas ink pass. |
| [Godot: ReflectionProbe](https://docs.godotengine.org/en/4.5/classes/class_reflectionprobe.html) | Real engine class, capture versus reflection masks and update behavior | Local box-projected, once-updated probe excludes water; this is not a planar reflection. |
| [ALLO: Anime in Blender Tutorial](https://www.blendernation.com/2022/09/03/anime-in-blender-tutorial/) | Coherent stylized environment materials | Research queue for walls, coping, metal and furniture; not claiming the whole video was viewed. |
| [ALLO: Anime Classroom Environment](https://www.blendernation.com/2022/03/30/anime-classroom-environment/) | Integrated prop, material and lighting treatment | Research queue, not a classroom asset/proportion transplant. |
| [mclelun: Anime Background Paint Over 3D Render](https://www.mclelun.com/2015/10/paint-over-3d-render.html) | Soft diffuse backgrounds, simple sunlight/ambient relationships, selective painted highlights instead of flat cartoon shading | Adopt material/light principles, not a camera-specific paint-over in place of movable 3D. |
| [SouthernShotty: Blender Stylized Wood Texture](https://www.blendernation.com/2020/05/12/blender-stylized-wood-texture/) | Painted base color and control of how grain is used in a scene | Restrained timber-grain study queued. Written creator introduction read; no whole-video viewing claim. |
| [Kristof Dedene: anime style caustics and sparkle FX](https://kdedene.gumroad.com/l/wTxJK) | Additional artist reference for water highlight language | Creator listing located only. No package purchased/downloaded or tutorial asset used. |

The Godot Shaders pages mark their code snippets CC0, not the images/videos/assets
in their previews. Attribution is retained even though their code was not copied.

## Opt-in water study

Open `godot/courtyard_hero_water.tscn`, then F6. W toggles feature flow, N toggles
study lighting. Original F5 and the foliage-scene entry point remain available.

The study keeps geometry-derived sheet contacts and the shared clock, but replaces
the flat surface-pattern treatment with measured receiver depth, Beer-Lambert
transmission, guarded refraction, dielectric specular and a local reflection probe.
The original water box renders only its top. Already-lit scene color enters via
emission rather than receiving a second diffuse-light pass.

Receiver caustics are affected by actual scene lighting/shadows, not added as
self-luminous paint. They share ripple phase/spectrum with surface normals, but
the surface shading amplitude is independently art-directed. This is not an exact
optical, photon or fluid solver. Softer transparent sheet shading and localized
impact response replace the old bright glint rods in this study only.

Painted foliage now has an illumination multiplier with a default of 1, preserving
the approved daytime behavior. Only the hero scene dims it at night and restores
it for daytime. Study pool lights affect the basin/water, not the whole yard.

## Evidence, limitations and next steps

[Actual water review](HERO_WATER_REVIEW.md) records the inspected run, failed first
attempt, 28-image capture set, 130 Python tests, import errors, renderer shutdown
warning and the remaining visual shortcomings. Source tests and complete PNGs are
not artistic approval or target-device performance evidence.

Water still needs more organic reflected distortion, luminous but controlled
receiver caustics, more credible sheers and full moving-camera review. Refraction
sees only opaque geometry already in the frame. A box-projected probe is not an
exact dynamic planar reflection; reflected brush cards remain tied to the main
camera. Four-direction analytic ripples are not fluid simulation. The binding
currently supports one upright rectangular pool and at most four contact spans.

Preserved source geometry has a shelf about 5.25 cm below water and a flat basin
about 95.25 cm deep. Those are look-development fixture limitations, not design
standards. Use calibrated shelf/step/deep-end fixtures and multiple plaster colors
before judging real-project depth behavior. Day caustics are disabled at night;
underwater-light caustics, true fixture/fire illumination and device costs remain
separate work. Eight sampled phases are not smooth live-performance proof.

After water's core visual issues, study masonry/coping/tile hierarchy, restrained
wood and powder-coated metal, furniture/fabric, gravel/turf, architecture-aware
outlines and lighting. Each material family needs its own references and actual
runtime comparison. Keep water independently adjustable throughout.
