extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player

func before_each() -> void:
	UpgradeManager.reset()
	player = load(PLAYER_SCENE_PATH).instantiate()
	add_child_autofree(player)
	RunManager._player = player

func after_each() -> void:
	PlaytestMode._on_invincibility_toggled(false)
	UpgradeManager.reset()
	RunManager._player = null

func test_f12_toggles_the_playtest_panel() -> void:
	assert_false(PlaytestMode.is_panel_open())
	var event := InputEventAction.new()
	event.action = "playtest_toggle"
	event.pressed = true
	PlaytestMode._unhandled_key_input(event)
	assert_true(PlaytestMode.is_panel_open())
	PlaytestMode._unhandled_key_input(event)
	assert_false(PlaytestMode.is_panel_open())

func test_invincibility_blocks_all_player_health_damage() -> void:
	player.current_health = 40.0
	PlaytestMode._on_invincibility_toggled(true)
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	var hit_data := HitData.new(100.0, Vector2(80.0, -20.0), attacker)
	player._on_hurtbox_hit(hit_data)
	assert_eq(player.current_health, 40.0)
	assert_eq(player.velocity, Vector2.ZERO)
	assert_false(player._is_dead)

func test_panel_grants_qi_and_purchases_player_and_reaction_upgrades() -> void:
	PlaytestMode._on_grant_qi_pressed()
	assert_eq(UpgradeManager.qi, 1000.0)
	player.current_health = 40.0
	PlaytestMode._on_buy_vitality_pressed()
	assert_eq(player.max_health, 110.0)
	assert_eq(player.current_health, 50.0)
	assert_eq(player.to_save_state()["max_health"], 100.0)
	PlaytestMode._on_buy_damage_pressed()
	player._active_weapon = player.weapon
	player._combo_step = 1
	player._configure_hitbox_for_current_swing()
	assert_almost_eq(player.hitbox.damage, player.weapon.damage * 1.1, 0.01)
	PlaytestMode._on_buy_rank1_pressed()
	PlaytestMode._on_buy_rank2_pressed()
	var pair: Array[StringName] = [Elements.KIM, Elements.THUY]
	assert_true(UpgradeManager.sinh_tier2_forced(pair))
	assert_eq(UpgradeManager.sinh_favored_element(pair), Elements.THUY)

func test_wildfire_rank_two_keeps_overload_active_and_scales_fire_dot() -> void:
	var elemental := ElementalCombatant.new()
	elemental.show_debug_readout = false
	add_child_autofree(elemental)
	var source := Node2D.new()
	add_child_autofree(source)

	var pair: Array[StringName] = [Elements.MOC, Elements.HOA]
	UpgradeManager.award_qi(80.0)
	assert_true(UpgradeManager.purchase_sinh_rank1(pair))
	assert_true(UpgradeManager.purchase_sinh_rank2(pair, Elements.HOA))

	elemental.status.apply(Elements.MOC, 1)
	var hit_data := HitData.new(1.0, Vector2.ZERO, source)
	hit_data.element = Elements.HOA
	hit_data.charge = 1
	elemental.handle_hit(hit_data)
	assert_true(elemental.wildfire_overload.active)
	assert_almost_eq(elemental.dot_effect.damage_per_tick, 3.5, 0.01)

	elemental.tick(0.5)
	assert_true(elemental.wildfire_overload.active, "level-zero overload must remain ready for a follow-up hit")
	elemental.handle_hit(hit_data)
	assert_eq(elemental.wildfire_overload.level, 1)
	assert_almost_eq(elemental.dot_effect.damage_per_tick, 5.0, 0.01)

	elemental.wildfire_overload.tick(WildfireOverload.SUSTAIN_TIME + 0.1)
	assert_false(elemental.wildfire_overload.active)
	assert_false(elemental.dot_effect.active, "the overload bonus burn must end when its last level decays")

func test_playtest_can_buy_sinh_rank_two_favoring_the_other_element() -> void:
	PlaytestMode._reaction_target.select(2)
	var reaction: Dictionary = PlaytestMode.REACTIONS[2]
	var pair: Array[StringName] = PlaytestMode._selected_reaction_pair(reaction)
	var generated := Elements.sinh_generated_element(pair)
	var other: StringName = pair[0] if pair[1] == generated else pair[1]

	UpgradeManager.award_qi(80.0)
	PlaytestMode._on_buy_sinh_rank1_pressed()
	PlaytestMode._on_buy_sinh_rank2_other_pressed()

	assert_true(UpgradeManager.sinh_tier2_forced(pair))
	assert_eq(UpgradeManager.sinh_favored_element(pair), other)


func test_playtest_skill_selector_lists_and_equips_every_skill_without_unlocking_it() -> void:
	assert_not_null(PlaytestMode._skill_target)
	assert_eq(PlaytestMode._skill_target.item_count, SkillPool.SKILL_PATHS.size())
	var unlocked_before := SaveManager.get_unlocked_skill_paths()

	for index in SkillPool.SKILL_PATHS.size():
		PlaytestMode._skill_target.select(index)
		PlaytestMode._equip_selected_skill(true)
		var selected_path := str(PlaytestMode._skill_target.get_item_metadata(index))
		assert_eq(player.skill_1.resource_path, selected_path)

	assert_eq(SaveManager.get_unlocked_skill_paths(), unlocked_before)


func test_playtest_skill_selector_blocks_duplicate_in_other_slot() -> void:
	PlaytestMode._skill_target.select(0)
	PlaytestMode._equip_selected_skill(true)
	var equipped := player.skill_1

	PlaytestMode._skill_target.select(0)
	PlaytestMode._equip_selected_skill(false)

	assert_null(player.skill_2)
	assert_eq(player.skill_1, equipped)