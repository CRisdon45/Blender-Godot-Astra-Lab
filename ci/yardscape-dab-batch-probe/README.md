# Dab tree batching witness

This renderer-only test keeps the retained dab v2 geometry and three-band hierarchy-value behavior, but bakes the sixteen group transforms into two ArrayMeshes: one opaque foliage mesh and one wood mesh.

The regular tree exposes 33 mesh instances. The candidate targets 2 while retaining the same 6,516 indexed triangles. Local dab pigment coordinates, branch-family direction and role are carried in vertex attributes so one foliage material can reproduce the current value logic and remain responsive to the actual scene sun.

This is an architecture/appearance witness, not a tablet benchmark. The probe compares regular and batched Plan, courtyard, front, reverse and top views and records changed-pixel counts. Any visually meaningful mismatch must be reviewed before adoption.
