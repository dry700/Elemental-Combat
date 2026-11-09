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

@export var boss_name: String = "Boss"
@export var phase_2_element: StringName = Elements.NONE

## Base armor for the boss's ElementalCombatant. Boss-only, so normal
## EnemyStats assets are untouched. Read directly by Boss._ready().
@export var armor: float = 10.0
## Charge of the boss's innate element status (phase 1 and 2).
@export_range(1, 3) var innate_charge: int = 1

signal phase_changed(new_phase: int)
signal wave_triggered(wave_index: int)
signal passive_window_started(duration: float)
signal passive_window_ended(was_early_clear: bool)
signal stunned(duration: float)
signal boss_died

@export var boss_stats: BossStats
@export var flash_duration: float = 0.08

var invulnerable: bool = false:
	set(value):
		invulnerable = value
		if hurtbox != null and not _is_dead:
			hurtbox.invulnerable = invulnerable or is_passive

var is_passive: bool = false:
	set(value):
		is_passive = value
		_set_passive_body_collision_disabled(is_passive)
		if hurtbox != null and not _is_dead:
			hurtbox.invulnerable = invulnerable or is_passive

var is_stunned: bool = false
var retreat_position: Vector2 = Vector2.ZERO
var has_retreat_position: bool = false

const PHASE_1_TELEGRAPH_TINT: Color = Color(1.0, 0.9, 0.3)
const PHASE_1_SPECIAL_TINT: Color = Color(1.0, 0.5, 0.9)
const PHASE_2_TELEGRAPH_TINT: Color = Color(0.6, 0.9, 1.0)
const PHASE_2_SPECIAL_TINT: Color = Color(0.9, 0.4, 1.0)
const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)
const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)
const PASSIVE_TINT: Color = Color(0.65, 0.65, 0.75, 0.8)
const STUNNED_TINT: Color = Color(1.0, 1.0, 0.4)
const DEATH_FADE_DELAY: float = 0.5
const DECEL_WHEN_NOT_CHASING: float = 400.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
const DamagePopup = preload("res://scripts/ui/damage_number.gd")
const BOSS_ATTACK_CONTROLLER_SCRIPT := preload("res://scenes/enemies/boss_attack_controller.gd")
@onready var health_bar: ProgressBar = $HealthBar

var elemental := ElementalCombatant.new()
var combat_ai: EnemyCombatAI
var attack_controller: Node
var _current_health: float = 0.0
var _is_dead: bool = false
var _current_phase: int = 1

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false
var _is_telegraphing: bool = false
var _telegraph_is_special: bool = false
var _special_attack_telegraphing: bool = false
var _stagger_damage_multiplier: float = 1.0
var _passive_timer: float = 0.0
var _passive_flight_started: bool = false
var _body_collision_shape_was_disabled: bool = false
var _stun_timer: float = 0.0
var _next_wave_index: int = 0
var facing: int = 1:
	set(value):
		var new_val := 1 if value >= 0 else -1
		if new_val != facing:
			facing = new_val
			_update_facing()


func _ready() -> void:
	_update_facing()
	_body_collision_shape_was_disabled = body_collision_shape.disabled
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color

	elemental.indicator_offset = Vector2(0, -20)
	if boss_stats != null:
		elemental.armor = boss_stats.armor
		elemental.innate_charge = boss_stats.innate_charge
		elemental.innate_element = boss_stats.element  ## Phase 1 starts as boss_stats.element, same field EnemyStats already uses.
		add_child(elemental)
		elemental.cc_resistance.configure(boss_stats.cc_free_hits, boss_stats.cc_window_seconds)
		elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
		elemental.apply_starting_status(boss_stats.element, boss_stats.innate_charge)

		_current_health = boss_stats.max_health
		health_bar.value = 100.0
		add_to_group("enemies")  ## Same group RoomController waits on for a normal enemy.
		add_to_group("bosses")   ## Lets Hud find this specifically, separate from ordinary enemies.
		combat_ai = EnemyCombatAI.new()
		combat_ai.stats = boss_stats
		combat_ai.can_chase = true
		combat_ai.hit_weight = &"heavy"
		add_child(combat_ai)
		combat_ai.telegraph_started.connect(_on_telegraph_started)
		attack_controller = BOSS_ATTACK_CONTROLLER_SCRIPT.new()
		attack_controller.set("boss", self)
		attack_controller.set("stats", boss_stats)
		add_child(attack_controller)
	else:
		elemental.armor = armor
		elemental.innate_charge = innate_charge
		add_child(elemental)
		health_bar.visible = false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)

	if not _is_flashing:
		visual.set_tint(_resting_color())

	if not is_on_floor() and not is_passive:
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity * delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and not is_passive and not is_stunned:
		var dir_val: float = sign(player.global_position.x - global_position.x)
		if dir_val != 0.0:
			facing = int(dir_val)

	if is_passive:
		_passive_timer -= delta
		if _passive_timer <= 0.0:
			end_passive_window(false)
		else:
			_update_passive_flight(delta)
	elif is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false
			_stagger_damage_multiplier = 1.0
			if combat_ai != null and not is_passive:
				combat_ai.can_chase = true
			if visual != null and not _is_flashing:
				visual.set_tint(_resting_color())
		velocity.x = move_toward(velocity.x, 0.0, DECEL_WHEN_NOT_CHASING)
	else:
		var special_attack_active: bool = false
		if attack_controller != null:
			special_attack_active = attack_controller.call("update", delta, player)
		if combat_ai != null and player != null and not special_attack_active:
			combat_ai.update(delta, player.global_position)

		if special_attack_active:
			pass
		elif elemental.is_disabled():
			velocity.x = 0.0
		elif combat_ai != null and combat_ai.should_chase() and player != null:
			var dir: float = sign(player.global_position.x - global_position.x)
			velocity.x = dir * boss_stats.chase_speed * elemental.get_speed_multiplier()
		else:
			velocity.x = move_toward(velocity.x, 0.0, DECEL_WHEN_NOT_CHASING)  ## Holds ground — no patrol behaviour, unlike PatrolDummy.

	move_and_slide()
	if attack_controller != null:
		attack_controller.call("after_move")


func _update_facing() -> void:
	if visual != null:
		visual.scale.x = absf(visual.scale.x) * facing
	if visual_polygon != null:
		visual_polygon.scale.x = absf(visual_polygon.scale.x) * facing


func _resting_color() -> Color:
	if is_passive:
		return PASSIVE_TINT
	if is_stunned or _stagger_damage_multiplier > 1.0:
		return STUNNED_TINT
	if _is_telegraphing:
		if _current_phase == 1:
			return PHASE_1_SPECIAL_TINT if _telegraph_is_special else PHASE_1_TELEGRAPH_TINT
		return PHASE_2_SPECIAL_TINT if _telegraph_is_special else PHASE_2_TELEGRAPH_TINT
	if _special_attack_telegraphing:
		return PHASE_1_SPECIAL_TINT if _current_phase == 1 else PHASE_2_SPECIAL_TINT
	if elemental.is_disabled():
		return DISABLED_TINT
	if elemental.is_slowed():
		return SLOWED_TINT
	return _base_color


func _on_hurtbox_hit(hit_data: HitData) -> void:
	if invulnerable or is_passive or _is_dead:
		return
	if elemental.try_absorb_hit(hit_data.source):
		var absorbed_weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
		HitStop.freeze_for_weight(absorbed_weight)
		ScreenShake.shake(3.0, 0.12)
		return
	_apply_damage(hit_data.damage, hit_data.perfect)
	var weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
	HitStop.freeze_for_weight(weight)
	ScreenShake.shake_for_weight(weight)
	elemental.handle_hit(hit_data)


func _on_bonus_damage_dealt(amount: float) -> void:
	if invulnerable or is_passive or _is_dead or hurtbox.invulnerable:
		return
	if elemental.try_absorb_hit():
		return
	_apply_damage(amount)


func _apply_damage(amount: float, is_perfect: bool = false) -> void:
	if invulnerable or is_passive or _is_dead:
		return
	if amount <= 0.0:
		return

	var effective_amount := amount * _stagger_damage_multiplier
	var mitigated := elemental.mitigate_damage(effective_amount)
	_total_damage_taken += mitigated
	DamagePopup.spawn(self, mitigated, Vector2(0, -10), is_perfect)
	_flash()

	var new_health: float = _current_health - mitigated

	# Check wave thresholds
	if boss_stats != null and not boss_stats.wave_thresholds.is_empty() and _next_wave_index < boss_stats.wave_thresholds.size():
		var threshold_ratio: float = boss_stats.wave_thresholds[_next_wave_index]
		var threshold_health: float = boss_stats.max_health * threshold_ratio
		if new_health <= threshold_health:
			_current_health = threshold_health
			var triggered_wave: int = _next_wave_index + 1
			_next_wave_index += 1

			_update_health_bar()

			wave_triggered.emit(triggered_wave)

			if _current_phase == 1 and boss_stats.phase_2_element != Elements.NONE and threshold_ratio <= boss_stats.phase_transition_health_ratio:
				_enter_phase_2()

			var passive_dur: float = boss_stats.passive_window_duration if boss_stats.passive_window_duration > 0.0 else 12.0
			enter_passive_window(passive_dur)
			return

	_current_health = new_health
	_update_health_bar()

	if _current_health <= 0.0:
		_die()
		return

	if _current_phase == 1 and boss_stats != null and boss_stats.phase_2_element != Elements.NONE:
		if _current_health <= boss_stats.max_health * boss_stats.phase_transition_health_ratio:
			_enter_phase_2()


func set_retreat_position(pos: Vector2) -> void:
	retreat_position = pos
	has_retreat_position = true


func _update_passive_flight(delta: float) -> void:
	var center_position := retreat_position if has_retreat_position else global_position
	var flight_speed := boss_stats.passive_flight_speed if boss_stats != null else 120.0
	if not _passive_flight_started:
		_move_toward_passive_position(center_position, flight_speed, delta)
		if global_position.distance_to(center_position) <= 4.0:
			_passive_flight_started = true
	else:
		var flight_height := boss_stats.passive_flight_height if boss_stats != null else 100.0
		_move_toward_passive_position(center_position + Vector2.UP * flight_height, flight_speed, delta)


func _move_toward_passive_position(target: Vector2, speed: float, delta: float) -> void:
	var offset := target - global_position
	if offset.length() <= 1.0:
		velocity = Vector2.ZERO
		return
	var movement_speed := minf(speed, offset.length() / maxf(delta, 0.001))
	velocity = offset.normalized() * movement_speed
	if offset.x != 0.0:
		facing = int(signf(offset.x))


func _set_passive_body_collision_disabled(disabled: bool) -> void:
	if body_collision_shape == null:
		return
	body_collision_shape.set_deferred(
		"disabled",
		true if disabled else _body_collision_shape_was_disabled
	)


func enter_passive_window(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = boss_stats.passive_window_duration if boss_stats != null else 12.0
	if attack_controller != null:
		attack_controller.call("cancel_attack")
	is_stunned = false
	_stun_timer = 0.0
	_stagger_damage_multiplier = 1.0
	is_passive = true
	invulnerable = true
	_passive_flight_started = false
	if hurtbox != null and not _is_dead:
		hurtbox.invulnerable = true
	if combat_ai != null:
		combat_ai.interrupt()
		combat_ai.can_chase = false
	_is_telegraphing = false
	_passive_timer = duration
	if not has_retreat_position:
		var anchor := get_tree().get_first_node_in_group("boss_retreat_anchor") as Node2D
		if anchor != null:
			retreat_position = anchor.global_position
			has_retreat_position = true
	passive_window_started.emit(duration)
	if visual != null and not _is_flashing:
		visual.set_tint(_resting_color())


func end_passive_window(was_early_clear: bool = false) -> void:
	if not is_passive:
		return
	is_passive = false
	invulnerable = false
	_passive_flight_started = false
	velocity = Vector2.ZERO
	if hurtbox != null and not _is_dead:
		hurtbox.invulnerable = false
	if combat_ai != null:
		combat_ai.can_chase = true
	passive_window_ended.emit(was_early_clear)
	if was_early_clear:
		var stagger_dur: float = boss_stats.early_clear_stagger_duration if boss_stats != null else 2.0
		var stagger_mult: float = boss_stats.early_clear_damage_multiplier if boss_stats != null else 1.5
		apply_stagger(stagger_dur, stagger_mult)
	elif visual != null and not _is_flashing:
		visual.set_tint(_resting_color())


func apply_stun(duration: float = -1.0, damage_mult: float = -1.0) -> void:
	if duration < 0.0:
		duration = boss_stats.charge_wall_stun_duration if boss_stats != null else 1.5
	if damage_mult < 0.0:
		damage_mult = boss_stats.charge_stun_damage_multiplier if boss_stats != null else 1.5
	if attack_controller != null:
		attack_controller.call("cancel_attack")
	is_stunned = true
	_stun_timer = duration
	_stagger_damage_multiplier = damage_mult
	if combat_ai != null:
		combat_ai.interrupt()
		combat_ai.can_chase = false
	stunned.emit(duration)
	if visual != null and not _is_flashing:
		visual.set_tint(_resting_color())


func apply_stagger(duration: float = -1.0, damage_mult: float = -1.0) -> void:
	if duration < 0.0:
		duration = boss_stats.early_clear_stagger_duration if boss_stats != null else 2.0
	if damage_mult < 0.0:
		damage_mult = boss_stats.early_clear_damage_multiplier if boss_stats != null else 1.5
	apply_stun(duration, damage_mult)


func _update_health_bar() -> void:
	if boss_stats != null and health_bar != null:
		health_bar.value = (_current_health / boss_stats.max_health) * 100.0


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

	if combat_ai != null:
		combat_ai.element_override = boss_stats.phase_2_element
		combat_ai.attack_cooldown_multiplier = boss_stats.phase_2_attack_cooldown_multiplier

	phase_changed.emit(_current_phase)

## Read by Hud's boss health bar — 0.0 to 1.0.
func get_health_ratio() -> float:
	if boss_stats == null or boss_stats.max_health <= 0.0:
		return 0.0
	return clampf(_current_health / boss_stats.max_health, 0.0, 1.0)


func get_passive_time_remaining() -> float:
	return maxf(_passive_timer, 0.0)


func set_attack_telegraph(active: bool) -> void:
	_special_attack_telegraphing = active
	if visual != null and not _is_flashing:
		visual.set_tint(_resting_color())


## Read by Hud so it stops tracking a boss the instant it dies, rather
## than waiting out DEATH_FADE_DELAY with a stale reference.
func is_dead() -> bool:
	return _is_dead

func _die() -> void:
	_is_dead = true
	invulnerable = true
	if attack_controller != null:
		attack_controller.call("cancel_attack")
	boss_died.emit()
	if hurtbox != null:
		hurtbox.invulnerable = true
	visual.set_tint(DEATH_TINT)
	health_bar.visible = false
	if boss_stats != null:
		QiOrb.spawn_burst(get_parent(), global_position, boss_stats.qi_reward)
		if boss_stats.element != Elements.NONE:
			var rune := RunePickup.new()
			rune.set_rune(RuneRoller.default().roll(RunePickup.roll_spirit_element(boss_stats.element), RuneData.Target.WEAPON))
			rune.global_position = global_position
			get_parent().add_child.call_deferred(rune)
		var skill_element := boss_stats.element
		if boss_stats.phase_2_element != Elements.NONE and randf() < 0.5:
			skill_element = boss_stats.phase_2_element
		SkillPickup.spawn_drop(get_parent(), global_position, skill_element)
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
