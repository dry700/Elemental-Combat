extends GutTest
## Integration tests for Boss "Thổ Ngưu" wave thresholds, passive window,
## invulnerability gating, early-clear stagger, and wall stun.

const BOSS_SCENE_PATH := "res://scenes/enemies/boss.tscn"
const THO_NGUU_STATS_PATH := "res://scripts/resources/enemies/tho_nguu_boss_stats.tres"

var boss: Boss


func before_each() -> void:
	var boss_scene: PackedScene = load(BOSS_SCENE_PATH)
	boss = boss_scene.instantiate()
	boss.boss_stats = load(THO_NGUU_STATS_PATH)
	add_child_autofree(boss)
	# Set armor to 0 for deterministic damage calculations in tests
	boss.elemental.armor = 0.0


func test_initial_state_matches_tho_nguu_stats() -> void:
	assert_eq(boss._current_phase, 1)
	assert_eq(boss.elemental.innate_element, &"tho")
	assert_eq(boss._current_health, 700.0)
	assert_false(boss.invulnerable)
	assert_false(boss.is_passive)
	assert_false(boss.is_stunned)
	assert_eq(boss._next_wave_index, 0)


func test_damage_crossing_75_percent_clamps_and_triggers_wave_1() -> void:
	watch_signals(boss)
	# 700 * 0.6 = 420 damage. 700 - 420 = 280, which crosses 75% (525 HP).
	boss._apply_damage(420.0)

	assert_eq(boss._current_health, 525.0, "Health must clamp to exactly 75% threshold")
	assert_signal_emit_count(boss, "wave_triggered", 1)
	assert_signal_emitted_with_parameters(boss, "wave_triggered", [1])
	assert_true(boss.is_passive, "Boss should enter passive window")
	assert_true(boss.invulnerable, "Boss should be invulnerable during passive window")
	assert_true(boss.hurtbox.invulnerable, "Hurtbox should be invulnerable")
	assert_signal_emit_count(boss, "passive_window_started", 1)
	assert_eq(boss._current_phase, 1, "Phase 1 should remain active at 75%")


func test_invulnerability_blocks_direct_damage_dot_and_bonus_damage() -> void:
	boss._apply_damage(420.0)  # Trigger wave 1, now in passive window at 525 HP
	assert_eq(boss._current_health, 525.0)

	# Direct damage
	boss._apply_damage(100.0)
	assert_eq(boss._current_health, 525.0, "Direct damage should be blocked while passive")

	# Bonus damage from reactions
	boss._on_bonus_damage_dealt(50.0)
	assert_eq(boss._current_health, 525.0, "Bonus damage should be blocked while passive")

	# Hurtbox hit
	var hit := HitData.new()
	hit.damage = 80.0
	boss._on_hurtbox_hit(hit)
	assert_eq(boss._current_health, 525.0, "Hurtbox hit should be blocked while passive")


func test_boss_is_intangible_during_passive_window_and_collision_returns_after() -> void:
	var body_shape := boss.get_node("CollisionShape2D") as CollisionShape2D
	assert_false(body_shape.disabled)

	boss.enter_passive_window(5.0)
	await get_tree().process_frame
	assert_true(body_shape.disabled, "boss body should not block other bodies while invulnerable")

	boss.end_passive_window(false)
	await get_tree().process_frame
	assert_false(body_shape.disabled, "boss body collision should return when the window ends")

	boss.enter_passive_window(5.0)
	await get_tree().process_frame
	assert_true(body_shape.disabled)
	boss.end_passive_window(true)
	await get_tree().process_frame
	assert_false(body_shape.disabled, "early-clear stagger also restores body collision")


func test_boss_moves_to_center_then_flies_during_passive_window() -> void:
	boss.global_position = Vector2(60.0, 0.0)
	boss.set_retreat_position(Vector2.ZERO)
	boss.enter_passive_window(5.0)

	await get_tree().create_timer(1.5).timeout

	assert_almost_eq(boss.global_position.x, 0.0, 1.0, "Boss should reach the room center")
	assert_lte(boss.global_position.y, -80.0, "Boss should hover above the center while invulnerable")
	assert_true(boss.is_passive)
	assert_true(boss.invulnerable)


func test_passive_window_normal_expiry_restores_combat_without_stagger() -> void:
	watch_signals(boss)
	boss._apply_damage(420.0)  # Enter passive window 1

	boss.end_passive_window(false)
	assert_signal_emit_count(boss, "passive_window_ended", 1)
	assert_signal_emitted_with_parameters(boss, "passive_window_ended", [false])
	assert_false(boss.is_passive)
	assert_false(boss.invulnerable)
	assert_false(boss.hurtbox.invulnerable)
	assert_false(boss.is_stunned)
	assert_eq(boss._stagger_damage_multiplier, 1.0)
	assert_true(boss.combat_ai.can_chase)


func test_wave_2_at_50_percent_swaps_element_to_hoa() -> void:
	watch_signals(boss)
	boss._apply_damage(420.0)  # Wave 1 at 75% (525 HP)
	boss.end_passive_window(false)

	# Hit again crossing 50% (350 HP): from 525 HP, deal 300 damage (525 - 300 = 225 < 350)
	boss._apply_damage(300.0)

	assert_eq(boss._current_health, 350.0, "Health must clamp to 50% threshold")
	assert_signal_emit_count(boss, "wave_triggered", 2)
	assert_signal_emitted_with_parameters(boss, "wave_triggered", [2])
	assert_signal_emit_count(boss, "phase_changed", 1)
	assert_signal_emitted_with_parameters(boss, "phase_changed", [2])
	assert_eq(boss._current_phase, 2)
	assert_eq(boss.elemental.innate_element, &"hoa")
	assert_eq(boss.elemental.status.element, &"hoa")
	assert_eq(boss.combat_ai.element_override, &"hoa")


func test_early_clear_staggers_boss_with_bonus_damage_multiplier() -> void:
	watch_signals(boss)
	boss._apply_damage(420.0)  # Wave 1 at 75% (525 HP)

	# Early clear wave
	boss.end_passive_window(true)
	assert_signal_emit_count(boss, "passive_window_ended", 1)
	assert_signal_emitted_with_parameters(boss, "passive_window_ended", [true])
	assert_signal_emit_count(boss, "stunned", 1)
	assert_true(boss.is_stunned)
	assert_eq(boss._stagger_damage_multiplier, 1.5)

	# Deal damage during stagger: 100 raw damage * 1.5 = 150 damage taken
	boss._apply_damage(100.0)
	assert_eq(boss._current_health, 525.0 - 150.0)


func test_wall_stun_applies_stun_and_damage_multiplier() -> void:
	watch_signals(boss)
	boss.apply_stun(1.5, 1.5)

	assert_signal_emit_count(boss, "stunned", 1)
	assert_signal_emitted_with_parameters(boss, "stunned", [1.5])
	assert_true(boss.is_stunned)
	assert_eq(boss._stagger_damage_multiplier, 1.5)
	assert_false(boss.combat_ai.can_chase)

	# Deal damage during wall stun: 100 raw damage * 1.5 = 150 damage taken
	boss._apply_damage(100.0)
	assert_eq(boss._current_health, 700.0 - 150.0)


func test_wave_3_and_subsequent_boss_death() -> void:
	watch_signals(boss)
	# Wave 1 (clamps to 525)
	boss._apply_damage(400.0)
	boss.end_passive_window(false)

	# Wave 2 (clamps to 350)
	boss._apply_damage(300.0)
	boss.end_passive_window(false)

	# Wave 3 (clamps to 175)
	boss._apply_damage(300.0)
	assert_eq(boss._current_health, 175.0, "Health must clamp to 25% threshold")
	assert_signal_emit_count(boss, "wave_triggered", 3)
	boss.end_passive_window(false)

	# Null stats before lethal hit so _die() skips rune roll catalogue requirement
	boss.boss_stats = null
	boss._apply_damage(200.0)
	assert_true(boss.is_dead())
