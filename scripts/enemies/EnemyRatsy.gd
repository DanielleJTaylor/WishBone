# res://scripts/enemies/EnemyRatsy.gd
extends RefCounted
class_name EnemyRatsyData

static func data() -> Dictionary:
	return {
		"id": "ratsy",
		"display_name": "Ratsy",
		"max_levels": 5,
		"levels": {
			1: "Ratsy 1: swarm starts—lots of small hits.",
			2: "Ratsy 2: adds hand disruption; your plan gets scrambled.",
			3: "Ratsy 3: faster swarms + stronger debuffs.",
			4: "Ratsy 4: punishes recovery—stabilizing is harder.",
			5: "Ratsy 5: relentless peak—survive the storm and strike back."
		},
		"scene_path": "res://scenes/enemies/RatsyBattle.tscn",
		"unlocked_by_default": true
	}
