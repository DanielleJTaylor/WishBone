# res://scripts/enemies/EnemyToad.gd
extends RefCounted
class_name EnemyToadData

static func data() -> Dictionary:
	return {
		"id": "toad",
		"display_name": "Toad",
		"max_levels": 5,
		"levels": {
			1: "Toad 1: tank basics—shields and steady hits.",
			2: "Toad 2: adds reflection/counter tricks—hit carefully.",
			3: "Toad 3: bigger shields, longer fights.",
			4: "Toad 4: fortress loops—break the wall or get drained.",
			5: "Toad 5: final tank test—one mistake snowballs."
		},
		"scene_path": "res://scenes/enemies/ToadBattle.tscn",
		"unlocked_by_default": true
	}
