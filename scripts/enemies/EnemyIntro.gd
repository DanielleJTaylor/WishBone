extends RefCounted
class_name EnemyIntroData

static func data() -> Dictionary:
	return {
		"id": "intro",
		"display_name": "Intro",
		"max_levels": 1,
		"levels": {
			1: "A short intro cutscene to set the stage before Hiro’s first real chase."
		},
		"scene_path": "", # handled by LevelDatabase/LevelSelect special-case
		"unlocked_by_default": true
	}
