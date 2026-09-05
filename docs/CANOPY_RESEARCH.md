# Canopy research and implementation ledger — 2026-09-05

## Decision

Test a hybrid canopy: opaque interior masses, small cutout sprays at the edge, shared analytical shading normals and restrained original paint masks. Keep real woody structure and three-dimensional gaps for the palo verde. Preserve the existing placement/cache/budget engine; do not replace it with an unrelated viewer or runtime biological simulation.

The new opt-in entry is `plant_lab/canopy_study.tscn`. The original entry and baseline catalog remain available. A/B captures use the same receiver, camera and sun in the same process. A second fresh engine process repeats all captures, with the actual differences saved rather than silently assuming repeatability.

## Sources actually consulted

The written pages, author explanations and linked technical images below were read/inspected. Video titles/descriptions were located, but full playback/transcripts were not available; those videos are leads, not a claim of having watched their full lessons.

| Source | Evidence/access | Adaptation or rejection |
| --- | --- | --- |
| Kids With Sticks, *Creating stylized art inspired by Ghibli using Unreal Engine 4*, https://kidswithsticks.com/creating-stylized-art-inspired-by-ghibli-using-unreal-engine-4/ | Primary production-team breakdown; read text and inspected normal-transfer and interior-mesh images | Adopt simplified leaf clusters, shared normal fields and opaque interiors. Do not port UE4 distance-field lighting to the tablet. |
| Kids With Sticks, *Rogue Spirit graphics summary*, https://kidswithsticks.com/rogue-spirit-graphics-summary/ | Primary production retrospective | Prefer sparse painterly detail; avoid unnecessary normal maps and keep instancing/placement cost explicit. |
| Simon Trumpler, *Airborn – Trees*, https://simonschreibt.de/gat/airborn-trees/ | Read author investigation, embedded explanation attributed to original artists, and inspected core-plus-edge diagram | Follow through to the original artist reply and production-team adaptation. Interior volume is not a final bare blob; edge detail and normals are essential. |
| Original Airborn artist discussion, https://polycount.com/discussion/comment/1665243/ | Original production discussion reached via the article | Attribution trail for opaque core plus peripheral cards; no assets copied. |
| Pontus Karlsson / pomperi, https://www.reddit.com/r/Unity3D/comments/jhwfkj/fluffy_trees_using_custom_shader_that_turns_quad/ | Primary author's written technical explanation | Retain fixed three-dimensional spray centers and proxy shading normals; do not billboard a whole tree. |
| Pontus Karlsson, *Fluffy stylized trees tutorial*, https://www.youtube.com/watch?v=iASMFba7GeI | Video page/description only | Relevant viewing lead, not full-video evidence. |
| Lightning Boy Studio / David Forest, *How to Create Ghibli Trees in 3D*, https://www.youtube.com/watch?v=DEgzuMmJtu8 and https://lightningboystudio.gumroad.com/l/RZcQI | Tutorial listing located; full video was not accessible | Useful authoring reference. Do not assume an Eevee node setup exports as a Godot shader. No tutorial asset downloaded or redistributed. |
| J Hell, *Simple, cheap stylized tree shader*, https://godotshaders.com/shader/simple-cheap-stylized-tree-shader/ | Primary author's code, description, corrections and license note read | Existing fixed-center shader already avoids its naive size-dependent offset issue. Note code is MIT but depicted textures are not covered; no snippets or textures copied into this pass. |
| Blender, *Editing Normals*, https://docs.blender.org/manual/en/latest/modeling/meshes/editing/mesh/normals.html | Official documentation | Compute and export analytical normals over larger canopy forms, independently of small spray orientation. |
| Blender, *Data Transfer Modifier*, https://docs.blender.org/manual/en/latest/modeling/modifiers/modify/data_transfer.html | Official documentation | Normal transfer is an authoring technique, not a runtime per-leaf calculation. Our simple field is calculated in the offline compiler. |
| Godot, *Spatial shaders*, https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html | Official reference | Separate opaque core shader from discarded cutout edge shader. Keep mobile force-vertex-shading disabled where custom light() functions are required. |
| Godot, *Optimizing 3D performance*, https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html | Official reference | Use explicit MultiMesh on Mobile, not Forward+-only automatic instancing. Triangle cost is not GPU cost. |
| Godot, *GPU optimization*, https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html | Official reference | Small cutout areas and opaque interiors are worth testing against overlapping foliage; no claim of measured device speedup. |
| Godot, *Standard Material 3D*, https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html | Official alpha-antialiasing documentation | Alpha-to-coverage is a later device A/B option with MSAA, not enabled speculatively across the pipeline. |

## What this implementation changes

- Offline art composition rearranges the same connected branch identities. Primary leaders differ in height and reach. Secondary branches are recomputed from the parent curves so no branch floats away from its attachment.
- Tree interiors remain separated canopy masses. Sage uses closely overlapping low masses. Both still need actual visual review; the method alone does not certify a species or style.
- Core geometry is truly opaque, with no fragment discard. Sparse sprays retain the fixed-center brush contract. A separate component costs an additional draw per spatial/variant group; all core triangles are included in budget allocation and diagnostics.
- Original procedural texture masks replace the previous conspicuous stamps for this treatment only. The core uses a packed wash/mark mask, and core/sprays share broad tonal shading. No per-leaf outlines, high-frequency normal map, screen-space effect, compute pass or AI service is required.
- A version-2 catalog names all four components. The existing version-1 baseline still uses three. The cache checks the actual imported components against catalog costs. Independent binary GLB audits verify indices, normals, fixed-center reconstruction, counts and cull bounds.
- The design envelope remains independent of rendering detail. Growth stages are illustrative, not calendar years, and the sage cultivar is still unspecified.

## Cost and acceptance boundaries

The new generator trades some alpha-covered area for opaque surface triangles. That is a hypothesis about rendering efficiency, not a measured tablet result. It may use an extra draw call per group. The 108-plant garden, close views, reverse/elevated views, three LODs and repeated captures are part of this cloud gate. Software Vulkan only establishes a functioning rendering path. The Galaxy Tab S10 FE, full courtyard water cost, sustained thermals and stylus behavior remain separate tests.

Do not declare art acceptance just because Python, GLB and Godot checks pass. Inspect whether either plant became a collection of smooth balls, whether the sage still has stamp-like edges, whether tree voids remain intentional, and whether distant models retain silhouette/fullness. Record failures as well as improvements.

## Licensing and provenance

All code, geometry and texture masks added in this pass are original project implementations of general techniques. No Ghibli film frame, tutorial project, marketplace model, third-party texture, shader snippet or font file is included in the deliverable. Links are an attribution/research trail, not a redistribution license. Future third-party assets must receive an explicit license/provenance entry before inclusion.
