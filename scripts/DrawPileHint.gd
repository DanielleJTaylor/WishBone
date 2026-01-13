extends Control
class_name DrawPileHint

@export_group("Node Paths (relative to DrawPile)")
@export var glow_path: NodePath = NodePath("Glow")                 # DrawPile/Glow
@export var arrow_path: NodePath = NodePath("BackofCard/Arrow")    # DrawPile/BackofCard/Arrow
@export var hand_layout_path: NodePath = NodePath("../Tray/HandBounds/HandLayout")

@export_group("Rule")
@export var target_hand_size: int = 7

@export_group("Glow Pulse")
@export var glow_pulse_min: float = 0.65
@export var glow_pulse_max: float = 1.25
@export var glow_pulse_time: float = 0.35

@export_group("Arrow Bob")
@export var arrow_bob_pixels: float = 6.0
@export var arrow_bob_time: float = 0.35

@export_group("Update")
@export var update_every_frame: bool = true

var glow: CanvasItem
var arrow: CanvasItem
var hand_layout: Control

var _tween: Tween
var _arrow_base_pos: Vector2 = Vector2.ZERO
var _last_should_show: bool = false

func _ready() -> void:
	glow = get_node_or_null(glow_path) as CanvasItem
	arrow = get_node_or_null(arrow_path) as CanvasItem
	hand_layout = get_node_or_null(hand_layout_path) as Control

	# Helpful debug if paths are wrong
	if glow == null:
		push_warning("DrawPileHint: glow not found at path: %s" % str(glow_path))
	if arrow == null:
		push_warning("DrawPileHint: arrow not found at path: %s" % str(arrow_path))
	if hand_layout == null:
		push_warning("DrawPileHint: hand_layout not found at path: %s" % str(hand_layout_path))

	if arrow != null:
		_arrow_base_pos = arrow.position

	# Force hidden on start (even if you forgot in editor)
	_force_hint_visible(false)
	_last_should_show = false

	set_process(update_every_frame)
	call_deferred("refresh_hint") # ensure layout exists first frame

func _process(_delta: float) -> void:
	if update_every_frame:
		refresh_hint()

func refresh_hint() -> void:
	var count := _get_hand_count()
	var should_show := count < target_hand_size

	if should_show == _last_should_show:
		return

	_last_should_show = should_show

	if should_show:
		_force_hint_visible(true)
		_start_anim()
	else:
		_stop_anim()
		_force_hint_visible(false)

func _get_hand_count() -> int:
	# If we can't find hand_layout, don't show hint (prevents false positives)
	if hand_layout == null:
		return target_hand_size

	var c := 0
	for child in hand_layout.get_children():
		if child is Control and not (child as Control).is_queued_for_deletion() and (child as Control).visible:
			c += 1
	return c

func _force_hint_visible(v: bool) -> void:
	if glow != null:
		glow.visible = v

	if arrow != null:
		arrow.visible = v
		if v:
			arrow.position = _arrow_base_pos

func _start_anim() -> void:
	if _tween != null and _tween.is_valid():
		return

	_tween = create_tween()
	_tween.set_loops()

	# Glow pulse
	if glow != null:
		var mat := glow.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("intensity", 1.0)

			_tween.tween_property(mat, "shader_parameter/intensity", glow_pulse_max, glow_pulse_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			_tween.tween_property(mat, "shader_parameter/intensity", glow_pulse_min, glow_pulse_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			# Fallback if no shader
			_tween.tween_property(glow, "modulate:a", 0.85, glow_pulse_time)
			_tween.tween_property(glow, "modulate:a", 0.55, glow_pulse_time)

	# Arrow bob + small pulse
	if arrow != null:
		_tween.parallel().tween_property(arrow, "position:y", _arrow_base_pos.y - arrow_bob_pixels, arrow_bob_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		_tween.parallel().tween_property(arrow, "position:y", _arrow_base_pos.y, arrow_bob_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(arrow_bob_time)

		_tween.parallel().tween_property(arrow, "modulate:a", 0.75, arrow_bob_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		_tween.parallel().tween_property(arrow, "modulate:a", 1.0, arrow_bob_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(arrow_bob_time)

func _stop_anim() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	if glow != null:
		var mat := glow.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("intensity", 1.0)
