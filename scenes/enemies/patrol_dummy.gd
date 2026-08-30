class_name PatrolDummy
extends CharacterBody2D
## A moving test target — same reaction handling as TestDummy (via the
## shared ElementalCombatant component), plus actual movement, so
## SlowEffect and DisableEffect have something real to slow or freeze
## instead of only showing through a colour tint. Patrols back and forth
## between two points around its spawn position; that's the entire "AI"
## here — no chasing, no attacking the player yet.

@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 120.0  ## Each direction, from spawn position.
@export var flash_duration: float = 0.08
@export var starting_element: StringName = Elements.NONE
@export var starting_charge: int = 1
@export var starting_armor: float = 10.0

const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Polygon2D = $PlaceholderVisual
@onready var damage_label: Label = $DamageLabel

var elemental := ElementalCombatant.new()

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false
var _spawn_x: float
var _patrol_direction: int = 1


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual.color
	_spawn_x = global_position.x

	elemental.indicator_offset = Vector2(0, -52)
	elemental.armor = starting_armor
	add_child(elemental)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(starting_element, starting_charge)


func _physics_process(delta: float) -> void:
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)

	if not _is_flashing:
		visual.color = _resting_color()

	if not is_on_floor():
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity * delta

	_process_patrol()
	move_and_slide()


func _process_patrol() -> void:
	if elemental.is_disabled():
		velocity.x = 0.0  # Rooted/staggered/stunned — no movement at all,
		return            # not even a slowed crawl.

	if global_position.x >= _spawn_x + patrol_distance:
		_patrol_direction = -1
	elif global_position.x <= _spawn_x - patrol_distance:
		_patrol_direction = 1

	velocity.x = _patrol_direction * patrol_speed * elemental.get_speed_multiplier()


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
