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