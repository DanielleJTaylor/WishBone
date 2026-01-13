# res://scripts/BattleUI.gd
extends Control
class_name BattleUI

@export_group("Debug")
@export var debug_enabled: bool = true
@export var debug_print_full_card_data: bool = true

@export_group("Dependencies")
@export var CardScene: PackedScene
@export var card_db: CardDatabase

@export_group("Scene References")
@export var hand_layout: HandLayout
@export var play_button: Button
@export var round_label_path: NodePath = NodePath("UILayer/RoundLabel")

@export_group("Action Prompt")
@export var action_prompt_path: NodePath = NodePath("UILayer/Bottom Bar/ActionPromptLabel")

@export_group("Zoom")
@export var zoom_controller: ZoomController

@export_group("Draw Pile")
@export var draw_button_path: NodePath = NodePath("UILayer/Bottom Bar/CardArea/DrawPile/BackofCard/DrawButton")
@export var draw_pile_visual_path: NodePath = NodePath("UILayer/Bottom Bar/CardArea/DrawPile/BackofCard")

@export_group("Discard UI")
@export var discard_pile_path: NodePath = NodePath("UILayer/Bottom Bar/CardArea/DiscardPile")

@export_group("Combatants")
@export var hiro_combatant_path: NodePath = NodePath("UILayer/Middle Track/Sprites/Hiro")
@export var enemy_combatant_path: NodePath = NodePath("UILayer/Middle Track/Sprites/Enemy")

@export_group("Enemy Identity")
@export var enemy_display_name: String = "Chips"

const FALLBACK_HITBUTTON_PATH: NodePath = NodePath("UILayer/Bottom Bar/CardArea/Tray/PlayButtonWrapper/CardPlayButton/HitButton")

@onready var panels: BattlePanels = get_node_or_null("Panels") as BattlePanels
@onready var turn_system: BattleTurnSystem = get_node_or_null("TurnSystem") as BattleTurnSystem
@onready var hand_controller: BattleHandController = get_node_or_null("HandController") as BattleHandController
@onready var animator: BattleCardAnimator = get_node_or_null("CardAnimator") as BattleCardAnimator
@onready var fx: EffectEngine = get_node_or_null("EffectEngine") as EffectEngine

var selected_card: CardView = null

var draw_button: Button = null
var draw_pile_visual: Control = null

var _discard_pile_widget: Node = null
var _round_label: Control = null
var _action_prompt: Control = null

var _hiro: BattleCombatant = null
var _enemy: BattleCombatant = null
var _enemy_phase_active: bool = false

# ✅ When Hiro has 0 turns, we block enemy phase until hand == 7
var _must_refill_before_enemy: bool = false

# ✅ Drop It waiting state (NO drag-drop)
var _waiting_for_drop_it: bool = false
var _drop_it_need_discards: int = 0
var _drop_it_done_discards: int = 0
var _drop_it_need_draws: int = 0


func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[BattleUI] ", msg)


func _ready() -> void:
	_wire_subsystems()
	start_battle()


func _wire_subsystems() -> void:
	if turn_system == null:
		push_error("BattleUI: Missing TurnSystem node.")
		return
	if hand_controller == null:
		push_error("BattleUI: Missing HandController node.")
		return
	if animator == null:
		push_error("BattleUI: Missing CardAnimator node.")
		return
	if card_db == null:
		push_error("BattleUI: card_db is missing.")
		return
	if CardScene == null:
		push_error("BattleUI: CardScene is missing.")
		return
	if hand_layout == null:
		push_error("BattleUI: hand_layout is missing.")
		return

	_hiro = get_node_or_null(hiro_combatant_path) as BattleCombatant
	_enemy = get_node_or_null(enemy_combatant_path) as BattleCombatant

	if fx != null:
		fx.hiro = _hiro
		fx.enemy = _enemy

	card_db.set_card_scene(CardScene)

	draw_button = get_node_or_null(draw_button_path) as Button
	draw_pile_visual = get_node_or_null(draw_pile_visual_path) as Control

	if draw_button != null:
		draw_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not draw_button.pressed.is_connected(_on_draw_pressed):
			draw_button.pressed.connect(_on_draw_pressed)
	else:
		_dbg("WARNING: DrawButton not found at %s" % str(draw_button_path))

	if draw_pile_visual == null:
		_dbg("WARNING: Draw pile visual not found at %s (draw anim deck_pos may be wrong)" % str(draw_pile_visual_path))

	hand_controller.setup(card_db, hand_layout, draw_pile_visual)

	if not hand_controller.card_clicked.is_connected(_on_card_clicked):
		hand_controller.card_clicked.connect(_on_card_clicked)
	if not hand_controller.card_zoom_requested.is_connected(_on_card_zoom_requested):
		hand_controller.card_zoom_requested.connect(_on_card_zoom_requested)
	if not hand_controller.draw_finished.is_connected(_on_draw_finished):
		hand_controller.draw_finished.connect(_on_draw_finished)

	if turn_system.has_signal("turns_changed") and not turn_system.turns_changed.is_connected(_on_turns_changed):
		turn_system.turns_changed.connect(_on_turns_changed)
	if turn_system.has_signal("round_started") and not turn_system.round_started.is_connected(_on_round_started):
		turn_system.round_started.connect(_on_round_started)
	if turn_system.has_signal("enemy_phase_started") and not turn_system.enemy_phase_started.is_connected(_on_enemy_phase_started):
		turn_system.enemy_phase_started.connect(_on_enemy_phase_started)
	if turn_system.has_signal("enemy_phase_ended") and not turn_system.enemy_phase_ended.is_connected(_on_enemy_phase_ended):
		turn_system.enemy_phase_ended.connect(_on_enemy_phase_ended)

	if zoom_controller != null:
		zoom_controller.set_card_scene(CardScene)

	_resolve_play_button()
	_resolve_discard_pile()

	_round_label = get_node_or_null(round_label_path) as Control
	if _round_label == null:
		_dbg("WARNING: RoundLabel not found at %s" % str(round_label_path))

	_action_prompt = get_node_or_null(action_prompt_path) as Control
	if _action_prompt == null:
		_dbg("WARNING: ActionPromptLabel not found at %s" % str(action_prompt_path))
	else:
		_action_prompt.visible = false

	if panels != null:
		panels.set_names("Hiro", enemy_display_name)


func _resolve_discard_pile() -> void:
	_discard_pile_widget = get_node_or_null(discard_pile_path)


func _resolve_play_button() -> void:
	if play_button == null:
		var fallback: Node = get_node_or_null(FALLBACK_HITBUTTON_PATH)
		if fallback is Button:
			play_button = fallback as Button
		else:
			push_error("BattleUI: Could not resolve HitButton.")
			return

	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)


func start_battle() -> void:
	selected_card = null
	_enemy_phase_active = false
	_must_refill_before_enemy = false

	_waiting_for_drop_it = false
	_drop_it_need_discards = 0
	_drop_it_done_discards = 0
	_drop_it_need_draws = 0
	_set_action_prompt("", false)

	turn_system.start_battle()
	hand_controller.reset_enemy_hand()

	hand_controller.clear_hand_immediate()
	animator.is_animating = true
	hand_controller.refill_hand_animated(animator)

	_update_all_ui()
	_refresh_ui()


func _on_draw_finished() -> void:
	if animator != null:
		animator.cache_positions(hand_layout)
		animator.is_animating = false
	_update_all_ui()
	_refresh_ui()


func _on_round_started(_rn: int) -> void:
	_enemy_phase_active = false
	_must_refill_before_enemy = false

	_waiting_for_drop_it = false
	_drop_it_need_discards = 0
	_drop_it_done_discards = 0
	_drop_it_need_draws = 0
	_set_action_prompt("", false)

	_update_all_ui()
	_refresh_ui()


func _on_turns_changed(_ht: int, _et: int) -> void:
	_update_all_ui()
	_refresh_ui()


func _on_enemy_phase_started() -> void:
	_enemy_phase_active = true
	_update_all_ui()
	_refresh_ui()


func _on_enemy_phase_ended() -> void:
	_enemy_phase_active = false
	_update_all_ui()
	_refresh_ui()


func _update_round_label() -> void:
	if _round_label == null:
		return

	var rn := int(turn_system.round_num)
	if _enemy_phase_active:
		_set_round_label_text("Round %d: %s Phase" % [rn, enemy_display_name], false)
	else:
		_set_round_label_text("Round %d: Hiro Phase" % rn, true)


func _set_round_label_text(txt: String, is_hiro: bool) -> void:
	if _round_label.has_method("set_text"):
		_round_label.call("set_text", txt)
	elif _round_label is Label:
		(_round_label as Label).text = txt
	elif _round_label is RichTextLabel:
		(_round_label as RichTextLabel).text = txt

	var blue_outline := Color(0.15, 0.35, 0.85, 1.0)
	var font_color := Color(1, 0.85, 0.25, 1.0) if is_hiro else Color(0.85, 0.85, 0.90, 1.0)

	_round_label.add_theme_color_override("font_color", font_color)
	_round_label.add_theme_color_override("font_outline_color", blue_outline)
	_round_label.add_theme_constant_override("outline_size", 6)


func _set_action_prompt(txt: String, visible_now: bool) -> void:
	if _action_prompt == null:
		return

	_action_prompt.visible = visible_now
	if not visible_now:
		return

	if _action_prompt is Label:
		(_action_prompt as Label).text = txt
	elif _action_prompt is RichTextLabel:
		(_action_prompt as RichTextLabel).text = txt
	elif _action_prompt.has_method("set_text"):
		_action_prompt.call("set_text", txt)

	_action_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_action_prompt.add_theme_color_override("font_outline_color", Color(0.10, 0.25, 0.85, 1.0))
	_action_prompt.add_theme_constant_override("outline_size", 6)


func _update_all_ui() -> void:
	_update_round_label()

	if panels != null and _hiro != null and _enemy != null:
		panels.update_all(
			int(turn_system.hiro_turns),
			int(turn_system.enemy_turns),
			int(_hiro.hp), int(_hiro.max_hp),
			int(_enemy.hp), int(_enemy.max_hp)
		)
	elif panels != null:
		panels.update_turns(int(turn_system.hiro_turns), int(turn_system.enemy_turns))


func _refresh_ui() -> void:
	var can_interact: bool = (animator != null and not animator.is_animating)
	var has_sel: bool = (selected_card != null)

	# ✅ Drop It waiting rules:
	# - PLAY discards selected card until required discards are done
	# - then DRAW becomes the final action (handled in _on_draw_pressed)
	if _waiting_for_drop_it:
		if play_button != null:
			var need_more_discards := (_drop_it_done_discards < _drop_it_need_discards)
			play_button.disabled = (not can_interact) or (not has_sel) or (not need_more_discards)
		return

	# Normal rules
	var can_play_turn: bool = (turn_system != null and turn_system.can_play())
	if play_button != null:
		play_button.disabled = (not can_interact) or (not can_play_turn) or (not has_sel)

	if turn_system != null and turn_system.hiro_turns <= 0 and not _enemy_phase_active:
		_must_refill_before_enemy = true

	if _must_refill_before_enemy:
		if play_button != null:
			play_button.disabled = true

		if _hand_count() >= 7:
			_dbg("Refill satisfied (hand=7). Starting enemy phase now.")
			_must_refill_before_enemy = false
			turn_system.begin_enemy_phase_and_advance_round()


func _hand_count() -> int:
	if hand_layout == null:
		return 0
	var count := 0
	for c in hand_layout.get_children():
		if c is Control and not (c as Control).is_queued_for_deletion():
			count += 1
	return count


func _on_draw_pressed() -> void:
	if animator != null and animator.is_animating:
		return
	if _enemy_phase_active:
		return

	# ✅ Drop It: Draw is only allowed after discards are completed
	if _waiting_for_drop_it:
		if _drop_it_done_discards < _drop_it_need_discards:
			_dbg("Drop It: draw blocked until you discard %d card(s)." % _drop_it_need_discards)
			return

		_dbg("Drop It: DrawButton pressed -> drawing %d" % _drop_it_need_draws)
		for i in range(_drop_it_need_draws):
			if _hand_count() >= 7:
				break
			hand_controller.draw_one_to_hand()

		_waiting_for_drop_it = false
		_drop_it_need_discards = 0
		_drop_it_done_discards = 0
		_drop_it_need_draws = 0
		_set_action_prompt("", false)

		await get_tree().process_frame
		if animator != null:
			animator.cache_positions(hand_layout)

		_update_all_ui()
		_refresh_ui()
		return

	# Normal draw
	if _hand_count() >= 7:
		_dbg("Draw blocked: hand already 7.")
		return

	_dbg("DrawButton pressed -> drawing 1 (hand=%d)" % _hand_count())
	hand_controller.draw_one_to_hand()

	await get_tree().process_frame
	if animator != null:
		animator.cache_positions(hand_layout)

	_update_all_ui()
	_refresh_ui()


func _on_card_clicked(card: CardView) -> void:
	if animator != null and animator.is_animating:
		return
	if _enemy_phase_active:
		return
	if _must_refill_before_enemy:
		return

	if selected_card != card:
		if is_instance_valid(selected_card):
			animator.animate_hover_selection(selected_card, false)
		selected_card = card
		animator.animate_hover_selection(card, true)

		var d := card.get_data()
		var cid := ""
		if d is Dictionary:
			cid = String((d as Dictionary).get("id", ""))
		_dbg("Card selected: %s" % cid)
	else:
		animator.animate_hover_selection(selected_card, false)
		_dbg("Card unselected.")
		selected_card = null

	_refresh_ui()


func _on_card_zoom_requested(card: CardView) -> void:
	if animator != null and animator.is_animating:
		return
	if zoom_controller == null:
		return
	if card == null or not is_instance_valid(card):
		return
	zoom_controller.open_zoom(card)


func _on_play_pressed() -> void:
	if animator != null and animator.is_animating:
		return
	if _enemy_phase_active:
		return
	if _must_refill_before_enemy:
		_dbg("Play blocked: must draw back to 7 before enemy phase.")
		return
	if selected_card == null:
		return

	# ✅ Drop It waiting: PLAY means "discard selected"
	if _waiting_for_drop_it:
		_drop_it_discard_selected()
		return

	# Normal play
	if not turn_system.can_play():
		return

	# ✅ BLOCK movement card if no space to move
	var data_check: Dictionary = selected_card.get_data()
	if fx != null and fx.has_method("can_play_card"):
		var ok := bool(fx.call("can_play_card", data_check, false))
		if not ok:
			_dbg("Blocked play: EffectEngine.can_play_card returned false.")
			return

	_play_sequence(selected_card)


func _drop_it_discard_selected() -> void:
	if selected_card == null or not is_instance_valid(selected_card):
		return
	if _drop_it_done_discards >= _drop_it_need_discards:
		return

	var to_discard := selected_card
	selected_card = null

	# Remove from hand
	var discarded_id := hand_controller.remove_card_from_hand(to_discard)
	if discarded_id == "":
		return

	# Add to discard pile widget so overlay/top preview stays correct
	if _discard_pile_widget != null and _discard_pile_widget.has_method("add_discard_id"):
		_discard_pile_widget.call("add_discard_id", discarded_id)

	_drop_it_done_discards += 1
	_dbg("Drop It discard: %s (%d/%d)" % [discarded_id, _drop_it_done_discards, _drop_it_need_discards])

	if _drop_it_done_discards >= _drop_it_need_discards:
		_set_action_prompt("Drop It!: Now click DRAW to draw %d." % _drop_it_need_draws, true)
	else:
		var left := _drop_it_need_discards - _drop_it_done_discards
		_set_action_prompt("Drop It!: Select a card and press PLAY to discard (%d left)." % left, true)

	await get_tree().process_frame
	if animator != null:
		animator.cache_positions(hand_layout)

	_update_all_ui()
	_refresh_ui()


func _play_sequence(card: CardView) -> void:
	if card == null or not is_instance_valid(card):
		return

	var data: Dictionary = card.get_data()
	_dbg("Card played (clicked Play): %s" % String(data.get("id", "")))
	if debug_print_full_card_data:
		_dbg("play data keys=%s" % str(data.keys()))

	selected_card = null
	_refresh_ui()

	animator.animate_play_card(card, func() -> void:
		var played_id: String = hand_controller.remove_card_from_hand(card)
		data["id"] = played_id

		# Add to discard pile
		if _discard_pile_widget != null and _discard_pile_widget.has_method("add_discard_id"):
			_discard_pile_widget.call("add_discard_id", played_id)

		var effect: Dictionary = data.get("effect", {})
		var kind := String(effect.get("kind", ""))

		# ✅ Drop It / mulligan enters waiting state (NO drag-drop)
		if kind == "hand_mulligan":
			var discard_count := int(effect.get("discard_count", 1))
			var draw_count := int(effect.get("draw_count", 1))

			_waiting_for_drop_it = true
			_drop_it_need_discards = max(1, discard_count)
			_drop_it_done_discards = 0
			_drop_it_need_draws = max(1, draw_count)

			_set_action_prompt("Drop It!: Select a card and press PLAY to discard (%d). Then click DRAW." % _drop_it_need_discards, true)

			var is_free := bool(effect.get("free", false))
			turn_system.on_player_played_card(is_free)

			await get_tree().process_frame
			if animator != null:
				animator.cache_positions(hand_layout)

			_update_all_ui()
			_refresh_ui()
			return

		# Normal effects
		if fx != null and fx.has_method("execute_card"):
			fx.execute_card(data, false)

		var is_free2 := bool(effect.get("free", false))
		turn_system.on_player_played_card(is_free2)

		await get_tree().process_frame
		if animator != null:
			animator.cache_positions(hand_layout)

		_update_all_ui()
		_refresh_ui()
	)
