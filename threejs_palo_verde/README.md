# Three.js plant renderer — anime-first recipe study

This branch is an isolated Perspective experiment. It is not a port of the Godot plant mesh and it is not a decision to replace Godot yet.

## Current art rule

**Illustrated massing first, species read second, literal micro-detail last.**

The Desert Museum Palo Verde now combines:

1. low green multi-leader structural gesture;
2. large opaque painted canopy masses carrying composition;
3. medium breakup/bridge masses preserving an airy vase silhouette;
4. sparse compound pinna sprays used as species-signature accents;
5. restrained yellow bloom;
6. three-tone Northstar-anime shading with selective major-branch ink only.

The visible foliage masses are fixed 3D geometry, not whole-tree billboards and not alpha-cutout clouds. LOD1/LOD2 are intentionally out of scope.

## Recipe architecture

`src/recipes.js` owns the semantic/art contract. The renderer consumes it rather than hiding species truth in generator constants.

Each recipe defines:

- identity / species signature;
- illustrative installed-to-mature envelope;
- category-specific structural grammar;
- canopy openness and mass hierarchy;
- fine accent and bloom rules;
- three-tone material palettes;
- shared style profile;
- an LOD0 budget boundary.

Two recipes exist immediately:

- `desert_museum_palo_verde` — airy vase tree;
- `texas_sage_generic` — dense woody mound, cultivar intentionally unspecified.

Texas sage is encoded now to make the recipe contract prove it can describe both an open tree and dense shrub; its Three.js generator is the next species implementation after the Palo Verde art language is accepted.

## Shared style profile

`northstar_anime_01` encodes the current whole-project plant style:

- three broad tonal bands;
- strong silhouette / negative-space priority;
- almost no foliage interior outlines;
- selective trunk and major-branch ink;
- soft subordinate ground shadows;
- large → medium → small shape hierarchy;
- very low micro-noise tolerance.

## Runtime

The study uses Three.js `WebGPURenderer` and TSL node materials. It prefers WebGPU and can fall back to WebGL 2. Geometry is created directly as `BufferGeometry`; Blender and GLB import are not part of normal visual iteration.

Serve this directory over HTTP, for example:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000/`.

The development page pins Three.js through a CDN import map for zero-install browser review. A production Android/WebView package would bundle the pinned dependencies locally.

## Evidence boundary

The GitHub workflow renders hero, side, low, elevated, and reverse LOD0 views in Chromium and verifies the runtime recipe report. Those software-browser frames are art evidence only. They are not Galaxy Tab S10 FE performance, thermal, power, or Android-driver certification.

Growth remains illustrative and not calendar-calibrated. No runtime AI service is used.
