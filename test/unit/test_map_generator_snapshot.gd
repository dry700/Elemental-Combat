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
