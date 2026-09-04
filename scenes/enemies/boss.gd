class_name Boss
extends CharacterBody2D
## Phase-based boss (A.6): up to two elements, "element A in phase 1, B
## in phase 2." Reuses EnemyCombatAI exactly as PatrolDummy does — the
## boss-specific piece is entirely in _apply_damage()/_enter_phase_2():
## watch health, and the instant it drops below boss_stats'
## phase_transition_health_ratio, swap the active attack element AND
## re-tag ElementalCombatant's own innate_element (so the "self-sustains
## its element" behaviour A.6 already gives every elemental spirit picks
## up the NEW element too, not the old one).
##
## Movement: always chases when aggroed, holds ground otherwise — no
## patrol behaviour (unlike PatrolDummy), since a boss doesn't need one.

signal phase_changed(new_phase: int)

@export var boss_stats: BossStats
@export var flash_duration: float = 0.08

const PHASE_1_TELEGRAPH_TINT: Color = Color(1.0, 0.9, 0.3)
const PHASE_1_SPECIAL_TINT: Color = Color(1.0, 0.5, 0.9)
const PHASE_2_TELEGRAPH_TINT: Color = Color(0.6, 0.9, 1.0)
const PHASE_2_SPECIAL_TINT: Color = Color(0.9, 0.4, 1.0)
const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)
const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)
const DEATH_FADE_DELAY: float = 0.5
const DECEL_WHEN_NOT_CHASING: float = 800.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
@onready var damage_label: Label = $DamageLabel

var elemental := ElementalCombatant.new()
var combat_ai: EnemyCombatAI
var _current_health: float = 0.0
var _is_dead: bool = false
var _current_phase: int = 1

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false
var _is_telegraphing: bool = false
var _telegraph_is_special: bool = false


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color

	elemental.indicator_offset = Vector2(0, -68)
	elemental.armor = boss_stats.armor if "armor" in boss_stats else 10.0
	elemental.innate_element = boss_stats.element  ## Phase 1 starts as boss_stats.element, same field EnemyStats already uses.
	add_child(elemental)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(boss_stats.element, boss_stats.innate_charge if "innate_charge" in boss_stats else 1)

	_current_health = boss_stats.max_health
	add_to_group("enemies")  ## Same group RoomController waits on for a normal enemy.
	add_to_group("bosses")   ## Lets Hud find this specifically, separate from ordinary enemies.
	combat_ai = EnemyCombatAI.new()
	combat_ai.stats = boss_stats
	combat_ai.can_chase = true
	add_child(combat_ai)
	combat_ai.telegraph_started.connect(_on_telegraph_started)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)

	if not _is_flashing:
		visual.set_tint(_resting_color())

	if not is_on_floor():
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity * delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if combat_ai != null and player != null:
		combat_ai.update(delta, player.global_position)

	if elemental.is_disabled():
		velocity.x = 0.0
	elif combat_ai != null and combat_ai.should_chase() and player != null:
		var dir: float = sign(player.global_position.x - global_position.x)
		velocity.x = dir * boss_stats.chase_speed * elemental.get_speed_multiplier()
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECEL_WHEN_NOT_CHASING)  ## Holds ground — no patrol behaviour, unlike PatrolDummy.

	move_and_slide()


func _resting_color() -> Color:
	if _is_telegraphing:
		if _current_phase == 1:
			return PHASE_1_SPECIAL_TINT if _telegraph_is_special else PHASE_1_TELEGRAPH_TINT
		return PHASE_2_SPECIAL_TINT if _telegraph_is_special else PHASE_2_TELEGRAPH_TINT
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
	if _is_dead:
		return

	_current_health -= amount
	if _current_health <= 0.0:
		_die()
		return

	if _current_phase == 1 and boss_stats.phase_2_element != Elements.NONE:
		if _current_health <= boss_stats.max_health * boss_stats.phase_transition_health_ratio:
			_enter_phase_2()


## A.6's phase swap: re-tags the boss's own self-sustaining element (so
## future natural recharges — see ElementalCombatant.tick() — carry the
## NEW element, not the old one), forces the status onto phase 2's
## element immediately (bypassing reaction resolution — this is a
## scripted phase shift, not a reaction, same reasoning as Stoneguard's
## self-apply), and retargets EnemyCombatAI's own attack element/speed.
func _enter_phase_2() -> void:
	_current_phase = 2
	print("Boss enters Phase 2 — element shifts to ", boss_stats.phase_2_element)

	elemental.innate_element = boss_stats.phase_2_element
	elemental.status.apply(boss_stats.phase_2_element, elemental.innate_charge)

	combat_ai.element_override = boss_stats.phase_2_element
	combat_ai.attack_cooldown_multiplier = boss_stats.phase_2_attack_cooldown_multiplier

	phase_changed.emit(_current_phase)

## Read by Hud's boss health bar — 0.0 to 1.0.
func get_health_ratio() -> float:
	return clampf(_current_health / boss_stats.max_health, 0.0, 1.0)


## Read by Hud so it stops tracking a boss the instant it dies, rather
## than waiting out DEATH_FADE_DELAY with a stale reference.
func is_dead() -> bool:
	return _is_dead

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
	if not _is_dead:
		visual.set_tint(_resting_color())


func _on_telegraph_started(is_special: bool) -> void:
	_is_telegraphing = true
	_telegraph_is_special = is_special
	var total := (boss_stats.special_telegraph_duration if is_special else boss_stats.telegraph_duration) + boss_stats.active_window
	await get_tree().create_timer(total).timeout
	_is_telegraphing = false
