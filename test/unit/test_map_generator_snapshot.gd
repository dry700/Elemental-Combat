extends GutTest

const CHUNK_DIR := "res://scenes/world/chunks"

func test_snapshot_restores_grid_markers_and_exact_chunk_choices() -> void:
	var original := MapGenerator.new(4, 3)
	original.load_pool_from_dir(CHUNK_DIR)
	original.generate()
	var first_map := Node2D.new()
	add_child_autofree(first_map)
	original.build_map(first_map)
	var snapshot := original.to_dict()

	var restored := MapGenerator.new(4, 3)
	restored.load_pool_from_dir(CHUNK_DIR)
	assert_true(restored.load_layout(snapshot))
	var restored_map := Node2D.new()
	add_child_autofree(restored_map)
	restored.build_map(restored_map)
	assert_eq(restored.to_dict(), snapshot)
	assert_eq(restored_map.get_child_count(), first_map.get_child_count())
	assert_eq(restored.start_cell, original.start_cell)
	assert_eq(restored.finish_cell, original.finish_cell)

func test_snapshot_rejects_wrong_dimensions_without_mutating_generator() -> void:
	var map_gen := MapGenerator.new(4, 3)
	var invalid := {
		"grid_w": 5,
		"grid_h": 3,
		"start_cell": [0, 0],
		"finish_cell": [4, 0],
		"cells": [],
	}
	assert_false(map_gen.load_layout(invalid))
	assert_true(map_gen.grid.is_empty())

func test_generator_places_one_dead_end_shop_and_round_trips_snapshot() -> void:
	var generator := MapGenerator.new(4, 3)
	generator.load_pool_from_dir(CHUNK_DIR)
	for i in range(100):
		generator.generate()
		assert_ne(generator.shop_cell, Vector2i(-1, -1), "shop must be assigned")
		assert_true(generator.grid.has(generator.shop_cell), "shop cell should exist in the grid")
		assert_ne(generator.shop_cell, generator.start_cell)
		assert_ne(generator.shop_cell, generator.finish_cell)
		var mask := int(generator.grid.get(generator.shop_cell, 0))
		assert_true(mask != 0 and (mask & (mask - 1)) == 0, "shop must be a single-bit dead end")
		assert_eq(generator.chunk_paths.get(generator.shop_cell, ""), "", "shop chunk is generated in-place")
		assert_true(_is_reachable(generator.start_cell, generator.grid, generator.shop_cell), "shop must remain reachable from the start")
		var snapshot := generator.to_dict()
		var restored := MapGenerator.new(4, 3)
		restored.load_pool_from_dir(CHUNK_DIR)
		assert_true(restored.load_layout(snapshot), "snapshot should round trip with the shop cell")
		assert_eq(restored.shop_cell, generator.shop_cell)
		assert_eq(restored.to_dict(), snapshot)

func test_procedural_room_populates_a_visible_shop_station() -> void:
	var room := ProceduralRoomController.new()
	add_child_autofree(room)
	var station_count := 0
	var stall_count := 0
	var skill_stall_count := 0
	var rune_count := 0
	var shop_weapons: Array[WeaponPickup] = []
	for child in room.get_children():
		if not child.is_in_group("shop_chunk"):
			continue
		for shop_item in child.get_children():
			if shop_item.get_script() == preload("res://scripts/items/shop_station.gd"):
				station_count += 1
			elif shop_item.get_script() == preload("res://scripts/items/shop_weapon_pickup.gd"):
				stall_count += 1
				shop_weapons.append(shop_item as WeaponPickup)
			elif shop_item.get_script() == preload("res://scripts/items/shop_skill_pickup.gd"):
				skill_stall_count += 1
				assert_eq(int(shop_item.get("price")), 60)
			elif shop_item.get_script() == preload("res://scripts/items/rune_pickup.gd"):
				rune_count += 1
	assert_eq(station_count, 1, "procedural rooms should spawn one station on the shop chunk")
	assert_eq(stall_count, 2, "shop should populate two distinct paid weapon stalls")
	assert_eq(skill_stall_count, 1, "shop should populate one paid skill stall")
	assert_eq(rune_count, 1, "shop should provide one free baseline rune")
	if shop_weapons.size() == 2:
		assert_ne(shop_weapons[0].weapon.resource_path, shop_weapons[1].weapon.resource_path)
	for shop_weapon in shop_weapons:
		assert_eq(int(shop_weapon.get("price")), _expected_shop_weapon_price(shop_weapon.weapon))

func _expected_shop_weapon_price(weapon: WeaponStats) -> int:
	match weapon.weight:
		WeaponStats.Weight.LIGHT:
			return 35
		WeaponStats.Weight.MEDIUM:
			return 45
		WeaponStats.Weight.HEAVY:
			return 55
	return 45

func _is_reachable(start: Vector2i, grid: Dictionary, target: Vector2i) -> bool:
	var queue: Array[Vector2i] = []
	queue.append(start)
	var visited: Dictionary = {start: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			return true
		var mask := int(grid.get(current, 0))
		var neighbors := [
			{ "delta": Vector2i(1, 0), "mask": MapGenerator.DIR_RIGHT },
			{ "delta": Vector2i(-1, 0), "mask": MapGenerator.DIR_LEFT },
			{ "delta": Vector2i(0, -1), "mask": MapGenerator.DIR_UP },
			{ "delta": Vector2i(0, 1), "mask": MapGenerator.DIR_DOWN },
		]
		for entry in neighbors:
			if (mask & int(entry["mask"])) == 0:
				continue
			var delta: Vector2i = entry["delta"]
			var next_cell: Vector2i = current + delta
			if not grid.has(next_cell) or visited.has(next_cell):
				continue
			visited[next_cell] = true
			queue.append(next_cell)
	return false
