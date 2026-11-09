extends GutTest

const BOSS_SCENE_PATH := "res://scenes/enemies/boss.tscn"
const THO_NGUU_STATS_PATH := "res://scripts/resources/enemies/tho_nguu_boss_stats.tres"
const BOSS_ROOM_PATH := "res://scenes/world/rooms/room_boss.tscn"
const ROCK_PROJECTILE_SCRIPT := preload("res://scripts/combat/boss_rock_projectile.gd")
const SHOCKWAVE_PROJECTILE_SCRIPT := preload("res://scripts/combat/boss_shockwave_projectile.gd")

var boss: Boss
var player: Node2D


func before_each() -> void:
	boss = load(BOSS_SCENE_PATH).instantiate() as Boss
	boss.boss_stats = load(THO_NGUU_STATS_PATH)
	add_child_autofree(boss)
	boss.elemental.armor = 0.0
	player = Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	player.global_position = boss.global_position + Vector2(300.0, 0.0)


func after_each() -> void:
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		projectile.queue_free()
	for spark in get_tree().get_nodes_in_group("boss_shockwave_sparks"):
		spark.queue_free()
	await get_tree().process_frame


func test_far_player_gets_rock_projectile_with_phase_element() -> void:
	var controller: Node = boss.attack_controller
	assert_true(controller.call("update", 0.01, player))
	assert_true(controller.call("update", 0.7, player))

	var projectiles := get_tree().get_nodes_in_group("boss_projectiles")
	assert_eq(projectiles.size(), 1)
	var projectile := projectiles[0] as BaseProjectile
	assert_not_null(projectile)
	assert_eq(projectile.element, Elements.THO)
	assert_eq(projectile.charge, 1)
	assert_almost_eq(projectile.direction.x, 1.0, 0.01)


func test_elevated_player_triggers_aimed_rock_with_visible_path_clue() -> void:
	player.global_position = boss.global_position + Vector2(70.0, -100.0)
	var controller: Node = boss.attack_controller
	assert_true(controller.call("update", 0.016, player))

	var aim_line := controller.get("_rock_aim_line") as Line2D
	assert_true(aim_line.visible)
	assert_gte(aim_line.get_point_count(), 6)
	var aimed_direction: Vector2 = controller.get("_rock_aim_direction")
	assert_lt(aimed_direction.y, 0.0)

	assert_true(controller.call("update", 0.7, player))
	assert_false(aim_line.visible)
	var projectiles := get_tree().get_nodes_in_group("boss_projectiles")
	assert_eq(projectiles.size(), 1)
	var rock := projectiles[0] as BaseProjectile
	assert_almost_eq(rock.direction.x, aimed_direction.x, 0.01)
	assert_almost_eq(rock.direction.y, aimed_direction.y, 0.01)


func test_rock_can_aim_downward_at_lower_player() -> void:
	player.global_position = boss.global_position + Vector2(70.0, 80.0)
	var controller: Node = boss.attack_controller
	assert_true(controller.call("update", 0.016, player))
	var aimed_direction: Vector2 = controller.get("_rock_aim_direction")
	assert_gt(aimed_direction.y, 0.0)

	controller.call("update", 0.7, player)
	var projectiles := get_tree().get_nodes_in_group("boss_projectiles")
	assert_eq(projectiles.size(), 1)
	var rock := projectiles[0] as BaseProjectile
	assert_gt(rock.direction.y, 0.0)


func test_close_player_gets_two_ground_shockwaves() -> void:
	player.global_position = boss.global_position + Vector2(50.0, 0.0)
	var controller: Node = boss.attack_controller
	assert_true(controller.call("update", 0.01, player))
	assert_true(controller.call("update", 0.61, player))

	var projectiles := get_tree().get_nodes_in_group("boss_projectiles")
	assert_eq(projectiles.size(), 2)
	for projectile_node in projectiles:
		var projectile := projectile_node as BaseProjectile
		assert_eq(projectile.element, Elements.THO)
		assert_eq(projectile.charge, 1)
		assert_almost_eq(absf(projectile.direction.x), 1.0, 0.01)


func test_shockwave_emits_element_tinted_ground_sparks_along_its_path() -> void:
	var shockwave := SHOCKWAVE_PROJECTILE_SCRIPT.new() as BaseProjectile
	shockwave.direction = Vector2.RIGHT
	shockwave.speed = 100.0
	shockwave.element = Elements.THO
	add_child_autofree(shockwave)
	shockwave.set_process(false)

	shockwave.call("_process", 0.6)

	var sparks := get_tree().get_nodes_in_group("boss_shockwave_sparks")
	assert_eq(sparks.size(), 3, "shockwave should emit a spark at each spacing interval")
	for index in range(sparks.size()):
		var spark_node: Node = sparks[index]
		var spark := spark_node as HitParticles
		assert_eq(spark.element, Elements.THO)
		assert_eq(spark.away_direction, Vector2.UP)
		assert_eq(spark.amount, 11, "shockwave bursts should emit more diamond shards")
		assert_almost_eq(spark.global_position.x, float(index + 1) * 20.0, 0.01)
		assert_almost_eq(spark.global_position.y, shockwave.global_position.y + 8.0, 0.01)


func test_shockwave_pierces_a_target_without_reapplying_its_hit() -> void:
	var hurtbox := Hurtbox.new()
	add_child_autofree(hurtbox)
	var received_hits: Array[HitData] = []
	hurtbox.hit_received.connect(func(hit_data: HitData) -> void: received_hits.append(hit_data))

	var shockwave := SHOCKWAVE_PROJECTILE_SCRIPT.new() as BaseProjectile
	shockwave.direction = Vector2.RIGHT
	shockwave.set("damage", 8.0)
	add_child_autofree(shockwave)
	shockwave.call("_resolve_hit", hurtbox)
	shockwave.call("_resolve_hit", hurtbox)

	assert_eq(received_hits.size(), 1, "the same target should only be damaged once")
	assert_false(shockwave.is_queued_for_deletion(), "shockwave should continue travelling after a hit")


func test_charge_hitbox_is_low_and_enabled_after_telegraph() -> void:
	player.global_position = boss.global_position + Vector2(150.0, 0.0)
	var controller: Node = boss.attack_controller
	assert_true(controller.call("update", 0.01, player))

	var charge_hitbox := controller.get("_charge_hitbox") as Hitbox
	assert_not_null(charge_hitbox)
	var shape := charge_hitbox.get_child(0) as CollisionShape2D
	assert_not_null(shape)
	assert_almost_eq((shape.shape as RectangleShape2D).size.y, 12.0, 0.01)

	assert_true(controller.call("update", 0.8, player))
	assert_true(controller.call("update", 0.016, player))
	assert_true(charge_hitbox.monitoring)
	assert_eq(charge_hitbox.weapon_weight, &"heavy")
	assert_eq(charge_hitbox.element, Elements.THO)
	assert_eq(charge_hitbox.charge, 2)


func test_charge_hits_arena_wall_and_stuns_boss() -> void:
	var room := load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	var room_boss := room.find_child("Boss", true, false) as Boss
	room_boss.set_physics_process(false)
	room_boss.global_position = Vector2(300.0, 90.0)
	room_boss.facing = 1
	var target := Node2D.new()
	add_child_autofree(target)
	target.global_position = Vector2(600.0, 90.0)

	var controller: Node = room_boss.attack_controller
	controller.call("_start_charge")
	controller.call("update", 1.0, target)
	controller.call("update", 0.016, target)
	await get_tree().physics_frame
	room_boss.move_and_slide()
	controller.call("after_move")

	assert_true(room_boss.is_on_wall())
	assert_true(room_boss.is_stunned)
	assert_eq(room_boss.get("_stagger_damage_multiplier"), 1.5)


func test_charge_miss_recovers_without_damage_bonus() -> void:
	boss.set_physics_process(false)
	player.global_position = boss.global_position + Vector2(150.0, 0.0)
	var controller: Node = boss.attack_controller
	controller.call("_start_charge")
	controller.call("update", 1.0, player)
	controller.call("update", 0.016, player)
	var start_x: float = controller.get("_charge_start_x")
	boss.global_position.x = start_x + boss.boss_stats.charge_max_distance + 1.0
	controller.call("after_move")

	assert_false(boss.is_stunned)
	assert_eq(controller.get("_state"), 5)
	assert_eq(boss.velocity.x, 0.0)


func test_projectiles_send_hitdata_through_hurtbox() -> void:
	var hurtbox := Hurtbox.new()
	add_child_autofree(hurtbox)
	hurtbox.global_position = Vector2(1000.0, 1000.0)
	var received: Array[HitData] = []
	hurtbox.hit_received.connect(func(hit_data: HitData) -> void: received.append(hit_data))

	var rock := ROCK_PROJECTILE_SCRIPT.new() as BaseProjectile
	add_child_autofree(rock)
	rock.attacker = boss
	rock.element = Elements.HOA
	rock.charge = 1
	rock.set("damage", 6.0)
	rock.call("_resolve_hit", hurtbox)

	var shockwave := SHOCKWAVE_PROJECTILE_SCRIPT.new() as BaseProjectile
	add_child_autofree(shockwave)
	shockwave.attacker = boss
	shockwave.element = Elements.THO
	shockwave.charge = 1
	shockwave.direction = Vector2.LEFT
	shockwave.set("damage", 8.0)
	shockwave.call("_resolve_hit", hurtbox)

	assert_eq(received.size(), 2)
	assert_eq(received[0].damage, 6.0)
	assert_eq(received[0].element, Elements.HOA)
	assert_eq(received[0].weapon_weight, &"heavy")
	assert_eq(received[1].damage, 8.0)
	assert_eq(received[1].element, Elements.THO)
	assert_eq(received[1].weapon_weight, &"heavy")
	assert_lt(received[1].knockback.x, 0.0)


func test_boss_melee_hitbox_uses_heavy_impact_weight() -> void:
	boss.combat_ai._start_active_window()

	assert_eq(boss.combat_ai._hitbox.weapon_weight, &"heavy")


func test_hud_shows_wave_ticks_and_passive_countdown() -> void:
	Hud._refresh_boss_ref()
	Hud._update_boss_panel()
	assert_eq(Hud._boss_wave_ticks.size(), 3)

	boss.enter_passive_window(8.0)
	Hud._update_boss_panel()

	assert_true(Hud._boss_window_countdown.visible)
	assert_eq(Hud._boss_window_countdown.text, "Boss returns in 8.0s")
	assert_eq(Hud._boss_hp_fill.modulate, Color(0.65, 0.65, 0.7))
