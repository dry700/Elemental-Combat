class_name Player
extends CharacterBody2D
## Sprint 1 core combat controller — movement, jump, dodge, and a single
## test attack. Deliberately has NO elemental system wired in yet; that's
## Sprint 2+ (Appendix A.2/A.3). The goal here is combat *feel* per Swink
## (2009): responsive input, readable states, and hit feedback that sells
## weight — tune these starting numbers via actual playtesting (Section 8),
## don't take them as final.

enum State { IDLE, RUN, JUMP, FALL, DODGE, ATTACK, DISABLED }

## --- Movement tuning (starting points) ---
@export var max_speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var air_acceleration: float = 900.0
@export var jump_velocity: float = -420.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var max_air_jumps: int = 1

## --- Dodge tuning ---
@export var dodge_speed: float = 420.0
@export var dodge_duration: float = 0.22
@export var dodge_cooldown: float = 0.4
## i-frames only cover part of the dodge, not the whole thing — a
## full-duration invuln window is what makes dodge-spam degenerate.
@export var dodge_iframe_window: Vector2 = Vector2(0.0, 0.16)

## --- Attack ---
@export var weapon: WeaponStats
@export var secondary_weapon: WeaponStats  ## DEBUG ONLY — for testing Sinh with two elements.
@export var attack_lunge_speed: float = 150.0

@export var skill_1: SkillData
@export var skill_2: SkillData

## --- Health (didn't exist before — DoT needs something real to damage) ---
@export var max_health: float = 100.0
var current_health: float
@export var starting_armor: float = 10.0

@onready var visuals: Node2D = $Visuals
@onready var hitbox: Hitbox = $Visuals/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

var state: State = State.IDLE
var facing: int = 1  ## 1 = right, -1 = left
## All elemental reaction state (status/DoT/Slow/Disable/armor/element
## indicator/Overgrowth-Link) lives in this composed component now,
## shared with TestDummy and PatrolDummy — see elemental_combatant.gd.
var elemental := ElementalCombatant.new()
var _active_weapon: WeaponStats

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _drop_through_timer: float = 0.0
var _skill_cooldowns: Dictionary = {}  ## SkillData -> remaining cooldown seconds
## Set on ANY jump-key press during State.DISABLED (however early in the
## stagger/stun/root it happens), consumed the instant the disable ends.
## Exists because the ordinary jump buffer (jump_buffer_time, ~0.1s) is
## tuned for "pressed just before landing" — a much shorter window than
## "pressed at some point during a disable that might run another second
## or more via floor-clamped natural decay after Break-Free bottoms out
## (see DisableEffect.reduce_duration)." Without this, mashing space
## early or mid-stagger (which is the natural way to "press quickly")
## does nothing for jumping once recovery actually lands, because that
## press is long past its 0.1s window by then — reads as the character
## refusing to jump right when control visibly returns.
var _wants_jump_on_recovery: bool = false

const ONE_WAY_PLATFORM_LAYER: int = 3  ## Must match Platform's Collision Layer in the editor.
@export var drop_through_duration: float = 0.25  ## Long enough to fall clear of the platform.

func _ready() -> void:
	add_to_group("player")  # Lets VisionBlocker (Douse's steam cloud, A.2) find the player generically.
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	current_health = max_health
	if weapon == null:
		weapon = WeaponStats.new()  # Fallback so the scene still runs unassigned.

	elemental.indicator_offset = Vector2(0, -26)
	elemental.armor = starting_armor
	add_child(elemental)  # Added to Player root, not Visuals — Visuals
	# flips scale.x for facing, which would mirror the glyph shape unreadable.
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.disabled_expired.connect(_on_disabled_expired)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_try_debug_test_effects()
	_try_start_drop_through()

	if elemental.is_disabled() and state not in [State.DODGE, State.ATTACK]:
		state = State.DISABLED
	# No elif here anymore — escaping DISABLED happens in _on_disabled_expired,
	# fired the instant elemental.disabled_expired emits, not polled here.

	match state:
		State.IDLE, State.RUN:
			_handle_move_and_jump(delta)
			_try_start_dodge()
			_try_start_attack()
			_try_cast_skill(skill_1, "skill_1")
			_try_cast_skill(skill_2, "skill_2")
			if state == State.IDLE or state == State.RUN:
				state = State.RUN if abs(velocity.x) > 10.0 else State.IDLE
		State.JUMP, State.FALL:
			_handle_move_and_jump(delta)
			_try_start_dodge()
			_try_start_attack()
			_try_cast_skill(skill_1, "skill_1")
			_try_cast_skill(skill_2, "skill_2")
			if state == State.JUMP or state == State.FALL:
				state = State.JUMP if velocity.y < 0.0 else State.FALL
		State.DODGE:
			_process_dodge(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DISABLED:
			_process_disabled(delta)

	if is_on_floor() and state in [State.JUMP, State.FALL]:
		state = State.IDLE

	move_and_slide()
	_update_facing()


func _update_timers(delta: float) -> void:
	_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	_dodge_cooldown_timer = max(_dodge_cooldown_timer - delta, 0.0)
	for skill in _skill_cooldowns.keys():
		_skill_cooldowns[skill] = maxf(_skill_cooldowns[skill] - delta, 0.0)
	
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)

	# Capturing the jump press here — unconditionally, every frame,
	# regardless of state — rather than inside _handle_move_and_jump()
	# is deliberate: Break-Free reuses the jump key while State.DISABLED,
	# and _handle_move_and_jump() never runs during DISABLED. Without
	# this living somewhere state-independent, the very presses the
	# player is spamming to escape a stagger/stun/root were silently
	# discarded, and recovery only felt responsive if a *fresh* press
	# happened to land within the 0.1s buffer window right after control
	# returned — otherwise jump felt dead for a beat, reading as "stuck
	# to the ground" even though the disable had already ended. Now a
	# Break-Free mash naturally buffers into a jump the instant control
	# returns, the same way landing-buffer already worked for platforming.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		current_health = maxf(current_health - dot_damage, 0.0)
		print("Player DoT tick: -", dot_damage, " (", current_health, "/", max_health, " HP)")

	if is_on_floor():
		_coyote_timer = coyote_time
		_air_jumps_used = 0


func _apply_gravity(delta: float) -> void:
	if state == State.DODGE:
		return  # Dodge overrides normal vertical movement entirely.
	if not is_on_floor():
		var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += gravity * delta


func _handle_move_and_jump(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var accel := acceleration if is_on_floor() else air_acceleration
	var effective_max_speed := max_speed * elemental.get_speed_multiplier()

	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * effective_max_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Buffered + coyote jump: a jump press just before landing, just after
	# walking off a ledge, or (now) during a Break-Free mash, still
	# registers — see _update_timers for where the press is actually
	# captured, and why it lives there instead of here.
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			state = State.JUMP
		elif _air_jumps_used < max_air_jumps:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_air_jumps_used += 1
			state = State.JUMP
			
func _try_start_drop_through() -> void:
	if Input.is_action_just_pressed("drop_down") and is_on_floor():
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
		_drop_through_timer = drop_through_duration


func _try_start_dodge() -> void:
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		state = State.DODGE
		_dodge_timer = 0.0
		_dodge_cooldown_timer = dodge_cooldown
		velocity = Vector2(facing * dodge_speed, 0.0)


func _process_dodge(delta: float) -> void:
	_dodge_timer += delta
	var in_iframe_window := _dodge_timer >= dodge_iframe_window.x and _dodge_timer <= dodge_iframe_window.y
	hurtbox.invulnerable = in_iframe_window

	if _dodge_timer >= dodge_duration:
		hurtbox.invulnerable = false
		state = State.IDLE if is_on_floor() else State.FALL


func _try_start_attack() -> void:
	if Input.is_action_just_pressed("attack"):
		_active_weapon = weapon
		state = State.ATTACK
		_attack_timer = 0.0
	elif Input.is_action_just_pressed("attack_secondary") and secondary_weapon != null:
		_active_weapon = secondary_weapon
		state = State.ATTACK
		_attack_timer = 0.0


func _process_attack(delta: float) -> void:
	_attack_timer += delta

	var active_start: float = _active_weapon.active_window.x
	var active_end: float = _active_weapon.active_window.y

	if _attack_timer < active_start:
		velocity.x = move_toward(velocity.x, facing * attack_lunge_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if _attack_timer >= active_start and _attack_timer < active_end:
		if not hitbox.monitoring:
			hitbox.damage = _active_weapon.damage
			hitbox.weapon_weight = StringName(WeaponStats.Weight.keys()[_active_weapon.weight].to_lower())
			var swing := _active_weapon.resolve_swing()
			hitbox.element = swing.element
			hitbox.charge = swing.charge
			hitbox.enable()
	else:
		hitbox.disable()

	if _attack_timer >= _active_weapon.attack_duration:
		hitbox.disable()
		state = State.IDLE if is_on_floor() else State.FALL


func _process_disabled(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# No movement/action input handled here — that's the point of being
	# disabled. Break-Free presses are handled separately in
	# _unhandled_input, not here, since they're event-based (need the
	# raw .echo flag) rather than a per-frame poll like everything else
	# in this method.


## DEBUG ONLY — applies a test Slow + Disable + DoT to the player at once,
## so all three shared components can be verified without needing a real
## reaction wired to them yet. Remove once actual reactions call these.
func _try_debug_test_effects() -> void:
	if Input.is_action_just_pressed("debug_test_effects"):
		print("DEBUG: applying test Slow/Disable/DoT to player")
		elemental.debug_apply_test_effects()

## Q/E skill casting (A.5). Both slots share one dispatcher rather than
## duplicating per-slot logic — mirrors how weapon/secondary_weapon
## already share _process_attack via _active_weapon.
func _try_cast_skill(skill: SkillData, action_name: String) -> void:
	if skill == null:
		return
	if not Input.is_action_just_pressed(action_name):
		return
	if _skill_cooldowns.get(skill, 0.0) > 0.0:
		print("Skill on cooldown: ", skill.skill_name, " (", "%.1f" % _skill_cooldowns[skill], "s left)")
		return

	var charge := _resolve_skill_charge(skill)

	match skill.function:
		SkillData.Function.APPLY_SELF:
			elemental.cast_apply_self(skill.element, charge)
		SkillData.Function.REMOVE_APPLY_SELF:
			elemental.cast_cleanse_and_apply_self(skill.element, charge)
		SkillData.Function.APPLY_SINGLE_TARGET:
			var target := _find_skill_target(skill.cast_range)
			if target != null:
				elemental.cast_apply_enemy(target, skill.element, charge)
		SkillData.Function.REMOVE_ENEMY:
			var enemy_target := _find_skill_target(skill.cast_range)
			if enemy_target != null:
				elemental.cast_remove_enemy(enemy_target)
		SkillData.Function.APPLY_AREA:
			elemental.cast_apply_area(skill.element, skill.zone_radius, skill.zone_lifetime)

	_skill_cooldowns[skill] = skill.cooldown
	print("Cast ", skill.skill_name)


## A.3's rune-to-skill bonus: a same-element rune's +1 Charge applies to
## any equipped skill sharing that element too, checked against either
## weapon slot — "one bonus, not two", so this returns on the first match
## rather than stacking. Base 2 matches A.4's Active Skill Charge row.
func _resolve_skill_charge(skill: SkillData) -> int:
	for w in [weapon, secondary_weapon]:
		if w == null:
			continue
		if w.rune_element != &"none" and w.rune_element == w.innate_element and w.innate_element == skill.element:
			return 3
	return 2


## No aim/targeting system exists anywhere else in this project (same
## reasoning as SkillData.cast_range) — "target" is the nearest OTHER
## combatant within range, enough to test Ignite Dart/Rending Edge
## against the arena's dummies.
func _find_skill_target(max_range: float) -> ElementalCombatant:
	var nearest: ElementalCombatant = null
	var nearest_dist := max_range
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == elemental:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= nearest_dist:
			nearest = other
			nearest_dist = dist
	return nearest

func _update_facing() -> void:
	if state in [State.DODGE, State.ATTACK]:
		return  # Don't flip mid-action — avoids the hitbox flipping under an active swing.
	if velocity.x > 5.0:
		facing = 1
	elif velocity.x < -5.0:
		facing = -1
	visuals.scale.x = absf(visuals.scale.x) * facing


## Break-Free (A.3): press Space repeatedly while disabled to claw an
## extended lock back toward its baseline duration — never past it, since
## the floor lives in DisableEffect itself, set per-reaction at apply
## time. Deliberately event-based via _unhandled_input rather than a
## polled Input.is_action_just_pressed() check in _physics_process:
## event.is_action_pressed(action, allow_echo) with allow_echo=false
## filters out OS-level key-repeat, so holding Space down doesn't
## accumulate free presses the way a naive just-pressed poll can. That's
## the actual WCAG 2.2.1 rationale (A.3) — removing the timing/speed
## requirement, not just widening it — so this isn't an arbitrary
## implementation choice to simplify later.
func _unhandled_input(event: InputEvent) -> void:
	if state == State.DISABLED and event.is_action_pressed("jump", false):
		elemental.break_free_press()
		_wants_jump_on_recovery = true
		print("Break-Free press — ", elemental.disable_effect.get_remaining_duration(), "s remaining")


## Fires the instant DisableEffect actually ends (natural decay, or —
## once some reaction ever has floor 0 — Break-Free finishing the job
## itself). This is the actual "escape the moment it times out": no
## poll, no next-frame check, this runs synchronously from inside
## elemental.tick()'s call chain, before the rest of this frame's
## _physics_process body even continues.
func _on_disabled_expired() -> void:
	if state != State.DISABLED:
		return  # Defensive only — DisableEffect can't expire without
				# having been active, and nothing else sets state away
				# from DISABLED while it's still active.
	state = State.IDLE if is_on_floor() else State.FALL
	if _wants_jump_on_recovery:
		_jump_buffer_timer = jump_buffer_time
		_wants_jump_on_recovery = false


func _on_hurtbox_hit(hit_data: HitData) -> void:
	velocity += hit_data.knockback
	HitStop.freeze(0.05)
	elemental.handle_hit(hit_data)


## Wildfire's chain (A.7 Link) landed on the player.
func _on_bonus_damage_dealt(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	print("Player takes Wildfire chain damage: -", amount, " (", current_health, "/", max_health, " HP)")
