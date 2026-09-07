# Three.js Desert Museum Palo Verde — anime LOD0 status

Current branch: `work/threejs-palo-verde-gold`

## Scope

This workstream is deliberately **LOD0 only**. LOD1 and LOD2 are deferred until the primary art language is accepted. Nothing here is Galaxy Tab S10 FE performance certification and nothing is merged to `main`.

## Current representation candidate

The strongest current Three.js representation is:

1. deterministic low green multi-leader / scaffold geometry;
2. broad painted foliage clusters attached to real branch curves;
3. each foliage cluster built from several small local planes distributed in the 3D crown, never one whole-tree billboard;
4. an original procedural four-tile foliage atlas used for painted cluster silhouettes and tonal breakup;
5. bent/proxy normals so local planes shade as coherent canopy volume rather than independent cards;
6. very limited fine accents and bloom;
7. selective trunk-only / primary-structure ink;
8. a deliberately painted soft contact shadow instead of detailed realtime foliage-shadow projection;
9. Three.js `WebGPURenderer` with TSL materials and WebGL2 fallback for the Chromium review path.

The current experimental page variants are retained side-by-side rather than overwritten so failed art directions remain inspectable.

## Recipe architecture

`threejs_palo_verde/src/recipes.js` is the semantic/art contract. It contains:

- `perspective-plant-style/1` shared style schema;
- `perspective-plant-species/1` species schema;
- `northstar_anime_01` style profile;
- `desert_museum_palo_verde` recipe;
- `texas_sage_generic` recipe, intentionally with cultivar unspecified.

The renderer should consume these recipes rather than burying species truth in rendering code. Growth values remain illustrative installed-to-mature interpolation, not calendar-age prediction.

## Why this representation survived

Several alternatives were actually rendered and rejected:

- **Detailed procedural sprigs / micro-twigs:** botanically interesting but read as a stylized 3D model rather than anime background art.
- **Large flat canopy cards:** moved toward shape design but looked like low-poly/cel plates.
- **Opaque volumetric puffs:** preserved volume but became CG beads / blobs.
- **Arbitrary global canopy regions:** created visually detached floating foliage islands without believable structural attachment.
- **Dense foliage distributed uniformly along many branches:** filled the tree but made the crown stripe along radial spokes.

The painted-atlas + bent-normal approach is the only current method that combines full crown parallax, illustrator-like foliage shape language, restrained geometry, and believable branch attachment.

## Current art problem

The renderer technique is no longer the main unknown. Remaining work is art direction:

- balance foliage mass against the open Desert Museum silhouette;
- terminate major branches inside foliage rather than exposing long spokes;
- make upper/mid/lower canopy regions overlap naturally without closing all sky windows;
- coordinate painted shadow/midtone/highlight regions so they read as one illustration;
- keep green wood visible but subordinate;
- preserve a few elegant negative spaces instead of many accidental holes;
- keep bloom a seasonal accent, never visual confetti.

`painted.html` is an isolated A/B page where the exact same dense branch-attached geometry uses a stronger painted-tone atlas. This exists specifically to test whether the remaining anime gap is primarily texture/paint language rather than plant geometry.

## Evidence boundary

The GitHub workflows and local clean Chromium verification render hero, side, low, elevated, and reverse 1280×800 views. Runtime reports assert LOD0 recipe identity, branch/canopy metrics, triangle hard caps, and successful browser execution.

These are not Android GPU, sustained-frame-rate, thermal, stylus, or production-scene measurements. Art remains explicitly unapproved until the actual multi-angle frames meet the intended Northstar/anime background bar.

## Non-goals for now

- no LOD1/LOD2 work;
- no new species generator until Palo Verde art language is stable;
- no merge to `main`;
- no physically realistic bark/leaf/PBR pass;
- no runtime AI;
- no claim that browser/SwiftShader performance predicts tablet performance.
