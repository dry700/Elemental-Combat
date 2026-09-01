extends GutTest
## Integration tests for Boss's phase transition (A.6: "up to two
## elements... phase-based"). Loads the real scene since the transition
## touches _ready()-wired state (elemental, combat_ai) awkward to fake
## standalone. Adjust BOSS_STATS_PATH if you file .tres assets elsewhere.

const BOSS_SCENE_PATH := "res://scenes/enemies/boss.tscn"
const BOSS_STATS_PATH := "res://scripts/resources/enemies/ember_tide_boss_stats.tres"

var boss: Boss

func before_each():
	var boss_scene: PackedScene = load(BOSS_SCENE_PATH)
	boss = boss_scene.instantiate()
	boss.boss_stats = load(BOSS_STATS_PATH)
	add_child_autofree(boss)

func test_starts_in_phase_1_with_phase_1_element():
	assert_eq(boss._current_phase, 1)
	assert_eq(boss.elemental.innate_element, boss.boss_stats.element)

func test_damage_above_threshold_does_not_trigger_phase_2():
	boss._apply_damage(boss.boss_stats.max_health * 0.1)
	assert_eq(boss._current_phase, 1)

func test_damage_crossing_threshold_triggers_phase_2():
	boss._apply_damage(boss.boss_stats.max_health * 0.6)  # crosses the default 0.5 ratio
	assert_eq(boss._current_phase, 2)
	assert_eq(boss.elemental.innate_element, boss.boss_stats.phase_2_element)
	assert_eq(boss.elemental.status.element, boss.boss_stats.phase_2_element)

func test_phase_transition_only_fires_once():
	watch_signals(boss)
	boss._apply_damage(boss.boss_stats.max_health * 0.6)
	boss._apply_damage(boss.boss_stats.max_health * 0.1)
	assert_signal_emit_count(boss, "phase_changed", 1)

func test_combat_ai_element_override_updates_on_phase_change():
	boss._apply_damage(boss.boss_stats.max_health * 0.6)
	assert_eq(boss.combat_ai.element_override, boss.boss_stats.phase_2_element)

func test_death_at_zero_health_still_works_after_phase_2():
	boss._apply_damage(boss.boss_stats.max_health * 0.6)  # -> phase 2
	boss._apply_damage(boss.boss_stats.max_health)         # lethal
	assert_true(boss._is_dead)
