# res://scripts/BattleCombatant.gd
extends Node2D
class_name BattleCombatant

signal stats_changed
signal took_hit(amount: int) # actual HP damage taken (after shield)
signal shield_changed(new_value: int)
signal stumbled(times: int)

@export var max_hp: int = 10

@export var hp: int = 10:
	set(v):
		hp = clampi(v, 0, max_hp)
		stats_changed.emit()

@export var shield: int = 0:
	set(v):
		shield = max(0, v)
		shield_changed.emit(shield)
		stats_changed.emit()

@export var track_position: int = 0:
	set(v):
		track_position = v
		stats_changed.emit()

# ✅ IMPORTANT:
# Hiro should be -1 (stumble left)
# Enemy should be +1 (stumble right)
@export var stumble_direction: int = -1

# Buff/debuff mods (optional)
var attack_mod: int = 0
var defense_mod: int = 0

# --- Shield UI above head ---
@export var show_shield_ui: bool = true
@export var shield_ui_offset: Vector2 = Vector2(0, -55)

var _shield_ui: Control = null
var _shield_label: Label = null

func _ready() -> void:
	if max_hp <= 0:
		max_hp = 1
	hp = clampi(hp, 0, max_hp)

	if stumble_direction == 0:
		stumble_direction = -1

	if show_shield_ui:
		_build_shield_ui()
	_update_shield_ui()

func _build_shield_ui() -> void:
	_shield_ui = Control.new()
	_shield_ui.name = "ShieldUI"
	add_child(_shield_ui)

	_shield_ui.z_index = 200
	_shield_ui.z_as_relative = true

	var bg := PanelContainer.new()
	bg.name = "Bg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_ui.add_child(bg)

	var h := HBoxContainer.new()
	h.name = "Row"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(h)

	var icon := Label.new()
	icon.name = "Icon"
	icon.text = "🛡"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)

	_shield_label = Label.new()
	_shield_label.name = "Value"
	_shield_label.text = "0"
	_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_shield_label)

	_shield_ui.position = shield_ui_offset

func _update_shield_ui() -> void:
	if _shield_ui == null or _shield_label == null:
		return
	_shield_ui.visible = (shield > 0)
	_shield_label.text = str(shield)

func gain_shield(amount: int) -> void:
	if amount <= 0:
		return
	shield += amount
	_update_shield_ui()

# ------------------------------------------------------------
# ✅ FIXED DAMAGE LOGIC
# - Shield absorbs first
# - Remaining damage can cause MULTIPLE stumbles in one hit
# - Overflow continues after each stumble
# - Final HP is correct (example: 45 dmg on 10 HP => 4 stumbles, end at 5/10)
# ------------------------------------------------------------
func take_damage(amount: int) -> void:
	var remaining: int = int(amount)
	if remaining <= 0:
		return

	# 1) Shield absorbs first (once)
	if shield > 0:
		var absorbed: int = min(shield, remaining)
		shield -= absorbed
		remaining -= absorbed

	# 2) Apply to HP with overflow + multi-stumble
	var stumbles := 0
	while remaining > 0:
		# If we still have HP to burn
		if hp > 0:
			var hp_hit := min(hp, remaining)
			hp -= hp_hit
			remaining -= hp_hit

			if hp_hit > 0:
				took_hit.emit(hp_hit)

		# If HP reached 0 AND we still have damage left, stumble and continue
		if hp <= 0 and remaining > 0:
			stumbles += 1
			_do_stumble_once()
			# after stumble, hp resets to max_hp (done inside), then loop continues to apply remaining
			continue

		# If HP is 0 and no remaining damage, we still stumble once (end-of-hit stumble)
		# (Your old rule: hitting 0 triggers stumble movement when enemies hit 0)
		if hp <= 0 and remaining <= 0:
			stumbles += 1
			_do_stumble_once()
			# no remaining to apply, stop
			break

		# Otherwise done
		break

	if stumbles > 0:
		stumbled.emit(stumbles)

	_update_shield_ui()
	stats_changed.emit()

# ✅ One stumble = move 1 tile in stumble_direction, then reset HP to max
func _do_stumble_once() -> void:
	# Move
	track_position += stumble_direction

	# Reset HP segment
	hp = max_hp

	# Optional: if you want shield wiped on stumble, uncomment:
	# shield = 0

func set_hp_full() -> void:
	hp = max_hp
	stats_changed.emit()
