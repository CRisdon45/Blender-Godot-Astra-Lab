# Project direction: illustrated environments, hero water

Owner direction, September 5, 2026: continue the approved anime-foliage approach
through the entire project. Research artist tutorials for each material family,
translate the useful technique into the real-time engine, and judge actual frames.
**Water is the star and has a higher, separate acceptance standard.** It must not
be flattened by a universal toon preset or disguised by illustrative noise.

## Working method

1. Study a relevant artist's process and inspect examples before changing a look.
2. Identify what actually produces the effect: geometry, normals, shading,
   material marks, lighting, or composition. Do not substitute a giant post filter.
3. Implement an isolated, reversible real-time study with explicit controls.
4. Render matched before/after views, close-ups and moving-camera evidence.
5. Promote only after visual review and device evidence; passing code is not art approval.

Keep architectural precision and full plant volume. Prioritize clear silhouettes,
large coherent light/shadow groups, restrained warm ink and selective material
marks. Avoid photographic texture noise, repeated tiny foliage edges, black
outlines on everything, universal grain, and fogging/blur as a shortcut.
There is no runtime AI dependency. AI is only a development aid.

## Research ledger

These sources were inspected for ideas, not treated as production-ready packages.
No third-party tutorial image, paid texture, or asset is copied into the runtime.
The hero-water code is an original bounded study, not a port of a donor shader.

| Aspect | Primary reference | Technique or lesson | Disposition |
| --- | --- | --- | --- |
| Pool optics | Malido, *Absorption Based Stylized Water*: https://godotshaders.com/shader/absorption-based-stylized-water/ | Depth-dependent transmission, refracted receiver sampling, reject foreground/edge samples; screen-space reflection has visibility limits | Adapted conceptually; no SSR ray-march dependency |
| Underwater light | binbun, *Water with Caustics*: https://godotshaders.com/shader/water-with-caustics/ | Receiver-space caustics and separate refraction/depth controls | Adapted conceptually; this study uses a shared analytic ripple field and bounded focusing approximation |
| Pool-quality benchmark | Evan Wallace, *WebGL Water*: https://madebyevan.com/webgl-water/ | Refraction/reflection, caustics and interaction must work together in a pool, not just form a pretty flat pattern | Benchmark only; not claiming this study reproduces its solver |
| Engine depth conventions | Godot, *Advanced post-processing*: https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html | Inverse projection of reverse-Z depth; different Compatibility NDC convention | Implemented explicitly; Forward+ is the actual capture target |
| Environment materials | ALLO, *Anime in Blender Tutorial*: https://www.blendernation.com/2022/09/03/anime-in-blender-tutorial/ | Artist-authored toon materials that belong together in an anime environment | Next donor study for walls, coping, metal and furniture; no claim that tutorial video was fully viewed |
| Environment lighting | ALLO, *Anime Classroom Environment*: https://www.blendernation.com/2022/03/30/anime-classroom-environment/ | Integrated material, prop and lighting treatment rather than one generic shader | Research queue; do not import classroom proportions/materials into landscape design |

The Godot Shaders pages describe their code snippets as CC0, not their preview
images/assets. Attribution is retained here even though their code was not copied.

## Hero water study 01

Open `godot/courtyard_hero_water.tscn`, then F6. Original F5/main and
`courtyard_anime.tscn` stay unchanged. W toggles flow, N toggles the lighting study.

- Existing geometry-derived sheet contacts and shared water clock are retained.
- The old water box renders only its upper surface. Screen depth reads the actual
  basin/shelf behind it instead of using the old world-Z color gradient.
- Beer-Lambert transmission absorbs red more quickly than green/blue; foreground
  and viewport-edge rejection bound screen-space refraction.
- Already-lit screen color enters through emission to avoid a second diffuse-light
  pass. Dielectric specular remains for sky/local-probe/sun reflections. The
  reflection probe excludes the pool, captures once, and is dirtied for lighting changes.
- Underwater highlights are on the opaque basin receiver, illuminated/shadowed by
  scene lighting. Their simplified focusing Jacobian comes from the same analytic
  wave spectrum as surface normals. They are not a photon or fluid simulation.
- Removed the old pool-wide fine horizontal highlight pattern in this opt-in shader.
  Sheet highlights use softer moving ribbons and localized aeration; legacy glint
  rods are hidden only in this study.
- The old spatial full-screen contour copy would overwrite transparent water with
  the pre-water screen. It is omitted here; the later canvas ink pass remains,
  with reduced grain. This is not the final depth-aware illustration compositor.

## Evidence and explicit limits

`godot/tests/capture_hero_water.gd` requests 20 genuine Godot images: four matched
before/after poses, flow-off, measured-depth diagnostic, two night-lighting studies,
and eight fixed-camera water phases. Every record stores pose, size and water
state. Python checks are source/math checks only. Godot logs, PNG validation and
runtime assertions remain necessary. Consult the run's `runner-report.json` for
actual status; requested images are not a claim that a run completed.

Preserved geometry exposes an existing limitation: the source shelf is about
5.25 cm under the waterline and the flat basin is about 95.25 cm deep. That is a
lookdev fixture, not a production pool-depth standard. This pass does not silently
change those dimensions. Shelf-depth, finish-color and deep-bowl witnesses are
required before judging the water across real projects.

This study is not final water approval. Screen refraction sees only opaque objects
already in the frame. A local box-projected reflection probe is not an exact planar
reflection and does not continuously reflect every animated element. Day caustics
are disabled in the night study; physically coupled underwater-light caustics,
credible nighttime fire illumination, adaptive quality and Android performance
remain separate acceptance work. Four-direction analytic ripples are not a fluid
simulation. The original real-scene binding still supports one upright rectangular
pool and at most four contact spans. General pool shapes/features are not added.

## Required future witnesses

Water: true shelf/steps/deep-end visibility; blue and white plaster; low/grazing and
high views; clear water without candy stripes; reflections that survive orbit;
soft full-width sheer contact; flow-off with ambient motion retained; pool light
on/off; multiple feature types; Android GPU cost and frame pacing. The water must
look excellent in motion, not just one curated still.

Other scene families, in order: masonry/coping/tile hierarchy, powder-coated metal
and timber grain, fabric/furniture, gravel/turf, architecture-aware outlines,
lighting and restrained atmosphere. Each gets its own tutorial ledger and matched
runtime witness. Water remains separately adjustable throughout.
