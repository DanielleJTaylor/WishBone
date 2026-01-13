# res://scripts/BattleTurnSystem.gd
extends Node
class_name BattleTurnSystem

signal round_started(round_num: int)
signal turns_changed(hiro_turns: int, enemy_turns: int)
signal enemy_phase_started()
signal enemy_phase_ended()

@export var turns_per_round: int = 2

@export var hand_controller_path: NodePath
@export var effect_engine_path: NodePath
@export var enemy_ai_path: NodePath
@export var card_db_path: NodePath = NodePath("../CardDatabase")

# ✅ NEW: pacing so enemy phase feels like combat
@export_group("Enemy Phase Timing")
@export var enemy_phase_min_seconds: float = 9.0
@export var min_delay_per_action: float = 0.75

# ✅ NEW: pause before enemy starts acting
@export_group("Enemy Phase Intro Delay")
@export var enemy_intro_delay_min: float = 3.0
@export var enemy_intro_delay_max: float = 5.0

@export_group("Debug")
@export var debug_enabled: bool = true

var round_num: int = 1
var hiro_turns: int = 0
var enemy_turns: int = 0

var _enemy_penalty_next_round: int = 0
var _enemy_is_playing: bool = false

var _hand: BattleHandController
var _fx: EffectEngine
var _ai: SimpleEnemyAI
var _db: CardDatabase

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[TurnSystem] ", msg)

func _ready() -> void:
	_hand = get_node_or_null(hand_controller_path) as BattleHandController
	_fx = get_node_or_null(effect_engine_path) as EffectEngine
	_ai = get_node_or_null(enemy_ai_path) as SimpleEnemyAI
	_db = get_node_or_null(card_db_path) as CardDatabase

func start_battle() -> void:
	round_num = 1
	_enemy_penalty_next_round = 0
	_enemy_is_playing = false
	_start_new_round()

func _start_new_round() -> void:
	hiro_turns = turns_per_round
	enemy_turns = max(0, turns_per_round - _enemy_penalty_next_round)
	_enemy_penalty_next_round = 0

	_dbg("=== ROUND %d START === hiro_turns=%d enemy_turns=%d" % [round_num, hiro_turns, enemy_turns])
	round_started.emit(round_num)
	turns_changed.emit(hiro_turns, enemy_turns)

func can_play() -> bool:
	return hiro_turns > 0 and not _enemy_is_playing

func spend_turn() -> void:
	var before := hiro_turns
	hiro_turns = max(0, hiro_turns - 1)
	_dbg("Hiro turn spent: %d -> %d" % [before, hiro_turns])
	turns_changed.emit(hiro_turns, enemy_turns)

func check_round_end() -> bool:
	return hiro_turns <= 0

func advance_round() -> void:
	round_num += 1
	_start_new_round()

func apply_enemy_penalty_next_round(amount: int) -> void:
	_enemy_penalty_next_round += max(0, amount)

# Called after a player card resolves.
func on_player_played_card(is_free: bool) -> void:
	_dbg("on_player_played_card(is_free=%s)" % str(is_free))
	if not is_free:
		spend_turn()
	else:
		_dbg("FREE card: no turn spent.")
	# BattleUI controls the “draw up to 7 before enemy phase” gate.

# BattleUI calls this ONLY after:
# - Hiro has 0 turns
# - Player has drawn up to 7 (or already has 7)
# BattleUI calls this ONLY after:
# - Hiro has 0 turns
# - Player has drawn up to 7 (or already has 7)
func begin_enemy_phase_and_advance_round() -> void:
	# ✅ CRITICAL: block double-start immediately (fixes "Hiro Phase while enemy plays")
	if _enemy_is_playing:
		return
	if not check_round_end():
		_dbg("begin_enemy_phase called but Hiro still has turns.")
		return

	# ✅ Set flag NOW, before deferring (prevents race condition)
	_enemy_is_playing = true
	call_deferred("_run_enemy_phase_async")


func _run_enemy_phase_async() -> void:
	# ✅ Run the phase; only advance the round after phase completes
	await _run_enemy_phase()
	advance_round()


func _run_enemy_phase() -> void:
	# NOTE: _enemy_is_playing is already true here.

	enemy_phase_started.emit()

	var enemy_name := _get_enemy_display_name()
	var turns_start := enemy_turns
	var delay_per_action := _calc_enemy_action_delay(turns_start)
	var track_move := _get_track_move_node()

	_dbg("--- %s PHASE START (enemy_turns=%d) ---" % [enemy_name, enemy_turns])

	if _hand == null or _fx == null or _ai == null or _db == null:
		push_warning("BattleTurnSystem: missing hand/fx/ai/db. Skipping enemy phase.")
		enemy_phase_ended.emit()
		_enemy_is_playing = false
		return

	# ✅ Pause BEFORE enemy does anything (3–5 seconds)
	var lo := max(0.0, enemy_intro_delay_min)
	var hi := max(lo, enemy_intro_delay_max)
	var intro_delay := randf_range(lo, hi)
	_dbg("%s thinking... (intro delay %.2fs)" % [enemy_name, intro_delay])
	await get_tree().create_timer(intro_delay).timeout

	var turns_used := 0
	_dbg("%s starting hand: %s" % [enemy_name, str(_hand.get_enemy_hand_ids())])

	while enemy_turns > 0:
		var hand_ids := _hand.get_enemy_hand_ids()
		if hand_ids.is_empty():
			_dbg("%s has no cards. Ending phase early." % enemy_name)
			break

		# ✅ pacing happens BEFORE the action (not after)
		# (If you want pacing ONLY before the first action, move this out of the loop.)
		await get_tree().create_timer(delay_per_action).timeout

		var chosen_id := _ai.choose_card(hand_ids, _db, track_move)
		if chosen_id == "":
			_dbg("%s AI returned ''. Ending phase." % enemy_name)
			break

		_dbg("%s plays card: %s" % [enemy_name, chosen_id])

		var card_data := _db.get_card_data(chosen_id)
		var effect: Dictionary = card_data.get("effect", {})
		var is_free := bool(effect.get("free", false))

		_hand.enemy_play_card(chosen_id)
		_fx.execute_card(card_data, true)

		if not is_free:
			var before := enemy_turns
			enemy_turns = max(0, enemy_turns - 1)
			turns_used += 1
			_dbg("%s turn spent: %d -> %d" % [enemy_name, before, enemy_turns])
			turns_changed.emit(hiro_turns, enemy_turns)
		else:
			_dbg("%s FREE card: no turn spent." % enemy_name)

	_dbg("--- %s PHASE END --- turns_used=%d/%d remaining=%d ---" % [enemy_name, turns_used, turns_start, enemy_turns])

	enemy_phase_ended.emit()
	_enemy_is_playing = false


func _get_enemy_display_name() -> String:
	var gm := get_node_or_null("/root/GameManager")
	var enemy_id := "chips"

	if gm != null:
		var v := gm.get("current_enemy_id")
		if v != null and String(v) != "":
			enemy_id = String(v)

	if enemy_id == "":
		enemy_id = "chips"
	return enemy_id.capitalize()


func _get_track_move_node() -> Node:
	if _fx != null:
		var tm := _fx.get("movement_controller")
		if tm != null:
			return tm

	var root := get_tree().current_scene
	if root != null:
		var found := root.find_child("TrackMovement", true, false)
		if found != null:
			return found

	return null

func _calc_enemy_action_delay(enemy_turns_start: int) -> float:
	var denom := max(1, enemy_turns_start)
	var per := enemy_phase_min_seconds / float(denom)
	return max(min_delay_per_action, per)
