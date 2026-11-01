extends GutTest

const SHIELDER_SCENE_PATH := "res://scenes/enemies/shielder_enemy.tscn"
const SHIELDER_STATS_PATH := "res://scripts/resources/enemies/shielder_stats.tres"
const CombatantOwner := preload("res://test/helpers/combatant_owner.gd")

var shielder: ShielderEnemy


func before_each() -> void:
	shielder = load(SHIELDER_SCENE_PATH).instantiate() as ShielderEnemy
	shielder.set_physics_process(false)
	add_child_autofree(shielder)


func _add_ally(position: Vector2, shielded: bool = false) -> CombatantOwner:
	var ally := CombatantOwner.new()
	ally.position = position
	ally.add_to_group("enemies")
	ally.elemental = ElementalCombatant.new()
	ally.elemental.show_debug_readout = false
	ally.add_child(ally.elemental)
	add_child_autofree(ally)
	if shielded:
		ally.elemental.shield.apply(3.0)
	return ally


func _add_floor(center: Vector2, width: float) -> void:
	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 10.0)
	shape_node.shape = shape
	floor.add_child(shape_node)
	floor.position = center
	add_child_autofree(floor)


func test_shielder_stats_define_support_range_cooldown_and_plain_shield() -> void:
	var stats := load(SHIELDER_STATS_PATH) as EnemyStats
	assert_not_null(stats)
	assert_gt(stats.support_range, 0.0)
	assert_gt(stats.support_cooldown, 0.0)
	assert_gt(stats.support_shield_duration, 0.0)
	assert_gt(stats.max_health, 0.0, "the shielder has ordinary killable enemy health")
	assert_true(shielder.is_in_group("enemies"), "room clear counts the shielder as a living enemy")


func test_crossroads_chunk_places_a_shielder_spawn_point() -> void:
	var chunk_scene := load("res://scenes/world/chunks/chunk_crossroads_v2.tscn") as PackedScene
	assert_not_null(chunk_scene)
	var chunk := chunk_scene.instantiate()
	add_child_autofree(chunk)
	var spawn := chunk.find_child("SpawnPoint_Shielder", true, false) as EnemySpawnPoint
	assert_not_null(spawn)
	if spawn != null:
		assert_eq(spawn.enemy_scene.resource_path, SHIELDER_SCENE_PATH)
		assert_eq(spawn.enemy_stats.support_range, 180.0)


func test_support_ai_shields_nearest_unshielded_ally_in_range() -> void:
	var shielded_nearby := _add_ally(Vector2(18, 0), true)
	var farther_nearby := _add_ally(Vector2(65, 0))
	_add_ally(Vector2(220, 0))
	shielder.support_ai.stats = EnemyStats.new()
	shielder.support_ai.stats.support_range = 100.0
	shielder.support_ai.stats.support_cooldown = 4.0
	shielder.support_ai.stats.support_shield_duration = 3.5
	shielder.support_ai.update(0.016, null)
	assert_true(shielded_nearby.elemental.shield.active, "the existing shield remains active")
	assert_true(farther_nearby.elemental.shield.active, "the nearest unshielded ally is protected")
	assert_true(farther_nearby.elemental.get_node("ShieldEllipseVFX").visible, "the ally gets an ellipse while shielded")
	assert_almost_eq(farther_nearby.elemental.shield.get_remaining_duration(), 3.5, 0.01)
	assert_false(shielder.elemental.shield.active, "the shielder does not shield itself")
	var link_found := false
	for node in get_tree().get_nodes_in_group("shield_link_vfx"):
		if node.get("source") == shielder and node.get("target") == farther_nearby:
			link_found = true
			node.queue_free()
	assert_true(link_found, "a brief lightning link connects the shielder to its ally")


func test_shield_absorbs_one_hit_before_damage_and_reaction() -> void:
	var attacker := CombatantOwner.new()
	attacker.elemental = ElementalCombatant.new()
	attacker.add_child(attacker.elemental)
	add_child_autofree(attacker)
	shielder.elemental.shield.apply(4.0)
	assert_true(shielder.elemental.get_node("ShieldEllipseVFX").visible)
	var health_before := shielder._current_health
	var hit := HitData.new(10.0, Vector2(50, 0), attacker, false)
	hit.element = Elements.KIM
	hit.charge = 1
	shielder._on_hurtbox_hit(hit)
	assert_almost_eq(shielder._current_health, health_before, 0.01, "the absorbed hit deals no damage")
	assert_false(shielder.elemental.shield.active)
	assert_false(shielder.elemental.get_node("ShieldEllipseVFX").visible)
	assert_eq(shielder.elemental.status.element, Elements.NONE, "an absorbed hit does not apply status")
	shielder._on_hurtbox_hit(hit)
	assert_lt(shielder._current_health, health_before, "the next hit uses the normal damage pipeline")
	assert_eq(shielder.elemental.status.element, Elements.KIM)


func test_shielder_retreats_in_cycles_and_holds_position_between_them() -> void:
	_add_floor(Vector2.ZERO, 400.0)
	shielder.position = Vector2(0, -12)
	var stats := EnemyStats.new()
	stats.support_keep_distance = 100.0
	stats.support_move_speed = 40.0
	stats.support_retreat_interval = 1.0
	stats.support_retreat_duration = 0.5
	shielder.support_ai.stats = stats
	var player := Node2D.new()
	player.position = Vector2(30, -12)
	add_child_autofree(player)
	shielder.support_ai.update(0.25, player)
	assert_almost_eq(shielder.velocity.x, 0.0, 0.01, "waits before the first retreat cycle")
	for _frame in range(3):
		shielder.support_ai.update(0.25, player)
	assert_lt(shielder.velocity.x, 0.0, "retreats when the cycle begins")
	for _frame in range(2):
		shielder.support_ai.update(0.25, player)
	assert_almost_eq(shielder.velocity.x, 0.0, 0.01, "holds position after the retreat burst")
	shielder.velocity.x = -20.0
	player.position = Vector2(200, -12)
	shielder.support_ai.update(0.016, player)
	assert_gt(shielder.velocity.x, -20.0, "stops retreating after reaching its spacing range")


func test_shielder_stops_retreating_before_a_platform_edge() -> void:
	_add_floor(Vector2(100, 0), 200.0)
	var stats := EnemyStats.new()
	stats.support_keep_distance = 100.0
	stats.support_move_speed = 40.0
	stats.support_retreat_interval = 0.01
	stats.support_retreat_duration = 0.5
	shielder.support_ai.stats = stats
	shielder.position = Vector2(5, -12)
	var player := Node2D.new()
	player.position = Vector2(30, -12)
	add_child_autofree(player)
	shielder.support_ai.update(0.016, player)
	assert_almost_eq(shielder.velocity.x, 0.0, 0.01, "does not step off the edge away from the player")
