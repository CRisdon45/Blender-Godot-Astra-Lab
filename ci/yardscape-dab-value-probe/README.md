# Hierarchy-coherent dab-tree value probe

This is a bounded material/value experiment on the already retained dab-group tree. It does not change foliage geometry, group transforms, branch structure, scene shadows, water, paving, cameras, source tree data, or engine configuration.

The sixteen existing groups are treated as five three-group branch families plus one leader. Each family receives one small light/mid/dark bias derived from its primary group's crown direction and the actual DirectionalLight3D orientation. Local per-dab vertex-tone variation is deliberately compressed rather than removed. Ordinary Godot Lambert lighting and real scene shadows remain active.

This is an adaptation motivated by research on hierarchy-coherent foliage color regions, not a reproduction of any paper. It does not add camera-facing leaves, implicit density, baked sunlight, alpha cards, screen-space processing, wind, runtime AI, or new plant geometry.

The native probe compares the exact retained dab baseline against this value organization in Plan, front, reverse and top views under Morning and Afternoon. A passing technical probe is not visual acceptance or tablet-performance evidence. If the result reads as sixteen separately colored pom-poms, the grouping hypothesis should be changed instead of adding texture.
