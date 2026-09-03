extends GutTest
## Unit tests for SaveManager — meta-progression unlocks, run history,
## and in-progress-run save/load. Uses the real SaveManager autoload
## singleton (consistent with how this project already tests other
## autoloads — Hud, RunManager), redirected to a throwaway save file for
## the duration of this file via SaveTestIsolation so these tests never
## read or overwrite the developer's actual user://save_data.json.

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()

func test_default_data_starts_empty():
	assert_eq(SaveManager.get_unlocked_weapon_paths(), [])
	assert_eq(SaveManager.get_run_history(), [])
	assert_false(SaveManager.has_in_progress_run())

func test_record_weapon_unlock_adds_a_new_path():
	SaveManager.record_weapon_unlock("res://fake_weapon.tres")
	assert_true("res://fake_weapon.tres" in SaveManager.get_unlocked_weapon_paths())

func test_record_weapon_unlock_does_not_duplicate():
	SaveManager.record_weapon_unlock("res://fake_weapon.tres")
	SaveManager.record_weapon_unlock("res://fake_weapon.tres")
	assert_eq(SaveManager.get_unlocked_weapon_paths().size(), 1)

func test_record_weapon_unlock_ignores_an_empty_path():
	SaveManager.record_weapon_unlock("")
	assert_eq(SaveManager.get_unlocked_weapon_paths().size(), 0)

func test_record_skill_unlock_adds_a_new_path():
	SaveManager.record_skill_unlock("res://fake_skill.tres")
	assert_true("res://fake_skill.tres" in SaveManager.get_unlocked_skill_paths())

func test_record_run_result_appends_an_entry():
	SaveManager.record_run_result("win", 4, 123.4)
	var history := SaveManager.get_run_history()
	assert_eq(history.size(), 1)
	assert_eq(history[0]["outcome"], "win")
	assert_eq(history[0]["rooms_cleared"], 4)

func test_run_history_caps_at_the_maximum_and_drops_the_oldest():
	for i in range(SaveManager.MAX_RUN_HISTORY_ENTRIES + 5):
		SaveManager.record_run_result("loss", i, 1.0)
	var history := SaveManager.get_run_history()
	assert_eq(history.size(), SaveManager.MAX_RUN_HISTORY_ENTRIES)
	assert_eq(history[0]["rooms_cleared"], 5, "the oldest 5 entries should have been dropped")

func test_save_and_load_in_progress_run_round_trips():
	var sequence: Array[String] = ["res://a.tscn", "res://b.tscn"]
	var player_state := {"current_health": 42.0, "weapon_path": "res://fake.tres"}
	SaveManager.save_in_progress_run(sequence, 1, player_state, 55.5)
	assert_true(SaveManager.has_in_progress_run())
	var loaded: Dictionary = SaveManager.load_in_progress_run()
	assert_eq(loaded["current_index"], 1)
	assert_almost_eq(loaded["elapsed_sec"], 55.5, 0.01)
	assert_eq(loaded["player"]["current_health"], 42.0)

func test_clear_in_progress_run_removes_it():
	SaveManager.save_in_progress_run(["res://a.tscn"], 0, {}, 0.0)
	SaveManager.clear_in_progress_run()
	assert_false(SaveManager.has_in_progress_run())

func test_data_actually_persists_to_and_reloads_from_disk():
	SaveManager.record_weapon_unlock("res://persisted_weapon.tres")
	SaveManager._data = SaveManager._default_data()  # Wipe in-memory state...
	SaveManager._load_from_disk()                     # ...and confirm reload recovers it from the file.
	assert_true("res://persisted_weapon.tres" in SaveManager.get_unlocked_weapon_paths())
