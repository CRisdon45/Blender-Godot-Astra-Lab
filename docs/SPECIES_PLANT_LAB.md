# Species Plant Lab: Android-oriented witness

Opt-in project: `plant_lab/project.godot`. The existing courtyard, water scenes,
settings and baseline assets are not modified. This is a two-species technical
and artistic experiment, not an approved production plant library.

## What this implements

The pure Python compiler creates a persistent, seeded branch graph, attached
foliage lobes, original species-specific brush atlases, grouped custom normals,
a separate blossom layer, and three nested geometry levels. Blender builds
36 GLBs and 12 editable `.blend` files: two species, two seeds, three illustrative
stages, three LODs. The Godot project loads these baked variants and groups
instances by species, variant, stage and 8 m spatial cell. It does NOT generate
topology on the tablet yet. Camera orbit changes only the small brush poses;
the whole crown never billboards. LODs use screen-size thresholds and hysteresis.

The Mobile renderer project uses a 1280 x 800 viewport with 0.8 internal 3D scale,
2x MSAA, one directional light, a 2048 shadow atlas, cutout rather than blended
foliage, and no screen-space / Forward+ dependencies. Flowers do not cast
shadows; far-LOD plants do not cast dynamic shadows in this experiment.
That is an explicit visual compromise, not a sunlight-analysis solution.

Controls include pair / isolated views, growth comparisons, a 108-plant garden,
bloom pulses and a bounded post-bloom litter example. The latter is a maximum
of 300 opaque instanced petal primitives on a flat ground plane, not a measured
litter deposition or physics simulation.

## Identity and accuracy boundaries

- Hybrid palo verde is assumed to mean Desert Museum. It has an open vase-like
  woody scaffold, green bark, fine connected foliage brushes and yellow blooms.
- Texas sage is generic Leucophyllum frutescens, natural form. Cultivar is
  deliberately null. Silver-green foliage and purple blossoms are art-directed.
- Stage 0 / 1 / 2 means installed example / growing example / mature target.
  These are NOT calendar ages. Nursery stock, cultivar, irrigation, establishment,
  climate and pruning histories have not been calibrated.
- The nominal mature envelope targets are 7.6 m x 7.6 m and 1.83 m x 1.83 m.
  These are profile targets, not certified tight bounds of every rendered seed
  or camera-facing brush pose. Rendered extents are exported separately as safe
  conservative AABBs. Production clearance/takeoff must use an authoritative
  botanical envelope, not count silhouette pixels or decorative triangles.
- Branches are connected geometrically but their architecture, taper and joint
  blending remain illustrative. This is not a botanically validated branch model.
- Bloom pulses are user-selected scenarios, not exact seasonal/weather forecasts.
  Texas sage is generally listed as low-litter even though visible local petal
  drop can follow flowering. Do not invent a high annual litter rate.
- No Android package, real-device GPU timing, thermal test, continuous age slider,
  runtime mesh compiler, terrain projection, pruning simulator, or complete
  species catalog is delivered by this witness.

## Reproduce

Pinned review engines: Blender 5.2.1 and Godot 4.7.1.

```sh
python -m unittest discover -s tests -p test_species_lab.py -v
blender --background --factory-startup --python-exit-code 1 --python tools/build_species_lab.py
python tools/check_species_assets.py plant_lab/assets
godot --headless --path plant_lab --rendering-method mobile --editor --import
godot --path plant_lab --rendering-method mobile
```

The workflow packages the complete runnable project and editable Blender sources.
Its capture command requests 17 actual Godot frames, including reverse/elevated
angles, reduced LODs, bloom states and the repeated-plant garden. Inspect logs,
geometry contracts AND the images. A green source test or software-Vulkan capture
is not final art approval or Galaxy Tab S10 FE performance evidence.

## Recommended production architecture

Keep botanical profiles and project plant descriptors authoritative. Compile
geometry only when species, seed, size/form or pruning changes. Cache by profile
version, morphology, seed and LOD; share completed meshes among placements.
Keep bloom/leaf retention/litter state separate from woody topology.

Use a small family of procedural grammars, not one generic tree formula: woody
canopies, basal woody shrubs, rosettes, grass clumps, columnar cacti and segmented
cacti. Art-direct the reusable local components in Blender. A later runtime
compiler can consume the same descriptor contract; cross-language determinism
must be tested rather than assumed from a shared random seed.

Before producing dozens of species, approve these two from all camera angles,
add stable silhouette-preserving LOD transitions, then measure a whole backyard
including pool reflections and architecture on the actual tablet. Compare
Mobile and Compatibility with matched visual settings. Reserve the water budget.

## Primary reference ledger

No third-party meshes or textures are bundled. Techniques, not artist assets,
are adapted from the existing courtyard study and the artist's tutorial:
https://trungduyng.substack.com/p/tutorial-blender-anime-foliage-pipeline

Botanical identity, indicative sizes and seasonal cautions:
https://extension.arizona.edu/es/publication/arboles-de-mezquite-y-palo-verde-para-el-paisaje-urbano
https://www.amwua.org/plants/texas-sage
https://www.txsmartscape.com/plant-search/texas-sage

Rendering / batching constraints:
https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
https://docs.godotengine.org/en/stable/classes/class_multimesh.html
https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html

A candidate for future constrained crown architecture, not implemented here:
https://algorithmicbotany.org/papers/colonization.egwnp2007.html
