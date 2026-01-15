extends Node
class_name EffectEngine

@export_group("Bindings")
@export var movement_controller_path: NodePath = NodePath("../TrackMovementController")

# NEW: a node that owns hand/deck/discard (BattleUI, TurnSystem, DeckRuntime, etc.)
# This node must implement a few methods (see _get_hand_api()).
@export var hand_api_path: NodePath = NodePath("../BattleUI")

@export_group("Debug")
@export var debug_enabled: bool = true

var movement_controller: Node = null
var hand_api: Node = null

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

	hand_api = get_node_or_null(hand_api_path)
	if hand_api == null:
		_dbg("WARNING: hand_api is NULL. Set hand_api_path in inspector (BattleUI/DeckRuntime).")

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

		# ✅ NEW
		"heal":
			_apply_heal(effect, from_enemy)

		# ✅ UPDATED: Engine can execute this now (calls BattleUI/deck runtime)
		"hand_mulligan":
			_apply_hand_mulligan(effect, from_enemy)

		_:
			_dbg("No handler for effect kind='%s'" % kind)

# ----------------------------
# DAMAGE / SHIELD / MOVE / STATUS
# ----------------------------
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

	var target: BattleCombatant = enemy if from_enemy else hiro
	if target == null:
		_dbg("WARNING: shield target is null.")
		return

	if target.has_method("gain_shield"):
		target.call("gain_shield", amount)
	else:
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

	if not can_play_card({"effect": effect}, from_enemy):
		_dbg("Move execution blocked (no space): who=%s delta=%d" % [who, delta])
		return

	if movement_controller == null:
		_dbg("WARNING: movement_controller is NULL. Move will NOT occur.")
		return

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

	# You can wire this to your combatant status system later.
	# For now it remains debug-only.

# ----------------------------
# ✅ NEW: HEAL
# ----------------------------
func _apply_heal(effect: Dictionary, from_enemy: bool) -> void:
	var amount := int(effect.get("amount", 0))
	if amount <= 0:
		return

	# Heal applies to self
	var target: BattleCombatant = enemy if from_enemy else hiro
	if target == null:
		_dbg("WARNING: heal target is null.")
		return

	# Preferred: heal(amount)
	if target.has_method("heal"):
		target.call("heal", amount)
	else:
		# fallback: hp clamp if max_hp exists
		var hp_now := int(target.hp)
		var hp_new := hp_now + amount
		if target.has_variable("max_hp"):
			hp_new = min(hp_new, int(target.max_hp))
		target.hp = hp_new

	_dbg("Applied heal: %d to %s" % [amount, ("enemy" if from_enemy else "hiro")])

# ----------------------------
# ✅ UPDATED: HAND MULLIGAN (Drop It!)
# Drop It! now:
# - discard up to 2
# - draw to 7
# - uses a turn (turn use is outside this engine)
# ----------------------------
func _apply_hand_mulligan(effect: Dictionary, from_enemy: bool) -> void:
	# If enemy ever uses hand mulligan, you can support it later.
	# For now, we only execute for player side.
	if from_enemy:
		_dbg("hand_mulligan ignored for enemy (not implemented).")
		return

	var api := _get_hand_api()
	if api == null:
		_dbg("hand_mulligan FAILED: No valid hand_api methods found. Set hand_api_path and implement required API.")
		return

	var discard_up_to := int(effect.get("discard_up_to", effect.get("discard_count", 0)))
	var draw_to := int(effect.get("draw_to", 7))

	_dbg("hand_mulligan: discard_up_to=%d draw_to=%d" % [discard_up_to, draw_to])

	# We support two styles:
	# A) UI-driven discard choice: api.begin_discard_choice(max, then_callback)
	# B) Simple auto-discard (random / last) if no UI exists

	# Prefer UI selection if available
	if api.has_method("begin_discard_choice"):
		# Expected signature:
		# begin_discard_choice(max_discard: int, on_done: Callable) -> void
		# and inside callback you call draw_to_hand_size(draw_to)
		var cb := func(_selected_ids := []):
			# after discard UI resolves, draw to target hand size
			_call_draw_to(api, draw_to)
		api.call("begin_discard_choice", discard_up_to, cb)
		return

	# Otherwise: auto-discard up to N then draw_to
	_auto_discard(api, discard_up_to)
	_call_draw_to(api, draw_to)

func _auto_discard(api: Node, discard_up_to: int) -> void:
	if discard_up_to <= 0:
		return

	# We need a way to discard a card from hand.
	# Supported methods:
	# - discard_random_from_hand()
	# - discard_from_hand_index(i)
	# - get_hand_ids() + discard_card_id(id)
	if api.has_method("discard_random_from_hand"):
		for i in range(discard_up_to):
			api.call("discard_random_from_hand")
		_dbg("hand_mulligan: auto-discard used discard_random_from_hand x%d" % discard_up_to)
		return

	if api.has_method("get_hand_size") and api.has_method("discard_from_hand_index"):
		for i in range(discard_up_to):
			var sz := int(api.call("get_hand_size"))
			if sz <= 0:
				break
			# discard last (simple)
			api.call("discard_from_hand_index", sz - 1)
		_dbg("hand_mulligan: auto-discard used discard_from_hand_index")
		return

	if api.has_method("get_hand_ids") and api.has_method("discard_card_id"):
		var ids: Array = api.call("get_hand_ids")
		var n := min(discard_up_to, ids.size())
		for i in range(n):
			api.call("discard_card_id", String(ids[ids.size() - 1 - i]))
		_dbg("hand_mulligan: auto-discard used get_hand_ids + discard_card_id")
		return

	_dbg("hand_mulligan: auto-discard FAILED (no discard methods on hand_api).")

func _call_draw_to(api: Node, draw_to: int) -> void:
	# Supported methods:
	# - draw_to_hand_size(target:int)
	# - draw_to_7() (fallback)
	# - draw_cards(n) with get_hand_size()
	if api.has_method("draw_to_hand_size"):
		api.call("draw_to_hand_size", draw_to)
		_dbg("hand_mulligan: called draw_to_hand_size(%d)" % draw_to)
		return

	if draw_to == 7 and api.has_method("draw_to_7"):
		api.call("draw_to_7")
		_dbg("hand_mulligan: called draw_to_7()")
		return

	if api.has_method("draw_cards") and api.has_method("get_hand_size"):
		var sz := int(api.call("get_hand_size"))
		var n := max(0, draw_to - sz)
		if n > 0:
			api.call("draw_cards", n)
		_dbg("hand_mulligan: called draw_cards(%d) to reach %d" % [n, draw_to])
		return

	_dbg("hand_mulligan: draw FAILED (no draw methods on hand_api).")

func _get_hand_api() -> Node:
	# direct node set in inspector
	if hand_api != null:
		return hand_api

	# try locate common nodes by path if someone moved it
	var try_node := get_node_or_null(hand_api_path)
	if try_node != null:
		hand_api = try_node
		return hand_api

	return null
