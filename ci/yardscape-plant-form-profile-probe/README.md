# Plant form profile equivalence

This bounded test extracts the retained Fan-Tex Ash v2 morphology from species-specific code into a normalized, validated data profile consumed by one generic two-mesh dab-tree builder.

The profile contains presentation morphology only: normalized family angles, reaches, crown levels, group scales/tilts, inner-crown placement, leader placement, trunk/scaffold control parameters, seed offsets and bark display color. It deliberately excludes mature dimensions, growth rate, water use, phenology, maintenance and every other horticultural fact that belongs in the future plant compendium.

The acceptance requirement is strict: the profile-driven Fan-Tex must reproduce the retained hard-coded v2 mesh arrays exactly, not merely look similar. Front, side, top and Plan images are also required to match byte-for-byte, while actual scene-sun response and deterministic regeneration must remain.

Proving this equivalence allows additional species to become data profiles instead of one renderer class per plant, and gives 2D/3D a shared normalized form vocabulary.
