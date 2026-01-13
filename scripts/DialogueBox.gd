extends CanvasLayer
class_name DialogueBox

signal finished
signal advanced(idx: int)

@onready var root_ui     : Control         = $RootUI
@onready var pad         : MarginContainer = $RootUI/Pad
@onready var text_box    : Control         = $RootUI/Pad/TextBox
@onready var inner_pad   : MarginContainer = $RootUI/Pad/TextBox/InnerPad
@onready var row         : HBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row
@onready var portrait_wr : Control         = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap
@onready var portrait    : TextureRect     = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/Portrait
@onready var emoji_bub   : Panel           = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/EmojiBubble
@onready var emoji_lbl   : Label           = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/EmojiBubble/Emoji
@onready var tail        : Control       = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/Tail
@onready var right_col   : VBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol
@onready var header      : HBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Header
@onready var name_lbl    : Label           = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Header/Name
@onready var dialogue    : RichTextLabel   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Dialogue
@onready var hint_lbl    : Label           = $RootUI/Pad/TextBox/InnerPad/Hint

var lines: Array = []
var idx: int = -1
var typing := false
var cps := 30.0
var tween: Tween
var type_tween: Tween
var panel_height := 260

func _enter_tree() -> void:
	if not InputMap.has_action("cutscene_advance"):
		InputMap.add_action("cutscene_advance")
		var ev := InputEventKey.new()
		ev.keycode = KEY_X
		InputMap.action_add_event("cutscene_advance", ev)
	if not InputMap.has_action("cutscene_skip"):
		InputMap.add_action("cutscene_skip")
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_ESCAPE
		InputMap.action_add_event("cutscene_skip", ev2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_enforce_layout()
	_apply_bubble_style()
	hint_lbl.modulate.a = 0.0

func _enforce_layout() -> void:
	# Fill screen + bottom dock
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)

	text_box.custom_minimum_size = Vector2(0, panel_height)
	text_box.size_flags_horizontal = Control.SIZE_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_END

	inner_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_pad.add_theme_constant_override("margin_left", 24)
	inner_pad.add_theme_constant_override("margin_right", 24)
	inner_pad.add_theme_constant_override("margin_top", 16)
	inner_pad.add_theme_constant_override("margin_bottom", 16)

	# Row
	row.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	row.size_flags_vertical = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 24)

	# Portrait block – a bit taller than the dialogue column
	portrait_wr.custom_minimum_size = Vector2(220, 220)
	portrait_wr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_wr.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.modulate.a = 1.0
	portrait.visible = true
	portrait_wr.visible = true

	# Emoji bubble position (up+right 40px from portrait top-right)
	var bubble_size := Vector2(80, 80)
	emoji_bub.z_index = 10
	emoji_bub.anchor_left = 1.0
	emoji_bub.anchor_right = 1.0
	emoji_bub.anchor_top = 0.0
	emoji_bub.anchor_bottom = 0.0
	emoji_bub.custom_minimum_size = bubble_size
	emoji_bub.offset_left = -bubble_size.x + 40.0
	emoji_bub.offset_top = -40.0

	# Tail: thin rectangle “stem” pointing down toward portrait
	tail.color = Color(1, 1, 1)
	tail.anchor_left = 0.5
	tail.anchor_right = 0.5
	tail.anchor_top = 1.0
	tail.anchor_bottom = 1.0
	tail.offset_left = -4.0
	tail.offset_right = 4.0
	tail.offset_top = 0.0
	tail.offset_bottom = 32.0

	# Emoji label itself
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	emoji_lbl.add_theme_font_size_override("font_size", 32)

	# Text column
	right_col.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	right_col.size_flags_vertical   = Control.SIZE_FILL
	right_col.add_theme_constant_override("separation", 6)

	dialogue.bbcode_enabled = true
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue.scroll_active = false
	dialogue.fit_content = false
	dialogue.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	dialogue.size_flags_vertical   = Control.SIZE_FILL
	dialogue.custom_minimum_size = Vector2(0, 140)
	dialogue.add_theme_font_size_override("normal_font_size", 28)

func _apply_bubble_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_color = Color(0.0, 0.15, 0.35)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	emoji_bub.add_theme_stylebox_override("panel", sb)

func play(_lines: Array) -> void:
	lines = _lines
	idx = -1
	_advance()

func _advance() -> void:
	if typing:
		if type_tween and type_tween.is_running():
			type_tween.kill()
		dialogue.visible_ratio = 1.0
		typing = false
		_hint(true)
		return

	idx += 1
	if idx >= lines.size():
		finished.emit()
		queue_free()
		return

	_hint(false)
	_show(lines[idx])
	advanced.emit(idx)

func _show(line: Dictionary) -> void:
	# Header
	name_lbl.text = str(line.get("speaker", ""))
	emoji_lbl.text = str(line.get("mood", ""))

	# PORTRAIT ------------- IMPORTANT PART
	var p := str(line.get("portrait_path", ""))
	if not p.is_empty() and ResourceLoader.exists(p, "Texture2D"):
		var tex := ResourceLoader.load(p) as Texture2D
		if tex:
			portrait.texture = tex
			portrait_wr.visible = true
		else:
			push_warning("Portrait load failed (null texture): %s" % p)
			portrait.texture = null
			portrait_wr.visible = false
	else:
		if not p.is_empty():
			push_warning("Portrait not found: %s" % p)
		portrait.texture = null
		portrait_wr.visible = false
	# -----------------------

	# Text + typewriter
	dialogue.bbcode_enabled = true
	dialogue.bbcode_text = str(line.get("text", ""))
	dialogue.visible_ratio = 0.0

	if type_tween and type_tween.is_running():
		type_tween.kill()

	var total := max(1, dialogue.get_total_character_count())
	var duration := max(0.05, float(total) / cps)

	typing = true
	type_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	type_tween.tween_property(dialogue, "visible_ratio", 1.0, duration)
	type_tween.finished.connect(func():
		typing = false
		_hint(true)
	)

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("cutscene_advance"):
			_advance()
		elif e.is_action_pressed("cutscene_skip"):
			finished.emit()
			queue_free()

func _hint(show: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if show:
		hint_lbl.scale = Vector2.ONE
		hint_lbl.modulate.a = 0.0
		tween.tween_property(hint_lbl, "modulate:a", 1.0, 0.18)
		tween.tween_property(hint_lbl, "scale", Vector2(1.05, 1.05), 0.08)
		tween.tween_property(hint_lbl, "scale", Vector2.ONE, 0.08)
	else:
		tween.tween_property(hint_lbl, "modulate:a", 0.0, 0.12)
