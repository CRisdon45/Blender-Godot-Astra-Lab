# Direct plant-form Plan projection

This probe is the first direct 2D consumer of plant-form-profile/1 and PlantFormLayout.

The Plan symbol receives only:
- an instance tree seed;
- instance crown radius;
- a validated plant-form profile;
- the pure shared layout functions.

It never instantiates, reads, or inspects a 3D tree or mesh. The runner intentionally stages only plant_form_profiles.gd and plant_form_layout.gd from the shared profile work; the 3D builder is absent.

The current visual witness is deliberately restrained: projected scaffold gestures behind overlapping irregular crown lobes, with family-level light/mid/dark values responding to a supplied sun direction. There are no literal leaves or texture assets.

The test requires Fan-Tex and Desert Museum to use the same 2D renderer while retaining different lobe/path counts, deterministic layout signatures, exact correspondence to PlantFormLayout.plan_lobes(), distinct rendered symbols, reversible sun-value changes, and no semantic layout mutation.
