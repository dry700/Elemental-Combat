class_name Player
extends CharacterBody2D
## Sprint 1 core combat controller — movement, jump, dodge, and a single
## test attack. Deliberately has NO elemental system wired in yet; that's
## Sprint 2+ (Appendix A.2/A.3). The goal here is combat *feel* per Swink
## (2009): responsive input, readable states, and hit feedback that sells
## weight — tune these starting numbers via actual playtesting (Section 8),
## don't take them as final.

enum State { IDLE, RUN, JUMP, FALL, DODGE, ATTACK, DISABLED, WALL_SLIDE, PLUNGE, SKILL_SLAM, HEAVY_WINDUP }

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

const DamagePopup = preload("res://scripts/ui/damage_number.gd")
const DashShadowScript: Script = preload("res://scripts/combat/dash_shadow.gd")
const SkillCastVFXScript: Script = preload("res://scripts/combat/skill_cast_vfx.gd")
const SkillWaveVFXScript: Script = preload("res://scripts/combat/skill_wave_vfx.gd")
const DASH_SHADOW_INTERVAL: float = 0.045
const NORMAL_DASH_SHADOW_COLOR := Color(0.72, 0.82, 1.0)
const SKILL_SLAM_LAUNCH_VELOCITY: float = -260.0
const SKILL_SLAM_DESCENT_VELOCITY: float = 420.0
const SKILL_SLAM_SHAKE_INTENSITY: float = 6.0
const SKILL_SLAM_SHAKE_DURATION: float = 0.24

## --- Movement tuning (starting points) ---
@export var max_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
@export var air_acceleration: float = 450.0
@export var jump_velocity: float = -210.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var max_air_jumps: int = 1

## --- Wall Slide / Jump tuning ---
@export var wall_slide_speed: float = 80.0
@export var wall_jump_push_force: float = 100.0
@export var wall_jump_up_force: float = 250.0

## --- Plunge Attack tuning ---
@export var min_plunge_height: float = 40.0:
	set(val):
		min_plunge_height = val
		if is_inside_tree() and plunge_raycast != null:
			plunge_raycast.target_position = Vector2(0, min_plunge_height)
@export var max_plunge_height: float = 200.0
@export var plunge_gravity_multiplier: float = 2.5
var _plunge_start_y: float = 0.0

@onready var plunge_raycast: RayCast2D = $PlungeRaycast

## --- Dodge tuning ---
@export var dodge_speed: float = 210.0
@export var dodge_duration: float = 0.22
@export var dodge_cooldown: float = 0.4
## i-frames only cover part of the dodge, not the whole thing — a
## full-duration invuln window is what makes dodge-spam degenerate.
@export var dodge_iframe_window: Vector2 = Vector2(0.0, 0.16)

## --- Attack ---
@export var weapon: WeaponStats
@export var secondary_weapon: WeaponStats  ## DEBUG ONLY — for testing Sinh with two elements.

var weapon_rune: RuneData = null
var secondary_weapon_rune: RuneData = null

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
@onready var anim_player: AnimationPlayer = $Visuals/AnimationPlayer
@onready var weapon_sprite: Sprite2D = $Visuals/Hitbox/WeaponSprite

var state: State = State.IDLE
var facing: int = 1  ## 1 = right, -1 = left
## All elemental reaction state (status/DoT/Slow/Disable/armor/element
## indicator/Overgrowth-Link) lives in this composed component now,
## shared with TestDummy and PatrolDummy — see elemental_combatant.gd.
var elemental := ElementalCombatant.new()
var _active_weapon: WeaponStats
var _is_dead: bool = false
var playtest_invincible: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0
var _dodge_timer: float = 0.0
var _active_dodge_duration: float = 0.0
var _active_dodge_iframe_window: Vector2 = Vector2.ZERO
var _dodge_cooldown_timer: float = 0.0
var _last_dodge_end_time: float = -999.0
var _dash_shadow_active: bool = false
var _dash_shadow_timer: float = 0.0
var _dash_shadow_color: Color = Color.WHITE
var _attack_timer: float = 0.0
var _current_attack_duration: float = 0.25
var _current_active_window: Vector2 = Vector2(0.08, 0.16)
var _combo_step: int = 0
var _combo_window_timer: float = 0.0
var _attack_buffered: bool = false
var _shot_fired: bool = false
## --- Heavy hit windup (plan-shop-and-skills §8) ---
var _heavy_hold_timer: float = 0.0
var _heavy_action: String = ""
var _heavy_charged: bool = false
var _heavy_charge_ratio: float = 0.0
var _heavy_arrow_speed_mult: float = 1.0  ## Applied to spawned arrows for a heavy SHOOT strike.
var _perfect_streak_count: int = 0
var _perfect_streak_last_hit_time: float = -999.0
var _drop_through_timer: float = 0.0
var _skill_cooldowns: Dictionary = {}  ## SkillData -> remaining cooldown seconds
var _skill_energy: Dictionary = {}  ## SkillData (uses_energy) -> current energy 0..energy_max (plan-shop-and-skills §7.1)
var _skill_slam_skill: SkillData
var _skill_slam_charge: int = 0
var _skill_slam_descending: bool = false
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

## Fixed distance from body-center to the hand/grip — anatomically this
## doesn't vary per weapon (your hand sits the same distance from your
## shoulder holding anything); what varies per weapon is `reach`, now
## read purely as blade length extending beyond this point.
const WEAPON_GRIP_OFFSET: float = 2.0

const ONE_WAY_PLATFORM_LAYER: int = 3  ## Must match Platform's Collision Layer in the editor.
@export var drop_through_duration: float = 0.25  ## Long enough to fall clear of the platform.
## §8 accessibility (WCAG, same rationale as Break-Free): when true, a tap
## starts the heavy windup charging automatically and a SECOND tap releases
## the strike, so players who can't hold a button can still charge.
@export var heavy_tap_to_charge: bool = false

func _ready() -> void:
	if plunge_raycast != null:
		plunge_raycast.target_position = Vector2(0, min_plunge_height)
		plunge_raycast.add_exception(self)
		
	add_to_group("player")  # Lets VisionBlocker (Douse's steam cloud, A.2) find the player generically.
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	max_health += UpgradeManager.vitality_hp_bonus()
	current_health = max_health
	if weapon == null:
		weapon = WeaponStats.new()  # Fallback so the scene still runs unassigned.
	# Defensive: the CircleShape2D loaded from the .tscn is ONE shared
	# Resource — mutating its radius per-swing (see
	# _configure_hitbox_for_current_swing) without duplicating first would
	# leak that mutation into every other node/scene referencing the same
	# sub-resource.
	if hitbox_shape.shape is RectangleShape2D:
		hitbox_shape.shape = hitbox_shape.shape.duplicate()

	elemental.indicator_offset = Vector2(0, -13)
	elemental.armor = starting_armor
	weapon_sprite.visible = false
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
	if Hud.is_overlay_active() or PlaytestMode.is_panel_open():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		_update_facing()
		return

	_try_debug_test_effects()
	_try_start_drop_through()
	
	if not is_on_floor() and state in [State.IDLE, State.RUN]:
		state = State.FALL

	if elemental.is_disabled() and state not in [State.DODGE, State.ATTACK, State.SKILL_SLAM]:
		if state == State.HEAVY_WINDUP:
			_reset_heavy_windup()  # §8 — a stagger/stun cancels the charge.
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
				var target_anim := "run" if state == State.RUN else "idle"
				if anim_player.current_animation != target_anim:
					anim_player.play(target_anim, -1.0, 1.6 if target_anim == "run" else 1.0)
		State.JUMP, State.FALL:
			_handle_move_and_jump(delta)
			_try_start_dodge()
			_try_start_attack()
			_try_cast_skill(skill_1, "skill_1")
			_try_cast_skill(skill_2, "skill_2")
			if state == State.JUMP or state == State.FALL:
				state = State.JUMP if velocity.y < 0.0 else State.FALL
		State.WALL_SLIDE:
			_process_wall_slide(delta)
			_try_start_dodge()
			_try_start_attack()
		State.PLUNGE:
			_process_plunge(delta)
		State.SKILL_SLAM:
			_process_skill_slam(delta)
		State.DODGE:
			_process_dodge(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HEAVY_WINDUP:
			_process_heavy_windup(delta)
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
			if plunge_raycast != null:
				plunge_raycast.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)

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
	if state == State.ATTACK:
		var expected_action = "attack_secondary" if (_active_weapon != null and _active_weapon == secondary_weapon) else "attack"
		if Input.is_action_just_pressed(expected_action):
			_attack_buffered = true

	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)
		print("Player DoT tick: -", dot_damage, " (", current_health, "/", max_health, " HP)")

	if is_on_floor():
		_coyote_timer = coyote_time
		_air_jumps_used = 0


func _apply_gravity(delta: float) -> void:
	if state in [State.DODGE, State.WALL_SLIDE, State.PLUNGE, State.SKILL_SLAM]:
		return  # Handled locally or overrides vertical movement
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
			
	if is_on_wall_only() and not _is_touching_unclimbable_wall() \
			and velocity.y > 0.0 and input_dir != 0.0:
		var wall_normal := get_wall_normal().x
		if (wall_normal < 0 and input_dir > 0) or (wall_normal > 0 and input_dir < 0):
			state = State.WALL_SLIDE
			_air_jumps_used = 0
			velocity.y = minf(velocity.y, wall_slide_speed)
			

func _process_wall_slide(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var wall_normal := get_wall_normal().x
	
	if not is_on_wall() or is_on_floor() or _is_touching_unclimbable_wall() \
			or (wall_normal < 0 and input_dir < 0) or (wall_normal > 0 and input_dir > 0):
		state = State.FALL
		return
	
	velocity.y = minf(velocity.y + ProjectSettings.get_setting("physics/2d/default_gravity") * delta, wall_slide_speed)
	
	if _jump_buffer_timer > 0.0:
		velocity.x = wall_normal * wall_jump_push_force
		velocity.y = -wall_jump_up_force
		_jump_buffer_timer = 0.0
		state = State.JUMP
		facing = int(sign(wall_normal)) if wall_normal != 0.0 else facing
		visuals.scale.x = absf(visuals.scale.x) * facing


func _is_touching_unclimbable_wall() -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group("unclimbable_walls"):
			return true
	return false


func _start_plunge(weapon_to_use: WeaponStats) -> void:
	if weapon_to_use == null:
		return
	_active_weapon = weapon_to_use
	state = State.PLUNGE
	velocity.x = 0.0
	_plunge_start_y = global_position.y
	
	weapon_sprite.texture = _active_weapon.weapon_texture
	weapon_sprite.visible = weapon_sprite.texture != null
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.position = Vector2.ZERO
	
	var actual_reach := _active_weapon.reach
	if _active_weapon.weapon_texture != null:
		actual_reach = float(_active_weapon.weapon_texture.get_width())
	weapon_sprite.offset = Vector2(actual_reach / 2.0, 0.0)
	
	hitbox.position.x = WEAPON_GRIP_OFFSET
	hitbox.rotation = deg_to_rad(90)  # Point straight down


func _process_plunge(delta: float) -> void:
	if is_on_floor():
		var height_fallen = maxf(0.0, global_position.y - _plunge_start_y)
		var impact_intensity = clamp((height_fallen - min_plunge_height) / (max_plunge_height - min_plunge_height), 0.0, 1.0)
		_trigger_plunge_impact(impact_intensity)
		
		weapon_sprite.visible = false
		hitbox.rotation = 0.0
		
		state = State.IDLE
		return
	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * plunge_gravity_multiplier * delta

func _trigger_plunge_impact(intensity: float) -> void:
	var radius = 20.0 + (40.0 * intensity)
	var plunge_charge = 2 if intensity >= 0.6 else 1
	var dmg = (_active_weapon.damage if _active_weapon else 10.0) * UpgradeManager.weapon_might_multiplier() * (1.0 + intensity)
	var active_rune = weapon_rune if _active_weapon == weapon else secondary_weapon_rune
	var swing = _active_weapon.resolve_swing(active_rune) if _active_weapon else null
	var element = swing.element if swing else Elements.NONE
	var weight = StringName(WeaponStats.Weight.keys()[_active_weapon.weight].to_lower()) if _active_weapon else &"none"
	var knockback = 150.0 * (1.0 + intensity)
	var is_perfect_plunge := _active_weapon != null and _active_weapon.perfect_condition == WeaponStats.PerfectCondition.PLUNGE and intensity >= 0.6
	
	var feedback_weight: StringName = &"heavy" if is_perfect_plunge else weight
	HitStop.freeze_for_weight(feedback_weight)
	ScreenShake.shake_for_weight(feedback_weight)
	
	# Spawn splash particles along the ground horizontally to match the blast radius
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var center_particles := HitParticles.new()
		center_particles.global_position = global_position + Vector2(0, 8)
		center_particles.away_direction = Vector2.UP
		center_particles.element = element
		center_particles.scale = Vector2.ONE * (1.0 + (intensity * 1.5))
		scene_root.add_child(center_particles)
		
		var num_side_splashes = int(radius / 25.0)
		for i in range(1, num_side_splashes + 1):
			var offset_x = i * 25.0
			for dir in [-1, 1]:
				var side_particles := HitParticles.new()
				side_particles.global_position = global_position + Vector2(offset_x * dir, 8)
				side_particles.away_direction = Vector2(dir * 0.5, -1).normalized()
				side_particles.element = element
				side_particles.scale = Vector2.ONE * (0.5 + intensity)
				scene_root.add_child(side_particles)
	
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		if node.get_parent() == self:
			continue
		var dist = node.global_position.distance_to(global_position)
		if dist <= radius:
			var owner_node = node.get_parent()
			if owner_node and owner_node.has_node("Hurtbox"):
				var target_hurtbox = owner_node.get_node("Hurtbox")
				if target_hurtbox:
					var direction = (target_hurtbox.global_position - global_position).normalized()
					if direction.is_zero_approx():
						direction = Vector2.RIGHT
					
					var is_perfect := false
					if _active_weapon != null and _active_weapon.perfect_condition == WeaponStats.PerfectCondition.PLUNGE and intensity >= 0.6:
						is_perfect = true
					var final_dmg: float = dmg
					if is_perfect:
						final_dmg *= _active_weapon.perfect_multiplier

					var specific_hit_data = HitData.new(final_dmg, direction * knockback, self, is_perfect)
					specific_hit_data.element = element
					specific_hit_data.charge = plunge_charge
					specific_hit_data.weapon_weight = weight
					
					target_hurtbox.take_hit(specific_hit_data)
					
					if hitbox.has_method("_spawn_hit_spark"):
						hitbox._spawn_hit_spark(target_hurtbox.global_position)
					if hitbox.has_method("_spawn_hit_particles"):
						hitbox._spawn_hit_particles(target_hurtbox.global_position, direction)



func _try_start_drop_through() -> void:
	if Input.is_action_just_pressed("drop_down") and is_on_floor():
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
		if plunge_raycast != null:
			plunge_raycast.set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
		_drop_through_timer = drop_through_duration


func _try_start_dodge() -> void:
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		state = State.DODGE
		_dodge_timer = 0.0
		_dodge_cooldown_timer = dodge_cooldown
		_active_dodge_duration = dodge_duration
		_active_dodge_iframe_window = dodge_iframe_window
		velocity = Vector2(facing * dodge_speed, 0.0)
		_start_dash_shadows(NORMAL_DASH_SHADOW_COLOR)


func _process_dodge(delta: float) -> void:
	_dodge_timer += delta
	_process_dash_shadows(delta)
	var in_iframe_window := _dodge_timer >= _active_dodge_iframe_window.x and _dodge_timer <= _active_dodge_iframe_window.y
	var was_in_iframe := hurtbox.invulnerable
	hurtbox.invulnerable = in_iframe_window

	if in_iframe_window and not was_in_iframe:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is CollisionObject2D:
				add_collision_exception_with(enemy)
	elif not in_iframe_window and was_in_iframe:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is CollisionObject2D:
				remove_collision_exception_with(enemy)

	if _dodge_timer >= _active_dodge_duration:
		_dash_shadow_active = false
		_last_dodge_end_time = Time.get_ticks_msec() / 1000.0
		state = State.IDLE if is_on_floor() else State.FALL


func _try_start_attack() -> void:
	if plunge_raycast != null:
		plunge_raycast.force_raycast_update()
		
	if Input.is_action_just_pressed("attack"):
		var can_plunge_state = state in [State.JUMP, State.FALL, State.WALL_SLIDE] or _drop_through_timer > 0.0
		if can_plunge_state and Input.is_action_pressed("drop_down") and plunge_raycast != null and not plunge_raycast.is_colliding():
			_start_plunge(weapon)
		else:
			_begin_attack(weapon, "attack")
	elif Input.is_action_just_pressed("attack_secondary") and secondary_weapon != null:
		var can_plunge_state = state in [State.JUMP, State.FALL, State.WALL_SLIDE] or _drop_through_timer > 0.0
		if can_plunge_state and Input.is_action_pressed("drop_down") and plunge_raycast != null and not plunge_raycast.is_colliding():
			_start_plunge(secondary_weapon)
		else:
			_begin_attack(secondary_weapon, "attack_secondary")

## §8 — heavy-aware attack entry. Heavy-capable weapons enter the charge
## windup on press (a short release falls through to a normal swing, so
## combo feel is unchanged); non-heavy weapons start a normal swing as before.
func _begin_attack(weapon_to_use: WeaponStats, action: String) -> void:
	if weapon_to_use != null and weapon_to_use.has_heavy_attack:
		_start_heavy_windup(weapon_to_use, action)
	else:
		_start_attack(weapon_to_use)

## Starts a fresh swing, OR — same weapon, still inside its post-swing
## combo_window, and the combo hasn't already hit its weapon-defined cap
## — advances to the next hit in the combo string instead of restarting
## at hit 1. force_fresh (used by the secondary/debug weapon) always
## restarts at hit 1 regardless, so testing a second element never
## accidentally inherits the primary weapon's combo progress.
func _start_attack(weapon_to_use: WeaponStats, force_fresh: bool = false) -> void:
	if weapon_to_use == null:
		return
	if not force_fresh and _active_weapon == weapon_to_use and _combo_window_timer > 0.0 and _combo_step < weapon_to_use.combo_steps.size():
		_combo_step += 1
	else:
		_combo_step = 1
	_active_weapon = weapon_to_use
	state = State.ATTACK
	_attack_timer = 0.0
	_attack_buffered = false
	_combo_window_timer = 0.0
	_configure_hitbox_for_current_swing()


const THRUST_EXTEND_DISTANCE: float = 3.0

func _process_attack(delta: float) -> void:
	_attack_timer += delta
	weapon_sprite.visible = weapon_sprite.texture != null

	var active_start: float = _current_active_window.x
	var active_end: float = _current_active_window.y

	if weapon_sprite.texture != null:
		var t := _swing_progress(active_start, active_end)
		var step := _current_combo_step_data()
		if step.style == WeaponStats.AttackStyle.THRUST:
			hitbox.rotation = 0.0
			hitbox.position.x = WEAPON_GRIP_OFFSET + sin(t * PI) * step.thrust_extend_distance
		elif step.style == WeaponStats.AttackStyle.SHOOT:
			hitbox.rotation = 0.0
			hitbox.position.x = WEAPON_GRIP_OFFSET
		else:
			hitbox.rotation = lerp_angle(deg_to_rad(step.swing_rotation_start_deg), deg_to_rad(step.swing_rotation_end_deg), t)
			hitbox.position.x = WEAPON_GRIP_OFFSET

	if _attack_timer < active_start:
		velocity.x = move_toward(velocity.x, facing * _active_weapon.lunge_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	var is_shoot := _current_combo_step_data().style == WeaponStats.AttackStyle.SHOOT
	if _attack_timer >= active_start and _attack_timer < active_end:
		if is_shoot:
			if not _shot_fired:
				_shot_fired = true
				_fire_arrow()
		elif not hitbox.monitoring:
			hitbox.enable()
			_spawn_slash_vfx()
			_spawn_trail_vfx()
	else:
		hitbox.disable()

	if _attack_timer >= _current_attack_duration:
		hitbox.disable()
		_end_or_chain_attack()


## Windup (before active_start) holds the pose at t=0 — weapon pulled
## back, anticipating. The strike sweeps through the FULL motion across
## just the active window, not the whole attack_duration — that's what
## makes it snap instead of easing through the entire swing. Recovery
## (after active_end) holds at t=1 until the attack finishes or chains.
func _swing_progress(active_start: float, active_end: float) -> float:
	if _attack_timer < active_start:
		return 0.0
	if _attack_timer >= active_end:
		return 1.0
	return (_attack_timer - active_start) / maxf(active_end - active_start, 0.001)

## Fires once per swing, the instant its active window opens — visible
## whether or not the swing actually lands a hit, unlike HitSpark.
func _spawn_slash_vfx() -> void:
	if _active_weapon.use_trail_vfx and _current_combo_step_data().style == WeaponStats.AttackStyle.SWING:
		return
	if _active_weapon.weapon_texture == null:
		return
	var step := _current_combo_step_data()
	var vfx: Node2D
	if step.style == WeaponStats.AttackStyle.THRUST:
		vfx = ThrustVFX.new()
	else:
		vfx = SlashVFX.new()
	vfx.element = hitbox.element
	hitbox.add_child(vfx)
	
func _spawn_trail_vfx() -> void:
	if _active_weapon == null or not _active_weapon.use_trail_vfx:
		return
	if _current_combo_step_data().style != WeaponStats.AttackStyle.SWING:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var trail := TrailVFX.new()
	trail.tip_source = hitbox
	trail.tip_offset = Vector2(hitbox.weapon_reach, 0.0)
	trail.element = hitbox.element
	trail.sample_duration = _current_active_window.y - _current_active_window.x + 0.02
	scene_root.add_child(trail)

## SHOOT-style swing: spawns one arrow at the start of the active window.
## Damage/element/charge come from the Hitbox values already configured for
## this swing, so combo scaling and rune alternation apply unchanged.
func _fire_arrow() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		return
	var origin := global_position + Vector2(facing * (WEAPON_GRIP_OFFSET + 4.0), 0.0)
	for angle_degrees in _active_weapon.get_projectile_angles():
		var arrow := ArrowProjectile.new()
		arrow.attacker = self
		arrow.direction = Vector2(facing, 0).rotated(deg_to_rad(angle_degrees))
		arrow.speed = _active_weapon.projectile_speed * _heavy_arrow_speed_mult
		arrow.lifetime = _active_weapon.projectile_lifetime
		arrow.element = hitbox.element
		arrow.charge = hitbox.charge
		arrow.damage = hitbox.damage
		arrow.weapon_weight = hitbox.weapon_weight
		arrow.knockback_strength = hitbox.knockback_strength
		arrow.perfect_condition = hitbox.perfect_condition
		arrow.perfect_multiplier = hitbox.perfect_multiplier
		arrow.spawn_position = origin
		arrow.global_position = origin
		scene_root.add_child(arrow)
	
## Called the instant a swing's attack_duration elapses. If the player
## already buffered another attack press during this swing (captured in
## _update_timers) AND the weapon's combo hasn't hit its cap, chains
## straight into the next hit — no idle frame between them, same "no
## gap" feel jump buffering already gives platforming. Otherwise ends the
## attack state and opens the post-swing combo_window grace period,
## during which a FRESH press (via _try_start_attack -> _start_attack)
## still continues the combo instead of resetting to hit 1.
func _end_or_chain_attack() -> void:
	if not _heavy_charged and _attack_buffered and _combo_step < _active_weapon.combo_steps.size():
		_combo_step += 1
		_attack_timer = 0.0
		_attack_buffered = false
		_configure_hitbox_for_current_swing()
		return  # Stays in State.ATTACK.
	weapon_sprite.visible = false
	hitbox.position.x = WEAPON_GRIP_OFFSET
	hitbox.rotation = 0.0
	_attack_buffered = false
	_combo_window_timer = _active_weapon.combo_window
	state = State.IDLE if is_on_floor() else State.FALL
	_reset_heavy_windup()


## --- Heavy hit windup (plan-shop-and-skills §8) ---
## Entered on press for heavy-capable weapons. A short release falls through
## to a normal swing (combo feel unchanged); holding past heavy_threshold
## charges, and release strikes — scaling damage/reach/knockback (and bow
## arrow speed) up to heavy_max_hold. Never raises reaction Charge. Dodge
## and a stagger/stun both cancel the windup.
func _start_heavy_windup(weapon_to_use: WeaponStats, action: String) -> void:
	if weapon_to_use == null:
		return
	_active_weapon = weapon_to_use
	_heavy_action = action
	_heavy_hold_timer = 0.0
	_heavy_charged = false
	_heavy_charge_ratio = 0.0
	_heavy_arrow_speed_mult = 1.0
	state = State.HEAVY_WINDUP
	weapon_sprite.texture = _active_weapon.weapon_texture
	weapon_sprite.visible = weapon_sprite.texture != null
	weapon_sprite.position = Vector2.ZERO
	weapon_sprite.rotation = 0.0
	weapon_sprite.modulate = Color.WHITE
	hitbox.position.x = WEAPON_GRIP_OFFSET
	hitbox.rotation = 0.0


func _process_heavy_windup(delta: float) -> void:
	# Dodge cancels the windup.
	_try_start_dodge()
	if state == State.DODGE:
		_reset_heavy_windup()
		return
	# Committed charge: gravity still applies (see _apply_gravity), but
	# horizontal control is damped — you slow to a stop while winding up.
	var threshold := _active_weapon.heavy_threshold
	var max_hold := _active_weapon.heavy_max_hold
	if heavy_tap_to_charge:
		# Accessibility: charge advances automatically; a second tap releases.
		_heavy_hold_timer = minf(_heavy_hold_timer + delta, threshold + max_hold)
		if _heavy_hold_timer >= threshold:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			_update_heavy_tell(threshold, max_hold)
		if Input.is_action_just_pressed(_heavy_action):
			_release_heavy()
	else:
		if Input.is_action_pressed(_heavy_action):
			_heavy_hold_timer = minf(_heavy_hold_timer + delta, threshold + max_hold)
			if _heavy_hold_timer >= threshold:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
				_update_heavy_tell(threshold, max_hold)
		else:
			_release_heavy()


func _release_heavy() -> void:
	var threshold := _active_weapon.heavy_threshold
	var max_hold := _active_weapon.heavy_max_hold
	weapon_sprite.modulate = Color.WHITE
	if _heavy_hold_timer >= threshold:
		_heavy_charged = true
		_heavy_charge_ratio = clampf((_heavy_hold_timer - threshold) / maxf(max_hold, 0.001), 0.0, 1.0)
		# A heavy strike is a committed single hit (force_fresh → combo step 1).
		_start_attack(_active_weapon, true)
	else:
		# Short press → normal swing (allow combo continuation).
		_start_attack(_active_weapon, false)
	_heavy_hold_timer = 0.0


## Weapon-sprite tell: pulses and tints while winding up, with a bright flash
## at full power (§8). Color is secondary to the growing-charge feel.
func _update_heavy_tell(threshold: float, max_hold: float) -> void:
	if weapon_sprite.texture == null:
		return
	var t := _heavy_hold_timer
	var pulse := 0.85 + 0.15 * sin(t * 20.0)
	var col: Color
	if t < threshold:
		var p := t / maxf(threshold, 0.001)
		col = Color(1.0, 1.0 - 0.15 * (1.0 - p), 0.7 + 0.2 * p)
	else:
		var ratio := clampf((t - threshold) / maxf(max_hold, 0.001), 0.0, 1.0)
		col = Color(1.0, 0.85, 0.5).lerp(Color(1.0, 1.0, 0.65), ratio)
		if ratio >= 1.0:
			col = Color(1.5, 1.25, 0.8)  # bright full-power flash (values >1 brighten the sprite)
	weapon_sprite.modulate = Color(col.r * pulse, col.g * pulse, col.b * pulse, 1.0)


func _reset_heavy_windup() -> void:
	_heavy_hold_timer = 0.0
	_heavy_charged = false
	_heavy_charge_ratio = 0.0
	_heavy_arrow_speed_mult = 1.0
	weapon_sprite.modulate = Color.WHITE
	weapon_sprite.visible = false


## Sets up the Hitbox for the swing currently starting — per-weapon reach
## and hitbox size (A.4's Weapon System, previously a single hardcoded
## offset/shape baked into player.tscn), plus the current combo step's
## scaled damage. Called once per swing, right as its active window opens.
## Sets up everything that's fixed for the WHOLE swing (geometry,
## texture, element/charge) — called once per swing/combo-step, not
## once per frame. What actually MOVES during the swing (hitbox.rotation
## / hitbox.position.x) is driven separately, every frame, by
## _process_attack — that split is what fixes the sprite/hitbox offset:
## one transform (Hitbox's own) now carries both the collision rectangle
## AND its child WeaponSprite, instead of only the sprite animating
## while the hitbox sat still.
func _configure_hitbox_for_current_swing() -> void:
	_shot_fired = false
	var bonus_damage_pct := _get_active_rune_modifier_value(&"damage_pct")
	# §7.2 — Maid's Sweep read-site: the buff is read HERE only, never on raw
	# reaction Charge. While active, swings become Thổ with bigger
	# reach/hitbox and a damage multiplier, and the rune alternation flip is
	# skipped (the override is temporary; base weapon Charge is untouched).
	var sweep_active := elemental.sweep_buff.active
	_heavy_charge_ratio = clampf(_heavy_charge_ratio, 0.0, 1.0)
	hitbox.damage = _active_weapon.damage * UpgradeManager.weapon_might_multiplier() * _combo_damage_multiplier() * (1.0 + bonus_damage_pct / 100.0)
	if _heavy_charged:
		hitbox.damage *= lerpf(1.0, _active_weapon.heavy_damage_mult, _heavy_charge_ratio)
	if sweep_active:
		hitbox.damage *= elemental.sweep_buff.damage_mult
	hitbox.weapon_weight = &"heavy" if _heavy_charged else StringName(WeaponStats.Weight.keys()[_active_weapon.weight].to_lower())
	hitbox.perfect_condition = _active_weapon.perfect_condition
	hitbox.perfect_multiplier = _active_weapon.perfect_multiplier
	var active_rune := weapon_rune if _active_weapon == weapon else secondary_weapon_rune
	var swing := _active_weapon.resolve_swing(active_rune, not sweep_active)
	hitbox.charge = swing.charge
	hitbox.element = Elements.THO if sweep_active else swing.element
	hitbox.position.x = WEAPON_GRIP_OFFSET
	hitbox.rotation = 0.0

	var bonus_knockback := _get_active_rune_modifier_value(&"knockback")
	hitbox.knockback_strength = 150.0 + bonus_knockback
	if _heavy_charged:
		hitbox.knockback_strength *= lerpf(1.0, _active_weapon.heavy_knockback_mult, _heavy_charge_ratio)

	var bonus_attack_speed := _get_active_rune_modifier_value(&"attack_speed")
	var speed_mult: float = 1.0 + (bonus_attack_speed / 100.0) if bonus_attack_speed > 0.0 else 1.0
	_current_attack_duration = _active_weapon.attack_duration / speed_mult
	_current_active_window = _active_weapon.active_window / speed_mult

	var actual_reach := _active_weapon.reach
	if _active_weapon.weapon_texture != null:
		actual_reach = float(_active_weapon.weapon_texture.get_width())
	var bonus_reach := _get_active_rune_modifier_value(&"reach")
	actual_reach += bonus_reach
	if sweep_active:
		actual_reach *= elemental.sweep_buff.reach_mult
	if _heavy_charged:
		actual_reach *= lerpf(1.0, _active_weapon.heavy_reach_mult, _heavy_charge_ratio)
		if _current_combo_step_data().style == WeaponStats.AttackStyle.SHOOT:
			_heavy_arrow_speed_mult = lerpf(1.0, _active_weapon.heavy_projectile_speed_mult, _heavy_charge_ratio)

	hitbox.combo_step = _combo_step
	hitbox.is_finisher = (_combo_step == _active_weapon.combo_steps.size())
	hitbox.wielder_is_airborne = (state == State.JUMP or state == State.FALL)
	var now := Time.get_ticks_msec() / 1000.0
	hitbox.time_since_dodge = now - _last_dodge_end_time
	hitbox.is_plunge = false
	hitbox.plunge_intensity = 0.0
	hitbox.attack_origin = global_position
	hitbox.weapon_reach = actual_reach

	var bonus_hitbox_size := _get_active_rune_modifier_value(&"hitbox_size")
	var actual_radius := _active_weapon.hitbox_radius + bonus_hitbox_size
	if _heavy_charged:
		actual_radius *= lerpf(1.0, _active_weapon.heavy_reach_mult, _heavy_charge_ratio)
	if sweep_active:
		actual_radius *= elemental.sweep_buff.reach_mult

	var rect := hitbox_shape.shape as RectangleShape2D
	if rect != null:
		rect.size = Vector2(actual_reach, actual_radius * 2.0)
	hitbox_shape.position.x = actual_reach / 2.0  # extends OUTWARD from the grip, not centered on it
	weapon_sprite.texture = _active_weapon.weapon_texture
	if weapon_sprite.texture != null:
		weapon_sprite.offset = Vector2(actual_reach / 2.0, 0.0)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.position = Vector2.ZERO  # sits at Hitbox's own origin now — Hitbox's transform does the moving
	weapon_sprite.rotation = 0.0


func _get_active_rune_modifier_value(modifier_id: StringName) -> float:
	var active_rune := weapon_rune if _active_weapon == weapon else secondary_weapon_rune
	if active_rune == null:
		return 0.0
	var total: float = 0.0
	for mod in active_rune.modifiers:
		if mod.get("id", &"") == modifier_id:
			total += float(mod.get("value", 0.0))
	return total


## 1.0 for the first hit, compounding by combo_damage_step_multiplier for
## each hit after that — following a combo string all the way through is
## meant to reward more than just spamming the first swing on cooldown.
func _combo_damage_multiplier() -> float:
	return pow(_active_weapon.combo_damage_step_multiplier, _combo_step - 1)

## Current combo step's motion data, wrapping past the array's end
## rather than indexing out of bounds — lets a weapon deliberately loop
## a shorter alternating pattern across a longer combo_length if it
## wants to (not used yet, but free once the array can be any length).
func _current_combo_step_data() -> ComboStepData:
	var steps := _active_weapon.combo_steps
	return steps[(_combo_step - 1) % steps.size()]

func _resolve_perfect_for_hit(hitbox: Hitbox, hurtbox: Hurtbox) -> bool:
	if hitbox == null or hitbox.perfect_condition == WeaponStats.PerfectCondition.NONE:
		return false
	if hitbox.perfect_condition == WeaponStats.PerfectCondition.STREAK:
		return _advance_perfect_streak_and_check()
	return false

func _advance_perfect_streak_and_check() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _perfect_streak_last_hit_time >= 2.0:
		_perfect_streak_count = 0
	_perfect_streak_count += 1
	_perfect_streak_last_hit_time = now
	return _perfect_streak_count >= 6

func _reset_perfect_streak() -> void:
	_perfect_streak_count = 0
	_perfect_streak_last_hit_time = -999.0

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
	# Energy-gated skills (plan-shop-and-skills §7.1) cast only when their
	# meter is full and have no cooldown; cooldown skills gate on
	# _skill_cooldowns as before.
	if skill.uses_energy:
		if get_skill_energy_ratio(skill) < 1.0:
			print("Skill needs full energy: ", skill.skill_name)
			return
	elif _skill_cooldowns.get(skill, 0.0) > 0.0:
		print("Skill on cooldown: ", skill.skill_name, " (", "%.1f" % _skill_cooldowns[skill], "s left)")
		return

	var charge := _resolve_skill_charge(skill)

	match skill.function:
		SkillData.Function.APPLY_SELF:
			elemental.cast_apply_self(skill.element, charge)
		SkillData.Function.REMOVE_APPLY_SELF:
			elemental.cast_cleanse_and_apply_self(skill.element, charge)
		SkillData.Function.APPLY_SINGLE_TARGET:
			_cast_single_target_skill(skill, charge)
		SkillData.Function.REMOVE_ENEMY:
			_cast_remove_enemy_skill(skill)
		SkillData.Function.APPLY_AREA:
			elemental.cast_apply_area(skill.element, skill.zone_radius, skill.zone_lifetime)
		SkillData.Function.AREA_BURST:
			elemental.cast_area_burst(skill.element, skill.radius, skill.damage, skill.control_duration, skill.slow_multiplier, skill.slow_duration, charge)
		SkillData.Function.JUMP_SLAM:
			_start_skill_slam(skill, charge)
		SkillData.Function.PROJECTILE_FAN:
			var fan_direction := Vector2(facing, 0)
			var fan_target := _find_skill_target(skill.cast_range)
			if fan_target != null:
				fan_direction = (fan_target.global_position - global_position).normalized()
			elemental.cast_projectile_fan(skill.element, charge, fan_direction, skill.projectile_count, skill.spread_deg, skill.damage, skill.projectile_speed, skill.projectile_lifetime, skill.pierce, skill.shred_amount)
		SkillData.Function.DASH:
			_start_skill_dash(skill)
		SkillData.Function.BUFF_ARMOR:
			elemental.cast_buff_armor(skill.armor_bonus, skill.buff_duration)
		SkillData.Function.APPLY_SHIELD:
			elemental.cast_apply_shield(skill.buff_duration, skill.damage, skill.radius, skill.control_duration)
		SkillData.Function.APPLY_SWEEP_BUFF:
			elemental.cast_sweep_buff(skill.buff_duration, skill.sweep_damage_mult, skill.sweep_reach_mult)

	if skill.function != SkillData.Function.JUMP_SLAM:
		_spawn_skill_cast_vfx(skill.element, skill.cast_vfx_style, facing, skill.radius)
	if skill.uses_energy:
		_skill_energy[skill] = 0.0  ## Cast consumes the full meter (plan-shop-and-skills §7.1).
	else:
		_skill_cooldowns[skill] = skill.cooldown
	print("Cast ", skill.skill_name)


func _spawn_skill_cast_vfx(
	element: StringName,
	style: SkillData.CastVFXStyle = SkillData.CastVFXStyle.BURST,
	wave_direction: int = 1,
	wave_distance: float = 90.0
) -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var parent: Node = tree.current_scene if tree.current_scene != null else get_parent()
	if parent == null:
		return null

	var vfx: Node2D
	if style == SkillData.CastVFXStyle.WAVE:
		vfx = SkillWaveVFXScript.new() as Node2D
		vfx.call("set_wave_direction", wave_direction)
		vfx.call("set_wave_distance", wave_distance * 1.5)
	else:
		vfx = SkillCastVFXScript.new() as Node2D
	vfx.call("set_element", element)
	parent.add_child(vfx)
	vfx.global_position = global_position
	return vfx


func _start_skill_slam(skill: SkillData, charge: int) -> void:
	_skill_slam_skill = skill
	_skill_slam_charge = charge
	_skill_slam_descending = false
	state = State.SKILL_SLAM
	velocity = Vector2(0.0, SKILL_SLAM_LAUNCH_VELOCITY)


func _process_skill_slam(delta: float) -> void:
	if _skill_slam_skill == null:
		state = State.IDLE if is_on_floor() else State.FALL
		return

	if _skill_slam_descending and is_on_floor():
		_finish_skill_slam()
		return

	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	if not _skill_slam_descending and velocity.y >= 0.0:
		_skill_slam_descending = true
		velocity.y = maxf(velocity.y, SKILL_SLAM_DESCENT_VELOCITY)


func _finish_skill_slam() -> void:
	var skill := _skill_slam_skill
	var charge := _skill_slam_charge
	_skill_slam_skill = null
	_skill_slam_charge = 0
	_skill_slam_descending = false
	state = State.IDLE
	velocity.y = 0.0
	if skill == null:
		return

	elemental.cast_area_burst(skill.element, skill.radius, skill.damage, skill.control_duration, skill.slow_multiplier, skill.slow_duration, charge)
	ScreenShake.shake(SKILL_SLAM_SHAKE_INTENSITY, SKILL_SLAM_SHAKE_DURATION)
	var impact_vfx := _spawn_skill_cast_vfx(skill.element)
	if impact_vfx != null:
		impact_vfx.global_position.y += 8.0


## A.3's rune-to-skill bonus: a same-element rune's +1 Charge applies to
## any equipped skill sharing that element too, checked against either
## weapon slot — "one bonus, not two", so this returns on the first match
## rather than stacking. Base 2 matches A.4's Active Skill Charge row.
func _resolve_skill_charge(skill: SkillData) -> int:
	if weapon != null:
		var effective1 = weapon_rune.element if weapon_rune != null else weapon.rune_element
		if effective1 != &"none" and effective1 == weapon.innate_element and weapon.innate_element == skill.element:
			return 3
	if secondary_weapon != null:
		var effective2 = secondary_weapon_rune.element if secondary_weapon_rune != null else secondary_weapon.rune_element
		if effective2 != &"none" and effective2 == secondary_weapon.innate_element and secondary_weapon.innate_element == skill.element:
			return 3
	return 2

func _cast_single_target_skill(skill: SkillData, charge: int) -> void:
	var aim_target := _find_skill_target(skill.cast_range)
	var aim_direction := Vector2(facing, 0)
	if aim_target != null:
		var to_target := aim_target.global_position - global_position
		if not to_target.is_zero_approx():
			aim_direction = to_target.normalized()
	elemental.cast_apply_projectile(skill.element, charge, aim_direction)

func _cast_remove_enemy_skill(skill: SkillData) -> void:
	var target := _find_skill_target(skill.cast_range)
	if target != null:
		elemental.cast_remove_enemy(target)

func _start_skill_dash(skill: SkillData) -> void:
	if skill.clear_slow:
		elemental.slow_effect.clear()
	var dash_duration := maxf(skill.dash_iframes, 0.2)
	state = State.DODGE
	_dodge_timer = 0.0
	_active_dodge_duration = dash_duration
	_active_dodge_iframe_window = Vector2(0.0, skill.dash_iframes)
	velocity = Vector2(facing * skill.dash_distance / dash_duration, 0.0)
	_start_dash_shadows(ElementIndicator.ELEMENT_COLOR.get(skill.element, Color(0.9, 0.9, 1.0)))


func _start_dash_shadows(tint: Color) -> void:
	_dash_shadow_color = tint
	_dash_shadow_active = true
	_dash_shadow_timer = DASH_SHADOW_INTERVAL
	_spawn_dash_shadow()


func _process_dash_shadows(delta: float) -> void:
	if not _dash_shadow_active:
		return
	_dash_shadow_timer -= delta
	while _dash_shadow_timer <= 0.0:
		_spawn_dash_shadow()
		_dash_shadow_timer += DASH_SHADOW_INTERVAL


func _spawn_dash_shadow() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else get_parent()
	if parent == null:
		return
	var shadow := DashShadowScript.new() as Node2D
	parent.add_child(shadow)
	shadow.call("capture", self, _dash_shadow_color)


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
func swap_weapon(is_primary: bool, new_weapon: WeaponStats, new_rune: RuneData = null) -> WeaponStats:
	var previous: WeaponStats
	if is_primary:
		previous = weapon
		weapon = new_weapon
		weapon_rune = new_rune
	else:
		previous = secondary_weapon
		secondary_weapon = new_weapon
		secondary_weapon_rune = new_rune
	_reset_perfect_streak()
	if new_weapon != null:
		SaveManager.record_weapon_unlock(new_weapon.resource_path)  ## Meta-progression (Section 6.2) — found once, unlocked forever.
	weapon_changed.emit(is_primary, new_weapon)
	return previous

func would_duplicate_weapon(is_primary: bool, candidate: WeaponStats) -> bool:
	if candidate == null or candidate.resource_path == "":
		return false
	var other := secondary_weapon if is_primary else weapon
	return other != null and other.resource_path == candidate.resource_path

func get_weapon_rune(is_primary: bool) -> RuneData:
	return weapon_rune if is_primary else secondary_weapon_rune

func can_apply_rune(rune: RuneData, is_primary: bool) -> bool:
	return (weapon != null) if is_primary else (secondary_weapon != null)

func apply_rune(rune: RuneData, is_primary: bool) -> RuneData:
	var old_rune: RuneData
	if is_primary:
		old_rune = weapon_rune
		weapon_rune = rune
	else:
		old_rune = secondary_weapon_rune
		secondary_weapon_rune = rune
	return old_rune


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

func would_duplicate_skill(is_primary: bool, candidate: SkillData) -> bool:
	if candidate == null or candidate.resource_path.is_empty():
		return false
	var other := skill_2 if is_primary else skill_1
	return other != null and other.resource_path == candidate.resource_path

func get_skill_cooldown_ratio(skill: SkillData) -> float:
	if skill == null or skill.cooldown <= 0.0:
		return 0.0
	return clampf(float(_skill_cooldowns.get(skill, 0.0)) / skill.cooldown, 0.0, 1.0)

## Energy-gated skill meter ratio for the HUD radial fill (plan-shop-and-skills
## §7.1). 0..1 — 1.0 means ready to cast.
func get_skill_energy_ratio(skill: SkillData) -> float:
	if skill == null or not skill.uses_energy or skill.energy_max <= 0.0:
		return 0.0
	return clampf(float(_skill_energy.get(skill, 0.0)) / skill.energy_max, 0.0, 1.0)

## §7.1 duck-typed hook called from ElementalCombatant.handle_hit() on the
## attacking Node when one of its hits causes a reaction. Fills the meter of
## any equipped energy skill whose element is in the reaction pair, EXCEPT
## Tương Vũ (reversed) outcomes. Only the attacker's own method is ever
## called, so enemy-caused reactions never reach here.
func on_reaction_caused(outcome: int, reaction_pair: Array) -> void:
	if outcome == Reactions.Outcome.KHAC_VU:
		return
	var amount := _reaction_energy_amount(outcome)
	if amount <= 0.0:
		return
	for skill in [skill_1, skill_2]:
		if skill == null or not skill.uses_energy:
			continue
		if not reaction_pair.has(skill.element):
			continue
		_skill_energy[skill] = minf(float(_skill_energy.get(skill, 0.0)) + amount, skill.energy_max)

## Placeholder fill amounts (plan §7.1): higher-quality reactions fill
## faster. Khắc partial = 5, Sinh Tier 1 / Khắc full clear = 10,
## Sinh Tier 2 / Thừa = 20.
func _reaction_energy_amount(outcome: int) -> float:
	match outcome:
		Reactions.Outcome.KHAC_PARTIAL:
			return 5.0
		Reactions.Outcome.SINH_TIER_1:
			return 10.0
		Reactions.Outcome.KHAC_FULL_CLEAR:
			return 10.0
		Reactions.Outcome.SINH_TIER_2:
			return 20.0
		Reactions.Outcome.KHAC_THUA:
			return 20.0
		_:
			return 0.0

func _update_facing() -> void:
	if state in [State.DODGE, State.ATTACK, State.SKILL_SLAM, State.HEAVY_WINDUP]:
		return  # Don't flip mid-action — avoids the hitbox flipping under an active swing.
	
	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir > 0.0:
		facing = 1
	elif input_dir < 0.0:
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


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 1.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _on_hurtbox_hit(hit_data: HitData) -> void:
	if playtest_invincible:
		return
	if elemental.try_absorb_hit(hit_data.source):
		var absorbed_weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
		HitStop.freeze_for_weight(absorbed_weight)
		ScreenShake.shake(3.0, 0.12)
		return
	_apply_damage(hit_data.damage, hit_data.perfect)
	velocity += hit_data.knockback
	var weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
	HitStop.freeze_for_weight(weight)
	ScreenShake.shake_for_weight(weight)
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
func _apply_damage(amount: float, is_perfect: bool = false) -> void:
	if _is_dead or playtest_invincible:
		return
	var mitigated = elemental.mitigate_damage(amount)
	DamagePopup.spawn(self, mitigated, Vector2(0, -10), is_perfect)
	current_health = maxf(current_health - mitigated, 0.0)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true  ## No further hits register — same convention as every enemy's own _die().
	visuals.modulate = Color(0.35, 0.35, 0.35)
	await get_tree().create_timer(0.6).timeout
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
		"max_health": max_health - UpgradeManager.vitality_hp_bonus(),
		"armor": elemental.armor,
		"weapon_path": weapon.resource_path if weapon != null else "",
		"weapon_rune": weapon_rune.to_dict() if weapon_rune != null else null,
		"secondary_weapon_path": secondary_weapon.resource_path if secondary_weapon != null else "",
		"secondary_weapon_rune": secondary_weapon_rune.to_dict() if secondary_weapon_rune != null else null,
		"skill_1_path": skill_1.resource_path if skill_1 != null else "",
		"skill_2_path": skill_2.resource_path if skill_2 != null else "",
		"skill_energy": _serialize_skill_energy(),
	}


## §7.1 — energy meters persist across save/resume (unlike cooldowns, which
## are deliberately not saved). Serialized by resource_path so the map
## round-trips across load(); instance identity is rebuilt on resume.
func _serialize_skill_energy() -> Dictionary:
	var out: Dictionary = {}
	for skill in [skill_1, skill_2]:
		if skill != null and skill.uses_energy:
			out[skill.resource_path] = _skill_energy.get(skill, 0.0)
	return out


## Restores a previously-saved state (RunManager, on resume). Weapon/
## skill paths are loaded fresh via load() rather than resolving back to
## some in-memory instance — safe because every real .tres weapon/skill
## is a stable, shared Resource, the same assumption swap_weapon/
## swap_skill already make when a pickup hands one over directly.
## Deliberately does NOT go through swap_weapon/swap_skill — resuming a
## run must not re-trigger a meta-progression unlock for something that
## was already unlocked the first time it was ever picked up.
func apply_save_state(saved_state: Dictionary) -> void:
	max_health = saved_state.get("max_health", max_health) + UpgradeManager.vitality_hp_bonus()
	current_health = minf(saved_state.get("current_health", current_health), max_health)
	elemental.armor = saved_state.get("armor", elemental.armor)
	_load_weapon_path(saved_state.get("weapon_path", ""), true)
	_load_weapon_path(saved_state.get("secondary_weapon_path", ""), false)
	
	if saved_state.has("weapon_rune") and saved_state.weapon_rune != null:
		weapon_rune = RuneData.from_dict(saved_state.weapon_rune)
	else:
		weapon_rune = null
		
	if saved_state.has("secondary_weapon_rune") and saved_state.secondary_weapon_rune != null:
		secondary_weapon_rune = RuneData.from_dict(saved_state.secondary_weapon_rune)
	else:
		secondary_weapon_rune = null

	_load_skill_path(saved_state.get("skill_1_path", ""), true)
	_load_skill_path(saved_state.get("skill_2_path", ""), false)
	# §7.1 — restore energy meters keyed by the freshly-loaded skill
	# instances. Legacy snapshots without "skill_energy" start at 0.
	_skill_energy.clear()
	var saved_energy: Dictionary = saved_state.get("skill_energy", {})
	for skill in [skill_1, skill_2]:
		if skill != null and skill.uses_energy:
			var path: String = skill.resource_path
			if saved_energy.has(path):
				_skill_energy[skill] = float(saved_energy[path])


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
