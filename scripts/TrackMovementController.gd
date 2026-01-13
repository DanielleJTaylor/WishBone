# res://scripts/TrackMovementController.gd
# res://scripts/TrackMovementController.gd
extends Node
class_name TrackMovementController

signal moved(who: String, from_tile: int, to_tile: int, requested_delta: int, actual_delta: int)
signal blocked(who: String, at_tile: int, requested_delta: int, reason: String)

@export_group("Wiring")
@export var track_bar_path: NodePath
@export var track_sprites_path: NodePath
@export var hiro_combatant_path: NodePath
@export var enemy_combatant_path: NodePath

@export_group("Rules")
@export var allow_partial_movement: bool = true
@export var skip_zero_tile: bool = true
@export var debug_enabled: bool = true

var track_bar: TrackBar
var track_sprites: TrackSprites
var hiro: BattleCombatant
var enemy: BattleCombatant

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[TrackMove] ", msg)

func _ready() -> void:
	track_bar = get_node_or_null(track_bar_path) as TrackBar
	track_sprites = get_node_or_null(track_sprites_path) as TrackSprites
	hiro = get_node_or_null(hiro_combatant_path) as BattleCombatant
	enemy = get_node_or_null(enemy_combatant_path) as BattleCombatant

	if track_bar == null:
		push_error("TrackMovementController: TrackBar not found. Fix track_bar_path.")
	if track_sprites == null:
		push_error("TrackMovementController: TrackSprites not found. Fix track_sprites_path.")
	if hiro == null:
		push_error("TrackMovementController: Hiro combatant not found. Fix hiro_combatant_path.")
	if enemy == null:
		push_error("TrackMovementController: Enemy combatant not found. Fix enemy_combatant_path.")

	_sync_sprites_from_combatants()

	if hiro != null and not hiro.stats_changed.is_connected(_sync_sprites_from_combatants):
		hiro.stats_changed.connect(_sync_sprites_from_combatants)
	if enemy != null and not enemy.stats_changed.is_connected(_sync_sprites_from_combatants):
		enemy.stats_changed.connect(_sync_sprites_from_combatants)

func can_move(who: String, delta: int) -> bool:
	if delta == 0:
		return true
	if track_bar == null or hiro == null or enemy == null:
		_dbg("can_move: wiring missing (allowing)")
		return true

	var mover := _get_combatant(who)
	var other := _get_other_combatant(who)
	if mover == null or other == null:
		return true

	var pos := int(mover.track_position)
	var other_pos := int(other.track_position)
	var step := 1 if delta > 0 else -1

	var next := _next_pos_skipping_zero(pos, step)

	if not track_bar.has_tile(next):
		return false
	if next == other_pos:
		return false
	return true

func try_move(who: String, delta: int) -> int:
	if delta == 0:
		return 0
	if track_bar == null or hiro == null or enemy == null:
		_dbg("try_move aborted: wiring missing track_bar/hiro/enemy")
		return 0

	var mover: BattleCombatant = _get_combatant(who)
	var other: BattleCombatant = _get_other_combatant(who)
	if mover == null or other == null:
		_dbg("try_move aborted: mover/other null")
		return 0

	var start := int(mover.track_position)
	var other_pos := int(other.track_position)

	var step := 1 if delta > 0 else -1
	var steps_requested := abs(delta)

	_dbg("try_move who=%s delta=%d start=%d other=%d" % [who, delta, start, other_pos])

	var pos := start
	var moved_steps := 0

	for _i in range(steps_requested):
		var next := _next_pos_skipping_zero(pos, step)

		if not track_bar.has_tile(next):
			_dbg("%s blocked by bounds at %d -> %d" % [who, pos, next])
			break

		if next == other_pos:
			_dbg("%s blocked by opponent at %d -> %d (other at %d)" % [who, pos, next, other_pos])
			break

		pos = next
		moved_steps += 1

	if moved_steps == 0:
		var reason := "blocked"
		var first_next := _next_pos_skipping_zero(start, step)
		if not track_bar.has_tile(first_next):
			reason = "bounds"
		elif first_next == other_pos:
			reason = "occupied"

		blocked.emit(who, start, delta, reason)
		_dbg("blocked.emit who=%s at=%d delta=%d reason=%s" % [who, start, delta, reason])
		return 0

	var actual_delta_steps := moved_steps * step
	mover.track_position = pos

	_sync_sprites_from_combatants()

	moved.emit(who, start, pos, delta, actual_delta_steps)
	_dbg("moved.emit who=%s %d->%d requested=%d actual_steps=%d" % [who, start, pos, delta, actual_delta_steps])

	return actual_delta_steps

# Stumble = backward from character perspective:
# Hiro backward = LEFT (-)
# Enemy backward = RIGHT (+)
func stumble(who: String, steps: int = 1) -> int:
	var delta: int
	if who.to_lower() == "hiro":
		delta = -abs(steps)
	else:
		delta = +abs(steps)
	return try_move(who, delta)

func get_min_tile() -> int:
	return track_bar.get_min_tile_index() if track_bar != null else 0

func get_max_tile() -> int:
	return track_bar.get_max_tile_index() if track_bar != null else 0

func check_win_lose() -> String:
	if track_bar == null or hiro == null or enemy == null:
		return ""
	var min_i := track_bar.get_min_tile_index()
	var max_i := track_bar.get_max_tile_index()

	if int(hiro.track_position) >= max_i:
		return "hiro_win"
	if int(hiro.track_position) <= min_i:
		return "hiro_lose"
	return ""

func _next_pos_skipping_zero(current: int, step: int) -> int:
	var n := current + step
	if skip_zero_tile and n == 0:
		n += step
	return n

func _get_combatant(who: String) -> BattleCombatant:
	return hiro if who.to_lower() == "hiro" else enemy

func _get_other_combatant(who: String) -> BattleCombatant:
	return enemy if who.to_lower() == "hiro" else hiro

func _sync_sprites_from_combatants() -> void:
	if track_sprites == null or hiro == null or enemy == null:
		return

	# enforce: nobody sits on 0
	if skip_zero_tile:
		if int(hiro.track_position) == 0:
			hiro.track_position = -1
		if int(enemy.track_position) == 0:
			enemy.track_position = 1

	track_sprites.hiro_tile = int(hiro.track_position)
	track_sprites.enemy_tile = int(enemy.track_position)
	track_sprites.call_deferred("_update_positions")
