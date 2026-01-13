# res://scripts/enemies/EnemyRaven.gd
extends RefCounted
class_name EnemyRavenData

static func data() -> Dictionary:
	return {
		"id": "raven",
		"display_name": "Raven",
		"max_levels": 5,
		"levels": {
			1: "Raven 1: pokes from range and tests your patience.",
			2: "Raven 2: adds debuffs and accuracy mind-games.",
			3: "Raven 3: burst turns—small mistakes start costing big.",
			4: "Raven 4: chains pressure with fewer safe turns.",
			5: "Raven 5: full predator mode—tight windows, huge punish."
		},
		"scene_path": "res://scenes/enemies/RavenBattle.tscn",
		"unlocked_by_default": true
	}
