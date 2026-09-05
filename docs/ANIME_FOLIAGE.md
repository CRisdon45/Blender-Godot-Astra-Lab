# Anime foliage study: Blender authoring, actual Godot rendering

This is a **generic broadleaf / flowering-mound study**, not a species-certified asset library or approved final art. The existing courtyard and baseline files stay available. The study entry point is `godot/courtyard_anime.tscn`.

## Why the construction changed

The previous exporter scatters thousands of independently oriented, randomly colored small leaf polygons. This makes the crown read as noise and exposes straight-spoke branches. Its "shrubs" are primarily thin flowering stems. The new approach prioritizes three-dimensional crown shape, continuous branch taper, overlapping foliage masses, and quiet light/shadow grouping.

Primary inspiration, studied as techniques rather than copied assets:

- Trung Duy Nguyen, **Blender Anime Foliage Pipeline**: https://trungduyng.substack.com/p/tutorial-blender-anime-foliage-pipeline — shaped emitter bushes, many small brush planes, grouped/custom normals, and stylized shading. Artist project: https://trungduyng.artstation.com/projects/P6aKNy
- Lightning Boy Studio, **Ghibli tree setup**: https://lightningboystudio.gumroad.com/l/RZcQI — foliage instancing and custom-normal transfer. Author's tutorial post: https://www.blendernation.com/2020/08/20/creating-ghibli-trees-in-3d/
- aVersionOfReality, **Building a Fancy Stylized Tree Shader in Blender 3.2**: https://www.blendernation.com/2022/08/11/building-a-fancy-stylized-tree-shader-in-blender-3-2/ — radial normals and art-directed, grouped lighting.

The atlas, branching geometry, crown shapes and code in this study are original. No artist assets, downloaded foliage textures, or tutorial project files are bundled.

## Actual implementation

`tools/build_anime_foliage.py` reads `pool_godot_source.blend`. It extracts the seven tree bases and original size scales, replaces their old crowns and branches, and replaces the five thin rear flowering groups with mounded shrubs. It retains the architecture, water geometry and agaves.

Each tree has ten overlapping, deliberately arranged ellipsoid lobes, 850 small brush cards in a real three-dimensional crown, and curved tapered branch leaders. Each shrub has five overlapping lobes, 240 cards, small stems and grouped blossoms. There are 7,150 cards in total (14,300 triangles), excluding trunks and flowers.

The eight-cell RGBA atlas contains connected brush shapes. Cards are small components, **not entire tree or shrub impostors**. Godot rotates each component around its fixed 3D center using the main camera basis, including during shadow rendering. The full crown does not rotate. Different anchors preserve depth and parallax.

Normals represent a blend of the local lobe and overall crown shape instead of the flat card normal. The shader uses a three-value paint palette with modest real shadow response. The atlas uses alpha discard rather than blended transparency. Geometry casts real shadows.

### Export contract

UV0 stores the card corner; UV1/Godot UV2 stores physical width and height after Blender's V flip. `BrushData` is explicitly exported as named `COLOR_0`: red selects the atlas tile, green gives a restrained local shading bias. The named export is necessary because the portable export materials do not themselves read that attribute.

Every custom-data layer is allocated before writing UVs/colors. Layer access is then by name, with read-back assertions before export. `tools/check_foliage_glb.py` independently checks the exported streams and 3D anchor extents. The runtime capture script checks every imported card triangle to confirm its corners reconstruct the same center. These check actual data, not only the placement formulas.

## Reproduce

With Blender 5.2.1 and Godot 4.7.1 available on the desktop:

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/build_anime_foliage.py
python tools/check_foliage_glb.py godot/assets/anime/courtyard_anime.glb
godot --headless --audio-driver Dummy --path godot --editor --import
godot --path godot --scene res://courtyard_anime.tscn
```

The authoring source is saved to `authoring/courtyard_anime.blend`, outside the Godot import directory. The atlas is packed into that file. Runtime assets go to `godot/assets/anime/`.

The Blender source retains editable geometry and an atlas material, but **the live per-brush camera-facing transform is implemented in Godot**, not in Blender's material preview. Blender appearance is not certified pixel-equivalent to the runtime shader.

`.github/workflows/anime-foliage-review.yml` builds the asset and requests 20 actual Godot PNGs: four matched before/after scene views, followed by twelve isolated-tree views at 30-degree intervals. It preserves all import/capture diagnostics and the original source hashes. The previous baseline image is never overwritten.

## Boundaries

No AI/runtime service dependency, wind, LOD transition system, botanical specification, species-size metadata, or Android performance approval is included. The rendering style is art-directed, not physical leaf scattering. The fixed shader sun direction currently matches the courtyard study, not an editable time-of-day system.

The original scene import/shutdown problems remain separate from artistic acceptance. A set of produced PNGs is not proof of a clean application lifecycle, and a green source-test suite is not visual approval. Consult the run's `runner-report.json`, `capture.log`, imported mesh check, and actual images together.
