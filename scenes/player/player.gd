class_name Player
extends CharacterBody2D
## Sprint 1 core combat controller — movement, jump, dodge, and a single
## test attack. Deliberately has NO elemental system wired in yet; that's
## Sprint 2+ (Appendix A.2/A.3). The goal here is combat *feel* per Swink
## (2009): responsive input, readable states, and hit feedback that sells
## weight — tune these starting numbers via actual playtesting (Section 8),
## don't take them as final.

enum State { IDLE, RUN, JUMP, FALL, DODGE, ATTACK, DISABLED }

## Emitted whenever a weapon slot changes — currently only WeaponPickup
## calls swap_weapon() below, but this is exposed generally in case
## anything else ever wants to react to an equip change immediately
## rather than on next frame (Hud itself just polls weapon/
## secondary_weapon directly each frame, simpler than wiring a listener
## from an autoload into whichever Player instance currently exists).
signal weapon_changed(is_primary: bool, new_weapon: WeaponStats)

## Same reasoning as weapon_changed above, for SkillPickup.
signal skill_changed(is_primary: bool, new_skill: SkillData)

## Fires exactly once, the instant current_health first reaches 0 — see
## _apply_damage()/_die(). RunManager listens to this to know a run has
## ended in a loss (Section 6.2's save/progression data needs a real
## "loss" case to log; nothing in this project previously did anything
## when the player's health hit zero).
signal died

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

@export var skill_1: SkillData
@export var skill_2: SkillData

## --- Health (didn't exist before — DoT needs something real to damage) ---
@export var max_health: float = 100.0
var current_health: float
@export var starting_armor: float = 10.0

@onready var visuals: Node2D = $Visuals
@onready var hitbox: Hitbox = $Visuals/Hitbox
@onready var hitbox_shape: CollisionShape2D = $Visuals/Hitbox/CollisionShape2D
@onready var hurtbox: Hurtbox = $Hurtbox

var state: State = State.IDLE
var facing: int = 1  ## 1 = right, -1 = left
## All elemental reaction state (status/DoT/Slow/Disable/armor/element
## indicator/Overgrowth-Link) lives in this composed component now,
## shared with TestDummy and PatrolDummy — see elemental_combatant.gd.
var elemental := ElementalCombatant.new()
var _active_weapon: WeaponStats
var _is_dead: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _combo_step: int = 0
var _combo_window_timer: float = 0.0
var _attack_buffered: bool = false
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
	# Defensive: the CircleShape2D loaded from the .tscn is ONE shared
	# Resource — mutating its radius per-swing (see
	# _configure_hitbox_for_current_swing) without duplicating first would
	# leak that mutation into every other node/scene referencing the same
	# sub-resource.
	if hitbox_shape.shape is CircleShape2D:
		hitbox_shape.shape = hitbox_shape.shape.duplicate()

	elemental.indicator_offset = Vector2(0, -26)
	elemental.armor = starting_armor
	add_child(elemental)  # Added to Player root, not Visuals — Visuals
	# flips scale.x for facing, which would mirror the glyph shape unreadable.
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.disabled_expired.connect(_on_disabled_expired)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_update_timers(delta)
	_apply_gravity(delta)

	# Hud's weapon/skill pickup overlay (opened via the "pickup" action)
	# freezes voluntary action input — movement, jump, dodge, attack,
	# skills — so the player can't wander off or swing mid-choice, while
	# gravity and elemental.tick() (already run via _update_timers above)
	# keep ticking normally, so opening the menu doesn't feel like the
	# whole game paused.
	if Hud.is_overlay_active():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		_update_facing()
		return

	_try_debug_test_effects()
	_try_start_drop_through()

	if elemental.is_disabled() and state not in [State.DODGE, State.ATTACK]:
		if state != State.DISABLED:
			_combo_window_timer = 0.0  # Getting staggered breaks any pending combo continuation.
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
	_combo_window_timer = maxf(_combo_window_timer - delta, 0.0)
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

	# Attack buffering — same reasoning as jump's buffer just above: a
	# press landing mid-swing needs to be captured somewhere
	# state-independent, since _try_start_attack() only gets polled from
	# IDLE/RUN/JUMP/FALL, never from State.ATTACK itself. Gated to
	# State.ATTACK specifically (unlike jump's unconditional capture)
	# because _try_start_attack() already handles a press landing in any
	# OTHER state directly — capturing it again here too would be redundant.
	if state == State.ATTACK and Input.is_action_just_pressed("attack"):
		_attack_buffered = true

	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)
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
		_start_attack(weapon)
	elif Input.is_action_just_pressed("attack_secondary") and secondary_weapon != null:
		_start_attack(secondary_weapon, true)


## Starts a fresh swing, OR — same weapon, still inside its post-swing
## combo_window, and the combo hasn't already hit its weapon-defined cap
## — advances to the next hit in the combo string instead of restarting
## at hit 1. force_fresh (used by the secondary/debug weapon) always
## restarts at hit 1 regardless, so testing a second element never
## accidentally inherits the primary weapon's combo progress.
func _start_attack(weapon_to_use: WeaponStats, force_fresh: bool = false) -> void:
	if weapon_to_use == null:
		return
	if not force_fresh and _active_weapon == weapon_to_use and _combo_window_timer > 0.0 and _combo_step < weapon_to_use.combo_length:
		_combo_step += 1
	else:
		_combo_step = 1
	_active_weapon = weapon_to_use
	state = State.ATTACK
	_attack_timer = 0.0
	_attack_buffered = false
	_combo_window_timer = 0.0


func _process_attack(delta: float) -> void:
	_attack_timer += delta

	var active_start: float = _active_weapon.active_window.x
	var active_end: float = _active_weapon.active_window.y

	if _attack_timer < active_start:
		velocity.x = move_toward(velocity.x, facing * _active_weapon.lunge_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if _attack_timer >= active_start and _attack_timer < active_end:
		if not hitbox.monitoring:
			_configure_hitbox_for_current_swing()
			hitbox.enable()
	else:
		hitbox.disable()

	if _attack_timer >= _active_weapon.attack_duration:
		hitbox.disable()
		_end_or_chain_attack()


## Called the instant a swing's attack_duration elapses. If the player
## already buffered another attack press during this swing (captured in
## _update_timers) AND the weapon's combo hasn't hit its cap, chains
## straight into the next hit — no idle frame between them, same "no
## gap" feel jump buffering already gives platforming. Otherwise ends the
## attack state and opens the post-swing combo_window grace period,
## during which a FRESH press (via _try_start_attack -> _start_attack)
## still continues the combo instead of resetting to hit 1.
func _end_or_chain_attack() -> void:
	if _attack_buffered and _combo_step < _active_weapon.combo_length:
		_combo_step += 1
		_attack_timer = 0.0
		_attack_buffered = false
		return  # Stays in State.ATTACK.
	_attack_buffered = false
	_combo_window_timer = _active_weapon.combo_window
	state = State.IDLE if is_on_floor() else State.FALL


## Sets up the Hitbox for the swing currently starting — per-weapon reach
## and hitbox size (A.4's Weapon System, previously a single hardcoded
## offset/shape baked into player.tscn), plus the current combo step's
## scaled damage. Called once per swing, right as its active window opens.
func _configure_hitbox_for_current_swing() -> void:
	hitbox.damage = _active_weapon.damage * _combo_damage_multiplier()
	hitbox.weapon_weight = StringName(WeaponStats.Weight.keys()[_active_weapon.weight].to_lower())
	var swing := _active_weapon.resolve_swing()
	hitbox.element = swing.element
	hitbox.charge = swing.charge
	hitbox.position.x = _active_weapon.reach
	var circle := hitbox_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = _active_weapon.hitbox_radius


## 1.0 for the first hit, compounding by combo_damage_step_multiplier for
## each hit after that — following a combo string all the way through is
## meant to reward more than just spamming the first swing on cooldown.
func _combo_damage_multiplier() -> float:
	return pow(_active_weapon.combo_damage_step_multiplier, _combo_step - 1)


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
			# No longer an instant hitscan resolution — fires a real
			# traveling SkillProjectile instead (see ElementalCombatant.
			# cast_apply_projectile). _find_skill_target(cast_range) is
			# only used to pick a DIRECTION to aim at now, not to
			# resolve the hit immediately — same "no aim/targeting
			# system exists elsewhere" reasoning SkillData.cast_range's
			# own doc comment already gives. Falls back to facing
			# direction with nothing in range, so the dart can now miss
			# a target that moves out of its path, same as it always
			# could with Ore Surge's fragments.
			var aim_target := _find_skill_target(skill.cast_range)
			var aim_direction := Vector2(facing, 0)
			if aim_target != null:
				var to_target := aim_target.global_position - global_position
				if not to_target.is_zero_approx():
					aim_direction = to_target.normalized()
			elemental.cast_apply_projectile(skill.element, charge, aim_direction)
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
	
## Called by WeaponPickup on contact — swaps whichever slot the pickup
## targets and returns the weapon that was previously equipped there
## (null if the slot was empty), so the caller can leave it behind as a
## new, walkable pickup. Mid-swing safety: if the swapped-out weapon
## happened to be _active_weapon, the current swing itself isn't
## interrupted — resolve_swing() already captured what it needed at
## swing-start; only the NEXT attack picks up the new weapon.
func swap_weapon(is_primary: bool, new_weapon: WeaponStats) -> WeaponStats:
	var previous: WeaponStats
	if is_primary:
		previous = weapon
		weapon = new_weapon
	else:
		previous = secondary_weapon
		secondary_weapon = new_weapon
	if new_weapon != null:
		SaveManager.record_weapon_unlock(new_weapon.resource_path)  ## Meta-progression (Section 6.2) — found once, unlocked forever.
	weapon_changed.emit(is_primary, new_weapon)
	return previous


## Called by SkillPickup on an F press — same swap-and-return-the-old-one
## shape as swap_weapon() above, targeting skill_1/skill_2 instead. A
## swapped-out skill still on cooldown loses its remaining cooldown
## timer entirely (skill_cooldowns is keyed by the SkillData resource
## itself) — a deliberate simplification, not a bug: cooldowns tracking
## a skill no longer even equipped wouldn't mean anything to carry over.
func swap_skill(is_primary: bool, new_skill: SkillData) -> SkillData:
	var previous: SkillData
	if is_primary:
		previous = skill_1
		skill_1 = new_skill
	else:
		previous = skill_2
		skill_2 = new_skill
	if new_skill != null:
		SaveManager.record_skill_unlock(new_skill.resource_path)  ## Meta-progression (Section 6.2) — found once, unlocked forever.
	skill_changed.emit(is_primary, new_skill)
	return previous

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
	_apply_damage(hit_data.damage)
	velocity += hit_data.knockback
	HitStop.freeze(0.05)
	elemental.handle_hit(hit_data)


## Wildfire's chain (A.7 Link) landed on the player.
func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)
	print("Player takes Wildfire chain damage: -", amount, " (", current_health, "/", max_health, " HP)")


## Centralised health-reduction path (every damage source — hits, DoT,
## Wildfire chain — routes through here) so death only needs to be
## checked in ONE place. Mirrors the _apply_damage()/_die() pattern
## already used by TestDummy/PatrolDummy/Boss, just inverted (their
## version tracks a rising damage-taken counter; this one drains a
## falling health float) since Player's health model has always been
## different from the dummies' own damage-counter approach.
func _apply_damage(amount: float) -> void:
	if _is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true  ## No further hits register — same convention as every enemy's own _die().
	died.emit()
	print("Player died")


## --- Save/resume (SaveManager, Section 6.2) ---

## Serializes the player's own persistable state — health/armor and
## which weapons/skills are equipped, by resource path rather than by
## value, since a WeaponStats/SkillData instance itself isn't JSON-safe
## but the res:// path that loads it back is. Read by RunManager's
## autosave — see run_manager.gd's own header comment on what this
## deliberately does NOT capture (position, in-flight cooldowns, etc.).
func to_save_state() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"armor": elemental.armor,
		"weapon_path": weapon.resource_path if weapon != null else "",
		"secondary_weapon_path": secondary_weapon.resource_path if secondary_weapon != null else "",
		"skill_1_path": skill_1.resource_path if skill_1 != null else "",
		"skill_2_path": skill_2.resource_path if skill_2 != null else "",
	}


## Restores a previously-saved state (RunManager, on resume). Weapon/
## skill paths are loaded fresh via load() rather than resolving back to
## some in-memory instance — safe because every real .tres weapon/skill
## is a stable, shared Resource, the same assumption swap_weapon/
## swap_skill already make when a pickup hands one over directly.
## Deliberately does NOT go through swap_weapon/swap_skill — resuming a
## run must not re-trigger a meta-progression unlock for something that
## was already unlocked the first time it was ever picked up.
func apply_save_state(saved_state: Dictionary) -> void:
	current_health = saved_state.get("current_health", current_health)
	max_health = saved_state.get("max_health", max_health)
	elemental.armor = saved_state.get("armor", elemental.armor)
	_load_weapon_path(saved_state.get("weapon_path", ""), true)
	_load_weapon_path(saved_state.get("secondary_weapon_path", ""), false)
	_load_skill_path(saved_state.get("skill_1_path", ""), true)
	_load_skill_path(saved_state.get("skill_2_path", ""), false)


func _load_weapon_path(path: String, is_primary: bool) -> void:
	if path == "":
		return
	var loaded := load(path) as WeaponStats
	if loaded == null:
		push_warning("Player.apply_save_state: could not load weapon at %s" % path)
		return
	if is_primary:
		weapon = loaded
	else:
		secondary_weapon = loaded


func _load_skill_path(path: String, is_primary: bool) -> void:
	if path == "":
		return
	var loaded := load(path) as SkillData
	if loaded == null:
		push_warning("Player.apply_save_state: could not load skill at %s" % path)
		return
	if is_primary:
		skill_1 = loaded
	else:
		skill_2 = loaded
