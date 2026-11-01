class_name SupportAI
extends Node
## Support behavior composed onto support enemies. It shields the nearest
## unshielded enemy ally in range and keeps its owner away from the player.

signal ally_shielded(ally: Node2D)

@export var stats: EnemyStats

var _support_cooldown: float = 0.0
var _retreat_cycle_remaining: float = -1.0
var _retreat_burst_remaining: float = 0.0


func update(delta: float, player: Node2D) -> void:
	if stats == null:
		return
	if _retreat_cycle_remaining < 0.0:
		_retreat_cycle_remaining = stats.support_retreat_interval
	_retreat_cycle_remaining = maxf(_retreat_cycle_remaining - delta, 0.0)
	if _retreat_cycle_remaining <= 0.0 and _retreat_burst_remaining <= 0.0:
		_retreat_burst_remaining = stats.support_retreat_duration
		_retreat_cycle_remaining = stats.support_retreat_interval
	_retreat_burst_remaining = maxf(_retreat_burst_remaining - delta, 0.0)
	_support_cooldown = maxf(_support_cooldown - delta, 0.0)
	var owner_body := get_parent() as CharacterBody2D
	var owner_elemental := owner_body.get("elemental") as ElementalCombatant if owner_body != null else null
	if owner_elemental != null and owner_elemental.is_disabled():
		_stop_movement(delta)
		return
	if _support_cooldown <= 0.0:
		var ally := find_nearest_unshielded_ally()
		if ally != null:
			var combatant := ally.get("elemental") as ElementalCombatant
			combatant.shield.apply(stats.support_shield_duration)
			_support_cooldown = stats.support_cooldown
			ally_shielded.emit(ally)
	_update_spacing(player, delta, _retreat_burst_remaining > 0.0)


func find_nearest_unshielded_ally() -> Node2D:
	if stats == null or stats.support_range <= 0.0 or not is_inside_tree():
		return null
	var owner_2d := get_parent() as Node2D
	if owner_2d == null:
		return null
	var nearest: Node2D
	var nearest_distance := stats.support_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var ally := node as Node2D
		if ally == null or ally == owner_2d or not is_instance_valid(ally):
			continue
		if not ally.has_method("get"):
			continue
		var combatant := ally.get("elemental") as ElementalCombatant
		if combatant == null or combatant.shield.active:
			continue
		var hurtbox := ally.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox != null and hurtbox.invulnerable:
			continue
		var distance := owner_2d.global_position.distance_to(ally.global_position)
		if distance <= nearest_distance:
			nearest = ally
			nearest_distance = distance
	return nearest


func _update_spacing(player: Node2D, delta: float, retreating: bool) -> void:
	var owner_body := get_parent() as CharacterBody2D
	if owner_body == null:
		return
	var owner_elemental := owner_body.get("elemental") as ElementalCombatant
	if player == null or not retreating or (owner_elemental != null and owner_elemental.is_disabled()):
		_stop_movement(delta)
		return
	var distance := owner_body.global_position.distance_to(player.global_position)
	if distance >= stats.support_keep_distance:
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0.0, stats.support_move_speed * delta)
		return
	var away_from_player := signf(owner_body.global_position.x - player.global_position.x)
	if is_zero_approx(away_from_player):
		away_from_player = float(owner_body.get("facing"))
		if is_zero_approx(away_from_player):
			away_from_player = 1.0
	if not _has_ground_ahead(owner_body, away_from_player):
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0.0, stats.support_move_speed * delta)
		return
	owner_body.velocity.x = away_from_player * stats.support_move_speed


func _stop_movement(_delta: float) -> void:
	var owner_body := get_parent() as CharacterBody2D
	if owner_body != null:
		owner_body.velocity.x = 0.0


func _has_ground_ahead(owner_body: CharacterBody2D, direction: float) -> bool:
	var ray_start := owner_body.global_position + Vector2(direction * 10.0, 5.0)
	var ray_end := ray_start + Vector2(0.0, 30.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = owner_body.collision_mask
	query.exclude = [owner_body.get_rid()]
	return not owner_body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
