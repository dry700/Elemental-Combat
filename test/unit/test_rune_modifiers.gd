extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String
var player: Player

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()
	UpgradeManager.reset()
	player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

func after_each():
	UpgradeManager.reset()

func test_default_swing_has_no_modifier_bonuses():
	player._start_attack(player.weapon, true)
	assert_eq(player.hitbox.damage, player.weapon.damage)
	assert_eq(player.hitbox.knockback_strength, 150.0)
	var expected_reach := player.weapon.reach
	if player.weapon.weapon_texture != null:
		expected_reach = float(player.weapon.weapon_texture.get_width())
	assert_eq(player.hitbox.weapon_reach, expected_reach)
	var rect := player.hitbox_shape.shape as RectangleShape2D
	assert_eq(rect.size.y, player.weapon.hitbox_radius * 2.0)
	assert_eq(player._current_attack_duration, player.weapon.attack_duration)
	assert_eq(player._current_active_window, player.weapon.active_window)

func test_damage_pct_modifier_increases_hitbox_damage():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"damage_pct", "value": 20.0})
	player.weapon_rune = rune
	player._start_attack(player.weapon, true)
	var expected_damage := player.weapon.damage * 1.20
	assert_almost_eq(player.hitbox.damage, expected_damage, 0.001)

func test_reach_modifier_increases_hitbox_reach():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"reach", "value": 4.0})
	player.weapon_rune = rune
	player._start_attack(player.weapon, true)
	var base_reach := player.weapon.reach
	if player.weapon.weapon_texture != null:
		base_reach = float(player.weapon.weapon_texture.get_width())
	assert_eq(player.hitbox.weapon_reach, base_reach + 4.0)
	var rect := player.hitbox_shape.shape as RectangleShape2D
	assert_eq(rect.size.x, base_reach + 4.0)
	assert_eq(player.hitbox_shape.position.x, (base_reach + 4.0) / 2.0)

func test_hitbox_size_modifier_increases_hitbox_radius():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"hitbox_size", "value": 2.0})
	player.weapon_rune = rune
	player._start_attack(player.weapon, true)
	var rect := player.hitbox_shape.shape as RectangleShape2D
	assert_eq(rect.size.y, (player.weapon.hitbox_radius + 2.0) * 2.0)

func test_knockback_modifier_increases_hitbox_knockback():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"knockback", "value": 50.0})
	player.weapon_rune = rune
	player._start_attack(player.weapon, true)
	assert_eq(player.hitbox.knockback_strength, 200.0)

func test_attack_speed_modifier_shortens_duration_and_window():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"attack_speed", "value": 25.0})
	player.weapon_rune = rune
	player._start_attack(player.weapon, true)
	var speed_mult := 1.25
	assert_almost_eq(player._current_attack_duration, player.weapon.attack_duration / speed_mult, 0.001)
	assert_almost_eq(player._current_active_window.x, player.weapon.active_window.x / speed_mult, 0.001)
	assert_almost_eq(player._current_active_window.y, player.weapon.active_window.y / speed_mult, 0.001)

func test_secondary_weapon_rune_applies_only_to_secondary_weapon():
	var rune := RuneData.new(Elements.THUY, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"damage_pct", "value": 50.0})
	player.secondary_weapon_rune = rune

	var secondary: WeaponStats = load("res://scripts/resources/weapons/training_greatsword.tres")
	player.secondary_weapon = secondary

	player._start_attack(player.weapon, true)
	assert_almost_eq(player.hitbox.damage, player.weapon.damage, 0.001)

	player._start_attack(player.secondary_weapon, true)
	assert_almost_eq(player.hitbox.damage, secondary.damage * 1.50, 0.001)

