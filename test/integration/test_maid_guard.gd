extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MAID_GUARD_PATH := "res://scripts/resources/skills/maid_guard.tres"
const PATROL_DUMMY_SCENE_PATH := "res://scenes/enemies/patrol_dummy.tscn"
const FlowerTurretScript := preload("res://scripts/reactions/flower_turret.gd")
const CombatantOwner := preload("res://test/helpers/combatant_owner.gd")

var player: Player


func before_each() -> void:
	player = load(PLAYER_SCENE_PATH).instantiate() as Player
	player.position = Vector2.ZERO
	player.elemental.show_debug_readout = false
	add_child_autofree(player)
	player.set_physics_process(false)


func _add_enemy(position: Vector2) -> CombatantOwner:
	var enemy := CombatantOwner.new()
	enemy.position = position
	enemy.add_to_group("enemies")
	add_child_autofree(enemy)
	enemy.elemental = ElementalCombatant.new()
	enemy.elemental.show_debug_readout = false
	enemy.add_child(enemy.elemental)
	return enemy


func test_shield_absorbs_only_one_hit_and_skips_reaction_damage_and_knockback() -> void:
	player.elemental.status.apply(Elements.KIM, 1)
	player.elemental.cast_apply_shield(12.0)
	var initial_health := player.current_health
	var hit := HitData.new(20.0, Vector2(30.0, -10.0))
	hit.element = Elements.HOA
	hit.charge = 1

	player._on_hurtbox_hit(hit)

	assert_false(player.elemental.shield.active)
	assert_almost_eq(player.current_health, initial_health, 0.01)
	assert_eq(player.velocity, Vector2.ZERO)
	assert_eq(player.elemental.status.element, Elements.KIM, "absorbed hits must not trigger reactions")
	assert_gt(HitStop._active_until_msec, Time.get_ticks_msec(), "absorbed hits should still play hit-stop")
	assert_gt(ScreenShake._active_until_msec, Time.get_ticks_msec(), "absorbed hits should still shake the screen")
	assert_almost_eq(ScreenShake._peak_trauma, 3.0, 0.01, "the shield impact should have distinct shake feedback")

	player._on_hurtbox_hit(HitData.new(0.0, Vector2(30.0, 0.0)))
	assert_eq(player.velocity, Vector2(30.0, 0.0), "the next hit should no longer be absorbed")


func test_dot_passes_through_active_shield() -> void:
	player.elemental.cast_apply_shield(12.0)
	player.elemental.dot_effect.apply(4.0, 0.1, 1.0, Elements.HOA)

	var dot_damage := player.elemental.tick(0.1)

	assert_almost_eq(dot_damage, 4.0, 0.01)
	assert_true(player.elemental.shield.active)


func test_bonus_damage_is_absorbed_but_dot_damage_still_bypasses_shield() -> void:
	player.elemental.armor = 0.0
	player.elemental.cast_apply_shield(12.0)
	var initial_health := player.current_health

	player._on_bonus_damage_dealt(5.0)

	assert_almost_eq(player.current_health, initial_health, 0.01)
	assert_false(player.elemental.shield.active, "direct non-DoT bonus damage should consume the shield")

	player.elemental.cast_apply_shield(12.0)
	player.elemental.dot_effect.apply(4.0, 0.1, 1.0, Elements.HOA)
	var dot_damage := player.elemental.tick(0.1)
	player._apply_damage(dot_damage)

	assert_almost_eq(player.current_health, initial_health - 4.0, 0.01)
	assert_true(player.elemental.shield.active, "DoT damage must not consume the shield")


func test_overgrowth_turret_shot_is_absorbed_by_enemy_shield() -> void:
	var stats := EnemyStats.new()
	stats.max_health = 100.0
	var target := load(PATROL_DUMMY_SCENE_PATH).instantiate() as PatrolDummy
	target.enemy_stats = stats
	target.starting_armor = 0.0
	target.set_physics_process(false)
	target.position = Vector2.ZERO
	add_child_autofree(target)
	target.elemental.shield.apply(4.0)
	var initial_health := target._current_health

	var turret := FlowerTurretScript.new() as FlowerTurret
	add_child_autofree(turret)
	turret.position = Vector2.ZERO
	turret.call("_try_fire")

	assert_almost_eq(target._current_health, initial_health, 0.01, "turret shot damage should be absorbed")
	assert_false(target.elemental.shield.active, "turret shot should consume the one-hit shield")


func test_shield_break_explodes_but_excludes_attacker_and_distant_enemies() -> void:
	var attacker := _add_enemy(Vector2(15.0, 0.0))
	var nearby := _add_enemy(Vector2(-30.0, 0.0))
	var distant := _add_enemy(Vector2(100.0, 0.0))
	var damage := {attacker: 0.0, nearby: 0.0, distant: 0.0}
	attacker.elemental.bonus_damage_dealt.connect(func(amount: float): damage[attacker] += amount)
	nearby.elemental.bonus_damage_dealt.connect(func(amount: float): damage[nearby] += amount)
	distant.elemental.bonus_damage_dealt.connect(func(amount: float): damage[distant] += amount)
	player.elemental.cast_apply_shield(12.0)
	var hit := HitData.new(5.0, Vector2.ZERO, attacker)

	player._on_hurtbox_hit(hit)

	assert_almost_eq(damage[attacker], 0.0, 0.01)
	assert_almost_eq(damage[nearby], 12.0, 0.01)
	assert_almost_eq(damage[distant], 0.0, 0.01)
	assert_true(nearby.elemental.is_disabled(), "nearby enemies should be staggered")


func test_shield_expiry_explodes_on_nearby_enemies() -> void:
	var nearby := _add_enemy(Vector2(30.0, 0.0))
	var damage := [0.0]
	nearby.elemental.bonus_damage_dealt.connect(func(amount: float): damage[0] += amount)
	player.elemental.cast_apply_shield(12.0)

	player.elemental.tick(12.0)

	assert_almost_eq(damage[0], 12.0, 0.01)
	assert_true(nearby.elemental.is_disabled())
	assert_false(player.elemental.shield.active)


func test_refresh_extends_same_shield_without_stacking() -> void:
	player.elemental.cast_apply_shield(12.0)
	player.elemental.shield.tick(5.0)
	player.elemental.cast_apply_shield(12.0)

	assert_almost_eq(player.elemental.shield.get_remaining_duration(), 12.0, 0.01)
	assert_true(player.elemental.shield.absorb_hit())
	assert_false(player.elemental.shield.absorb_hit())


func test_dodge_iframes_and_playtest_invincibility_preserve_shield() -> void:
	player.elemental.cast_apply_shield(12.0)
	player.hurtbox.invulnerable = true
	player.hurtbox.take_hit(HitData.new(5.0))
	assert_true(player.elemental.shield.active, "the hurtbox should reject hits during dodge i-frames")

	player.hurtbox.invulnerable = false
	player.playtest_invincible = true
	player._on_hurtbox_hit(HitData.new(5.0))
	assert_true(player.elemental.shield.active, "playtest invincibility should take priority over the shield")


func test_skill_resource_dispatches_maid_guard_and_enters_cooldown() -> void:
	var skill := load(MAID_GUARD_PATH) as SkillData
	Input.action_release("skill_1")
	Input.action_press("skill_1")

	player._try_cast_skill(skill, "skill_1")

	Input.action_release("skill_1")
	assert_true(player.elemental.shield.active)
	assert_almost_eq(player.elemental.shield.get_remaining_duration(), 12.0, 0.01)
	assert_almost_eq(player._skill_cooldowns[skill], 18.0, 0.01)
