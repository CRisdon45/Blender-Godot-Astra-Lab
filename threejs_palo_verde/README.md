# Three.js Desert Museum Palo Verde — clean-sheet LOD0 study

This is an isolated Perspective renderer experiment. It is **not** a port of the Godot plant mesh.

## Visual target

- Desert Museum palo verde reads immediately from silhouette and structure.
- Low, green multi-leader trunk; open asymmetrical vase crown; deliberate negative spaces.
- Fine grouped foliage sprays rather than leaf noise or large billboard clouds.
- Broad illustrated tonal groups driven by proxy normals, height and controlled variation.
- Yellow bloom pulse is a separate sparse layer.
- Freely movable perspective camera.

## Rendering architecture

The study uses Three.js `WebGPURenderer` and TSL node materials. The renderer prefers WebGPU and can fall back to WebGL 2. Geometry is created directly as `BufferGeometry`; Blender and GLB import are not in the iteration loop.

The tree currently renders as four components: restrained branch outline, green wood, merged opaque foliage-brush geometry, and bloom geometry. Foliage brushes are fixed in 3D, not whole-crown billboards. LOD1/LOD2 are intentionally out of scope.

## Run

Serve this directory over HTTP and open `index.html`. Example:

```bash
python3 -m http.server 8000
```

Then browse to `http://localhost:8000/`.

The browser study uses a pinned Three.js CDN import map for zero-install review. A production Android/WebView build should bundle the pinned package locally rather than depend on a CDN.

## Non-claims

This is not yet art-approved, Android-device-tested, calendar-growth-calibrated, or a final decision to replace Godot. The point is to determine how close a bespoke Three.js renderer can get to the intended Perspective look and how quickly it can be iterated.
