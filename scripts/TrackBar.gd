@tool
extends Control
class_name TrackBar

signal track_rebuilt

@export_group("Tile Counts")
@export_range(0, 50, 1) var left_tiles: int = 3:
	set(v):
		left_tiles = max(0, v)
		_queue_rebuild()

@export_range(0, 50, 1) var right_tiles: int = 3:
	set(v):
		right_tiles = max(0, v)
		_queue_rebuild()

@export_group("Overlap / Connection")
@export_range(0.0, 0.35, 0.01) var overlap_ratio: float = 0.08:
	set(v):
		overlap_ratio = clamp(v, 0.0, 0.35)
		_queue_rebuild()

@export_group("Center Line")
@export_range(0, 12, 1) var center_line_width: int = 2:
	set(v):
		center_line_width = max(0, v)
		_queue_rebuild()

@export var show_center_line: bool = true:
	set(v):
		show_center_line = v
		_queue_rebuild()

@export_group("Pixel Art")
@export var force_nearest_filter: bool = true:
	set(v):
		force_nearest_filter = v
		_queue_rebuild()

@export_group("Debug")
@export var print_debug: bool = false:
	set(v):
		print_debug = v
		_queue_rebuild()

@onready var row: HBoxContainer = get_node_or_null("Row") as HBoxContainer

@onready var left_group: HBoxContainer = get_node_or_null("Row/LeftGroup") as HBoxContainer
@onready var left_tile_template: TextureRect = get_node_or_null("Row/LeftGroup/LeftTile") as TextureRect
@onready var left_mid_tile: TextureRect = get_node_or_null("Row/LeftGroup/LeftMidTile") as TextureRect

@onready var mid_line: Control = get_node_or_null("Row/MidLine") as Control

@onready var right_group: HBoxContainer = get_node_or_null("Row/RightGroup") as HBoxContainer
@onready var right_mid_tile: TextureRect = get_node_or_null("Row/RightGroup/RightMidTile") as TextureRect
@onready var right_tile_template: TextureRect = get_node_or_null("Row/RightGroup/RightTile") as TextureRect

var _rebuild_queued: bool = false
var _tile_rects: Dictionary = {} # int -> Rect2 (GLOBAL rect)

func _ready() -> void:
	# Editor + runtime safety
	if row == null:
		push_error("TrackBar: 'Row' must be an HBoxContainer at TrackBar/Row")
		return
	if left_group == null or right_group == null:
		push_error("TrackBar: LeftGroup/RightGroup must be HBoxContainer nodes.")
		return
	if left_tile_template == null or left_mid_tile == null:
		push_error("TrackBar: Missing LeftTile or LeftMidTile in LeftGroup.")
		return
	if right_mid_tile == null or right_tile_template == null:
		push_error("TrackBar: Missing RightMidTile or RightTile in RightGroup.")
		return
	if mid_line == null:
		push_error("TrackBar: Missing MidLine node.")
		return

	# Keep containers stable (overlap handled via negative separation)
	row.add_theme_constant_override("separation", 0)
	left_group.add_theme_constant_override("separation", 0)
	right_group.add_theme_constant_override("separation", 0)

	# Midline shouldn't push layout width
	mid_line.custom_minimum_size.x = 0
	mid_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Rebuild when resized at runtime
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

	_queue_rebuild()

func _notification(what: int) -> void:
	# ✅ This is the KEY for editor preview resizing
	if what == NOTIFICATION_RESIZED:
		_queue_rebuild()

func _on_resized() -> void:
	_queue_rebuild()

func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")

func _rebuild() -> void:
	_rebuild_queued = false

	# Guard against early editor frames (size can be 0 in tool mode)
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if row == null:
		return

	_rebuild_left_tiles()
	_rebuild_right_tiles()

	_apply_math_sizes()
	_apply_center_line()

	# Wait for layout to settle before mapping rects
	call_deferred("_post_layout_map")

func _post_layout_map() -> void:
	# Give containers a frame to compute child sizes/positions
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_build_tile_index_map()
	track_rebuilt.emit()

# -----------------------------
# Left: clones go BEFORE LeftMidTile
# LeftMidTile ALWAYS last in LeftGroup
# -----------------------------
func _rebuild_left_tiles() -> void:
	left_tile_template.visible = true
	left_mid_tile.visible = true

	# Remove clones
	for child in left_group.get_children():
		if child == left_tile_template or child == left_mid_tile:
			continue
		child.queue_free()

	# Template only visible if we want >=1 left tiles
	left_tile_template.visible = (left_tiles > 0)

	# Ensure LeftMidTile is last child (important for editor)
	left_group.move_child(left_mid_tile, left_group.get_child_count() - 1)

	# Ensure LeftTile template is BEFORE LeftMidTile (slot 0 if it exists)
	if left_group.get_children().has(left_tile_template):
		var target_index := max(0, left_group.get_child_count() - 2)
		left_group.move_child(left_tile_template, target_index)

	# Build list excluding mid tile
	var existing_left_tiles: Array[TextureRect] = []
	for child in left_group.get_children():
		if child is TextureRect and child != left_mid_tile:
			# include template + any clones
			existing_left_tiles.append(child as TextureRect)

	# If 0, hide all non-mid
	if left_tiles == 0:
		for t in existing_left_tiles:
			t.visible = false
		return

	# Ensure template counts as 1 slot, then clone up to left_tiles
	# If template exists, it is slot 0.
	while existing_left_tiles.size() < left_tiles:
		var clone := left_tile_template.duplicate() as TextureRect
		clone.name = "LeftTile_%d" % existing_left_tiles.size()
		clone.visible = true
		left_group.add_child(clone)

		# Always insert right before LeftMidTile
		left_group.move_child(clone, left_group.get_child_count() - 2)
		existing_left_tiles.append(clone)

	# Hide any extras (if you lowered left_tiles)
	if existing_left_tiles.size() > left_tiles:
		for i in range(left_tiles, existing_left_tiles.size()):
			existing_left_tiles[i].queue_free()

	# Re-assert mid tile is last
	left_group.move_child(left_mid_tile, left_group.get_child_count() - 1)

# -----------------------------
# Right: RightMidTile ALWAYS first in RightGroup
# clones go AFTER RightMidTile
# -----------------------------
func _rebuild_right_tiles() -> void:
	right_mid_tile.visible = true

	# Remove clones
	for child in right_group.get_children():
		if child == right_mid_tile or child == right_tile_template:
			continue
		child.queue_free()

	right_tile_template.visible = (right_tiles > 0)

	# Ensure RightMidTile is FIRST
	right_group.move_child(right_mid_tile, 0)

	# Ensure template is AFTER mid tile
	if right_group.get_children().has(right_tile_template):
		right_group.move_child(right_tile_template, 1)

	var existing_right_tiles: Array[TextureRect] = []
	for child in right_group.get_children():
		if child is TextureRect and child != right_mid_tile:
			existing_right_tiles.append(child as TextureRect)

	if right_tiles == 0:
		for t in existing_right_tiles:
			t.visible = false
		return

	while existing_right_tiles.size() < right_tiles:
		var clone := right_tile_template.duplicate() as TextureRect
		clone.name = "RightTile_%d" % existing_right_tiles.size()
		clone.visible = true
		right_group.add_child(clone)
		existing_right_tiles.append(clone)

	# Hide extras (if reduced)
	if existing_right_tiles.size() > right_tiles:
		for i in range(right_tiles, existing_right_tiles.size()):
			existing_right_tiles[i].queue_free()

	# Re-assert mid is first
	right_group.move_child(right_mid_tile, 0)

# -----------------------------
# Sizes / overlap / flip
# -----------------------------
func _apply_math_sizes() -> void:
	var n: int = left_tiles + right_tiles + 2 # +2 for (-1) and (+1)
	if n <= 0:
		return

	var track_w: float = max(1.0, size.x)
	var track_h: float = max(1.0, size.y)

	var denom: float = float(n) - float(n - 1) * overlap_ratio
	if denom <= 0.001:
		denom = 0.001

	var tile_w: float = track_w / denom
	var overlap_px: float = tile_w * overlap_ratio
	var sep_int: int = int(round(-overlap_px))

	left_group.add_theme_constant_override("separation", sep_int)
	right_group.add_theme_constant_override("separation", sep_int)

	var all_tiles: Array[TextureRect] = []
	for c in left_group.get_children():
		if c is TextureRect and (c as TextureRect).visible:
			all_tiles.append(c as TextureRect)
	for c in right_group.get_children():
		if c is TextureRect and (c as TextureRect).visible:
			all_tiles.append(c as TextureRect)

	for t in all_tiles:
		if force_nearest_filter:
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		t.custom_minimum_size = Vector2(tile_w, track_h)
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size_flags_horizontal = Control.SIZE_FILL
		t.size_flags_vertical = Control.SIZE_FILL

	# Mirror right side
	right_mid_tile.flip_h = true
	for c in right_group.get_children():
		if c is TextureRect:
			(c as TextureRect).flip_h = true

	if print_debug:
		print("--- TrackBar Rebuild ---")
		print("Track size: ", Vector2(track_w, track_h))
		print("Tiles n: ", n, " tile_w: ", tile_w, " overlap_px: ", overlap_px, " sep: ", sep_int)

func _apply_center_line() -> void:
	mid_line.custom_minimum_size.x = 0
	mid_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var line: ColorRect = null
	for c in mid_line.get_children():
		if c is ColorRect:
			line = c
			break

	if line == null:
		line = ColorRect.new()
		line.name = "CenterLine"
		mid_line.add_child(line)

	line.visible = show_center_line and center_line_width > 0
	line.set_anchors_preset(Control.PRESET_CENTER)
	line.size = Vector2(float(center_line_width), max(1.0, size.y))
	line.position = Vector2(-line.size.x * 0.5, -line.size.y * 0.5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

# -----------------------------
# Tile map API
# -----------------------------
func get_min_tile_index() -> int:
	return -(left_tiles + 1)

func get_max_tile_index() -> int:
	return (right_tiles + 1)

func has_tile(tile_index: int) -> bool:
	return _tile_rects.has(tile_index)

func get_tile_rect_global(tile_index: int) -> Rect2:
	if not _tile_rects.has(tile_index):
		return Rect2()
	return _tile_rects[tile_index]

func get_tile_center_global(tile_index: int) -> Vector2:
	var r := get_tile_rect_global(tile_index)
	return r.position + r.size * 0.5

func _build_tile_index_map() -> void:
	_tile_rects.clear()

	# Left order = visual left-to-right within LeftGroup
	var left_order: Array[TextureRect] = []
	for c in left_group.get_children():
		if c is TextureRect and (c as TextureRect).visible:
			left_order.append(c as TextureRect)

	# Right order = visual left-to-right within RightGroup
	var right_order: Array[TextureRect] = []
	for c in right_group.get_children():
		if c is TextureRect and (c as TextureRect).visible:
			right_order.append(c as TextureRect)

	# Left indices:
	# should contain: [-N .. -2, -1] where -1 is LeftMidTile
	var left_start: int = -(left_tiles + 1)
	for i in range(left_order.size()):
		var idx := left_start + i
		if left_order[i] == left_mid_tile:
			idx = -1
		_tile_rects[idx] = left_order[i].get_global_rect()

	# Right indices:
	# first tile is +1 (RightMidTile), then +2.. etc
	for i in range(right_order.size()):
		var idx := 1 + i
		_tile_rects[idx] = right_order[i].get_global_rect()

	if print_debug:
		print("Tile map keys: ", _tile_rects.keys())
