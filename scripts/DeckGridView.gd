extends TabContainer
class_name DeckGridView

signal tile_clicked(card_id: String)
signal qty_changed(card_id: String, qty: int)

@export var debug_enabled := true

@export_group("Scene")
@export var tile_scene: PackedScene # assign DeckCardTile.tscn

@export_group("Grid Paths (inside this TabContainer)")
@export var all_grid_path: NodePath = NodePath("All/AllScroll/AllCenter/AllGrid")
@export var sel_grid_path: NodePath = NodePath("Selected/SelScroll/SelCenter/SelGrid")

var _all_grid: GridContainer
var _sel_grid: GridContainer

var _deck_size := 52
var _max_copies := 4

# Keep references so sync_qty doesn’t rebuild everything
var _all_tile_by_id: Dictionary = {} # id -> DeckCardTile
var _sel_tile_by_id: Dictionary = {} # id -> DeckCardTile

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[DeckGridView] ", msg)

func _ready() -> void:
	_all_grid = get_node_or_null(all_grid_path) as GridContainer
	_sel_grid = get_node_or_null(sel_grid_path) as GridContainer

	if tile_scene == null:
		push_error("DeckGridView: tile_scene not assigned (DeckCardTile.tscn).")
	if _all_grid == null:
		push_error("DeckGridView: AllGrid not found at %s" % str(all_grid_path))
	if _sel_grid == null:
		push_error("DeckGridView: SelGrid not found at %s" % str(sel_grid_path))

	# Enforce 6 columns by code (so scene edits don’t break it)
	if _all_grid != null:
		_all_grid.columns = 6
	if _sel_grid != null:
		_sel_grid.columns = 6

func set_rules(deck_size: int, max_copies: int) -> void:
	_deck_size = deck_size
	_max_copies = max(1, max_copies)
	_dbg("Rules: deck_size=%d max_copies=%d" % [_deck_size, _max_copies])

func render_all(all_ids: Array[String], lib: CardLibrary, model: DeckModel) -> void:
	if _all_grid == null or tile_scene == null:
		return

	_clear_children(_all_grid)
	_all_tile_by_id.clear()

	# ✅ Sort: unlocked first, locked last
	var unlocked: Array[String] = []
	var locked: Array[String] = []
	for id in all_ids:
		if lib.is_unlocked(id):
			unlocked.append(id)
		else:
			locked.append(id)

	unlocked.sort()
	locked.sort()

	var sorted := unlocked
	sorted.append_array(locked)

	_dbg("render_all: unlocked=%d locked=%d total=%d" % [unlocked.size(), locked.size(), sorted.size()])

	for id in sorted:
		var data := lib.get_data(id)
		var is_locked := not lib.is_unlocked(id)
		var qty := model.get_qty(id)
		var tile := _make_tile(id, data, qty, is_locked, _all_grid)
		_all_tile_by_id[id] = tile

func render_selected(all_ids: Array[String], lib: CardLibrary, model: DeckModel) -> void:
	if _sel_grid == null or tile_scene == null:
		return

	_clear_children(_sel_grid)
	_sel_tile_by_id.clear()

	var selected: Array[String] = []
	for id in all_ids:
		if model.get_qty(id) > 0:
			selected.append(id)

	# Sort selected nicely (unlocked only anyway)
	selected.sort()

	_dbg("render_selected: count=%d" % selected.size())

	for id in selected:
		var data := lib.get_data(id)
		var qty := model.get_qty(id)
		var tile := _make_tile(id, data, qty, false, _sel_grid)
		_sel_tile_by_id[id] = tile

func sync_qty(card_id: String, qty: int) -> void:
	# IMPORTANT: this must not emit qty_changed again (silent update)
	if _all_tile_by_id.has(card_id):
		var t1 = _all_tile_by_id[card_id]
		if is_instance_valid(t1):
			t1.set_qty_silent(qty)

	if _sel_tile_by_id.has(card_id):
		var t2 = _sel_tile_by_id[card_id]
		if is_instance_valid(t2):
			t2.set_qty_silent(qty)

func _make_tile(id: String, data: Dictionary, qty: int, locked: bool, parent_grid: GridContainer) -> DeckCardTile:
	var inst := tile_scene.instantiate()
	var tile := inst as DeckCardTile
	parent_grid.add_child(tile)

	# ✅ apply cap here (9 early, 4 later)
	tile.setup(id, data, qty, locked, _max_copies)

	# Wire signals
	if not tile.tile_clicked.is_connected(_on_tile_clicked):
		tile.tile_clicked.connect(_on_tile_clicked)
	if not tile.qty_changed.is_connected(_on_qty_changed):
		tile.qty_changed.connect(_on_qty_changed)

	_dbg("Created tile id=%s qty=%d locked=%s cap=%d" % [id, qty, str(locked), _max_copies])
	return tile

func _on_tile_clicked(card_id: String) -> void:
	tile_clicked.emit(card_id)

func _on_qty_changed(card_id: String, qty: int) -> void:
	qty_changed.emit(card_id, qty)

func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
