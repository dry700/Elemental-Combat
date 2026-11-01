extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const BOW_PATH := "res://scripts/resources/weapons/training_bow.tres"
const GREATSWORD_PATH := "res://scripts/resources/weapons/training_greatsword.tres"
const HAMMER_PATH := "res://scripts/resources/weapons/training_hammer.tres"
const DAGGER_PATH := "res://scripts/resources/weapons/training_dagger.tres"

var player: Player


func before_each() -> void:
	player = load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func test_heavy_weapons_have_per_weapon_threshold_and_hold_caps() -> void:
	var bow := load(BOW_PATH) as WeaponStats
	var greatsword := load(GREATSWORD_PATH) as WeaponStats
	var hammer := load(HAMMER_PATH) as WeaponStats
	assert_true(bow.has_heavy_attack)
	assert_true(greatsword.has_heavy_attack)
	assert_true(hammer.has_heavy_attack)
	assert_almost_eq(bow.heavy_threshold, 0.28, 0.001)
	assert_almost_eq(bow.heavy_max_hold, 0.6, 0.001)
	assert_almost_eq(greatsword.heavy_max_hold, 1.0, 0.001)
	assert_almost_eq(hammer.heavy_max_hold, 1.3, 0.001)


func test_short_press_releases_as_a_normal_swing_and_threshold_marks_heavy() -> void:
	var bow := load(BOW_PATH) as WeaponStats
	player._start_heavy_windup(bow, "attack")
	player._heavy_hold_timer = bow.heavy_threshold - 0.01
	player._release_heavy()
	assert_eq(player.state, Player.State.ATTACK)
	assert_false(player._heavy_charged)
	assert_almost_eq(player.hitbox.damage, bow.damage, 0.01)

	player._start_heavy_windup(bow, "attack")
	player._heavy_hold_timer = bow.heavy_threshold
	player._release_heavy()
	assert_true(player._heavy_charged)
	assert_almost_eq(player._heavy_charge_ratio, 0.0, 0.001)
	assert_eq(player.state, Player.State.ATTACK)


func test_full_heavy_hit_scales_damage_reach_and_knockback_to_cap_without_changing_charge() -> void:
	var hammer := load(HAMMER_PATH) as WeaponStats
	player._active_weapon = hammer
	player._combo_step = 1
	player._heavy_charged = false
	player._configure_hitbox_for_current_swing()
	var normal_damage := player.hitbox.damage
	var normal_knockback := player.hitbox.knockback_strength
	var normal_reach := player.hitbox.weapon_reach
	var normal_charge := player.hitbox.charge
	player._heavy_charged = true
	player._heavy_charge_ratio = 1.0
	player._configure_hitbox_for_current_swing()
	assert_almost_eq(player.hitbox.damage, normal_damage * hammer.heavy_damage_mult, 0.01)
	assert_almost_eq(player.hitbox.knockback_strength, normal_knockback * hammer.heavy_knockback_mult, 0.01)
	assert_almost_eq(player.hitbox.weapon_reach, normal_reach * hammer.heavy_reach_mult, 0.01)
	assert_eq(player.hitbox.charge, normal_charge, "heavy power must not raise reaction Charge")
	player._heavy_charge_ratio = 2.0
	player._configure_hitbox_for_current_swing()
	assert_almost_eq(player.hitbox.damage, normal_damage * hammer.heavy_damage_mult, 0.01, "power is capped")


func test_full_bow_hit_scales_projectile_speed_and_damage() -> void:
	var bow := load(BOW_PATH) as WeaponStats
	player._active_weapon = bow
	player._combo_step = 1
	player._heavy_charged = true
	player._heavy_charge_ratio = 1.0
	player._configure_hitbox_for_current_swing()
	assert_eq(player.hitbox.weapon_weight, &"heavy", "charged impacts reuse the heavy hit-stop and shake preset")
	player._fire_arrow()
	var arrows: Array[ArrowProjectile] = []
	for child in player.get_parent().get_children():
		if child is ArrowProjectile:
			arrows.append(child)
	assert_eq(arrows.size(), 1)
	if arrows.size() == 1:
		assert_almost_eq(arrows[0].speed, bow.projectile_speed * bow.heavy_projectile_speed_mult, 0.01)
		assert_almost_eq(arrows[0].damage, bow.damage * bow.heavy_damage_mult, 0.01)
		arrows[0].queue_free()


func test_dodge_and_disable_cancel_windup() -> void:
	var hammer := load(HAMMER_PATH) as WeaponStats
	player._start_heavy_windup(hammer, "attack")
	Input.action_press("dodge")
	player._process_heavy_windup(0.016)
	Input.action_release("dodge")
	assert_eq(player.state, Player.State.DODGE)
	assert_false(player._heavy_charged)
	assert_almost_eq(player._heavy_hold_timer, 0.0, 0.001)
	assert_almost_eq(player._heavy_charge_ratio, 0.0, 0.001)
	player.state = Player.State.HEAVY_WINDUP
	player.elemental.apply_control(1.0)
	player._physics_process(0.016)
	assert_eq(player.state, Player.State.DISABLED)
	assert_false(player._heavy_charged)


func test_weapons_without_heavy_option_keep_the_normal_attack_path() -> void:
	var dagger := load(DAGGER_PATH) as WeaponStats
	assert_false(dagger.has_heavy_attack)
	player._begin_attack(dagger, "attack")
	assert_eq(player.state, Player.State.ATTACK)
	assert_false(player._heavy_charged)
	assert_almost_eq(player.hitbox.damage, dagger.damage, 0.01)
