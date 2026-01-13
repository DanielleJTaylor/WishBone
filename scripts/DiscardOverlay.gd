# res://scripts/DiscardOverlay.gd
extends Control
class_name DiscardOverlay

@export_group("Bindings")
@export var backdrop_path: NodePath = NodePath("Backdrop")
@export var left_button_path: NodePath = NodePath("Center/LeftButton")
@export var card_strip_path: NodePath = NodePath("Center/CardStrip")
@export var right_button_path: NodePath = NodePath("Center/RightButton")
@export var card_database_path: NodePath = NodePath("../../CardDatabase") # set in inspector if different

# ✅ NEW: open trigger (TopCardButton)
@export_group("Open Trigger")
@export var open_button_path: NodePath = NodePath("../Bottom Bar/CardArea/DiscardPile/TopCardPreview/TopCardButton")

@export_group("Sizing (Match HandLayout)")
@export var max_card_height: float = 200.0
@export var card_scale_mul: float = 1.0
@export var strip_separation: int = 16

@export_group("Paging")
@export var cards_per_page: int = 8

@export_group("Debug")
@export var debug_enabled: bool = true

var _backdrop: Control
var _left_btn: Button
var _right_btn: Button
var _strip: HBoxContainer
var _card_db: Node
var _open_btn: Button

# Stored oldest -> newest (same as DiscardPileWidget)
var _discard_ids: Array[String] = []

# Page is "offset from newest":
# page 0 = newest page
# page 1 = next older page
var _page: int = 0

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[DiscardOverlay] ", msg)

func _ready() -> void:
	# Fullscreen overlay / top layer
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	mouse_filter = Control.MOUSE_FILTER_STOP

	_backdrop = get_node_or_null(backdrop_path) as Control
	_left_btn = get_node_or_null(left_button_path) as Button
	_right_btn = get_node_or_null(right_button_path) as Button
	_strip = get_node_or_null(card_strip_path) as HBoxContainer
	_card_db = get_node_or_null(card_database_path)
	_open_btn = get_node_or_null(open_button_path) as Button

	# Backdrop click closes
	if _backdrop != null:
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.z_index = 0
		if not _backdrop.gui_input.is_connected(_on_backdrop_gui_input):
			_backdrop.gui_input.connect(_on_backdrop_gui_input)

	# Center above backdrop
	var center := get_node_or_null("Center") as CanvasItem
	if center != null:
		center.z_index = 1

	# Strip separation
	if _strip != null:
		_strip.add_theme_constant_override("separation", strip_separation)

	# Paging buttons:
	# LEFT = toward NEWER pages (page--)
	# RIGHT = toward OLDER pages (page++)
	if _left_btn != null and not _left_btn.pressed.is_connected(_on_left):
		_left_btn.pressed.connect(_on_left)
	if _right_btn != null and not _right_btn.pressed.is_connected(_on_right):
		_right_btn.pressed.connect(_on_right)

	# ✅ Open on TopCardButton
	if _open_btn != null and not _open_btn.pressed.is_connected(_on_open_pressed):
		_open_btn.pressed.connect(_on_open_pressed)
	else:
		_dbg("WARNING: open_button not found at open_button_path. Set it in Inspector if needed.")

	# ✅ Start invisible always
	visible = false

	_dbg("Ready. strip=%s left=%s right=%s open_btn=%s db=%s" % [
		str(_strip), str(_left_btn), str(_right_btn), str(_open_btn), str(_card_db)
	])

# -----------------------
# Open/Close
# -----------------------
func _on_open_pressed() -> void:
	_dbg("Open pressed (TopCardButton)")
	open()

func open() -> void:
	visible = true
	_page = clamp(_page, 0, _max_page())
	_update_buttons()
	_render_page()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _on_backdrop_gui_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		close()
		get_viewport().set_input_as_handled()

# Called by DiscardPileWidget
func set_discard_ids(ids: Array[String]) -> void:
	_discard_ids = ids.duplicate()
	_page = clamp(_page, 0, _max_page())
	if visible:
		_update_buttons()
		_render_page()

# -----------------------
# Paging
# -----------------------
func _max_page() -> int:
	if _discard_ids.is_empty():
		return 0
	return int(max(0, ceil(float(_discard_ids.size()) / float(max(1, cards_per_page))) - 1))

# LEFT = go back toward NEWER (smaller page index)
func _on_left() -> void:
	_page = max(0, _page - 1)
	_update_buttons()
	_render_page()

# RIGHT = go toward OLDER (bigger page index)
func _on_right() -> void:
	_page = min(_max_page(), _page + 1)
	_update_buttons()
	_render_page()

func _update_buttons() -> void:
	# If we're on page 0 (newest), LEFT disabled (can't go newer than newest)
	if _left_btn != null:
		_left_btn.disabled = (_page <= 0)
	# If we're on max page (oldest), RIGHT disabled
	if _right_btn != null:
		_right_btn.disabled = (_page >= _max_page())

# -----------------------
# Render: Newest (left) -> Oldest (right)
# Page 0 shows newest slice of discards.
# -----------------------
func _render_page() -> void:
	if _strip == null:
		_dbg("Missing CardStrip")
		return
	if _card_db == null:
		_dbg("Missing CardDatabase (fix card_database_path)")
		return

	# Clear old children
	for c in _strip.get_children():
		(c as Node).queue_free()

	if _discard_ids.is_empty():
		return

	var total := _discard_ids.size()

	# page 0: i = 0..cards_per_page-1 => newest..older
	var start_from_newest := _page * cards_per_page
	var end_from_newest := min(start_from_newest + cards_per_page, total)

	# Spawn cards newest -> older (LEFT to RIGHT)
	for i in range(start_from_newest, end_from_newest):
		var id := _discard_ids[total - 1 - i] # newest first
		var card: Control = _card_db.call("make_card_instance", id)
		if card == null:
			continue

		# Preview only (no interaction)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE

		if card is BaseCard:
			(card as BaseCard).enable_click = false
			(card as BaseCard).enable_zoom = false

		_strip.add_child(card)

	# Let cards resolve minimum sizes before scaling
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_uniform_scale_to_strip()

	_dbg("Rendered page %d/%d newest->older strip_children=%d" % [
		_page + 1, _max_page() + 1, _strip.get_child_count()
	])

func _apply_uniform_scale_to_strip() -> void:
	if _strip == null:
		return

	for child in _strip.get_children():
		var card := child as Control
		if card == null:
			continue

		var base_size := Vector2(154, 210)
		var ms := card.get_combined_minimum_size()
		if ms != Vector2.ZERO:
			base_size = ms
		elif card.size != Vector2.ZERO:
			base_size = card.size

		var scale_h := 1.0
		if base_size.y > 0.0 and max_card_height > 0.0:
			scale_h = min(1.0, max_card_height / base_size.y)

		var s := scale_h * card_scale_mul

		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.scale = Vector2(s, s)

		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
