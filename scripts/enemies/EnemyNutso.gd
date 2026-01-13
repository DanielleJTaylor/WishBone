# res://scripts/enemies/EnemyNutso.gd
extends RefCounted
class_name EnemyNutsoData

static func data() -> Dictionary:
	return {
		"id": "nutso",
		"display_name": "Nutso",
		"max_levels": 5,
		"levels": {
			1: "Nutso 1: slow ramp—easy early, scarier later.",
			2: "Nutso 2: buffs come faster; punish stalling.",
			3: "Nutso 3: mid-fight spikes—prepare for swing turns.",
			4: "Nutso 4: heavy pressure; you must end fights sooner.",
			5: "Nutso 5: chaos peak—huge bursts and brutal finishes."
		},
		"scene_path": "res://scenes/enemies/NutsoBattle.tscn",
		"unlocked_by_default": true
	}
