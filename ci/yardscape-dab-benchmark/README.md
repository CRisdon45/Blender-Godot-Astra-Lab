# Repeated dab-tree batching benchmark

This is a **relative same-worker architecture benchmark**, not a tablet forecast.

It compares the retained regular hierarchy-value tree (33 visible meshes / 6,516 indexed triangles) with the visually equivalent batched tree (2 visible meshes / 6,516 triangles) at 1, 8, 24 and 32 trees.

Both representations coexist but only the selected condition is visible. Tree positions, camera, directional sun, shadows, material/value logic, viewport and per-tree geometry are fixed. Each count uses alternating regular → batched → batched → regular blocks, with warm-up frames before each block. Godot's measured viewport CPU render time, frame setup time, reported GPU time, wall-frame interval, and visible/shadow render counters are retained.

The benchmark can establish a trend on the pinned Ubuntu/llvmpipe worker. It cannot establish Android GPU behavior, thermal sustainability, stylus responsiveness, memory pressure or target-tablet FPS. Physical-device profiling remains required before a mobile performance claim.
