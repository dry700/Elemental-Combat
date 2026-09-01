extends GutTest
## Integration tests for the per-weapon lunge/range/combo system
## (WeaponStats.lunge_speed/reach/hitbox_radius/combo_length/
## combo_window/combo_damage_step_multiplier + Player's chaining logic).
## Calls Player's own state-machine helpers directly rather than
## simulating real Input events — avoids InputMap/frame-timing
## flakiness while still exercising the actual production code path.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player
var combo_dagger: WeaponStats

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	combo_dagger = WeaponStats.new()
	combo_dagger.innate_element = Elements.HOA
	combo_dagger.combo_length = 3
	combo_dagger.combo_window = 0.3
	combo_dagger.combo_damage_step_multiplier = 1.5
	combo_dagger.damage = 10.0
	combo_dagger.reach = 20.0
	combo_dagger.hitbox_radius = 12.0
	player.weapon = combo_dagger
	add_child_autofree(player)

func test_fresh_attack_starts_at_combo_step_1():
	player._start_attack(combo_dagger)
	assert_eq(player._combo_step, 1)
	assert_eq(player.state, Player.State.ATTACK)

func test_buffered_press_chains_to_the_next_combo_step():
	player._start_attack(combo_dagger)
	player._attack_buffered = true
	player._end_or_chain_attack()
	assert_eq(player._combo_step, 2)
	assert_eq(player.state, Player.State.ATTACK, "chaining stays in ATTACK, no idle frame between hits")

func test_combo_does_not_exceed_weapon_combo_length():
	player._start_attack(combo_dagger)
	player._combo_step = 3  # already at the weapon's cap
	player._attack_buffered = true
	player._end_or_chain_attack()
	assert_eq(player._combo_step, 3, "cannot chain past combo_length")
	assert_ne(player.state, Player.State.ATTACK, "should fall through to idle/fall once the cap is hit")

func test_no_buffered_press_ends_the_attack_and_starts_the_grace_window():
	player._start_attack(combo_dagger)
	player._attack_buffered = false
	player._end_or_chain_attack()
	assert_almost_eq(player._combo_window_timer, combo_dagger.combo_window, 0.01)

func test_pressing_again_within_the_grace_window_continues_the_combo():
	player._start_attack(combo_dagger)
	player._attack_buffered = false
	player._end_or_chain_attack()  # ends hit 1, opens the grace window
	player._start_attack(combo_dagger)  # simulates a fresh press landing inside the window
	assert_eq(player._combo_step, 2)

func test_pressing_after_the_grace_window_expires_resets_to_step_1():
	player._start_attack(combo_dagger)
	player._attack_buffered = false
	player._end_or_chain_attack()
	player._combo_window_timer = 0.0  # simulate the window having expired
	player._start_attack(combo_dagger)
	assert_eq(player._combo_step, 1)

func test_combo_damage_multiplier_compounds_per_step():
	player._active_weapon = combo_dagger
	player._combo_step = 1
	assert_almost_eq(player._combo_damage_multiplier(), 1.0, 0.01)
	player._combo_step = 2
	assert_almost_eq(player._combo_damage_multiplier(), 1.5, 0.01)
	player._combo_step = 3
	assert_almost_eq(player._combo_damage_multiplier(), 2.25, 0.01)

func test_configure_hitbox_applies_weapon_reach_and_radius():
	player._active_weapon = combo_dagger
	player._combo_step = 1
	player._configure_hitbox_for_current_swing()
	assert_almost_eq(player.hitbox.position.x, 20.0, 0.01)
	var shape := player.hitbox_shape.shape as CircleShape2D
	assert_almost_eq(shape.radius, 12.0, 0.01)

func test_configure_hitbox_scales_damage_by_combo_step():
	player._active_weapon = combo_dagger
	player._combo_step = 2
	player._configure_hitbox_for_current_swing()
	assert_almost_eq(player.hitbox.damage, 15.0, 0.01)  # 10 base * 1.5 step multiplier

func test_switching_weapon_forces_a_fresh_combo_not_a_chain():
	var other_weapon := WeaponStats.new()
	other_weapon.innate_element = Elements.THUY
	player._start_attack(combo_dagger)
	player._attack_buffered = false
	player._end_or_chain_attack()  # grace window open for combo_dagger
	player._start_attack(other_weapon)  # different weapon — must not "continue" combo_dagger's combo
	assert_eq(player._combo_step, 1)
