class_name PatrolDummy
extends CharacterBody2D
## Moving test target — same reaction handling as TestDummy, plus actual
## movement, now doubling as a chasing melee enemy (A.6) when enemy_stats
## is assigned. Patrols normally until the player enters aggro_range, at
## which point combat_ai takes over movement entirely until the player
## leaves range again.

@export var patrol_speed: float = 60.0
@export var patrol_distance: float = 120.0
@export var flash_duration: float = 0.08
@export var starting_element: StringName = Elements.NONE
@export var starting_charge: int = 1
@export var starting_armor: float = 10.0
@export var enemy_stats: EnemyStats  ## A.6 — null keeps this a pure patrol-and-take-damage target, same as before.

const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)
const TELEGRAPH_TINT: Color = Color(1.0, 0.9, 0.3)
const SPECIAL_TELEGRAPH_TINT: Color = Color(1.0, 0.5, 0.9)

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
@onready var damage_label: Label = $DamageLabel

var elemental := ElementalCombatant.new()
var combat_ai: EnemyCombatAI
var _current_health: float = 0.0
var _is_dead: bool = false

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false
var _is_telegraphing: bool = false
var _telegraph_is_special: bool = false
var _spawn_x: float
var _patrol_direction: int = 1


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color
	_spawn_x = global_position.x

	elemental.indicator_offset = Vector2(0, -52)
	elemental.armor = starting_armor
	elemental.innate_element = starting_element
	add_child(elemental)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(starting_element, starting_charge)

	if enemy_stats != null:
		_current_health = enemy_stats.max_health
		add_to_group("enemies")
		combat_ai = EnemyCombatAI.new()
		combat_ai.stats = enemy_stats
		combat_ai.can_chase = true
		add_child(combat_ai)
		combat_ai.telegraph_started.connect(_on_telegraph_started)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	var _dot_damage := elemental.tick(delta)

	if not _is_flashing:
		visual.set_tint(_resting_color())

	if not is_on_floor():
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity * delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if combat_ai != null and player != null:
		combat_ai.update(delta, player.global_position)

	if combat_ai != null and combat_ai.is_engaged():
		_process_combat_movement(player)
	else:
		_process_patrol()

	move_and_slide()


## Aggroed (chasing, telegraphing, or attacking) — overrides ordinary
## patrol movement entirely, same override relationship
## elemental.is_disabled() already has over patrol below.
func _process_combat_movement(player: Node2D) -> void:
	if elemental.is_disabled():
		velocity.x = 0.0
		return
	if combat_ai.should_chase() and player != null:
		var dir: float = sign(player.global_position.x - global_position.x)
		velocity.x = dir * combat_ai.stats.chase_speed * elemental.get_speed_multiplier()
	else:
		velocity.x = 0.0  ## Telegraphing/attacking/in-range-on-cooldown — holds position.


func _process_patrol() -> void:
	if elemental.is_disabled():
		velocity.x = 0.0
		return

	if global_position.x >= _spawn_x + patrol_distance:
		_patrol_direction = -1
	elif global_position.x <= _spawn_x - patrol_distance:
		_patrol_direction = 1

	velocity.x = _patrol_direction * patrol_speed * elemental.get_speed_multiplier()


func _resting_color() -> Color:
	if _is_telegraphing:
		return SPECIAL_TELEGRAPH_TINT if _telegraph_is_special else TELEGRAPH_TINT
	if elemental.is_disabled():
		return DISABLED_TINT
	if elemental.is_slowed():
		return SLOWED_TINT
	return _base_color


func _on_hurtbox_hit(hit_data: HitData) -> void:
	_apply_damage(hit_data.damage)
	HitStop.freeze(0.05)
	elemental.handle_hit(hit_data)


func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	_total_damage_taken += amount
	damage_label.text = str(int(_total_damage_taken))
	_flash()
	if enemy_stats != null and not _is_dead:
		_current_health -= amount
		if _current_health <= 0.0:
			_die()


const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)
const DEATH_FADE_DELAY: float = 0.3

func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true
	visual.set_tint(DEATH_TINT)
	damage_label.text = "X"
	await get_tree().create_timer(DEATH_FADE_DELAY).timeout
	queue_free()


func _flash() -> void:
	_is_flashing = true
	visual.set_tint(Color.WHITE)
	await get_tree().create_timer(flash_duration).timeout
	_is_flashing = false
	visual.set_tint(_resting_color())


func _on_telegraph_started(is_special: bool) -> void:
	_is_telegraphing = true
	_telegraph_is_special = is_special
	var total := (combat_ai.stats.special_telegraph_duration if is_special else combat_ai.stats.telegraph_duration) + combat_ai.stats.active_window
	await get_tree().create_timer(total).timeout
	_is_telegraphing = false
