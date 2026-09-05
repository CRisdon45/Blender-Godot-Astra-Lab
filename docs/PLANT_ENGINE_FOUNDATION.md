# Plant Engine Foundation — isolated VM validation

## Implemented foundation

- Versioned recipes for Desert Museum palo verde and generic, natural-form Texas sage.
- Two supported botanical grammars: open-vase tree and basal woody shrub. Other families require a backend; arbitrary settings are rejected rather than ignored.
- Persistent blueprint and branch identities across normalized installed/growing/mature stages. Inactive branches remain explicit in the lifetime graph. Activation is NOT a biological birth year.
- Independent GLB checks, geometry/source parity, content hashes for recipes, models, shaders and atlases, and atomically published runtime catalogs.
- A bounded threaded asset cache, transactional scene preparation, spatial MultiMesh groups, and one active LOD component set per group.
- Camera-projected size selection with hysteresis and a primary-pass triangle target. Impossible targets are reported; plants are not hidden to manufacture a pass.
- Translation and yaw only. Arbitrary scaled instances are not supported by the current fixed-center brush contract.
- A mature design footprint independent of the displayed LOD, runtime diagnostics, and executable engine smoke tests.

## Cloud gate

`.github/workflows/plant-engine-vm-review.yml` builds the actual Blender assets, runs Python tests with baked assets present, imports the Godot project, executes the foundation smoke test, and captures the new foundation scene with the Mobile renderer through software Vulkan/Xvfb.

Reports and screenshots include source/run provenance and are uploaded even after a failed step. Test logs remain unfiltered. Source-only tests are not represented as a successful Godot run. A prior local ZIP's lack of engine execution is superseded only by actual successful run evidence, not by this document.

## Explicit non-claims

This is not a fully general plant engine, continuous on-device botanical simulation, calibrated year-by-year growth predictor, production streaming cache, frame-time/thermal controller, or Android performance certification. The study loads at most 36 assets, retains legacy far-LOD shadow behavior, and its initial uploaded art remains the earlier canopy/atlas artwork. The first VM pass tests runtime behavior before artistic iteration.

Approval flags remain false for art, Android, calendar growth and production. No runtime AI is used. Main, courtyard and water work remain untouched.
