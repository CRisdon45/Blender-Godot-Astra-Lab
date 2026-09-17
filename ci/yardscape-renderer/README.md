# Public native leaf-renderer test worker

This directory is an owner-authorized, reviewed renderer excerpt and synthetic
component test. It is **not the Yardscape application repository** and is not an
application migration. The full application, editing/persistence code, project
history, customer data and art-reference images remain outside this worker.

## Contents and disclosure boundary

Eight runtime files are copied unchanged from the candidate renderer. Their exact
SHA-256 values are enforced by `source_manifest.json`. The inherited generic plant
and stroke code is retained to avoid changing the component under test. The new
probe creates synthetic records in memory. It does not read customer designs,
load a saved workspace, connect to an MCP server or fetch private repository data.

The public workflow uses a standard Ubuntu worker, an exact checksum-pinned Godot
binary, Compatibility rendering and software OpenGL under Xvfb. It publishes only
component screenshots, the test report, bounded logs and source/output hashes.
No source archive, credentials, signed source URL, history or environment dump is
included in the output artifact. The public source itself is intentionally visible
under the owner's authorization. This publication grants no new blanket license
to the owner's original code. Third-party license terms remain in
`THIRD_PARTY_NOTICES.md`.

## Checks and limits

The probe tests leaf geometry identity, context validation, received shade,
unchanged alpha/gaps, off-state equivalence to the original leaf shader, material
reuse, transform/light round trips, native/batched stroke parity, cache rebuilding,
Technical mode, and synthetic seed/radius cases. The source hash gate runs first.

**This does not execute the six full application scene suites.** It cannot certify
whole-yard integration, shared Plan/3D editing, all historical screenshots, physical
tablet performance, botanical accuracy or artistic acceptance. A passing component
probe is evidence only for its listed tests and recorded worker/engine.

Native execution is restricted by the runner to the authorized Linux GitHub worker.
Local Python source verification is available with:

```sh
python ci/yardscape-renderer/run_probe.py --verify-only
```

Application changes remain in the private application repo. Any necessary fix to
the copied runtime must be reconciled there and have its manifest updated. Do not
silently fork runtime behavior here or change engine/test thresholds to make a
failing proof appear green. The existing courtyard study elsewhere in this public
repository is unrelated and remains unchanged.
