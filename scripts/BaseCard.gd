# res://scripts/BaseCard.gd
extends Control
class_name BaseCard

signal clicked(card: BaseCard)
signal zoom_requested(card: BaseCard)
signal hovered(card: BaseCard, is_hovering: bool)

@export_group("Input")
@export var enable_click: bool = true
@export var enable_zoom: bool = true
@export var zoom_on_right_click: bool = true
@export var zoom_on_double_click: bool = false

@export_group("Debug")
@export var debug_enabled: bool = false

var _data: Dictionary = {}

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[BaseCard] ", msg)

func set_data(data: Dictionary) -> void:
	_data = data.duplicate(true)

	# Ensure id exists
	if not _data.has("id"):
		_data["id"] = String(name)

	# Ensure effect exists + is Dictionary
	if not _data.has("effect") or not (_data["effect"] is Dictionary):
		_data["effect"] = {}

	# Normalize effect.kind (accept legacy keys)
	var eff: Dictionary = _data["effect"] as Dictionary
	var kind := String(eff.get("kind", ""))

	if kind == "":
		if String(eff.get("type", "")) != "":
			kind = String(eff.get("type", ""))
		elif String(eff.get("action", "")) != "":
			kind = String(eff.get("action", ""))

	if kind != "":
		eff["kind"] = kind

	_data["effect"] = eff

	# Store meta for quick lookup elsewhere
	set_meta("card_id", String(_data.get("id", "")))

func get_data() -> Dictionary:
	return _data.duplicate(true)

func get_card_id() -> String:
	if has_meta("card_id"):
		return String(get_meta("card_id"))
	return String(_data.get("id", name))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void:
	hovered.emit(self, true)

func _on_mouse_exited() -> void:
	hovered.emit(self, false)

func _on_gui_input(ev: InputEvent) -> void:
	if not enable_click and not enable_zoom:
		return

	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			if enable_click and mb.button_index == MOUSE_BUTTON_LEFT:
				_dbg("clicked -> %s" % get_card_id())
				clicked.emit(self)

			if enable_zoom and zoom_on_right_click and mb.button_index == MOUSE_BUTTON_RIGHT:
				_dbg("zoom_requested -> %s" % get_card_id())
				zoom_requested.emit(self)

	# Optional double click zoom
	if enable_zoom and zoom_on_double_click and ev is InputEventMouseButton:
		var mb2 := ev as InputEventMouseButton
		if mb2.double_click and mb2.button_index == MOUSE_BUTTON_LEFT:
			_dbg("zoom_requested(double) -> %s" % get_card_id())
			zoom_requested.emit(self)
