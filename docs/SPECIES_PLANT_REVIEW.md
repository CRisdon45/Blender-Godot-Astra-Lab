# Species plant review: actual Blender and Godot evidence

Reviewed 2026-09-05. This is an opt-in technical/art prototype, NOT an approved
plant library, botanical growth predictor, or Android performance certification.
The existing courtyard and water study source/settings remain unchanged.

## Reproducible evidence

- Branch: `work/species-android-plant-lab`.
- Reviewed implementation commit: `226ae1b25850f0b66560cd80af88ba04dc3ac84c`.
- Successful build/render run: https://github.com/CRisdon45/Blender-Godot-Astra-Lab/actions/runs/33973948275
- Artifact: `species-plant-review-2`, ID `9971761398`.
- Artifact ZIP SHA256: `d8c990251c927b26c8b250deb59d913ba233d47ba81132ef24b237524cb48d83`.
- Engines actually used: Blender 5.2.1 LTS and Godot 4.7.1.
- Actual renderer: Mobile, Vulkan, software llvmpipe LLVM 20.1.2. NOT an Android GPU.

The artifact contains the ready-to-import `bundle/plant_lab/project.godot`,
36 generated GLB files, 12 editable Blender files under
`bundle/authoring/species_lab/`, four original atlases, 12 plant descriptors,
generation/validation source, tests, manifest and unfiltered logs.
The generated binary assets and screenshots are in the artifact; they are NOT
committed to the source branch by this review documentation commit.

All 17 Python tests passed in the runner and again on the downloaded bundle.
All 36 GLBs passed independent index, count, normal, texture-coordinate,
vertex-color, volume and billboard-anchor checks, also repeated after download.
Maximum reconstructed card-center error was approximately 4.92e-7 metres.
Actual imported resources were checked to preserve authored LODs and enable
atlas mipmaps. All 17 PNGs passed file validation and were visually inspected.
Godot import and capture logs contained no error/warning diagnostics in this run.
Blender's Material.use_nodes deprecation warning remains in the raw build log.
These checks prove only the stated contracts, not complete application correctness.

## Included views and behavior

The 17 actual 1280 x 800 captures include each species with/without flowers,
reverse and elevated views, deliberately forced medium/far LOD close-ups,
a post-bloom ground-litter example, three-stage comparisons and a garden
configured with 12 trees plus 96 shrubs (108 placements).

The project uses Mobile on desktop and mobile feature overrides, a 0.8 internal
3D scale (1024 x 640 at this test viewport), 2x MSAA, one directional light and
a 2048 shadow map. There are no Forward+ screen-space shader dependencies.
Shared meshes/materials are instanced with MultiMesh in spatial/variant batches.
The complete crown never billboards; small brush components rotate around their
fixed, volumetrically distributed 3D centers.

The garden capture reported 112 draw calls and 104,900 rendered primitives.
These are one captured view's Godot counters, including relevant render passes
and the current visibility/LOD state. They are not the sum of all source meshes,
a maximum scene budget, or evidence of any tablet frame rate.

## Actual per-asset geometry

Mature stage, seed 41. Counts include wood, foliage and the complete blossom
layer once; shadows/reflections may submit geometry again.

| Asset | Near triangles | Medium triangles | Far triangles |
| --- | ---: | ---: | ---: |
| Desert Museum palo verde | 4,504 | 2,080 | 1,132 |
| Natural-form Texas sage | 1,692 | 992 | 562 |

The near palo verde has 1,448 wood triangles, 1,207 leaf cards and 321 flower
cards. The near sage has 732 wood triangles, 386 leaf cards and 94 flower cards.
Counts vary by seed and stage; the checked exported set ranges from 464 to
4,504 triangles per complete asset.

## Visual judgment, not merely test results

The first run technically passed but was not accepted as the visual direction:
the sage was too bare underneath and read like a miniature tree, the palo verde
was too rounded, and blossoms read as oversized stars. Revision two lowers the
sage's canopy shoulders, changes branch taper and joints, spreads/flattens tree
masses, reduces hidden shrub wood, and uses small clustered blossom marks.

The second pass is still NOT final art. The sage's separate brush stamps remain
too conspicuous at close range. The palo verde's canopy masses remain too
regular/tiered to call its branching and habit species-accurate. Medium/far LODs
lose too much coverage and open conspicuous holes in the deliberately forced
close-ups. Hysteresis prevents rapid LOD oscillation but does not solve that
artistic transition. The far LOD disables dynamic plant shadows entirely; this
is an explicit prototype compromise, not the desired final shadow treatment.

The next art pass should use carefully authored crown/branch guides and better
species-specific brush components, plus coverage-preserving LOD representations.
Do not solve the loss of coverage only by adding thousands of independent leaves.
Keep actual camera-orbit and elevated reviews as acceptance gates.

## Implemented versus proposed

Implemented: deterministic, species-specific offline procedural compilation;
Blender editing/export; two reusable seeds per species; three discrete illustrative
growth stages; branch-connected foliage masses; three authored LODs; original
cutout atlases; grouped normal/shading treatment; shared instancing; separate
bloom state; a capped flat-ground petal example; actual Mobile-renderer captures.

NOT implemented: on-device topology generation, a continuous age slider, calibrated
years-after-installation growth, cultivar-specific Texas sage profiles, weather-
driven phenology, measured litter rates, terrain/pool-aware litter projection,
plant wind, APK/export presets, actual Galaxy Tab S10 FE testing or full-courtyard
performance with pool reflections and architecture.

The generic sage cultivar remains null. Desert Museum is an explicit assumption
for 'hybrid palo verde'. Nominal mature size targets are 7.6 x 7.6 metres and
1.83 x 1.83 metres. These are illustrative profile targets, not certified physical
bounds of the displayed geometry. Source-linked botanical envelopes must remain
separate from decorative meshes for clearance, plan symbols and takeoffs.
Growth stage is NOT plant age; installed sizes are not certified nursery grades.

## Recommended continuation

Use a hybrid system: Blender-authored form guides and small components, bounded
species/family grammars, event-driven geometry generation and a shared cache.
Reuse ordinary variants for mass planting; generate a unique form only when it
adds design value. Seasonal state should not rebuild the woody scaffold.

Approve these two species and their LODs before mass-producing a catalogue.
Then test an actual backyard on the Galaxy Tab S10 FE with water, architecture,
worst-case foliage views and sustained thermal load. Compare Mobile and
Compatibility using matched images/settings rather than assuming a winner.
Only then move the proven geometry compiler into the runtime contract and add
an unrelated family such as agave to test whether the abstraction generalizes.
