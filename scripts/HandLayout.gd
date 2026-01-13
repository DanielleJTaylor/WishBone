# res://scripts/HandLayout.gd
@tool
extends Control
class_name HandLayout

@export_group("Layout")
@export var max_card_height: float = 200.0
@export var spacing: float = 16.0
@export_range(0.10, 1.0, 0.01) var min_visible_width_ratio: float = 0.35

@export_group("Padding")
@export var left_padding: float = 0.0
@export var top_padding: float = 0.0
@export var bottom_padding: float = 0.0

@export_group("Scale")
@export var card_scale_mul: float = 1.0

# Animator needs these for "home" X positions
var _cached_start_x: float = 0.0
var _cached_step: float = 0.0
var _cached_y: float = 0.0

# Prevent re-layout spam (especially in editor @tool)
var _layout_queued: bool = false

func _ready() -> void:
	# Defer layout to avoid fighting tweens mid-frame
	resized.connect(request_layout)
	child_entered_tree.connect(func(_n): request_layout())
	child_exiting_tree.connect(func(_n): request_layout())

	# First layout
	request_layout()

func _notification(what: int) -> void:
	# IMPORTANT: NOTIFICATION_SORT_CHILDREN is not in Godot 4 the way you used it.
	# We only respond to child order changes.
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		request_layout()

func request_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_do_layout")

func get_card_resting_x(index: int) -> float:
	return _cached_start_x + (_cached_step * index)

func get_card_resting_y() -> float:
	return _cached_y

func _do_layout() -> void:
	_layout_queued = false
	layout_cards()

func layout_cards() -> void:
	var cards: Array[Control] = []
	for n in get_children():
		if n is Control and not n.is_queued_for_deletion() and n.visible:
			cards.append(n as Control)

	var n_cards := cards.size()
	if n_cards == 0:
		return

	var area_w: float = max(0.0, size.x - left_padding * 2.0)
	var area_h: float = max(0.0, size.y - top_padding - bottom_padding)

	# Determine base card size from first card
	var base_size := Vector2(154, 210)
	var first := cards[0]
	var ms := first.get_combined_minimum_size()
	if ms != Vector2.ZERO:
		base_size = ms
	elif first.size != Vector2.ZERO:
		base_size = first.size

	# Scale to fit height constraint
	var scale_h: float = 1.0
	if base_size.y > 0.0 and max_card_height > 0.0:
		scale_h = min(1.0, max_card_height / base_size.y)

	var s: float = scale_h * card_scale_mul
	var card_w: float = base_size.x * s
	var card_h: float = base_size.y * s

	var min_step: float = card_w * min_visible_width_ratio
	var max_step: float = card_w + spacing
	var step: float = max_step

	if n_cards > 1:
		var ideal_step: float = (area_w - card_w) / float(n_cards - 1)
		step = clamp(ideal_step, min_step, max_step)

	var total_span_w: float = card_w + step * float(n_cards - 1)
	var start_x: float = left_padding + (area_w - total_span_w) * 0.5
	var start_y: float = top_padding + (area_h - card_h) * 0.5

	# Cache for animator "home" positions
	_cached_start_x = start_x
	_cached_step = step
	_cached_y = start_y

	for i in range(n_cards):
		var c := cards[i]
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.scale = Vector2(s, s)
		c.position = Vector2(get_card_resting_x(i), start_y)
		c.z_index = i
