extends Node2D

const ROCK_PROJECTILE_SCRIPT := preload("res://scripts/combat/boss_rock_projectile.gd")
const SHOCKWAVE_PROJECTILE_SCRIPT := preload("res://scripts/combat/boss_shockwave_projectile.gd")

enum AttackState {
	READY,
	CHARGE_TELEGRAPH,
	CHARGING,
	ROCK_TELEGRAPH,
	SHOCKWAVE_TELEGRAPH,
	RECOVERY,
}

const ROCK_START_DISTANCE: float = 240.0
const CHARGE_START_DISTANCE: float = 95.0
const SHOCKWAVE_START_DISTANCE: float = 65.0
const ROCK_TELEGRAPH_DURATION: float = 0.25
const MISSED_CHARGE_RECOVERY: float = 0.45

var boss: Boss
var stats: BossStats

var _state: AttackState = AttackState.READY
var _state_timer: float = 0.0
var _charge_cooldown: float = 0.0
var _shockwave_cooldown: float = 0.0
var _rock_cooldown: float = 0.0
var _last_special: AttackState = AttackState.READY
var _charge_direction: float = 1.0
var _charge_start_x: float = 0.0
var _charge_hitbox: Hitbox
var _charge_lane: Line2D
var _rock_aim_line: Line2D
var _rock_aim_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_charge_hitbox = Hitbox.new()
	_charge_hitbox.monitoring = false
	_charge_hitbox.collision_layer = 0
	_charge_hitbox.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(26.0, 12.0)
	shape.shape = rectangle
	_charge_hitbox.position = Vector2(0.0, 6.0)
	_charge_hitbox.add_child(shape)
	add_child(_charge_hitbox)
	_charge_hitbox.owner = boss

	_charge_lane = Line2D.new()
	_charge_lane.width = 3.0
	_charge_lane.default_color = Color(1.0, 0.55, 0.2, 0.8)
	_charge_lane.add_point(Vector2.ZERO)
	_charge_lane.add_point(Vector2.ZERO)
	_charge_lane.visible = false
	add_child(_charge_lane)

	_rock_aim_line = Line2D.new()
	_rock_aim_line.name = "RockAimTrail"
	_rock_aim_line.width = 2.0
	_rock_aim_line.default_color = Color(1.0, 0.78, 0.34, 0.9)
	_rock_aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rock_aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_rock_aim_line.visible = false
	add_child(_rock_aim_line)


func update(delta: float, player: Node2D) -> bool:
	if boss == null or stats == null or boss.is_dead():
		return false

	var cooldown_scale := maxf(boss.combat_ai.attack_cooldown_multiplier if boss.combat_ai != null else 1.0, 0.1)
	_charge_cooldown = maxf(_charge_cooldown - delta / cooldown_scale, 0.0)
	_shockwave_cooldown = maxf(_shockwave_cooldown - delta / cooldown_scale, 0.0)
	_rock_cooldown = maxf(_rock_cooldown - delta / cooldown_scale, 0.0)

	if boss.elemental.is_disabled():
		cancel_attack()
		return false

	match _state:
		AttackState.CHARGE_TELEGRAPH:
			_state_timer -= delta
			boss.velocity.x = 0.0
			if _state_timer <= 0.0:
				_begin_charge()
			return true
		AttackState.CHARGING:
			boss.velocity.x = _charge_direction * stats.charge_speed
			return true
		AttackState.ROCK_TELEGRAPH:
			_state_timer -= delta
			boss.velocity.x = 0.0
			if _state_timer <= 0.0:
				_throw_rock()
				_begin_recovery(0.2)
			return true
		AttackState.SHOCKWAVE_TELEGRAPH:
			_state_timer -= delta
			boss.velocity.x = 0.0
			if _state_timer <= 0.0:
				_release_shockwave()
				_begin_recovery(0.35)
			return true
		AttackState.RECOVERY:
			_state_timer -= delta
			boss.velocity.x = move_toward(boss.velocity.x, 0.0, 800.0 * delta)
			if _state_timer <= 0.0:
				_finish_recovery()
				return false
			return true

	if boss.is_passive or boss.is_stunned or player == null:
		return false

	var distance := absf(player.global_position.x - boss.global_position.x)
	var vertical_distance := absf(player.global_position.y - boss.global_position.y)
	if _try_start_special(distance, vertical_distance, player):
		return true
	return false


func after_move() -> void:
	if _state != AttackState.CHARGING:
		return

	var travelled := absf(boss.global_position.x - _charge_start_x)
	if boss.is_on_wall():
		_charge_hitbox.disable()
		_state = AttackState.READY
		boss.velocity.x = 0.0
		boss.apply_stun(stats.charge_wall_stun_duration, stats.charge_stun_damage_multiplier)
	elif travelled >= stats.charge_max_distance:
		_charge_hitbox.disable()
		boss.velocity.x = 0.0
		_begin_recovery(MISSED_CHARGE_RECOVERY)


func cancel_attack() -> void:
	if _charge_hitbox != null:
		_charge_hitbox.disable()
	if _charge_lane != null:
		_charge_lane.visible = false
	if _rock_aim_line != null:
		_rock_aim_line.visible = false
	if boss != null:
		boss.velocity.x = 0.0
		boss.set_attack_telegraph(false)
		if boss.combat_ai != null and not boss.is_passive and not boss.is_stunned:
			boss.combat_ai.can_chase = true
	_state = AttackState.READY
	_state_timer = 0.0


func _try_start_special(distance: float, vertical_distance: float, player: Node2D) -> bool:
	var player_is_elevated := player.global_position.y < boss.global_position.y - 20.0
	var player_is_below := player.global_position.y > boss.global_position.y + 50.0
	var rock_range := Vector2(distance, vertical_distance).length()
	if stats.rock_throw_enabled and (rock_range >= ROCK_START_DISTANCE or player_is_elevated or player_is_below) and _rock_cooldown <= 0.0 and _last_special != AttackState.ROCK_TELEGRAPH:
		_start_rock(player)
		return true
	if stats.charge_enabled and distance >= CHARGE_START_DISTANCE and distance <= stats.charge_max_distance and _charge_cooldown <= 0.0 and _last_special != AttackState.CHARGE_TELEGRAPH:
		_start_charge()
		return true
	if stats.shockwave_enabled and distance <= SHOCKWAVE_START_DISTANCE and _shockwave_cooldown <= 0.0 and _last_special != AttackState.SHOCKWAVE_TELEGRAPH:
		_start_shockwave(player)
		return true
	return false


func _prepare_special() -> void:
	if boss.combat_ai != null:
		boss.combat_ai.interrupt()
		boss.combat_ai.can_chase = false
	boss.velocity.x = 0.0


func _start_charge() -> void:
	_prepare_special()
	_state = AttackState.CHARGE_TELEGRAPH
	_state_timer = maxf(stats.charge_telegraph_duration, 0.0)
	_charge_direction = float(boss.facing)
	_charge_lane.set_point_position(0, Vector2(0.0, 6.0))
	_charge_lane.set_point_position(1, Vector2(_charge_direction * stats.charge_max_distance, 6.0))
	_charge_lane.visible = true
	_charge_cooldown = stats.charge_cooldown
	_last_special = AttackState.CHARGE_TELEGRAPH
	boss.set_attack_telegraph(true)


func _begin_charge() -> void:
	_charge_lane.visible = false
	boss.set_attack_telegraph(false)
	_state = AttackState.CHARGING
	_charge_start_x = boss.global_position.x
	_charge_hitbox.damage = stats.charge_damage
	_charge_hitbox.knockback_strength = stats.knockback_strength * 1.5
	_charge_hitbox.weapon_weight = &"heavy"
	_charge_hitbox.element = boss.elemental.innate_element
	_charge_hitbox.charge = stats.charge_innate_charge
	_charge_hitbox.enable()


func _start_rock(player: Node2D) -> void:
	_prepare_special()
	_state = AttackState.ROCK_TELEGRAPH
	_state_timer = maxf(stats.rock_telegraph_duration, 0.0)
	var spawn_position := Vector2(float(boss.facing) * 10.0, -4.0)
	_rock_aim_direction = (player.global_position - (boss.global_position + spawn_position)).normalized()
	if _rock_aim_direction.is_zero_approx():
		_rock_aim_direction = Vector2(float(boss.facing), 0.0)
	var aim_length := minf(stats.rock_aim_distance, stats.rock_speed * maxf(_state_timer, 0.1))
	var aim_end := spawn_position + _rock_aim_direction * aim_length
	var arrow_side := Vector2(-_rock_aim_direction.y, _rock_aim_direction.x) * 5.0
	_rock_aim_line.clear_points()
	_rock_aim_line.add_point(spawn_position)
	_rock_aim_line.add_point(aim_end - _rock_aim_direction * 7.0)
	_rock_aim_line.add_point(aim_end)
	_rock_aim_line.add_point(aim_end - _rock_aim_direction * 7.0 + arrow_side)
	_rock_aim_line.add_point(aim_end)
	_rock_aim_line.add_point(aim_end - _rock_aim_direction * 7.0 - arrow_side)
	_rock_aim_line.visible = true
	_rock_cooldown = stats.rock_cooldown
	_last_special = AttackState.ROCK_TELEGRAPH
	boss.set_attack_telegraph(true)


func _throw_rock() -> void:
	boss.set_attack_telegraph(false)
	_rock_aim_line.visible = false
	var projectile := ROCK_PROJECTILE_SCRIPT.new() as BaseProjectile
	var spawn_position := boss.global_position + Vector2(float(boss.facing) * 10.0, -4.0)
	projectile.direction = _rock_aim_direction
	projectile.speed = stats.rock_speed
	projectile.element = boss.elemental.innate_element
	projectile.charge = 1
	projectile.attacker = boss
	projectile.set("damage", stats.rock_damage)
	projectile.set("knockback_strength", stats.knockback_strength)
	projectile.add_to_group("boss_projectiles")
	_add_projectile_to_room(projectile, spawn_position)


func _start_shockwave(_player: Node2D) -> void:
	_prepare_special()
	_state = AttackState.SHOCKWAVE_TELEGRAPH
	_state_timer = maxf(stats.shockwave_telegraph_duration, 0.0)
	_shockwave_cooldown = stats.shockwave_cooldown
	_last_special = AttackState.SHOCKWAVE_TELEGRAPH
	boss.set_attack_telegraph(true)


func _release_shockwave() -> void:
	boss.set_attack_telegraph(false)
	for direction_x in [-1.0, 1.0]:
		var projectile := SHOCKWAVE_PROJECTILE_SCRIPT.new() as BaseProjectile
		projectile.direction = Vector2(direction_x, 0.0)
		projectile.speed = stats.shockwave_speed
		projectile.element = boss.elemental.innate_element
		projectile.charge = stats.shockwave_innate_charge
		projectile.attacker = boss
		projectile.set("damage", stats.shockwave_damage)
		projectile.set("knockback_strength", stats.knockback_strength * 0.75)
		projectile.add_to_group("boss_projectiles")
		_add_projectile_to_room(projectile, boss.global_position + Vector2(0.0, 6.0))


func _add_projectile_to_room(projectile: BaseProjectile, spawn_position: Vector2) -> void:
	var room_root := boss.get_tree().current_scene
	if room_root == null:
		room_root = boss.get_parent()
	if room_root == null:
		push_error("Boss projectile could not find a room parent")
		projectile.free()
		return
	room_root.add_child(projectile)
	projectile.global_position = spawn_position


func _begin_recovery(duration: float) -> void:
	_state = AttackState.RECOVERY
	_state_timer = duration


func _finish_recovery() -> void:
	_state = AttackState.READY
	boss.set_attack_telegraph(false)
	if boss.combat_ai != null and not boss.is_passive and not boss.is_stunned:
		boss.combat_ai.can_chase = true
