extends GutTest
## Integration tests for RunManager's SaveManager integration — autosave
## after a room transition, resuming from a save, and recording a
## win/loss into run history. Uses the real RunManager and SaveManager
## autoload singletons (same pattern as test_run_manager_sequence.gd),
## redirected to a throwaway save file for isolation.

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String
var player: Player

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	add_child_autofree(player)
	# Reset RunManager's own state between tests — it's a persistent
	# autoload, not a fresh instance per test.
	RunManager._sequence = []
	RunManager._current_index = -1
	RunManager._current_room = null
	RunManager._player = player
	RunManager._elapsed_sec = 0.0
	RunManager._run_active = true
	if player.died.is_connected(RunManager._on_player_died):
		player.died.disconnect(RunManager._on_player_died)
	player.died.connect(RunManager._on_player_died)

func after_each():
	RunManager._run_active = false
	RunManager.set_process(false)

func test_finish_run_win_records_history_and_clears_save():
	RunManager._sequence = ["res://a.tscn", "res://b.tscn"]
	RunManager._elapsed_sec = 42.0
	SaveManager.save_in_progress_run(RunManager._sequence, 1, {}, 42.0)
	RunManager._finish_run("win", 2)
	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "win")
	assert_eq(history[-1]["rooms_cleared"], 2)
	assert_false(SaveManager.has_in_progress_run())

func test_player_death_triggers_a_loss_record():
	RunManager._sequence = ["res://a.tscn", "res://b.tscn", "res://c.tscn"]
	RunManager._current_index = 1
	player._apply_damage(player.max_health)  # lethal
	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "loss")
	assert_eq(history[-1]["rooms_cleared"], 1)

func test_death_after_run_already_finished_does_not_double_record():
	RunManager._sequence = ["res://a.tscn"]
	RunManager._finish_run("win", 1)  # _run_active is now false
	var count_before := SaveManager.get_run_history().size()
	player._apply_damage(player.max_health)
	assert_eq(SaveManager.get_run_history().size(), count_before, "a death after the run already ended must not add a second entry")

func test_resume_from_save_restores_sequence_and_player_state():
	var saved_sequence: Array[String] = ["res://a.tscn", "res://b.tscn", "res://c.tscn"]
	var player_state := {"current_health": 17.0, "weapon_path": "", "secondary_weapon_path": "", "skill_1_path": "", "skill_2_path": ""}
	# Point current_index PAST the sequence so _resume_from_save()'s own
	# call to _advance() hits the "run complete" branch instead of
	# trying to instantiate a real (possibly non-existent) room scene —
	# keeps this test focused on state restoration, not room loading.
	var saved := {
		"sequence": saved_sequence,
		"current_index": saved_sequence.size(),
		"elapsed_sec": 88.0,
		"player": player_state,
	}
	RunManager._resume_from_save(saved)
	assert_eq(RunManager._sequence, saved_sequence)
	assert_almost_eq(RunManager._elapsed_sec, 88.0, 0.01)
	assert_eq(player.current_health, 17.0)
