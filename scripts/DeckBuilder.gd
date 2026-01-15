# res://scripts/DeckBuilder.gd
extends Control
class_name DeckBuilder

const DECK_SIZE := 52

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

var _all_ids: Array[String] = []
var _max_copies_per_card: int = 4

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

	if _db == null:
		push_error("DeckBuilder: CardDatabase not found at %s" % str(card_db_path))
		return
	if _grid_view == null:
		push_error("DeckBuilder: DeckGridView not found at %s (attach DeckGridView.gd there)" % str(grid_view_path))
		return
	if _details_view == null:
		push_error("DeckBuilder: DeckDetailsView not found at %s (attach DeckDetailsView.gd there)" % str(details_view_path))
		return

	if _confirm_btn != null:
		_confirm_btn.disabled = true

	# ✅ decide copy cap based on Chips completion
	_max_copies_per_card = _compute_max_copies()
	_dbg("Max copies per card = %d" % _max_copies_per_card)

	# ✅ DeckModel owns deck size (fixes your is_valid argument error)
	_model.set_deck_size(DECK_SIZE)

	# ✅ CardLibrary is RefCounted, so we pass GameManager in
	var gm := get_node_or_null("/root/GameManager")
	_lib.setup(_db, gm)

	# ✅ Use PLAYER pool ids (prevents enemy cards appearing in deckbuilder)
	# If your CardDatabase doesn't have pool helpers yet, CardLibrary should filter.
	_all_ids = _lib.get_all_ids()

	# Ensure qty dict has every id
	_model.ensure_ids(_all_ids)

	_wire_ui()
	_refresh_deck_picker()

	_load_from_gamemanager()

	# ✅ Render (6 columns + tab margins handled inside DeckGridView)
	_grid_view.set_rules(DECK_SIZE, _max_copies_per_card)

	# ✅ This render should internally sort unlocked first then locked.
	_grid_view.render_all(_all_ids, _lib, _model)
	_grid_view.render_selected(_all_ids, _lib, _model)

	_update_banner()

	if _all_ids.size() > 0:
		_details_view.show_card(_lib.get_data(_all_ids[0]))

func _compute_max_copies() -> int:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return 9 # safest during early dev

	# Chips done = 3 levels completed
	var chips_done := 0
	if gm.has_method("get_highest_completed"):
		chips_done = int(gm.call("get_highest_completed", "chips"))
	elif gm.has_variable("completed_level"):
		var d = gm.get("completed_level")
		if d is Dictionary:
			chips_done = int((d as Dictionary).get("chips", 0))

	# before level 3 completed => 9, else => 4
	return 4 if chips_done >= 3 else 9

func _wire_ui() -> void:
	if not _grid_view.tile_clicked.is_connected(_on_tile_clicked):
		_grid_view.tile_clicked.connect(_on_tile_clicked)
	if not _grid_view.qty_changed.is_connected(_on_qty_changed):
		_grid_view.qty_changed.connect(_on_qty_changed)

	if _save_btn != null:
		if not _save_btn.pressed.is_connected(_on_save_pressed):
			_save_btn.pressed.connect(_on_save_pressed)
		_dbg("SaveButton wired: %s" % _save_btn.get_path())
	else:
		_dbg("SaveButton is NULL (check save_button_path)")

	if _load_btn != null and not _load_btn.pressed.is_connected(_on_load_pressed):
		_load_btn.pressed.connect(_on_load_pressed)

	if _deck_picker != null and not _deck_picker.item_selected.is_connected(_on_deck_selected):
		_deck_picker.item_selected.connect(_on_deck_selected)

	if _confirm_btn != null and not _confirm_btn.pressed.is_connected(_on_confirm_pressed):
		_confirm_btn.pressed.connect(_on_confirm_pressed)

func _on_tile_clicked(card_id: String) -> void:
	_details_view.show_card(_lib.get_data(card_id))

func _on_qty_changed(card_id: String, qty: int) -> void:
	_model.set_qty(card_id, qty, _max_copies_per_card)

	# ✅ sync both tabs without recursion (DeckGridView should support "silent" set)
	_grid_view.sync_qty(card_id, qty)

	# simplest: rebuild selected
	_grid_view.render_selected(_all_ids, _lib, _model)

	_update_banner()

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
	var name := ""
	if _deck_name != null:
		name = _deck_name.text.strip_edges()

	if name == "":
		if _deck_picker != null and _deck_picker.item_count > 0:
			name = _deck_picker.get_item_text(_deck_picker.selected)
		else:
			name = "Deck_%d" % int(Time.get_unix_time_from_system())

	_dbg("SAVE pressed -> '%s' total=%d" % [name, _model.get_total()])
	_persist.save_deck(name, _model)

	_refresh_deck_picker()

	# select saved name
	if _deck_picker != null:
		for i in range(_deck_picker.item_count):
			if _deck_picker.get_item_text(i) == name:
				_deck_picker.select(i)
				break

func _on_load_pressed() -> void:
	if _deck_picker == null or _deck_picker.item_count <= 0:
		return
	var idx := _deck_picker.selected
	if idx < 0:
		idx = 0
	var name := _deck_picker.get_item_text(idx)
	_load_named_deck(name)

func _on_deck_selected(idx: int) -> void:
	if _deck_picker == null:
		return
	var name := _deck_picker.get_item_text(idx)
	_load_named_deck(name)

func _load_named_deck(name: String) -> void:
	var deck := _persist.load_deck(name)
	_model.from_deck_array(deck)
	_model.ensure_ids(_all_ids)

	_grid_view.set_rules(DECK_SIZE, _max_copies_per_card)
	_grid_view.render_all(_all_ids, _lib, _model)
	_grid_view.render_selected(_all_ids, _lib, _model)

	_update_banner()

	if _deck_name != null:
		_deck_name.text = name

func _on_confirm_pressed() -> void:
	# ✅ FIX: is_valid() takes NO args now (DeckModel owns DECK_SIZE)
	if not _model.is_valid():
		_dbg("Confirm blocked: not %d cards yet." % DECK_SIZE)
		return

	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		var deck := _model.to_deck_array()
		if gm.has_variable("current_deck"):
			gm.set("current_deck", deck)
		elif gm.has_method("set_current_deck"):
			gm.call("set_current_deck", deck)

		_dbg("Confirmed deck saved to GameManager. size=%d" % deck.size())

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
		_model.from_deck_array(deck as Array)
