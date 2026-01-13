extends Node
class_name EffectEngine

@export_group("Bindings")
@export var movement_controller_path: NodePath = NodePath("../TrackMovementController")

@export_group("Debug")
@export var debug_enabled: bool = true

var movement_controller: Node = null

# Set by BattleUI
var hiro: BattleCombatant = null
var enemy: BattleCombatant = null

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[EffectEngine] ", msg)

func _ready() -> void:
	movement_controller = get_node_or_null(movement_controller_path)
	if movement_controller == null:
		_dbg("WARNING: movement_controller is NULL. Set movement_controller_path in inspector.")

# ✅ Pre-flight check used by BattleUI / TurnSystem
# IMPORTANT: We interpret "can_play" for movement as:
# - TRUE if the mover can move at least 1 legal step in that direction
# - FALSE if they are fully blocked (0 legal steps)
func can_play_card(card_data: Dictionary, from_enemy: bool) -> bool:
	if card_data == null:
		return true

	var effect: Dictionary = card_data.get("effect", {})
	if not (effect is Dictionary):
		return true

	var kind := String(effect.get("kind", ""))

	# Only block movement cards
	if kind != "move":
		return true

	var delta := int(effect.get("delta", 0))
	if delta == 0:
		return true

	var who := String(effect.get("who", ""))
	if who == "":
		who = "enemy" if from_enemy else "hiro"

	if movement_controller == null:
		_dbg("BLOCK move: movement_controller is NULL (cannot validate).")
		return false

	# Preferred: can_move(who, delta) where can_move means "at least 1 step possible"
	if movement_controller.has_method("can_move"):
		var ok := bool(movement_controller.call("can_move", who, delta))
		if not ok:
			_dbg("BLOCK move: can_move(%s, %d) returned false." % [who, delta])
		return ok

	# Alternate
	if movement_controller.has_method("would_move_be_valid"):
		var ok2 := bool(movement_controller.call("would_move_be_valid", who, delta))
		if not ok2:
			_dbg("BLOCK move: would_move_be_valid(%s, %d) returned false." % [who, delta])
		return ok2

	_dbg("WARNING: No can_move/would_move_be_valid on movement_controller. Allowing move by default.")
	return true

func execute_card(card_data: Dictionary, from_enemy: bool) -> void:
	if card_data == null:
		return

	var cid := String(card_data.get("id", ""))
	_dbg("execute_card id='%s' from_enemy=%s" % [cid, str(from_enemy)])

	var effect: Dictionary = card_data.get("effect", {})
	if not (effect is Dictionary):
		effect = {}

	var kind := String(effect.get("kind", ""))
	_dbg("Executing effect kind='%s' from_enemy=%s" % [kind, str(from_enemy)])

	match kind:
		"damage":
			_apply_damage(effect, from_enemy)
		"shield":
			_apply_shield(effect, from_enemy)
		"move":
			_apply_move(effect, from_enemy)
		"status":
			_apply_status(effect, from_enemy)
		"hand_mulligan":
			_dbg("hand_mulligan handled by BattleUI (waiting state).")
		_:
			_dbg("No handler for effect kind='%s'" % kind)

func _apply_damage(effect: Dictionary, from_enemy: bool) -> void:
	var amount := int(effect.get("amount", 0))
	if amount <= 0:
		return

	var target := hiro if from_enemy else enemy
	if target == null:
		_dbg("WARNING: damage target is null.")
		return

	if target.has_method("take_damage"):
		target.call("take_damage", amount)
	else:
		target.hp = max(0, int(target.hp) - amount)

	_dbg("Applied damage: %d" % amount)

func _apply_shield(effect: Dictionary, from_enemy: bool) -> void:
	var amount := int(effect.get("amount", 0))
	if amount <= 0:
		return

	# Shield applies to self: enemy->enemy, player->hiro
	var target: BattleCombatant = enemy if from_enemy else hiro
	if target == null:
		_dbg("WARNING: shield target is null.")
		return

	# ✅ Your BattleCombatant uses gain_shield()
	if target.has_method("gain_shield"):
		target.call("gain_shield", amount)
	else:
		# fallback
		if target is BattleCombatant:
			(target as BattleCombatant).shield = int((target as BattleCombatant).shield) + amount

	_dbg("Applied shield: %d to %s" % [amount, ("enemy" if from_enemy else "hiro")])

func _apply_move(effect: Dictionary, from_enemy: bool) -> void:
	var delta := int(effect.get("delta", 0))
	if delta == 0:
		return

	var who := String(effect.get("who", ""))
	if who == "":
		who = "enemy" if from_enemy else "hiro"

	# ✅ Safety: don't execute if it can't be played at all (0 legal steps)
	if not can_play_card({"effect": effect}, from_enemy):
		_dbg("Move execution blocked (no space): who=%s delta=%d" % [who, delta])
		return

	if movement_controller == null:
		_dbg("WARNING: movement_controller is NULL. Move will NOT occur.")
		return

	# We expect TrackMovementController.try_move to do partial resolution automatically.
	if movement_controller.has_method("try_move"):
		movement_controller.call("try_move", who, delta)
	elif movement_controller.has_method("move"):
		movement_controller.call("move", who, delta)
	else:
		_dbg("WARNING: movement_controller has no try_move/move method.")

func _apply_status(effect: Dictionary, from_enemy: bool) -> void:
	var target_str := String(effect.get("target", ""))
	var status_id := String(effect.get("status_id", ""))
	var amount := int(effect.get("amount", 0))
	var duration := int(effect.get("duration", 0))
	_dbg("Status: target=%s id=%s amount=%d duration=%d" % [target_str, status_id, amount, duration])
