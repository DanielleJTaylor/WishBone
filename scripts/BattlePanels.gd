# res://scripts/BattlePanels.gd
extends Node
class_name BattlePanels

@export_group("Top Bar Panels")
@export var hiro_panel_path: NodePath = NodePath("UILayer/Top Bar/HiroPanel")
@export var enemy_panel_path: NodePath = NodePath("UILayer/Top Bar/EnemyPanel")

@export_group("Label Paths inside each panel (relative to the panel root)")
@export var name_label_rel_path: NodePath = NodePath("Frame/Content/Row/VBoxContainer/NameWrap/NameLabel")
@export var turn_label_rel_path: NodePath = NodePath("Frame/Content/Row/VBoxContainer/TurnRow/TurnLabel")
@export var hp_label_rel_path: NodePath = NodePath("Frame/Content/Row/VBoxContainer/HpRow/HpLabel")
@export var portrait_rel_path: NodePath = NodePath("Frame/Content/Row/PortraitBox/Portrait")

@export_group("Debug")
@export var debug_enabled: bool = true

var _hiro_turn: Label = null
var _enemy_turn: Label = null
var _hiro_hp: Label = null
var _enemy_hp: Label = null
var _hiro_name: Label = null
var _enemy_name: Label = null
var _hiro_portrait: TextureRect = null
var _enemy_portrait: TextureRect = null

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[BattlePanels] ", msg)

func _ready() -> void:
	_resolve()

func _resolve() -> void:
	_hiro_turn = null
	_enemy_turn = null
	_hiro_hp = null
	_enemy_hp = null
	_hiro_name = null
	_enemy_name = null
	_hiro_portrait = null
	_enemy_portrait = null

	var hiro_panel: Node = get_node_or_null(hiro_panel_path)
	var enemy_panel: Node = get_node_or_null(enemy_panel_path)

	if hiro_panel == null:
		_dbg("HiroPanel not found at %s" % str(hiro_panel_path))
	else:
		_hiro_turn = hiro_panel.get_node_or_null(turn_label_rel_path) as Label
		_hiro_hp = hiro_panel.get_node_or_null(hp_label_rel_path) as Label
		_hiro_name = hiro_panel.get_node_or_null(name_label_rel_path) as Label
		_hiro_portrait = hiro_panel.get_node_or_null(portrait_rel_path) as TextureRect

	if enemy_panel == null:
		_dbg("EnemyPanel not found at %s" % str(enemy_panel_path))
	else:
		_enemy_turn = enemy_panel.get_node_or_null(turn_label_rel_path) as Label
		_enemy_hp = enemy_panel.get_node_or_null(hp_label_rel_path) as Label
		_enemy_name = enemy_panel.get_node_or_null(name_label_rel_path) as Label
		_enemy_portrait = enemy_panel.get_node_or_null(portrait_rel_path) as TextureRect

	_dbg("Resolved: hiro_turn=%s hiro_hp=%s enemy_turn=%s enemy_hp=%s" % [
		str(_hiro_turn != null),
		str(_hiro_hp != null),
		str(_enemy_turn != null),
		str(_enemy_hp != null)
	])

func set_names(hiro_name: String, enemy_name: String) -> void:
	if _hiro_name == null or _enemy_name == null:
		_resolve()
	if _hiro_name != null:
		_hiro_name.text = hiro_name
	if _enemy_name != null:
		_enemy_name.text = enemy_name

func set_portraits(hiro_tex: Texture2D, enemy_tex: Texture2D) -> void:
	if _hiro_portrait == null or _enemy_portrait == null:
		_resolve()
	if _hiro_portrait != null and hiro_tex != null:
		_hiro_portrait.texture = hiro_tex
	if _enemy_portrait != null and enemy_tex != null:
		_enemy_portrait.texture = enemy_tex

func update_all(
	hiro_turns: int,
	enemy_turns: int,
	hiro_hp_val: int,
	hiro_hp_max: int,
	enemy_hp_val: int,
	enemy_hp_max: int
) -> void:
	if _hiro_turn == null or _enemy_turn == null or _hiro_hp == null or _enemy_hp == null:
		_resolve()

	if _hiro_turn != null:
		_hiro_turn.text = str(hiro_turns)
	if _enemy_turn != null:
		_enemy_turn.text = str(enemy_turns)

	if _hiro_hp != null:
		_hiro_hp.text = "%d/%d" % [hiro_hp_val, hiro_hp_max]
	if _enemy_hp != null:
		_enemy_hp.text = "%d/%d" % [enemy_hp_val, enemy_hp_max]

# Backward compatible
func update_turns(hiro_turns: int, enemy_turns: int) -> void:
	if _hiro_turn == null or _enemy_turn == null:
		_resolve()
	if _hiro_turn != null:
		_hiro_turn.text = str(hiro_turns)
	if _enemy_turn != null:
		_enemy_turn.text = str(enemy_turns)
