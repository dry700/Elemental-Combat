extends GutTest

const PATROL_DUMMY_SCENE := preload("res://scenes/enemies/patrol_dummy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const FLYING_ENEMY_SCENE := preload("res://scenes/enemies/flying_enemy.tscn")
const SHOOTER_ENEMY_SCENE := preload("res://scenes/enemies/shooter_enemy.tscn")
const SWOOPER_ENEMY_SCENE := preload("res://scenes/enemies/swooper_enemy.tscn")
const TEST_DUMMY_SCENE := preload("res://scenes/enemies/test_dummy.tscn")

func test_patrol_dummy_facing_property_and_scale():
	var dummy := PATROL_DUMMY_SCENE.instantiate() as PatrolDummy
	add_child_autofree(dummy)
	assert_eq(dummy.facing, 1)
	assert_gt(dummy.visual.scale.x, 0.0)

	dummy.facing = -1
	assert_eq(dummy.facing, -1)
	assert_lt(dummy.visual.scale.x, 0.0)
	assert_lt(dummy.visual_polygon.scale.x, 0.0)

	dummy.facing = 1
	assert_eq(dummy.facing, 1)
	assert_gt(dummy.visual.scale.x, 0.0)
	assert_gt(dummy.visual_polygon.scale.x, 0.0)

func test_boss_facing_property_and_scale():
	var boss := BOSS_SCENE.instantiate() as Boss
	add_child_autofree(boss)
	assert_eq(boss.facing, 1)

	boss.facing = -1
	assert_eq(boss.facing, -1)
	assert_lt(boss.visual.scale.x, 0.0)
	assert_lt(boss.visual_polygon.scale.x, 0.0)

func test_flying_enemy_facing_property_and_scale():
	var enemy := FLYING_ENEMY_SCENE.instantiate() as FlyingEnemy
	add_child_autofree(enemy)
	assert_eq(enemy.facing, 1)

	enemy.facing = -1
	assert_eq(enemy.facing, -1)
	assert_lt(enemy.visual.scale.x, 0.0)
	assert_lt(enemy.visual_polygon.scale.x, 0.0)

func test_shooter_enemy_facing_property_and_scale():
	var enemy := SHOOTER_ENEMY_SCENE.instantiate() as ShooterEnemy
	add_child_autofree(enemy)
	assert_eq(enemy.facing, 1)

	enemy.facing = -1
	assert_eq(enemy.facing, -1)
	assert_lt(enemy.visual.scale.x, 0.0)
	assert_lt(enemy.visual_polygon.scale.x, 0.0)

func test_swooper_enemy_facing_property_and_scale():
	var enemy := SWOOPER_ENEMY_SCENE.instantiate() as SwooperEnemy
	add_child_autofree(enemy)
	assert_eq(enemy.facing, 1)

	enemy.facing = -1
	assert_eq(enemy.facing, -1)
	assert_lt(enemy.visual.scale.x, 0.0)
	assert_lt(enemy.visual_polygon.scale.x, 0.0)

func test_test_dummy_facing_property_and_scale():
	var dummy := TEST_DUMMY_SCENE.instantiate() as TestDummy
	add_child_autofree(dummy)
	assert_eq(dummy.facing, 1)

	dummy.facing = -1
	assert_eq(dummy.facing, -1)
	assert_lt(dummy.visual.scale.x, 0.0)
	assert_lt(dummy.visual_polygon.scale.x, 0.0)

