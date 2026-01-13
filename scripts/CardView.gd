# res://scripts/CardView.gd
extends BaseCard
class_name CardView

@export_group("Bindings (optional)")
@export var name_label_path: NodePath
@export var desc_label_path: NodePath
@export var art_texture_path: NodePath
@export var type_label_path: NodePath

@export_group("Preview Mode")
@export var preview_mode: bool = false

@export_group("Debug")
@export var debug_enabled_view: bool = true

# ✅ Your confirmed path (relative to CardView root)
const DEFAULT_DESC_REL_PATH := "Overlay/MainVBox/DescArea/DescStack/DarkBox/DarkPadding/DescriptionLabel"

# Optional: common fallbacks for other fields (kept flexible)
const COMMON_NAME_NAMES := ["NameLabel", "TitleLabel", "CardName", "Name"]
const COMMON_TYPE_NAMES := ["TypeLabel", "CardType", "Type"]
const COMMON_ART_NAMES  := ["Art", "ArtTextureRect", "ArtSprite", "Portrait", "PortraitRect"]

var _name_node: Node = null
var _desc_node: Node = null
var _type_node: Node = null
var _art: TextureRect = null

func _dbg_view(msg: String) -> void:
	if debug_enabled_view:
		print("[CardView] ", msg)

func _ready() -> void:
	super._ready()
	_resolve_nodes(true)

	if preview_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		enable_click = false
		enable_zoom = false

	_apply_data_to_ui()

func set_from_data(data: Dictionary) -> void:
	set_data(data)

func set_data(data: Dictionary) -> void:
	super.set_data(data)

	# If data arrives before ready, delay safely
	if not is_node_ready():
		call_deferred("_apply_data_to_ui")
		return

	# Always re-resolve so we never bind the wrong label
	_resolve_nodes(false)
	_apply_data_to_ui()

# -----------------------------
# Node resolution
# -----------------------------
func _resolve_nodes(force: bool) -> void:
	if force:
		_name_node = null
		_desc_node = null
		_type_node = null
		_art = null

	# 1) If user bound NodePaths in inspector, use them
	if _name_node == null and name_label_path != NodePath():
		_name_node = get_node_or_null(name_label_path)
	if _desc_node == null and desc_label_path != NodePath():
		_desc_node = get_node_or_null(desc_label_path)
	if _type_node == null and type_label_path != NodePath():
		_type_node = get_node_or_null(type_label_path)
	if _art == null and art_texture_path != NodePath():
		_art = get_node_or_null(art_texture_path) as TextureRect

	# 2) ✅ Hard fallback to your confirmed description label path
	if _desc_node == null:
		_desc_node = get_node_or_null(DEFAULT_DESC_REL_PATH)

	# 3) Auto-bind other nodes (Label OR RichTextLabel)
	if _name_node == null:
		_name_node = _find_text_node_by_names(COMMON_NAME_NAMES)
	if _type_node == null:
		_type_node = _find_text_node_by_names(COMMON_TYPE_NAMES)
	if _art == null:
		_art = _find_texture_rect_by_names(COMMON_ART_NAMES)

# Replace these function signatures:

func _find_text_node_by_names(names: Array) -> Node:
	for n in names:
		var key := String(n)
		var node := find_child(key, true, false)
		if node != null and (node is Label or node is RichTextLabel):
			return node
	# fallback: first Label/RichTextLabel encountered
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.append(child)
			if child is Label or child is RichTextLabel:
				return child
	return null


func _find_texture_rect_by_names(names: Array) -> TextureRect:
	for n in names:
		var key := String(n)
		var node := find_child(key, true, false)
		if node is TextureRect:
			return node as TextureRect
	# fallback: first TextureRect encountered
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.append(child)
			if child is TextureRect:
				return child as TextureRect
	return null


func _set_text(node: Node, text: String) -> void:
	if node == null:
		return
	if node is Label:
		(node as Label).text = text
	elif node is RichTextLabel:
		(node as RichTextLabel).text = text

# -----------------------------
# Apply Data to UI
# -----------------------------
func _apply_data_to_ui() -> void:
	if not is_node_ready():
		return

	var d := get_data()

	var nm := String(d.get("name", d.get("title", "")))
	var desc := String(d.get("desc", d.get("description", "")))
	var typ := String(d.get("type", ""))

	var eff: Dictionary = d.get("effect", {}) if d.has("effect") else {}
	var kind := String(eff.get("kind", ""))

	var ap := String(d.get("art_path", d.get("art", "")))

	_set_text(_name_node, nm)
	_set_text(_desc_node, desc)
	_set_text(_type_node, typ)

	if _art != null and ap != "":
		var tex := load(ap)
		if tex is Texture2D:
			_art.texture = tex

	_dbg_view("Applied UI id=%s name='%s' desc_len=%d kind='%s' art='%s' desc_node=%s" % [
		get_card_id(),
		nm,
		desc.length(),
		kind,
		ap,
		_desc_node
	])
