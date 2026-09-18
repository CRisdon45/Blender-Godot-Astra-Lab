# Whole-plan display probe, not the private application

This extends the owner-authorized public renderer/test worker. Application development remains in private Yard-Scape. No main branch or existing courtyard is changed.

## Deliberately limited publication

The five `renderer.*.b64` parts are a base64-encoded XZ-compressed JSON mapping of 27 allowlisted UTF-8 renderer files. They are **public source**, not a secret or a download credential. `source_index.json` lists every path, byte hash and role. The runner verifies each encoded part, the compressed payload and every decoded file before staging it. It writes only allowlisted renderer paths. This packaging preserves exact source bytes without copying private Git history or a broad application archive.

Twenty-five entries are unchanged renderer/control files from the reviewed application snapshot. Two are explicitly adapted: `fixture.gd` supplies read-only synthetic polygons rather than the application's analytic projection; the base `study.gd` omits private session, codec, store and model-observation code. Existing material-rendering and UI methods remain. The eight previously verified leaf dependencies are reused directly from the sibling worker without overrides. The fixed plant records retain the prior synthetic study arrangement, not a customer design.

No customer records, private reference pixels, saved projects, original project.godot, core/application modules, private repository history, credentials, or private download links are included. Artifact retention contains only native PNGs, bounded logs, reports and hashes, never the source payload or environment dumps. The Godot-derived stroke adapter retains the MIT notice in `../yardscape-renderer/THIRD_PARTY_NOTICES.md`. Publishing this test slice does not grant a new blanket license to original owner code.

## What this tests

The actual region, broadleaf and receiving-shade classes and their inherited U/O/B/A/S/W/P/I/G/V/C input paths run over the synthetic display adapter. Matched whole-plan/detail views test shade placement, unchanged leaf alpha, unchanged pixels outside leaf coverage, pool-interior invariance, predecessor equivalence, geometry/material/context reuse, Technical mode, light/view returns, cache rebuilding and guarded export. The original 56-check component probe runs separately and unchanged before this new test.

This is not the six original full-application suites. Rounded polygon tessellation is a new fixed display approximation, not proof of the private analytic geometry kernel, dimensional editing, save/load, shared Plan/3D integration, tablet performance or artistic acceptance. Images are actual native Godot outputs, not a composited frozen screenshot background. No Northstar concept image is used by the renderer.

Native execution is restricted to Linux GitHub Actions, using the unchanged checksum-pinned engine and software Compatibility framebuffer. Local Python inspection does not execute Godot.

To inspect decoded source without running Godot, import `run_plan.py` and call `sources()` from a checkout that includes both worker directories. It returns the verified filename-to-bytes map. Changes to original runtime behavior must first be reconciled into the private application, not silently forked in this worker.
