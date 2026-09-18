extends RefCounted
## PUBLIC synthetic display values, not the private model/validation/codec.
## Plan x/y map to world x/-z; elevation is world y. Water level is datum 0.

static func fresh() -> Dictionary:
	return {"schema": "spatial-courtyard-study/1", "datum": "water_level_m", "site": {"id": "site", "width": 10.0, "length": 14.0},
		"pool": {"id": "pool", "x": 1.5, "y": 4.0, "width": 4.0, "length": 7.0, "water_elevation": 0.0, "floor_elevation": -1.5, "shelf_elevation": -0.35, "shelf_length": 1.5, "coping_width": 0.25},
		"deck": {"id": "deck", "elevation": 0.2},
		"bed": {"id": "bed", "x": 7.0, "y": 4.0, "width": 2.5, "length": 8.0, "elevation": 0.45},
		"tree": {"id": "tree-01", "x": 8.25, "y": 8.5, "base_elevation": 0.45, "height": 3.5, "crown_radius": 1.2, "seed": 8125},
		"lamp": {"id": "lamp-01", "x": 6.5, "y": 7.0, "elevation": 2.8},
		"sun": {"id": "sun", "morning": [-48.0, -32.0, 0.0], "afternoon": [-38.0, 125.0, 0.0]}}

