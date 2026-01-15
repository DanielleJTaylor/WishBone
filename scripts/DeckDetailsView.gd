# res://scripts/DeckDetailsView.gd
extends PanelContainer
class_name DeckDetailsView

@export var art_path: NodePath
@export var name_path: NodePath
@export var meta_path: NodePath
@export var desc_path: NodePath

var _art: Node
var _name: Label
var _meta: Label
var _desc: RichTextLabel

func _ready() -> void:
	_art = get_node_or_null(art_path)
	_name = get_node_or_null(name_path) as Label
	_meta = get_node_or_null(meta_path) as Label
	_desc = get_node_or_null(desc_path) as RichTextLabel

func show_card(d: Dictionary) -> void:
	var name := String(d.get("name", d.get("id", "")))
	var type := String(d.get("type", "")).to_upper()
	var rank := int(d.get("rank", 0))
	var desc := String(d.get("desc", ""))

	if _name != null:
		_name.text = name
	if _meta != null:
		_meta.text = "R%d • %s" % [rank, type]
	if _desc != null:
		_desc.text = desc

	# Placeholder "art"
	if _art is ColorRect:
		(_art as ColorRect).color = _type_to_color(type)

func _type_to_color(t: String) -> Color:
	match t:
		"ATTACK": return Color(0.85, 0.3, 0.3)
		"DEFENSE": return Color(0.3, 0.75, 0.45)
		"HEALING": return Color(0.3, 0.9, 0.6)
		"CONDITION": return Color(0.95, 0.6, 0.2)
		"HAND": return Color(0.55, 0.35, 0.85)
		"MOVEMENT": return Color(0.25, 0.55, 0.95)
		"SPECIAL": return Color(0.95, 0.85, 0.25)
		_: return Color(0.4, 0.4, 0.4)
