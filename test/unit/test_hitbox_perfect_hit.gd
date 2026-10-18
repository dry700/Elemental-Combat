extends GutTest

class DummyTarget extends Node2D:
	var elemental: ElementalCombatant
	var _health_ratio: float = 1.0

	func _init() -> void:
		elemental = ElementalCombatant.new()
		add_child(elemental)

	func get_health_ratio() -> float:
		return _health_ratio

class MockHurtbox extends Hurtbox:
	var last_hit: HitData = null

	func take_hit(data: HitData) -> void:
		last_hit = data


func test_hitbox_no_perfect_condition_does_not_multiply_damage():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 10.0
	hitbox.charge = 1
	hitbox.element = Elements.HOA
	hitbox.perfect_condition = WeaponStats.PerfectCondition.NONE
	hitbox.perfect_multiplier = 1.75

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)
	var landed: Array[Hurtbox] = []
	hitbox.hit_landed.connect(func(hit_hurtbox: Hurtbox) -> void: landed.append(hit_hurtbox))

	hitbox._on_area_entered(hurtbox)

	assert_not_null(hurtbox.last_hit)
	assert_false(hurtbox.last_hit.perfect)
	assert_eq(hurtbox.last_hit.damage, 10.0)
	assert_eq(hurtbox.last_hit.charge, 1)
	assert_eq(landed, [hurtbox])

	hitbox.enable()
	hurtbox.invulnerable = true
	hitbox._on_area_entered(hurtbox)
	assert_eq(landed.size(), 1, "An invulnerable target does not count as a landed hit")


func test_hitbox_target_slowed_multiplies_damage_and_leaves_charge_intact():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 10.0
	hitbox.charge = 2
	hitbox.element = Elements.THUY
	hitbox.perfect_condition = WeaponStats.PerfectCondition.TARGET_SLOWED
	hitbox.perfect_multiplier = 1.75

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# Case 1: Target is NOT slowed
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)
	assert_eq(hurtbox.last_hit.damage, 10.0)
	assert_eq(hurtbox.last_hit.charge, 2)

	# Clear already_hit list by re-enabling
	hitbox.enable()

	# Case 2: Target is slowed
	target.elemental.apply_control_slow(0.5, 3.0)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_almost_eq(hurtbox.last_hit.damage, 17.5, 0.01)
	assert_eq(hurtbox.last_hit.charge, 2, "Perfect Hit never touches Charge")


func test_hitbox_target_disabled_window():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 20.0
	hitbox.perfect_condition = WeaponStats.PerfectCondition.TARGET_DISABLED
	hitbox.perfect_multiplier = 2.0

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)
	assert_eq(hurtbox.last_hit.damage, 20.0)

	hitbox.enable()
	target.elemental.apply_control(2.0)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_eq(hurtbox.last_hit.damage, 40.0)
	hitbox.enable()
	target.elemental.status.apply(Elements.HOA, 1)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect, "An element overwrite does not consume the disabled-target window")


func test_hitbox_finisher_and_airborne_windows():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 10.0
	hitbox.perfect_multiplier = 1.75
	hitbox.perfect_condition = WeaponStats.PerfectCondition.FINISHER

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# Finisher false
	hitbox.is_finisher = false
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	# Finisher true
	hitbox.enable()
	hitbox.is_finisher = true
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_almost_eq(hurtbox.last_hit.damage, 17.5, 0.01)

	# Airborne
	hitbox.enable()
	hitbox.perfect_condition = WeaponStats.PerfectCondition.AIRBORNE
	hitbox.wielder_is_airborne = false
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	hitbox.enable()
	hitbox.wielder_is_airborne = true
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)


func test_hitbox_plunge_and_dodge_windows():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 10.0
	hitbox.perfect_multiplier = 1.5
	hitbox.perfect_condition = WeaponStats.PerfectCondition.DODGE

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# Dodge window: > 0.5s -> false
	hitbox.time_since_dodge = 0.6
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	# Dodge window: <= 0.5s -> true
	hitbox.enable()
	hitbox.time_since_dodge = 0.3
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_almost_eq(hurtbox.last_hit.damage, 15.0, 0.01)

	# Plunge window: intensity < 0.6 -> false
	hitbox.enable()
	hitbox.perfect_condition = WeaponStats.PerfectCondition.PLUNGE
	hitbox.is_plunge = true
	hitbox.plunge_intensity = 0.5
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	# Plunge window: intensity >= 0.6 -> true
	hitbox.enable()
	hitbox.plunge_intensity = 0.8
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)


func test_hitbox_distance_and_tip_windows():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 10.0
	hitbox.perfect_multiplier = 1.5
	hitbox.attack_origin = Vector2.ZERO
	hitbox.weapon_reach = 20.0

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# Long range: < 110 px -> false, >= 110 px -> true
	hitbox.perfect_condition = WeaponStats.PerfectCondition.LONG_RANGE
	hurtbox.global_position = Vector2(80, 0)
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	hitbox.enable()
	hurtbox.global_position = Vector2(120, 0)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)

	# Close range: > 40 px -> false, <= 40 px -> true
	hitbox.enable()
	hitbox.perfect_condition = WeaponStats.PerfectCondition.CLOSE_RANGE
	hurtbox.global_position = Vector2(50, 0)
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	hitbox.enable()
	hurtbox.global_position = Vector2(30, 0)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)

	# Tip: reach 20, 70% = 14 px. 10 px -> false, 16 px -> true
	hitbox.enable()
	hitbox.perfect_condition = WeaponStats.PerfectCondition.TIP
	hurtbox.global_position = Vector2(10, 0)
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	hitbox.enable()
	hurtbox.global_position = Vector2(16, 0)
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)


func test_hitbox_low_health_window():
	var hitbox: Hitbox = add_child_autofree(Hitbox.new())
	hitbox.damage = 30.0
	hitbox.perfect_multiplier = 2.0
	hitbox.perfect_condition = WeaponStats.PerfectCondition.LOW_HEALTH

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# Health 50% -> false
	target._health_ratio = 0.50
	hitbox._on_area_entered(hurtbox)
	assert_false(hurtbox.last_hit.perfect)

	# Health 25% -> true
	hitbox.enable()
	target._health_ratio = 0.25
	hitbox._on_area_entered(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_almost_eq(hurtbox.last_hit.damage, 60.0, 0.01)


func test_arrow_projectile_long_range_window():
	var arrow: ArrowProjectile = add_child_autofree(ArrowProjectile.new())
	arrow.damage = 10.0
	arrow.perfect_condition = WeaponStats.PerfectCondition.LONG_RANGE
	arrow.perfect_multiplier = 1.5
	arrow.spawn_position = Vector2.ZERO

	var target: DummyTarget = add_child_autofree(DummyTarget.new())
	var hurtbox: MockHurtbox = MockHurtbox.new()
	target.add_child(hurtbox)

	# At 80px distance -> false
	hurtbox.global_position = Vector2(80, 0)
	arrow._resolve_hit(hurtbox)
	assert_not_null(hurtbox.last_hit)
	assert_false(hurtbox.last_hit.perfect)
	assert_eq(hurtbox.last_hit.damage, 10.0)

	# A new arrow at 130px distance -> true
	var arrow2: ArrowProjectile = add_child_autofree(ArrowProjectile.new())
	arrow2.damage = 10.0
	arrow2.perfect_condition = WeaponStats.PerfectCondition.LONG_RANGE
	arrow2.perfect_multiplier = 1.5
	arrow2.spawn_position = Vector2.ZERO

	hurtbox.global_position = Vector2(130, 0)
	arrow2._resolve_hit(hurtbox)
	assert_true(hurtbox.last_hit.perfect)
	assert_almost_eq(hurtbox.last_hit.damage, 15.0, 0.01)

