extends GutTest

const BOSS_ROOM_PATH := "res://scenes/world/rooms/room_boss.tscn"

var room: RoomController
var boss: Boss


func before_each() -> void:
	room = load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	boss = room.find_child("Boss", true, false) as Boss
	boss.elemental.armor = 0.0


func test_wave_threshold_spawns_the_matching_wave() -> void:
	boss._apply_damage(420.0)

	assert_true(boss.is_passive)
	var active_enemies: Array = room.get("_active_wave_enemies")
	assert_eq(active_enemies.size(), 4)
	for enemy in active_enemies:
		assert_true(room.get_node("Wave1Spawns").is_ancestor_of(enemy))


func test_clearing_wave_early_ends_passive_window_and_staggers_boss() -> void:
	boss._apply_damage(420.0)
	var wave_enemies: Array = (room.get("_active_wave_enemies") as Array).duplicate()
	assert_eq(wave_enemies.size(), 4)

	for enemy in wave_enemies:
		enemy.queue_free()
	await get_tree().process_frame

	assert_false(boss.is_passive)
	assert_true(boss.is_stunned)
	assert_eq(boss.get("_stagger_damage_multiplier"), 1.5)


func test_boss_death_despawns_remaining_wave_adds() -> void:
	boss._apply_damage(420.0)
	var wave_enemies: Array = (room.get("_active_wave_enemies") as Array).duplicate()
	assert_eq(wave_enemies.size(), 4)

	boss._die()
	await get_tree().process_frame

	for enemy in wave_enemies:
		assert_false(is_instance_valid(enemy))
