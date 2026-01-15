# res://scripts/LevelSelect.gd
extends Node
class_name LevelSelect

const DB_SCRIPT := preload("res://scripts/LevelDatabase.gd")

# ------------------------------------------------------------
# NodePaths (set in Inspector OR we auto-resolve by fallback paths)
# ------------------------------------------------------------
@export var back_button_path: NodePath
@export var enemy_name_label_path: NodePath
@export var enemy_desc_label_path: NodePath
@export var levels_row_path: NodePath
@export var start_button_path: NodePath

@export var intro_button_path: NodePath
@export var chips_button_path: NodePath
@export var raven_button_path: NodePath
@export var cats_button_path: NodePath
@export var nutso_button_path: NodePath
@export var toad_button_path: NodePath
@export var ratsy_button_path: NodePath
@export var one_eye_button_path: NodePath

# ------------------------------------------------------------
# Hard fallback paths (from your message)
# ------------------------------------------------------------
const FALLBACK_BACK_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/LeftHeaderRow/BackButton")
const FALLBACK_INTRO_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Intro/PanelContainer/TextureButton")
const FALLBACK_CHIPS_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_Chips/PanelContainer/TextureButton")
const FALLBACK_CATS_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_Cats/PanelContainer/TextureButton")
const FALLBACK_NUTSO_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_Nutso/PanelContainer/TextureButton")
const FALLBACK_TOAD_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_Toad/PanelContainer/TextureButton")
const FALLBACK_RATSY_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_Ratsy/PanelContainer/TextureButton")
const FALLBACK_ONE_EYE_BUTTON := NodePath("SafeArea/MainRow/LeftPanel/LeftPadding/LeftContent/EnemyGrid/Enemy_One-Eye/PanelContainer/TextureButton")

const FALLBACK_ENEMY_NAME := NodePath("SafeArea/MainRow/RightPanel/MarginContainer/RightContent/EnemyName")
const FALLBACK_ENEMY_DESC := NodePath("SafeArea/MainRow/RightPanel/MarginContainer/RightContent/DetailRow/EnemyDesc")
const FALLBACK_START_BUTTON := NodePath("SafeArea/MainRow/RightPanel/MarginContainer/RightContent/StartButton")

# ------------------------------------------------------------
# Style resources (you already have these)
# ------------------------------------------------------------
const ENEMY_SLOT_NORMAL := "res://themes/enemy_slot_normal.tres"
const ENEMY_SLOT_HOVER := "res://themes/enemy_slot_hover.tres"
const ENEMY_SLOT_SELECTED := "res://themes/enemy_slot_selected.tres"

const LEVEL_BADGE_NORMAL := "res://themes/normallevelbadge.tres"
const LEVEL_BADGE_HOVER := "res://themes/hoverlevelbadge.tres"
const LEVEL_BADGE_PRESSED := "res://themes/pressedlevelbadge.tres"

# ------------------------------------------------------------
# Cached nodes
# ------------------------------------------------------------
var _enemy_name_label: Label
var _enemy_desc_label: Label
var _levels_row: Control
var _start_button: BaseButton
var _back_button: BaseButton

var _enemy_buttons: Dictionary = {} # enemy_id -> BaseButton
var _enemy_slots: Dictionary = {}   # enemy_id -> PanelContainer

class BadgeRefs:
	var btn: Button
	var panel: PanelContainer
	var label: Label
	var level_num: int
	func _init(b: Button, p: PanelContainer, l: Label, n: int) -> void:
		btn = b
		panel = p
		label = l
		level_num = n

var _badges: Array[BadgeRefs] = []

# Styles
var _slot_style_normal: StyleBox
var _slot_style_hover: StyleBox
var _slot_style_selected: StyleBox

var _badge_panel_normal: StyleBox
var _badge_panel_hover: StyleBox
var _badge_panel_pressed: StyleBox

var _badge_panel_available_white: StyleBox
var _badge_panel_locked_dark: StyleBox
var _badge_panel_selected_highlight: StyleBox

# ------------------------------------------------------------
# DB instance
# ------------------------------------------------------------
var _db: LevelDatabase

# ------------------------------------------------------------
# State
# ------------------------------------------------------------
var selected_enemy_id: String = LevelDatabase.ENEMY_CHIPS
var selected_level: int = 1
var _selected_enemy_slot: PanelContainer = null

# enemy_id -> highest completed level (0 = none)
var _completed_levels: Dictionary = {}

# ------------------------------------------------------------
# Ready
# ------------------------------------------------------------
func _ready() -> void:
	_db = DB_SCRIPT.new()

	_resolve_core_nodes()
	_load_styles()
	_build_derived_badge_styles()

	_cache_enemy_buttons_and_slots()
	_cache_level_badges()

	_connect_back()
	_connect_enemy_buttons()
	_connect_level_badges()
	_connect_start()

	_select_enemy(LevelDatabase.ENEMY_CHIPS)
	_select_level(1)

# ------------------------------------------------------------
# SceneTree safety (fixes get_tree() null)
# ------------------------------------------------------------
func _tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	if _start_button != null and _start_button.is_inside_tree():
		return _start_button.get_tree()
	if _back_button != null and _back_button.is_inside_tree():
		return _back_button.get_tree()
	return null

# ------------------------------------------------------------
# Resolve paths (Inspector OR fallback)
# ------------------------------------------------------------
func _resolve_core_nodes() -> void:
	# Labels
	var name_path := enemy_name_label_path if enemy_name_label_path != NodePath() else FALLBACK_ENEMY_NAME
	var desc_path := enemy_desc_label_path if enemy_desc_label_path != NodePath() else FALLBACK_ENEMY_DESC
	_enemy_name_label = get_node_or_null(name_path) as Label
	_enemy_desc_label = get_node_or_null(desc_path) as Label

	# Levels row is optional (only if you have LevelBadge buttons)
	if levels_row_path != NodePath():
		_levels_row = get_node_or_null(levels_row_path) as Control
	else:
		_levels_row = null

	# Buttons
	var back_path := back_button_path if back_button_path != NodePath() else FALLBACK_BACK_BUTTON
	var start_path := start_button_path if start_button_path != NodePath() else FALLBACK_START_BUTTON
	_back_button = get_node_or_null(back_path) as BaseButton
	_start_button = get_node_or_null(start_path) as BaseButton

	if _enemy_name_label == null:
		push_warning("LevelSelect: EnemyName label not found at %s" % str(name_path))
	if _enemy_desc_label == null:
		push_warning("LevelSelect: EnemyDesc label not found at %s" % str(desc_path))
	if _back_button == null:
		push_warning("LevelSelect: BackButton not found at %s" % str(back_path))
	if _start_button == null:
		push_warning("LevelSelect: StartButton not found at %s" % str(start_path))

# ------------------------------------------------------------
# Robust style loading
# ------------------------------------------------------------
func _load_stylebox(path: String, theme_type: String, theme_item: String) -> StyleBox:
	var res := load(path)
	if res == null:
		push_warning("Missing style resource: %s" % path)
		return null

	if res is StyleBox:
		return res as StyleBox

	if res is Theme:
		var t := res as Theme
		if t.has_stylebox(theme_item, theme_type):
			return t.get_stylebox(theme_item, theme_type)
		push_warning("Theme %s missing stylebox %s/%s" % [path, theme_type, theme_item])
		return null

	push_warning("Unsupported resource type at %s" % path)
	return null

func _load_styles() -> void:
	_slot_style_normal = _load_stylebox(ENEMY_SLOT_NORMAL, "PanelContainer", "panel")
	_slot_style_hover = _load_stylebox(ENEMY_SLOT_HOVER, "PanelContainer", "panel")
	_slot_style_selected = _load_stylebox(ENEMY_SLOT_SELECTED, "PanelContainer", "panel")

	_badge_panel_normal = _load_stylebox(LEVEL_BADGE_NORMAL, "PanelContainer", "panel")
	_badge_panel_hover = _load_stylebox(LEVEL_BADGE_HOVER, "PanelContainer", "panel")
	_badge_panel_pressed = _load_stylebox(LEVEL_BADGE_PRESSED, "PanelContainer", "panel")

func _clone_stylebox(style: StyleBox) -> StyleBox:
	if style == null:
		return null
	return style.duplicate(true)

func _build_derived_badge_styles() -> void:
	_badge_panel_available_white = _clone_stylebox(_badge_panel_normal)
	if _badge_panel_available_white is StyleBoxFlat:
		(_badge_panel_available_white as StyleBoxFlat).bg_color = Color(1, 1, 1, 1)

	_badge_panel_locked_dark = _clone_stylebox(_badge_panel_normal)
	if _badge_panel_locked_dark is StyleBoxFlat:
		var sbl := _badge_panel_locked_dark as StyleBoxFlat
		var base := sbl.bg_color
		if base.a <= 0.01:
			base = Color(0.25, 0.25, 0.25, 1)
		sbl.bg_color = Color(base.r * 0.55, base.g * 0.55, base.b * 0.55, 1)

	_badge_panel_selected_highlight = _clone_stylebox(_badge_panel_available_white)
	if _badge_panel_selected_highlight is StyleBoxFlat:
		var sbs := _badge_panel_selected_highlight as StyleBoxFlat
		sbs.border_width_left = max(6, sbs.border_width_left)
		sbs.border_width_top = max(6, sbs.border_width_top)
		sbs.border_width_right = max(6, sbs.border_width_right)
		sbs.border_width_bottom = max(6, sbs.border_width_bottom)
		sbs.border_color = Color(1.0, 0.74, 0.22, 1.0)

# ------------------------------------------------------------
# Cache enemy buttons + slots
# ------------------------------------------------------------
func _cache_enemy_buttons_and_slots() -> void:
	_enemy_buttons.clear()
	_enemy_slots.clear()

	# Use inspector paths if set, else fallbacks from your scene
	_register_enemy((intro_button_path if intro_button_path != NodePath() else FALLBACK_INTRO_BUTTON), LevelDatabase.ENEMY_INTRO)
	_register_enemy((chips_button_path if chips_button_path != NodePath() else FALLBACK_CHIPS_BUTTON), LevelDatabase.ENEMY_CHIPS)
	_register_enemy((cats_button_path if cats_button_path != NodePath() else FALLBACK_CATS_BUTTON), LevelDatabase.ENEMY_CATS)
	_register_enemy((nutso_button_path if nutso_button_path != NodePath() else FALLBACK_NUTSO_BUTTON), LevelDatabase.ENEMY_NUTSO)
	_register_enemy((toad_button_path if toad_button_path != NodePath() else FALLBACK_TOAD_BUTTON), LevelDatabase.ENEMY_TOAD)
	_register_enemy((ratsy_button_path if ratsy_button_path != NodePath() else FALLBACK_RATSY_BUTTON), LevelDatabase.ENEMY_RATSY)
	_register_enemy((one_eye_button_path if one_eye_button_path != NodePath() else FALLBACK_ONE_EYE_BUTTON), LevelDatabase.ENEMY_ONE_EYE)

	# Raven button path wasn't included in your list; only register if you set it in Inspector
	if raven_button_path != NodePath():
		_register_enemy(raven_button_path, LevelDatabase.ENEMY_RAVEN)

func _register_enemy(btn_path: NodePath, enemy_id: String) -> void:
	if btn_path == NodePath():
		return

	var btn := get_node_or_null(btn_path) as BaseButton
	if btn == null:
		push_warning("Enemy button not found for %s at %s" % [enemy_id, str(btn_path)])
		return

	_enemy_buttons[enemy_id] = btn
	btn.focus_mode = Control.FOCUS_NONE

	# Slot style lives on parent PanelContainer
	var slot := btn.get_parent() as PanelContainer
	if slot == null:
		push_warning("Enemy slot parent PanelContainer not found for %s at %s" % [enemy_id, str(btn_path)])
		return

	_enemy_slots[enemy_id] = slot
	_apply_slot_style(slot, _slot_style_normal)

# ------------------------------------------------------------
# Cache level badges dynamically (optional)
# ------------------------------------------------------------
func _cache_level_badges() -> void:
	_badges.clear()
	if _levels_row == null:
		return

	var found: Array[BadgeRefs] = []
	for child in _levels_row.get_children():
		if child is Button:
			var btn := child as Button
			if not btn.name.begins_with("LevelBadge"):
				continue

			var suffix := btn.name.replace("LevelBadge", "")
			if not suffix.is_valid_int():
				continue
			var level_num := int(suffix)

			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_filter = Control.MOUSE_FILTER_STOP

			var panel := btn.get_node_or_null("PanelContainer") as PanelContainer
			if panel == null:
				push_warning("%s missing PanelContainer child" % btn.name)
				continue

			var label := panel.get_node_or_null("CenterContainer/Label") as Label
			if label == null:
				push_warning("%s missing CenterContainer/Label" % btn.name)
				continue

			_force_children_mouse_ignore(panel)
			_apply_badge_panel_style(panel, _badge_panel_normal)

			found.append(BadgeRefs.new(btn, panel, label, level_num))

	found.sort_custom(func(a: BadgeRefs, b: BadgeRefs) -> bool:
		return a.level_num < b.level_num
	)
	_badges = found

func _force_children_mouse_ignore(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_force_children_mouse_ignore(c)

# ------------------------------------------------------------
# Connections
# ------------------------------------------------------------
func _connect_back() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)

func _connect_enemy_buttons() -> void:
	for enemy_id in _enemy_buttons.keys():
		var btn: BaseButton = _enemy_buttons[enemy_id]
		if not btn.pressed.is_connected(Callable(self, "_on_enemy_pressed")):
			btn.pressed.connect(Callable(self, "_on_enemy_pressed").bind(enemy_id))
		if not btn.mouse_entered.is_connected(Callable(self, "_on_enemy_hover_enter")):
			btn.mouse_entered.connect(Callable(self, "_on_enemy_hover_enter").bind(enemy_id))
		if not btn.mouse_exited.is_connected(Callable(self, "_on_enemy_hover_exit")):
			btn.mouse_exited.connect(Callable(self, "_on_enemy_hover_exit").bind(enemy_id))

func _connect_level_badges() -> void:
	for badge in _badges:
		if not badge.btn.pressed.is_connected(Callable(self, "_on_badge_pressed")):
			badge.btn.pressed.connect(Callable(self, "_on_badge_pressed").bind(badge.level_num))
		if not badge.btn.mouse_entered.is_connected(Callable(self, "_on_badge_hover_enter")):
			badge.btn.mouse_entered.connect(Callable(self, "_on_badge_hover_enter").bind(badge.level_num, badge.panel))
		if not badge.btn.mouse_exited.is_connected(_refresh_level_badges):
			badge.btn.mouse_exited.connect(_refresh_level_badges)

func _connect_start() -> void:
	if _start_button == null:
		return
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)

# ------------------------------------------------------------
# Handlers
# ------------------------------------------------------------
func _on_enemy_pressed(enemy_id: String) -> void:
	_select_enemy(enemy_id)

func _on_enemy_hover_enter(enemy_id: String) -> void:
	var slot: PanelContainer = _enemy_slots.get(enemy_id, null)
	if slot != null and slot != _selected_enemy_slot:
		_apply_slot_style(slot, _slot_style_hover)

func _on_enemy_hover_exit(enemy_id: String) -> void:
	var slot: PanelContainer = _enemy_slots.get(enemy_id, null)
	if slot != null and slot != _selected_enemy_slot:
		_apply_slot_style(slot, _slot_style_normal)

func _on_badge_pressed(level_num: int) -> void:
	if _is_level_locked(selected_enemy_id, level_num):
		return
	_select_level(level_num)

func _on_badge_hover_enter(level_num: int, panel: PanelContainer) -> void:
	if _is_level_locked(selected_enemy_id, level_num):
		return
	if level_num == selected_level:
		return
	_apply_badge_panel_style(panel, _badge_panel_hover if _badge_panel_hover != null else _badge_panel_normal)

# ------------------------------------------------------------
# Selection + UI
# ------------------------------------------------------------
func _select_enemy(enemy_id: String) -> void:
	selected_enemy_id = enemy_id
	selected_level = 1
	_refresh_all()

func _select_level(level_num: int) -> void:
	var max_levels := _db.get_enemy_max_levels(selected_enemy_id)
	selected_level = clamp(level_num, 1, max_levels)
	_refresh_all()

func _refresh_all() -> void:
	_refresh_enemy_header()
	_refresh_enemy_slot_styles()
	_refresh_level_badges()
	_refresh_description()
	_refresh_start_enabled()

func _refresh_enemy_header() -> void:
	if _enemy_name_label != null:
		_enemy_name_label.text = _db.get_enemy_display_name(selected_enemy_id)

func _refresh_description() -> void:
	if _enemy_desc_label != null:
		_enemy_desc_label.text = _db.get_level_description(selected_enemy_id, selected_level)

func _refresh_enemy_slot_styles() -> void:
	_selected_enemy_slot = null
	for enemy_id in _enemy_slots.keys():
		_apply_slot_style(_enemy_slots[enemy_id], _slot_style_normal)

	if _enemy_slots.has(selected_enemy_id):
		_selected_enemy_slot = _enemy_slots[selected_enemy_id]
		_apply_slot_style(_selected_enemy_slot, _slot_style_selected)

# ------------------------------------------------------------
# Level Progression Rules
# ------------------------------------------------------------
func _get_completed_level(enemy_id: String) -> int:
	if _completed_levels.has(enemy_id):
		return int(_completed_levels[enemy_id])
	return 0

func _get_next_playable_level(enemy_id: String) -> int:
	return _get_completed_level(enemy_id) + 1

func _is_level_locked(enemy_id: String, level_num: int) -> bool:
	var max_levels := _db.get_enemy_max_levels(enemy_id)
	if level_num > max_levels:
		return true
	return level_num > _get_next_playable_level(enemy_id)

func _refresh_level_badges() -> void:
	if _badges.is_empty():
		return

	var max_levels := _db.get_enemy_max_levels(selected_enemy_id)
	var completed := _get_completed_level(selected_enemy_id)

	for badge in _badges:
		var level_num := badge.level_num

		var in_range := level_num <= max_levels
		badge.btn.visible = in_range
		if not in_range:
			continue

		var locked := _is_level_locked(selected_enemy_id, level_num)
		badge.btn.disabled = locked

		if level_num <= completed:
			_apply_badge_panel_style(badge.panel, _badge_panel_pressed)
			badge.label.text = "✓"
			badge.label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			continue

		if locked:
			_apply_badge_panel_style(badge.panel, _badge_panel_locked_dark)
			badge.label.text = "🔒"
			badge.label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
			continue

		if level_num == selected_level:
			_apply_badge_panel_style(badge.panel, _badge_panel_selected_highlight)
		else:
			_apply_badge_panel_style(badge.panel, _badge_panel_available_white)

		badge.label.text = "O"
		badge.label.add_theme_color_override("font_color", Color(0, 0, 0, 1))

func _refresh_start_enabled() -> void:
	if _start_button == null:
		return

	var max_levels := _db.get_enemy_max_levels(selected_enemy_id)
	var in_range := selected_level <= max_levels
	var locked := _is_level_locked(selected_enemy_id, selected_level)

	_start_button.disabled = (not in_range) or locked

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------
func _on_back_pressed() -> void:
	var t := _tree()
	if t == null:
		push_error("LevelSelect: Back pressed but no SceneTree (node not inside tree).")
		return

	var scene := "res://scenes/MainTitle.tscn"
	if not ResourceLoader.exists(scene):
		push_error("LevelSelect: Missing scene: %s" % scene)
		return

	var err := t.change_scene_to_file(scene)
	if err != OK:
		push_error("LevelSelect: change_scene_to_file failed: %s" % str(err))



func _on_start_pressed() -> void:
	var t := _tree()
	if t == null:
		push_error("LevelSelect: No SceneTree (node not inside tree).")
		return

	print("[LevelSelect] Start -> enemy=", selected_enemy_id, " level=", selected_level)

	# Send selection to BattleScene
	t.set_meta("selected_enemy_id", selected_enemy_id)
	t.set_meta("selected_level", selected_level)

	# Intro cutscene only on level 1
	if selected_enemy_id == LevelDatabase.ENEMY_INTRO and selected_level == 1:
		t.change_scene_to_file(LevelDatabase.SCENE_INTRO_CUTSCENE)
		return

	# ALL fights use the same scene
	var scene_path := LevelDatabase.SCENE_BATTLE
	if not ResourceLoader.exists(scene_path):
		push_warning("BattleScene missing: %s" % scene_path)
		return

	var err := t.change_scene_to_file(scene_path)
	if err != OK:
		push_warning("Failed to change scene (%s): %s" % [str(err), scene_path])

# ------------------------------------------------------------
# Style helpers
# ------------------------------------------------------------
func _apply_slot_style(slot: PanelContainer, style: StyleBox) -> void:
	if slot != null and style != null:
		slot.add_theme_stylebox_override("panel", style)

func _apply_badge_panel_style(panel: PanelContainer, style: StyleBox) -> void:
	if panel != null and style != null:
		panel.add_theme_stylebox_override("panel", style)
