# res://scripts/enemies/EnemyOneEye.gd
extends RefCounted
class_name EnemyOneEyeData

static func data() -> Dictionary:
	return {
		"id": "one_eye",
		"display_name": "One-Eye",
		"max_levels": 5,
		"levels": {
			1: "One-Eye 1: reads patterns and punishes repeats.",
			2: "One-Eye 2: stronger counters—bait and punish.",
			3: "One-Eye 3: mid-game spike; tempo matters a lot.",
			4: "One-Eye 4: control phase—debuffs + shutdown turns.",
			5: "One-Eye 5: final duel—every choice is life or death."
		},
		"scene_path": "res://scenes/enemies/OneEyeBattle.tscn",
		"unlocked_by_default": true
	}
