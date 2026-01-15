extends PanelContainer
class_name DeckCardTile

signal tile_clicked(card_id: String)
signal qty_changed(card_id: String, qty: int)

var card_id: String = ""
var is_locked: bool = false

# Cached nodes (resolved safely)
var _title: Label
var _icon: ColorRect
var _slider: HSlider
var _qty_label: Label

var _data: Dictionary = {}
var _cap: int = 4
var _suppress_emit := false

func _ready() -> void:
	# Safe node fetch (prevents Nil crashes if names differ)
	_title = get_node_or_null("VBox/Title") as Label
	_icon = get_node_or_null("VBox/IconBox") as ColorRect
	_slider = get_node_or_null("VBox/QtyRow/QtySlider") as HSlider
	_qty_label = get_node_or_null("VBox/QtyRow/QtyLabel") as Label

	if _slider != null and not _slider.value_changed.is_connected(_on_slider_changed):
		_slider.value_changed.connect(_on_slider_changed)

	# Allow click anywhere on tile
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func setup(id: String, data: Dictionary, qty: int, locked: bool, cap: int) -> void:
	card_id = id
	_data = data
	is_locked = locked
	_cap = max(1, cap)

	_apply_slider_rules()
	set_qty_silent(qty)

	if is_locked:
		_apply_locked_visuals()
	else:
		_apply_unlocked_visuals()

func _apply_slider_rules() -> void:
	if _slider == null:
		return

	_slider.min_value = 0
	_slider.max_value = _cap
	_slider.step = 1
	_slider.rounded = true

	# ticks = cap+1 positions (0..cap)
	_slider.tick_count = _cap + 1
	_slider.ticks_on_borders = true

func set_qty_silent(qty: int) -> void:
	_suppress_emit = true
	_set_qty_internal(qty)
	_suppress_emit = false

func _set_qty_internal(qty: int) -> void:
	if _slider == null:
		return

	var q := clampi(qty, 0, int(_slider.max_value))
	_slider.value = q

	if _qty_label != null:
		_qty_label.text = str(q)

func _on_slider_changed(v: float) -> void:
	if is_locked:
		set_qty_silent(0)
		return

	var q := int(v)
	_set_qty_internal(q)

	if not _suppress_emit:
		qty_changed.emit(card_id, q)

func _on_gui_input(event: InputEvent) -> void:
	if is_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(card_id)

func _apply_locked_visuals() -> void:
	if _title != null:
		_title.text = "LOCKED"
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _icon != null:
		_icon.color = Color(0.15, 0.2, 0.35)

	if _slider != null:
		_slider.editable = false
		_slider.visible = false
	if _qty_label != null:
		_qty_label.visible = false

func _apply_unlocked_visuals() -> void:
	if _title != null:
		_title.text = String(_data.get("name", card_id))

	if _icon != null:
		_icon.color = _type_to_color(String(_data.get("type", "")))

	if _slider != null:
		_slider.visible = true
		_slider.editable = true
	if _qty_label != null:
		_qty_label.visible = true

func _type_to_color(t: String) -> Color:
	match t:
		"ATTACK": return Color(0.85, 0.3, 0.3)
		"DEFENSE": return Color(0.3, 0.75, 0.45)
		"HEALING": return Color(0.3, 0.9, 0.6)
		"CONDITION": return Color(0.95, 0.6, 0.2)
		"HAND": return Color(0.55, 0.35, 0.85)
		"MOVEMENT": return Color(0.25, 0.55, 0.95)
		"SPECIAL": return Color(0.95, 0.85, 0.25)
		_: return Color(0.85, 0.85, 0.85)
