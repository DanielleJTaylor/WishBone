# res://scripts/enemies/EnemyChips.gd
extends RefCounted
class_name EnemyChipsData

static func data() -> Dictionary:
	return {
		"id": "chips",
		"display_name": "Chips",
		"max_levels": 3,
		"levels": {
			1: "Tutorial 1: learn basic attacks, shield timing, and ending turns cleanly.",
			2: "Tutorial 2: learn conditional cards, accuracy risk, and simple combos.",
			3: "Tutorial 3: learn locking/unlocking levels, reading intent, and finishing strong."
		},
		"scene_path": "res://scenes/enemies/ChipsBattle.tscn",
		"unlocked_by_default": true
	}
