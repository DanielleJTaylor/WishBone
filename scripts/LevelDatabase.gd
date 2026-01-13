extends RefCounted
class_name LevelDatabase

# -------------------------
# Scene routes
# -------------------------
const SCENE_TITLE := "res://scenes/Title.tscn"
const SCENE_INTRO_CUTSCENE := "res://scenes/IntroCutscene.tscn"
const SCENE_BATTLE := "res://scenes/BattleScene.tscn"

# -------------------------
# Enemy IDs (used everywhere)
# -------------------------
const ENEMY_INTRO := "intro"
const ENEMY_CHIPS := "chips"
const ENEMY_RAVEN := "raven"
const ENEMY_CATS := "cats"
const ENEMY_NUTSO := "nutso"
const ENEMY_TOAD := "toad"
const ENEMY_RATSY := "ratsy"
const ENEMY_ONE_EYE := "one_eye"

# -------------------------
# Load enemy scripts (data providers)
# -------------------------
const ENEMY_INTRO_DATA := preload("res://scripts/enemies/EnemyIntro.gd")
const ENEMY_CHIPS_DATA := preload("res://scripts/enemies/EnemyChips.gd")
const ENEMY_RAVEN_DATA := preload("res://scripts/enemies/EnemyRaven.gd")
const ENEMY_CATS_DATA := preload("res://scripts/enemies/EnemyCats.gd")
const ENEMY_NUTSO_DATA := preload("res://scripts/enemies/EnemyNutso.gd")
const ENEMY_TOAD_DATA := preload("res://scripts/enemies/EnemyToad.gd")
const ENEMY_RATSY_DATA := preload("res://scripts/enemies/EnemyRatsy.gd")
const ENEMY_ONE_EYE_DATA := preload("res://scripts/enemies/EnemyOneEye.gd")

# Optional: stable ordering for UI
const ENEMY_ORDER := [
	ENEMY_INTRO,
	ENEMY_CHIPS,
	ENEMY_RAVEN,
	ENEMY_CATS,
	ENEMY_NUTSO,
	ENEMY_TOAD,
	ENEMY_RATSY,
	ENEMY_ONE_EYE,
]

# enemy_id -> data dict
var _enemy_map: Dictionary = {}
var _built: bool = false


func _ensure_built() -> void:
	if _built:
		return
	_build_enemy_map()
	_built = true


func _build_enemy_map() -> void:
	_enemy_map.clear()

	_register_enemy(ENEMY_INTRO_DATA)
	_register_enemy(ENEMY_CHIPS_DATA)
	_register_enemy(ENEMY_RAVEN_DATA)
	_register_enemy(ENEMY_CATS_DATA)
	_register_enemy(ENEMY_NUTSO_DATA)
	_register_enemy(ENEMY_TOAD_DATA)
	_register_enemy(ENEMY_RATSY_DATA)
	_register_enemy(ENEMY_ONE_EYE_DATA)


func _register_enemy(script_ref: Script) -> void:
	if script_ref == null:
		return

	# Each enemy script has: static func data() -> Dictionary
	var d: Dictionary = script_ref.call("data")
	if not d.has("id"):
		push_warning("Enemy data missing 'id' in %s" % [script_ref.resource_path])
		return

	_enemy_map[String(d["id"])] = d


func _get_enemy(enemy_id: String) -> Dictionary:
	_ensure_built()
	if _enemy_map.has(enemy_id):
		return _enemy_map[enemy_id]
	return {}


# -------------------------
# Public API used by LevelSelect / BattleScene
# -------------------------
func get_enemy_data(enemy_id: String) -> Dictionary:
	# Useful for BattleScene to pull extra fields later
	return _get_enemy(enemy_id)


func is_enemy_unlocked(enemy_id: String) -> bool:
	var d := _get_enemy(enemy_id)
	if d.is_empty():
		return false
	return bool(d.get("unlocked_by_default", true))


func get_enemy_display_name(enemy_id: String) -> String:
	var d := _get_enemy(enemy_id)
	return String(d.get("display_name", enemy_id))


func get_enemy_max_levels(enemy_id: String) -> int:
	var d := _get_enemy(enemy_id)
	return int(d.get("max_levels", 1))


func get_level_description(enemy_id: String, level_num: int) -> String:
	var d := _get_enemy(enemy_id)
	var levels := d.get("levels", {})
	if typeof(levels) == TYPE_DICTIONARY and (levels as Dictionary).has(level_num):
		return String((levels as Dictionary)[level_num])
	return "No description yet."


func get_all_enemy_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for id in ENEMY_ORDER:
		out.append(id)
	return out
