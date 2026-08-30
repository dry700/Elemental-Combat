class_name TestDummy
extends StaticBody2D
## Sprint 2 elemental reaction test target. Static (StaticBody2D), so
## SlowEffect/DisableEffect only ever show as a colour tint here, not
## actual movement — see PatrolDummy for a moving target that shows both
## for real. All reaction logic now lives in ElementalCombatant (composed,
## not inherited — StaticBody2D and CharacterBody2D don't share a useful
## common ancestor); this script is just visuals + raw damage bookkeeping.

@export var flash_duration: float = 0.08
@export var starting_element: StringName = Elements.KIM
@export var starting_charge: int = 1
@export var starting_armor: float = 10.0

## Pale blue while SlowEffect is active — TestDummy is a StaticBody2D and
## never moves, so this tint is the only visible confirmation a slow
## (Condensation, Silt) actually landed.
const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
## Orange while DisableEffect (stagger/stun/root) is active. Takes priority
## over the slow tint if both happen to be active — "can't act" reads as
## the more severe state.
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Polygon2D = $PlaceholderVisual
@onready var damage_label: Label = $DamageLabel

var elemental := ElementalCombatant.new()

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual.color

	elemental.indicator_offset = Vector2(0, -52)  ## Above the DamageLabel (-36..-16).
	elemental.armor = starting_armor
	add_child(elemental)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(starting_element, starting_charge)


func _physics_process(_delta: float) -> void:
	var dot_damage := elemental.tick(_delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)

	if not _is_flashing:
		visual.color = _resting_color()


func _resting_color() -> Color:
	if elemental.is_disabled():
		return DISABLED_TINT
	if elemental.is_slowed():
		return SLOWED_TINT
	return _base_color


func _on_hurtbox_hit(hit_data: HitData) -> void:
	_apply_damage(hit_data.damage)
	HitStop.freeze(0.05)
	elemental.handle_hit(hit_data)


## Wildfire's chain (A.7 Link) landed on this dummy.
func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	_total_damage_taken += amount
	damage_label.text = str(int(_total_damage_taken))
	_flash()


func _flash() -> void:
	_is_flashing = true
	visual.color = Color.WHITE
	await get_tree().create_timer(flash_duration).timeout
	_is_flashing = false
	visual.color = _resting_color()
