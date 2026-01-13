# res://scripts/ZoomController.gd
extends CanvasLayer
class_name ZoomController

@export var zoom_scale: float = 4.0     # <- set to 3.5 or 4.0 (you wanted 3.5/4)
@export var zoom_time: float = 0.18
@export var backdrop_alpha: float = 0.75

# Set by BattleUI on _ready()
var CardScene: PackedScene = null

@onready var zoom_backdrop: ColorRect = %ZoomBackdrop
@onready var zoom_slot: Control = %ZoomSlot

var zoom_open: bool = false
var zoom_card: Control = null
var zoom_from_pos: Vector2 = Vector2.ZERO
var zoom_from_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	visible = false

	# Block clicks; click to close
	if zoom_backdrop:
		zoom_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		zoom_backdrop.gui_input.connect(_on_backdrop_input)

		# Start fully transparent
		var m := zoom_backdrop.modulate
		m.a = 0.0
		zoom_backdrop.modulate = m


func set_card_scene(scene: PackedScene) -> void:
	CardScene = scene


func _unhandled_input(event: InputEvent) -> void:
	if zoom_open and event.is_action_pressed("ui_cancel"):
		close_zoom()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_zoom()


func open_zoom(real_card: Control) -> void:
	if zoom_open:
		return
	if CardScene == null:
		push_error("ZoomController: CardScene is null. BattleUI must call zoom.set_card_scene(CardScene).")
		return
	if real_card == null or not is_instance_valid(real_card):
		push_warning("ZoomController: open_zoom called with invalid real_card.")
		return

	zoom_open = true
	visible = true

	# Reset fade each open
	if zoom_backdrop:
		var m := zoom_backdrop.modulate
		m.a = 0.0
		zoom_backdrop.modulate = m

	# Clear old zoom children
	if zoom_slot:
		for child in zoom_slot.get_children():
			child.queue_free()

	# Create ghost card (so hand card never moves)
	var ghost := CardScene.instantiate() as Control
	if ghost == null:
		push_error("ZoomController: CardScene did not instantiate to a Control.")
		close_zoom()
		return

	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_slot.add_child(ghost)
	zoom_card = ghost

	# Copy visuals (CardView-safe: set_from_data caches if not ready)
	_copy_card_visual(real_card, ghost)

	# Start position/scale = real card
	zoom_from_pos = real_card.get_global_rect().position.round()
	zoom_from_scale = real_card.scale

	ghost.global_position = zoom_from_pos
	ghost.scale = zoom_from_scale

	# Target centered in viewport
	var vp := get_viewport().get_visible_rect()
	var target_center := vp.size * 0.5

	# Use a reliable size. (Some Controls report size 0 until laid out.)
	var base_size := ghost.get_combined_minimum_size()
	if base_size == Vector2.ZERO:
		base_size = ghost.size
	if base_size == Vector2.ZERO:
		base_size = Vector2(160, 240) # safe fallback so centering math works

	var ghost_size := base_size * zoom_scale
	var target_pos := (target_center - (ghost_size * 0.5)).round()

	# Tween in
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if zoom_backdrop:
		t.tween_property(zoom_backdrop, "modulate:a", backdrop_alpha, zoom_time)

	t.parallel().tween_property(ghost, "global_position", target_pos, zoom_time)
	t.parallel().tween_property(ghost, "scale", Vector2(zoom_scale, zoom_scale), zoom_time)


func close_zoom() -> void:
	if not zoom_open:
		return
	zoom_open = false

	var ghost := zoom_card
	zoom_card = null

	if ghost == null or not is_instance_valid(ghost):
		visible = false
		return

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if zoom_backdrop:
		t.tween_property(zoom_backdrop, "modulate:a", 0.0, zoom_time)

	t.parallel().tween_property(ghost, "global_position", zoom_from_pos, zoom_time)
	t.parallel().tween_property(ghost, "scale", zoom_from_scale, zoom_time)

	t.finished.connect(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		visible = false
	)


func _copy_card_visual(real_card: Control, ghost: Control) -> void:
	# Preferred path: CardView -> CardView (uses safe set_from_data caching)
	if real_card is CardView and ghost is CardView:
		var rc := real_card as CardView
		var gc := ghost as CardView

		var data := {
			"id": rc.card_id,
			"name": (rc.name_label.text if rc.name_label else ""),
			"rank": (int(rc.rank_label.text) if rc.rank_label else 0),
			"type": (rc.type_label.text if rc.type_label else ""),
			"desc": (rc.desc_label.text if rc.desc_label else ""),
			"art_path": ""
		}
		gc.set_from_data(data)

		# Copy texture directly if available
		if rc.art_sprite and gc.art_sprite:
			gc.art_sprite.texture = rc.art_sprite.texture
		return

	# Fallback: try unique-name nodes if you have them
	var pairs := [
		["%NameLabel", "text"],
		["%RankText", "text"],
		["%TypeText", "text"],
		["%Description", "text"],
		["%ArtSprite", "texture"],
	]
	for p in pairs:
		var r := real_card.get_node_or_null(p[0])
		var g := ghost.get_node_or_null(p[0])
		if r == null or g == null:
			continue

		match p[1]:
			"text":
				if (r is Label and g is Label):
					(g as Label).text = (r as Label).text
				elif (r is RichTextLabel and g is RichTextLabel):
					(g as RichTextLabel).text = (r as RichTextLabel).text
			"texture":
				if (r is TextureRect and g is TextureRect):
					(g as TextureRect).texture = (r as TextureRect).texture
