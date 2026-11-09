extends GutTest

const THO_NGUU_STATS_PATH := "res://scripts/resources/enemies/tho_nguu_boss_stats.tres"
const EMBER_TIDE_STATS_PATH := "res://scripts/resources/enemies/ember_tide_boss_stats.tres"
const SHIELDER_STATS_PATH := "res://scripts/resources/enemies/shielder_stats.tres"

func test_shielder_support_cooldown_halved_for_faster_pacing() -> void:
	var shielder_stats := load(SHIELDER_STATS_PATH) as EnemyStats
	assert_not_null(shielder_stats)
	assert_almost_eq(shielder_stats.support_cooldown, 2.5, 0.01, "shielder cooldown is 2.5s (twice previous 5.0s pace)")


func test_ember_tide_backward_compatibility() -> void:
	var ember_tide := load(EMBER_TIDE_STATS_PATH) as BossStats
	assert_not_null(ember_tide)
	assert_eq(ember_tide.boss_name, "Ember Tide")
	assert_eq(ember_tide.element, Elements.THUY)
	assert_eq(ember_tide.phase_2_element, Elements.HOA)
	assert_eq(ember_tide.armor, 15.0)
	assert_eq(ember_tide.max_health, 700.0)
	assert_true(ember_tide.wave_thresholds.is_empty(), "Ember Tide has no wave thresholds by default")
	assert_false(ember_tide.charge_enabled)
	assert_false(ember_tide.shockwave_enabled)
	assert_false(ember_tide.rock_throw_enabled)


func test_tho_nguu_stats_loaded_and_configured() -> void:
	var stats := load(THO_NGUU_STATS_PATH) as BossStats
	assert_not_null(stats)
	assert_eq(stats.boss_name, "Thổ Ngưu")
	assert_eq(stats.element, Elements.THO, "Phase 1 is Thổ")
	assert_eq(stats.phase_2_element, Elements.HOA, "Phase 2 is Hỏa")
	assert_almost_eq(stats.phase_transition_health_ratio, 0.5, 0.01)
	assert_almost_eq(stats.phase_2_attack_cooldown_multiplier, 0.75, 0.01)
	assert_eq(stats.max_health, 700.0)
	assert_eq(stats.armor, 15.0)
	assert_eq(stats.damage, 10.0)
	assert_eq(stats.innate_charge, 2)
	assert_eq(stats.qi_reward, 30.0)

	# Waves & passive retreat window
	assert_eq(stats.wave_thresholds.size(), 3)
	assert_almost_eq(stats.wave_thresholds[0], 0.75, 0.01)
	assert_almost_eq(stats.wave_thresholds[1], 0.5, 0.01)
	assert_almost_eq(stats.wave_thresholds[2], 0.25, 0.01)
	assert_almost_eq(stats.passive_window_duration, 12.0, 0.01)
	assert_almost_eq(stats.early_clear_stagger_duration, 2.0, 0.01)
	assert_almost_eq(stats.early_clear_damage_multiplier, 1.5, 0.01)

	# Bull charge
	assert_true(stats.charge_enabled)
	assert_almost_eq(stats.charge_telegraph_duration, 0.8, 0.01)
	assert_almost_eq(stats.charge_speed, 220.0, 0.01)
	assert_almost_eq(stats.charge_max_distance, 450.0, 0.01)
	assert_almost_eq(stats.charge_damage, 14.0, 0.01)
	assert_eq(stats.charge_innate_charge, 2)
	assert_almost_eq(stats.charge_wall_stun_duration, 1.5, 0.01)
	assert_almost_eq(stats.charge_stun_damage_multiplier, 1.5, 0.01)

	# Ground shockwave
	assert_true(stats.shockwave_enabled)
	assert_almost_eq(stats.shockwave_telegraph_duration, 0.6, 0.01)
	assert_almost_eq(stats.shockwave_speed, 130.0, 0.01)
	assert_almost_eq(stats.shockwave_damage, 8.0, 0.01)
	assert_eq(stats.shockwave_innate_charge, 1)

	# Rock throw
	assert_true(stats.rock_throw_enabled)
	assert_almost_eq(stats.rock_damage, 6.0, 0.01)
	assert_almost_eq(stats.rock_speed, 200.0, 0.01)
	assert_almost_eq(stats.rock_cooldown, 5.0, 0.01)

