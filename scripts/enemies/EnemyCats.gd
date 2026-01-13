# res://scripts/enemies/EnemyCats.gd
extends RefCounted
class_name EnemyCatsData

static func data() -> Dictionary:
	return {
		"id": "cats",
		"display_name": "Cats",
		"max_levels": 5,
		"levels": {
			1: "Cats 1: quick jabs and tricky movement.",
			2: "Cats 2: start chaining turns and forcing awkward positions.",
			3: "Cats 3: counters appear—don’t autopilot attacks.",
			4: "Cats 4: tempo swings hard; plan 2 turns ahead.",
			5: "Cats 5: boss pack behavior—relentless, coordinated pressure."
		},
		"scene_path": "res://scenes/enemies/CatsBattle.tscn",
		"unlocked_by_default": true
	}
