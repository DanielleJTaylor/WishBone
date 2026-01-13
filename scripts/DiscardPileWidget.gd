# res://scripts/DiscardPileWidget.gd
extends Control
class_name DiscardPileWidget

@export_group("Bindings")
@export var top_button_path: NodePath = NodePath("TopCardPreview/TopCardButton")
@export var top_art_path: NodePath = NodePath("TopCardPreview/TopCardArt")
@export var discard_overlay_path: NodePath = NodePath("../../DiscardOverlay") # adjust if needed

@export_group("Debug")
@export var debug_enabled: bool = true

var _top_button: Button = null
var _top_art: TextureRect = null
var _overlay: DiscardOverlay = null

var _discard_ids: Array[String] = []

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[DiscardPile] ", msg)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_top_button = get_node_or_null(top_button_path) as Button
	_top_art = get_node_or_null(top_art_path) as TextureRect
	_overlay = get_node_or_null(discard_overlay_path) as DiscardOverlay

	if _top_button != null and not _top_button.pressed.is_connected(_on_top_pressed):
		_top_button.pressed.connect(_on_top_pressed)

	_refresh_top_preview()

func clear() -> void:
	_discard_ids.clear()
	_refresh_top_preview()
	if _overlay != null:
		_overlay.set_discard_ids(_discard_ids)

func add_discard_id(id: String) -> void:
	if id == "":
		return
	_discard_ids.append(id)
	_refresh_top_preview()
	if _overlay != null:
		_overlay.set_discard_ids(_discard_ids)

func get_discard_ids() -> Array[String]:
	return _discard_ids.duplicate()

func _refresh_top_preview() -> void:
	if _top_art == null:
		return
	_top_art.visible = true

func _on_top_pressed() -> void:
	if _overlay == null:
		_dbg("No DiscardOverlay found at %s" % str(discard_overlay_path))
		return
	_overlay.set_discard_ids(_discard_ids)
	_overlay.open()
