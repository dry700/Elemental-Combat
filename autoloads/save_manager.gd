extends Node
## Local JSON save/progression data (Section 6.2: "Local JSON... no
## backend required for a single-player, offline game"). Handles three
## independent concerns in one file, all keyed under a single JSON
## object on disk:
##   - unlocked_weapons / unlocked_skills: meta-progression — every
##     weapon/skill the player has EVER equipped from a world pickup
##     (see Player.swap_weapon/swap_skill), tracked by resource path,
##     persists across deaths and new runs.
##   - run_history: a capped log of completed runs (win or loss), each
##     with an outcome, how many rooms were cleared, and how long it
##     took — the evaluation-friendly record GUIDE.md's own "keep track
##     of what you tried" advice already models for tuning sessions,
##     just for runs instead.
##   - in_progress_run: a single mid-run snapshot (room sequence,
##     current room index, elapsed time, and the player's health/armor/
##     equipped weapons+skills by resource path) written after every
##     room transition, so quitting and relaunching resumes exactly
##     where the player left off. Deliberately NOT mid-room precise —
##     see run_manager.gd's own autosave comment for why.
##
## Godot's user:// maps to a real per-OS user data directory
## (AppData/Library/.local per platform) — the correct writable location
## for save data, unlike res:// which is read-only once exported.

const MAX_RUN_HISTORY_ENTRIES: int = 50  ## Oldest entries drop off first — a run history log, not an unbounded database.

## Non-const so tests can point this at a throwaway file instead of the
## real save — see test/helpers/save_test_isolation.gd. Never intended
## to change at runtime during actual play.
var _save_path: String = "user://save_data.json"

var _data: Dictionary = {}


func _ready() -> void:
	_load_from_disk()


func _default_data() -> Dictionary:
	return {
		"version": 1,
		"unlocked_weapons": [],
		"unlocked_skills": [],
		"run_history": [],
		"in_progress_run": null,
	}


func _load_from_disk() -> void:
	if not FileAccess.file_exists(_save_path):
		_data = _default_data()
		return
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open %s for reading — starting fresh" % _save_path)
		_data = _default_data()
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
		# Fill in any keys missing from an older save version rather than
		# rejecting the whole file — additive, not a hard schema gate.
		for key in _default_data():
			if not _data.has(key):
				_data[key] = _default_data()[key]
	else:
		push_warning("SaveManager: %s was not valid JSON — starting fresh" % _save_path)
		_data = _default_data()


func _save_to_disk() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open %s for writing — progress not saved" % _save_path)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


## --- Meta-progression: weapons/skills ever found ---

func record_weapon_unlock(resource_path: String) -> void:
	if resource_path == "":
		return  ## Runtime-only WeaponStats.new() (e.g. tests, the fallback in player.gd) has no path to persist.
	var unlocked: Array = _data["unlocked_weapons"]
	if resource_path in unlocked:
		return
	unlocked.append(resource_path)
	_save_to_disk()


func record_skill_unlock(resource_path: String) -> void:
	if resource_path == "":
		return
	var unlocked: Array = _data["unlocked_skills"]
	if resource_path in unlocked:
		return
	unlocked.append(resource_path)
	_save_to_disk()


func get_unlocked_weapon_paths() -> Array:
	return _data["unlocked_weapons"].duplicate()


func get_unlocked_skill_paths() -> Array:
	return _data["unlocked_skills"].duplicate()


## --- Run history ---

func record_run_result(outcome: String, rooms_cleared: int, duration_sec: float) -> void:
	var history: Array = _data["run_history"]
	history.append({
		"outcome": outcome,  # "win" or "loss"
		"rooms_cleared": rooms_cleared,
		"duration_sec": duration_sec,
		"timestamp": Time.get_datetime_string_from_system(),
	})
	while history.size() > MAX_RUN_HISTORY_ENTRIES:
		history.pop_front()
	_save_to_disk()


func get_run_history() -> Array:
	return _data["run_history"].duplicate()


## --- Mid-run save/resume ---

func save_in_progress_run(sequence: Array, current_index: int, player_state: Dictionary, elapsed_sec: float) -> void:
	_data["in_progress_run"] = {
		"sequence": sequence,
		"current_index": current_index,
		"elapsed_sec": elapsed_sec,
		"player": player_state,
	}
	_save_to_disk()


func has_in_progress_run() -> bool:
	return _data.get("in_progress_run") != null


## Returns the saved run dict, or null if none exists. Does NOT clear it —
## RunManager clears explicitly once the resumed run actually ends (win
## or loss), so a crash mid-resume doesn't silently lose the save.
func load_in_progress_run() -> Variant:
	return _data.get("in_progress_run")


func clear_in_progress_run() -> void:
	_data["in_progress_run"] = null
	_save_to_disk()
