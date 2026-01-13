@tool
extends Control
class_name TrackSprites

@export_group("Wiring")
@export var track_bar_path: NodePath = NodePath("../TrackBar")

@export_group("Start Tiles (Mid Tiles)")
# Hard start: LeftMidTile = -1, RightMidTile = +1
@export var hiro_tile: int = -1
@export var enemy_tile: int = 1

@export_group("Sizing")
@export var desired_sprite_size: Vector2 = Vector2(150, 110)
@export var bottom_padding_px: float = 0.0

@export_group("Placement Tweaks")
@export var hiro_offset: Vector2 = Vector2.ZERO
@export var enemy_offset: Vector2 = Vector2.ZERO

@export_group("Debug")
@export var print_debug: bool = true
@export var print_every_update: bool = false

@onready var track_bar: TrackBar = get_node_or_null(track_bar_path) as TrackBar
@onready var hiro: AnimatedSprite2D = get_node_or_null("Hiro") as AnimatedSprite2D
@onready var enemy: AnimatedSprite2D = get_node_or_null("Enemy") as AnimatedSprite2D

var _last_print_hiro_tile: int = 999999
var _last_print_enemy_tile: int = 999999


func _ready() -> void:
	_bind_trackbar()
	# Force start at mid tiles every run
	hiro_tile = -1
	enemy_tile = 1
	_update_positions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		call_deferred("_bind_trackbar")
		call_deferred("_update_positions")


func _bind_trackbar() -> void:
	track_bar = get_node_or_null(track_bar_path) as TrackBar
	if track_bar == null:
		if print_debug:
			print("TrackSprites: TrackBar not found at path: ", track_bar_path)
		return

	if not track_bar.track_rebuilt.is_connected(_on_track_rebuilt):
		track_bar.track_rebuilt.connect(_on_track_rebuilt)


func _on_track_rebuilt() -> void:
	_update_positions()


func _update_positions() -> void:
	if track_bar == null:
		return

	# If tiles aren't built yet, wait (common at scene start)
	if not track_bar.has_tile(-1) or not track_bar.has_tile(1):
		return

	if hiro != null:
		_apply_size_to_sprite(hiro, desired_sprite_size)
		_place_sprite_on_tile_x_lock_lane_bottom_y(hiro, hiro_tile, hiro_offset, "Hiro")

	if enemy != null:
		_apply_size_to_sprite(enemy, desired_sprite_size)
		_place_sprite_on_tile_x_lock_lane_bottom_y(enemy, enemy_tile, enemy_offset, "Enemy")


func _apply_size_to_sprite(s: AnimatedSprite2D, desired: Vector2) -> void:
	if s.sprite_frames == null:
		return

	# Ensure an animation exists
	var anim := s.animation
	if anim == "" or not s.sprite_frames.has_animation(anim):
		var names := s.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		anim = names[0]
		s.animation = anim

	if s.sprite_frames.get_frame_count(anim) <= 0:
		return

	var tex: Texture2D = s.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return

	var native := tex.get_size()
	if native.x <= 0 or native.y <= 0:
		return

	s.scale = Vector2(desired.x / native.x, desired.y / native.y)
	s.centered = true


func _lane_bottom_global_y() -> float:
	# Bottom of *Middle Track/Sprites* (this Control)
	var r := get_global_rect()
	return r.position.y + r.size.y


func _place_sprite_on_tile_x_lock_lane_bottom_y(
	s: AnimatedSprite2D,
	tile_index: int,
	extra_offset: Vector2,
	label: String
) -> void:
	if not track_bar.has_tile(tile_index):
		s.visible = false
		if print_debug:
			print("TrackSprites: ", label, " tile missing: ", tile_index)
		return

	s.visible = true

	# X from TrackBar tile center
	var tile_center_g: Vector2 = track_bar.get_tile_center_global(tile_index)

	# Y locked to bottom of Sprites lane
	var bottom_y: float = _lane_bottom_global_y()

	# Bottom-anchored sprite (centered means its origin is center)
	var target_global := Vector2(
		tile_center_g.x,
		bottom_y - (desired_sprite_size.y * 0.5) - bottom_padding_px
	) + extra_offset

	# GLOBAL -> Sprites-local
	var inv := get_global_transform_with_canvas().affine_inverse()
	var local_pos: Vector2 = inv * target_global
	s.position = local_pos

	_print_debug_if_needed(label, tile_index)


func _print_debug_if_needed(label: String, tile_index: int) -> void:
	if not print_debug:
		return

	if label == "Hiro":
		if print_every_update or tile_index != _last_print_hiro_tile:
			_last_print_hiro_tile = tile_index
			print("Hiro on tile: ", _format_tile(tile_index))
	elif label == "Enemy":
		if print_every_update or tile_index != _last_print_enemy_tile:
			_last_print_enemy_tile = tile_index
			print("Enemy on tile: ", _format_tile(tile_index))


func _format_tile(i: int) -> String:
	# Godot 4 ternary syntax:
	# truthy_value if condition else falsy_value
	return ("+" + str(i)) if i > 0 else str(i)
