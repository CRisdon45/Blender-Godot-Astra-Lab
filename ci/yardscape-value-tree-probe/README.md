# Hierarchy-coherent dab-tree value comparison

This is a material/value experiment on the retained dab-group tree. Geometry, group transforms, triangle count, visible mesh count, actual scene lights and real shadows are identical to the baseline. Only the foliage pigment values change.

Each of the sixteen deterministic branch groups gets a bounded target value derived from its retained height and primary/secondary/leader role. The shader blends local per-dab tone toward that group value, preserving a little low-frequency local variation. Godot's ordinary Lambert lighting and shadowing still determine how those pigments are illuminated. No camera-facing behavior, baked sun, extra foliage, alpha, outline, density field, runtime AI or reference image is introduced.

This is inspired by the research principle of organizing foliage color regions through hierarchy, not a reproduction of Akagi et al.'s complete shading-layer framework. If group values look like obvious color blocks or detach from the moving sun, reject or weaken the grouping rather than changing geometry.
