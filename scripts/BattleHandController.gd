# res://scripts/BattleHandController.gd
extends Node
class_name BattleHandController

signal card_clicked(card_view: CardView)
signal card_zoom_requested(card_view: CardView)
signal draw_finished

@export_group("Hand")
@export var hand_layout: HandLayout
@export var card_db: CardDatabase
@export var hand_size: int = 7
@export var draw_pile_node: Control

@export_group("Enemy Hand")
@export var enemy_hand_size: int = 5

@export_group("Debug")
@export var debug_enabled: bool = true

var rng := RandomNumberGenerator.new()
var _animator: BattleCardAnimator = null
var _enemy_hand_ids: Array[String] = []

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[HandController] ", msg)

func _ready() -> void:
	rng.randomize()

	var parent: Node = get_parent()
	if parent != null:
		_animator = parent.get_node_or_null("CardAnimator") as BattleCardAnimator

func setup(db: CardDatabase, layout: HandLayout, draw_pile: Control) -> void:
	card_db = db
	hand_layout = layout
	draw_pile_node = draw_pile

func clear_hand_immediate() -> void:
	if hand_layout == null:
		return
	for c in hand_layout.get_children():
		(c as Node).queue_free()

# -----------------------------
# ✅ Player (Hiro) draw pool MUST be player-only
# -----------------------------
func _get_player_draw_ids() -> Array[String]:
	if card_db == null:
		return []
	# IMPORTANT: this returns GameManager deck/unlocked (player-only)
	return card_db.get_deck_ids()

func _get_real_card_count() -> int:
	if hand_layout == null:
		return 0
	var count: int = 0
	for child in hand_layout.get_children():
		if child is Control and not (child as Control).is_queued_for_deletion():
			count += 1
	return count

func refill_hand_instant() -> void:
	if hand_layout == null or card_db == null:
		return

	while _get_real_card_count() < hand_size:
		var c: Control = _create_player_card_instance()
		if c != null:
			hand_layout.add_child(c)

	hand_layout.request_layout()
	draw_finished.emit()

func refill_hand_animated(animator_ref: BattleCardAnimator) -> void:
	if hand_layout == null or card_db == null:
		return

	var new_cards: Array[Control] = []
	while _get_real_card_count() < hand_size:
		var card: Control = _create_player_card_instance()
		if card != null:
			card.modulate.a = 0.0
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hand_layout.add_child(card)
			new_cards.append(card)

	hand_layout.request_layout()
	await get_tree().process_frame

	var deck_pos: Vector2 = Vector2.ZERO
	if draw_pile_node != null and is_instance_valid(draw_pile_node):
		var r: Rect2 = draw_pile_node.get_global_rect()
		deck_pos = r.position + r.size * 0.5

	var last_tween: Tween = null
	for i in range(new_cards.size()):
		var card2: Control = new_cards[i]
		last_tween = animator_ref.draw_from_deck(card2, deck_pos, float(i) * 0.10)

	if last_tween == null:
		animator_ref.is_animating = false
		draw_finished.emit()
		return

	last_tween.finished.connect(func() -> void:
		animator_ref.is_animating = false
		draw_finished.emit()
	)

# -----------------------------
# ✅ Draw exactly ONE card (player clicks draw pile)
# -----------------------------
func draw_one_to_hand() -> void:
	if hand_layout == null or card_db == null:
		return
	if _get_real_card_count() >= hand_size:
		_dbg("draw_one_to_hand: hand already at %d" % hand_size)
		return

	var c: Control = _create_player_card_instance()
	if c != null:
		hand_layout.add_child(c)

	hand_layout.request_layout()
	draw_finished.emit()

# -----------------------------
# ✅ Hand removal API (UI-only)
# -----------------------------
func remove_card_from_hand(card: Control) -> String:
	if card == null or not is_instance_valid(card):
		return ""

	var id: String = _extract_card_id(card)
	_dbg("remove_card_from_hand id='%s'" % id)

	card.queue_free()
	return id

func discard_random(count: int) -> Array[String]:
	var discarded: Array[String] = []
	if hand_layout == null or count <= 0:
		return discarded

	var valid: Array[Control] = []
	for c in hand_layout.get_children():
		if c is Control and not (c as Control).is_queued_for_deletion():
			valid.append(c as Control)

	for _i in range(count):
		if valid.is_empty():
			break
		var idx: int = rng.randi_range(0, valid.size() - 1)
		var pick: Control = valid[idx]
		valid.remove_at(idx)

		var id: String = _extract_card_id(pick)
		_dbg("discard_random picked id='%s'" % id)
		if id != "":
			discarded.append(id)

		pick.queue_free()

	return discarded

func request_mulligan(discard_count: int, draw_count: int) -> Array[String]:
	var ids := discard_random(discard_count)
	refill_hand_instant()
	return ids

# -----------------------------
# Enemy hand API used by TurnSystem
# -----------------------------
func reset_enemy_hand() -> void:
	_enemy_hand_ids.clear()
	_refill_enemy_hand()

func get_enemy_hand_ids() -> Array[String]:
	return _enemy_hand_ids.duplicate()

func enemy_play_card(card_id: String) -> void:
	var idx: int = _enemy_hand_ids.find(card_id)
	if idx != -1:
		_enemy_hand_ids.remove_at(idx)
	_refill_enemy_hand()


func _refill_enemy_hand() -> void:
	if card_db == null:
		return

	var gm := get_node_or_null("/root/GameManager")

	var enemy_id: String = "chips"
	var level: int = 1

	# ✅ Godot 4: no has_variable(). Use get() then fallback.
	if gm != null:
		var v_enemy := gm.get("current_enemy_id") # may be null if missing
		if v_enemy != null and String(v_enemy) != "":
			enemy_id = String(v_enemy)

		var v_level := gm.get("current_level_index")
		if v_level != null:
			level = int(v_level)

	if enemy_id == "":
		enemy_id = "chips"
	if level <= 0:
		level = 1

	var pool: Array[String] = card_db.get_enemy_deck_ids(enemy_id, level)
	if pool.is_empty():
		_dbg("WARNING: enemy pool empty for %s L%d" % [enemy_id, level])
		return

	while _enemy_hand_ids.size() < enemy_hand_size:
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		_enemy_hand_ids.append(pick)


# -----------------------------
# Internals
# -----------------------------
func _create_player_card_instance() -> Control:
	if card_db == null:
		return null

	var ids: Array[String] = _get_player_draw_ids()
	if ids.is_empty():
		_dbg("WARNING: player draw ids empty (deck/unlocked?)")
		return null

	var pick: String = ids[rng.randi_range(0, ids.size() - 1)]
	var card: Control = card_db.make_card_instance(pick)
	if card == null:
		return null

	var cv: CardView = card as CardView
	if cv != null:
		if not cv.clicked.is_connected(_on_card_clicked):
			cv.clicked.connect(_on_card_clicked)
		if not cv.zoom_requested.is_connected(_on_card_zoom_requested):
			cv.zoom_requested.connect(_on_card_zoom_requested)
		if not cv.hovered.is_connected(_on_card_hovered):
			cv.hovered.connect(_on_card_hovered)

	return card

func _extract_card_id(card: Control) -> String:
	if card == null:
		return ""

	if card.has_method("get_card_id"):
		var v := card.call("get_card_id")
		if typeof(v) == TYPE_STRING and String(v) != "":
			return String(v)

	if card.has_meta("card_id"):
		var m := card.get_meta("card_id")
		if typeof(m) == TYPE_STRING and String(m) != "":
			return String(m)

	if card.has_method("get_data"):
		var data := card.call("get_data")
		if data is Dictionary:
			var d: Dictionary = data as Dictionary
			for key in ["id", "card_id", "key", "cardKey", "name_id"]:
				if d.has(key) and String(d.get(key, "")) != "":
					return String(d.get(key, ""))

			var inner := d.get("card", null)
			if inner is Dictionary:
				var cd: Dictionary = inner as Dictionary
				for key2 in ["id", "card_id", "key"]:
					if cd.has(key2) and String(cd.get(key2, "")) != "":
						return String(cd.get(key2, ""))

	if card.name != "" and not card.name.begins_with("@"):
		return String(card.name)

	return ""

func _on_card_clicked(c: CardView) -> void:
	card_clicked.emit(c)

func _on_card_zoom_requested(c: CardView) -> void:
	card_zoom_requested.emit(c)

func _on_card_hovered(card: CardView, is_hovering: bool) -> void:
	if _animator == null or hand_layout == null:
		return
	_animator.animate_hover_fan(card, is_hovering, hand_layout)
