# res://scripts/BattleCardAnimator.gd
extends Node
class_name BattleCardAnimator

var is_animating: bool = false

@export var selected_y_offset: float = 10.0 # (still used for CLICK selection)
# res://scripts/BattleCardAnimator.gd

# 1. Set fan_offset to 0 or a very small value (e.g., 5.0) in the Inspector 
# to prevent cards from pushing outside the UI bounds.
@export var fan_offset: float = 20.0        # horizontal push for neighbors
@export var hover_raise_y: float = 0.0      # keep 0.0 so hover NEVER moves vertically

# base positions cache (instance_id -> y)
var _base_y: Dictionary = {}

func cache_positions(hand_layout: Control) -> void:
	_base_y.clear()
	if hand_layout == null:
		return
	for c in hand_layout.get_children():
		if c is Control and not c.is_queued_for_deletion():
			_base_y[c.get_instance_id()] = float((c as Control).position.y)



func animate_hover_fan(active_card: Control, is_hovering: bool, layout: HandLayout) -> void:
	if is_animating:
		return
	if not is_instance_valid(active_card):
		return
	if layout == null:
		return

	var cards := layout.get_children()
	var active_idx := active_card.get_index()

	for i in range(cards.size()):
		var c := cards[i]
		if not (c is Control) or not is_instance_valid(c):
			continue

		var cc := c as Control
		var iid := cc.get_instance_id()

		# Get the "resting" home position from the layout
		var home_x: float = float(layout.get_card_resting_x(i))
		var home_y: float = float(_base_y.get(iid, cc.position.y))

		var target_x: float = home_x
		var target_y: float = home_y

		if is_hovering:
			if cc == active_card:
				# ✅ Bring to the absolute front
				cc.z_index = 100 
				# Card stays at home_x, showing its full area over the others
			else:
				# ✅ Keep standard stacking order for non-hovered cards
				cc.z_index = i
				
				# Instead of pushing cards away (which causes clipping), 
				# we keep target_x = home_x. 
				# If you want them to 'tuck' slightly under, 
				# you can use a tiny negative fan_offset.
				if i < active_idx:
					target_x = home_x - fan_offset
				elif i > active_idx:
					target_x = home_x + fan_offset
		else:
			# Reset z_index to the original sibling order
			cc.z_index = i

		# Use a very fast tween for a responsive "flip through" feel
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(cc, "position:x", target_x, 0.1)
		t.parallel().tween_property(cc, "position:y", target_y, 0.1)

func animate_hover_selection(card: Control, is_selected: bool) -> void:
	# CLICK selection (this is allowed to move vertically)
	if is_animating:
		return
	if not is_instance_valid(card):
		return

	var iid := card.get_instance_id()
	var base_y: float = float(_base_y.get(iid, card.position.y))
	var target_y: float = base_y - (selected_y_offset if is_selected else 0.0)

	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:y", target_y, 0.12)

	var target_col := Color(1.3, 1.3, 1.3, 1.0) if is_selected else Color(1, 1, 1, 1)
	t.parallel().tween_property(card, "modulate", target_col, 0.12)

# Alias expected by BattleHandController
func draw_from_deck(card: Control, deck_global_pos: Vector2, delay: float) -> Tween:
	return animate_draw_from_deck(card, deck_global_pos, delay)

func animate_draw_from_deck(card: Control, deck_global_pos: Vector2, delay: float) -> Tween:
	is_animating = true
	if not is_instance_valid(card):
		return null

	var target_local: Vector2 = card.position

	var parent_ctrl := card.get_parent() as Control
	if parent_ctrl == null:
		return null

	var inv := parent_ctrl.get_global_transform_with_canvas().affine_inverse()
	var start_local: Vector2 = inv * deck_global_pos

	card.position = start_local
	card.modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_interval(delay)
	t.tween_property(card, "position", target_local, 0.28)
	t.parallel().tween_property(card, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(card, "scale", Vector2(1, 1), 0.22)

	t.finished.connect(func():
		if is_instance_valid(card):
			card.mouse_filter = Control.MOUSE_FILTER_STOP
	)

	return t

func animate_play_card(card: Control, on_complete: Callable) -> void:
	is_animating = true
	if not is_instance_valid(card):
		is_animating = false
		return

	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(card, "position:y", card.position.y - 50.0, 0.20)
	t.parallel().tween_property(card, "modulate:a", 0.0, 0.20)

	t.finished.connect(func():
		_base_y.erase(card.get_instance_id())
		is_animating = false
		on_complete.call()
	)
