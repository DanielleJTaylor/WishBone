# res://scripts/DeckBuilder.gd
extends Control
class_name DeckBuilder

const DECK_SIZE := 52
const MAX_COPIES_PER_CARD := 4
const BACK_SCENE := "res://scenes/MainTitle.tscn"

@export var debug_enabled: bool = true

@export_group("Dependencies")
@export var card_db_path: NodePath = NodePath("../CardDatabase")

@export_group("Views")
@export var grid_view_path: NodePath = NodePath("MainVBox/Tabs") # DeckGridView attached here
@export var details_view_path: NodePath = NodePath("MainVBox/BottomDetails") # DeckDetailsView

@export_group("TopBar")
@export var count_label_path: NodePath = NodePath("MainVBox/TopBar/TopRow/CountLabel")
@export var confirm_button_path: NodePath = NodePath("MainVBox/TopBar/TopRow/ConfirmButton")
@export var deck_picker_path: NodePath = NodePath("MainVBox/TopBar/TopRow/DeckPicker")
@export var deck_name_path: NodePath = NodePath("MainVBox/TopBar/TopRow/DeckName")
@export var save_button_path: NodePath = NodePath("MainVBox/TopBar/TopRow/SaveButton")
@export var load_button_path: NodePath = NodePath("MainVBox/TopBar/TopRow/LoadButton")

# ✅ Back button path (your provided node path)
@export var back_button_path: NodePath = NodePath("MainVBox/MarginContainer/TopBar/TopRow/BackButton")

var _db: CardDatabase
var _lib := CardLibrary.new()
var _model := DeckModel.new()
var _persist := DeckPersistence.new()

var _grid_view: DeckGridView
var _details_view: DeckDetailsView

var _count_label: Label
var _confirm_btn: Button
var _deck_picker: OptionButton
var _deck_name: LineEdit
var _save_btn: Button
var _load_btn: Button
var _back_btn: Button

var _all_ids: Array[String] = []

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[DeckBuilder] ", msg)

func _ready() -> void:
	_db = get_node_or_null(card_db_path) as CardDatabase
	_grid_view = get_node_or_null(grid_view_path) as DeckGridView
	_details_view = get_node_or_null(details_view_path) as DeckDetailsView

	_count_label = get_node_or_null(count_label_path) as Label
	_confirm_btn = get_node_or_null(confirm_button_path) as Button
	_deck_picker = get_node_or_null(deck_picker_path) as OptionButton
	_deck_name = get_node_or_null(deck_name_path) as LineEdit
	_save_btn = get_node_or_null(save_button_path) as Button
	_load_btn = get_node_or_null(load_button_path) as Button
	_back_btn = get_node_or_null(back_button_path) as Button

	if _db == null:
		push_error("DeckBuilder: CardDatabase not found at %s" % str(card_db_path))
		return
	if _grid_view == null:
		push_error("DeckBuilder: DeckGridView not found at %s (attach DeckGridView.gd there)" % str(grid_view_path))
		return
	if _details_view == null:
		push_error("DeckBuilder: DeckDetailsView not found at %s (attach DeckDetailsView.gd there)" % str(details_view_path))
		return

	# Deck size owned by model
	_model.set_deck_size(DECK_SIZE)

	# CardLibrary needs db + gm (RefCounted cannot call get_node)
	var gm := get_node_or_null("/root/GameManager")
	_lib.setup(_db, gm)

	# Player-only cards (CardLibrary should filter to player pool)
	_all_ids = _lib.get_all_ids()
	_model.ensure_ids(_all_ids)

	_wire_ui()
	_apply_chips_gating() # ✅ disable deckpicker until chips complete

	_refresh_deck_picker()

	_load_from_gamemanager()

	# Render
	_grid_view.set_rules(DECK_SIZE, MAX_COPIES_PER_CARD)
	_grid_view.render_all(_all_ids, _lib, _model)
	_grid_view.render_selected(_all_ids, _lib, _model)

	_update_banner()

	if _all_ids.size() > 0:
		_details_view.show_card(_lib.get_data(_all_ids[0]))

# ---------------------------------------------------
# Chips gating: disable DeckPicker until Chips level 3 complete
# ---------------------------------------------------
func _chips_completed_all() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return false

	# Convention: highest_completed("chips") >= 3 means done
	if gm.has_method("get_highest_completed"):
		return int(gm.call("get_highest_completed", "chips")) >= 3

	# Fallback: completed_level["chips"] >= 3
	if gm.has_variable("completed_level"):
		var d = gm.get("completed_level")
		if d is Dictionary:
			return int((d as Dictionary).get("chips", 0)) >= 3

	return false

func _apply_chips_gating() -> void:
	var done := _chips_completed_all()

	if _deck_picker != null:
		_deck_picker.disabled = not done
	if _save_btn != null:
		_save_btn.disabled = not done
	if _load_btn != null:
		_load_btn.disabled = not done
	if _deck_name != null:
		_deck_name.editable = done

	_dbg("Chips completed all=%s -> DeckPicker/Save/Load %s" % [str(done), ("ENABLED" if done else "DISABLED")])

# ---------------------------------------------------
# Wiring
# ---------------------------------------------------
func _wire_ui() -> void:
	# grid view signals
	if not _grid_view.tile_clicked.is_connected(_on_tile_clicked):
		_grid_view.tile_clicked.connect(_on_tile_clicked)
	if not _grid_view.qty_changed.is_connected(_on_qty_changed):
		_grid_view.qty_changed.connect(_on_qty_changed)

	# back
	if _back_btn != null and not _back_btn.pressed.is_connected(_on_back_pressed):
		_back_btn.pressed.connect(_on_back_pressed)

	# save/load
	if _save_btn != null and not _save_btn.pressed.is_connected(_on_save_pressed):
		_save_btn.pressed.connect(_on_save_pressed)
	if _load_btn != null and not _load_btn.pressed.is_connected(_on_load_pressed):
		_load_btn.pressed.connect(_on_load_pressed)

	# picker
	if _deck_picker != null and not _deck_picker.item_selected.is_connected(_on_deck_selected):
		_deck_picker.item_selected.connect(_on_deck_selected)

	# confirm
	if _confirm_btn != null and not _confirm_btn.pressed.is_connected(_on_confirm_pressed):
		_confirm_btn.pressed.connect(_on_confirm_pressed)

# ---------------------------------------------------
# Back
# ---------------------------------------------------
func _on_back_pressed() -> void:
	_dbg("Back pressed -> %s" % BACK_SCENE)
	if not ResourceLoader.exists(BACK_SCENE):
		push_error("DeckBuilder: Missing scene: %s" % BACK_SCENE)
		return
	get_tree().change_scene_to_file(BACK_SCENE)

# ---------------------------------------------------
# Tiles
# ---------------------------------------------------
func _on_tile_clicked(card_id: String) -> void:
	_details_view.show_card(_lib.get_data(card_id))

func _on_qty_changed(card_id: String, qty: int) -> void:
	_model.set_qty(card_id, qty, MAX_COPIES_PER_CARD)

	# Sync both tabs without recursion (DeckGridView must do silent updates)
	_grid_view.sync_qty(card_id, qty)

	_grid_view.render_selected(_all_ids, _lib, _model)
	_update_banner()

# ---------------------------------------------------
# Banner
# ---------------------------------------------------
func _update_banner() -> void:
	var total := _model.get_total()
	if _count_label != null:
		_count_label.text = "%d / %d" % [total, DECK_SIZE]

	var ok := (total == DECK_SIZE)
	if _confirm_btn != null:
		_confirm_btn.disabled = not ok

	if _count_label != null:
		var good := Color(0.2, 1.0, 0.2)
		var bad := Color(1.0, 0.2, 0.2)
		_count_label.add_theme_color_override("font_color", good if ok else bad)

# ---------------------------------------------------
# Save/Load
# ---------------------------------------------------
func _refresh_deck_picker() -> void:
	if _deck_picker == null:
		return
	_deck_picker.clear()
	var names := _persist.list_decks()
	for n in names:
		_deck_picker.add_item(n)
	if _deck_picker.item_count > 0:
		_deck_picker.select(0)

func _on_save_pressed() -> void:
	# gated by disabled button, but keep safe
	if not _chips_completed_all():
		_dbg("Save blocked until Chips complete.")
		return

	var name := ""
	if _deck_name != null:
		name = _deck_name.text.strip_edges()

	if name == "":
		if _deck_picker != null and _deck_picker.item_count > 0:
			name = _deck_picker.get_item_text(_deck_picker.selected)
		else:
			name = "Deck_%d" % int(Time.get_unix_time_from_system())

	_dbg("SAVE -> '%s' total=%d" % [name, _model.get_total()])
	_persist.save_deck(name, _model)
	_refresh_deck_picker()

func _on_load_pressed() -> void:
	if not _chips_completed_all():
		_dbg("Load blocked until Chips complete.")
		return
	if _deck_picker == null or _deck_picker.item_count <= 0:
		return
	var idx := max(0, _deck_picker.selected)
	_load_named_deck(_deck_picker.get_item_text(idx))

func _on_deck_selected(idx: int) -> void:
	if not _chips_completed_all():
		return
	if _deck_picker == null:
		return
	_load_named_deck(_deck_picker.get_item_text(idx))

func _load_named_deck(name: String) -> void:
	_dbg("LOAD deck '%s'" % name)
	var deck := _persist.load_deck(name)
	_model.from_deck_array(deck)
	_model.ensure_ids(_all_ids)

	_grid_view.set_rules(DECK_SIZE, MAX_COPIES_PER_CARD)
	_grid_view.render_all(_all_ids, _lib, _model)
	_grid_view.render_selected(_all_ids, _lib, _model)
	_update_banner()

	if _deck_name != null:
		_deck_name.text = name

# ---------------------------------------------------
# Confirm
# ---------------------------------------------------
func _on_confirm_pressed() -> void:
	if not _model.is_valid():
		_dbg("Confirm blocked: need %d cards." % DECK_SIZE)
		return

	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		var deck := _model.to_deck_array()
		if gm.has_variable("current_deck"):
			gm.set("current_deck", deck)
		elif gm.has_method("set_current_deck"):
			gm.call("set_current_deck", deck)

		_dbg("Confirmed -> GameManager.current_deck size=%d" % deck.size())

# ---------------------------------------------------
# Load current deck (if exists)
# ---------------------------------------------------
func _load_from_gamemanager() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return

	var deck: Array = []
	if gm.has_method("get_current_deck"):
		deck = gm.call("get_current_deck")
	elif gm.has_variable("current_deck"):
		deck = gm.get("current_deck")

	if deck is Array and (deck as Array).size() > 0:
		_dbg("Loaded deck from GameManager size=%d" % (deck as Array).size())
		_model.from_deck_array(deck as Array)
