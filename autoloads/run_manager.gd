extends Node
## Sequences a single run's rooms (Section 2.3: "run-based progression").
## Deliberately linear, not branching — a small, contained addition
## rather than a full level-graph system. Paths listed as constants,
## matching this project's existing autoload convention (input_setup.gd's
## KEYCODE constants) — a script-only autoload has no Inspector to set
## exports on anyway.
##
## Save/resume (SaveManager, Section 6.2): every successful room
## transition autosaves the room sequence, current index, elapsed time,
## and the player's health/armor/equipped weapons+skills. Deliberately
## NOT mid-room precise — enemy state (which are alive, their current
## HP/status) is never captured, so resuming always re-enters a room
## fresh from its EnemySpawnPoints, same as if the player had just
## walked in. Saving full enemy state would mean serializing
## ElementalStatus/DoT/Disable timers mid-tick for an arbitrary number
## of enemies — a much bigger surface than "resume where I left off"
## actually needs; most roguelikes checkpoint at room/floor boundaries
## for exactly this reason.

const ROOM_SCENE_PATHS: Array[String] = [
	"res://scenes/world/rooms/procedural_room.tscn",
]

## Always the LAST room of a run — never part of the random pool above,
## and never eligible for the "no immediate repeats" shuffle those go
## through. A boss encounter should be a guaranteed, telegraphed final
## room per Section 6.3's Sprint 3 definition of done ("a full run is
## completable start to finish"), not something that might get skipped
## or land mid-run depending on the RNG.
const BOSS_ROOM_SCENE_PATH: String = "res://scenes/world/rooms/room_boss.tscn"

const ROOMS_PER_RUN: int = 3  ## Normal rooms only — the boss room is appended on top of this count, not included in it.

var _sequence: Array[String] = []
var _current_index: int = -1
var _current_room: Node = null
var _room_container: Node = null
var _player: Player = null
var _elapsed_sec: float = 0.0
var _run_active: bool = false
var _map_structure_to_restore: Dictionary = {}

var loop: int = 1
var _continue_loop: bool = false

var pending_weapon_path: String = ""
var pending_secondary_weapon_path: String = ""
var pending_skill_1_path: String = ""
var pending_skill_2_path: String = ""
var pending_weapon_rune: Dictionary = {}
var pending_secondary_weapon_rune: Dictionary = {}

var _room_start_time: float = 0.0
var _room_start_hp: float = 0.0
var _room_start_qi_earned: float = 0.0
var _room_start_qi_spent: float = 0.0

func consume_pending_loadout(player: Player) -> void:
	if pending_weapon_path != "":
		var w := load(pending_weapon_path) as WeaponStats
		if w != null:
			player.weapon = w
	if pending_secondary_weapon_path != "":
		var w2 := load(pending_secondary_weapon_path) as WeaponStats
		if w2 != null:
			player.secondary_weapon = w2
	if pending_skill_1_path != "":
		var s1 := load(pending_skill_1_path) as SkillData
		if s1 != null:
			player.skill_1 = s1
	if pending_skill_2_path != "":
		var s2 := load(pending_skill_2_path) as SkillData
		if s2 != null:
			player.skill_2 = s2
	if not pending_weapon_rune.is_empty():
		var r := RuneData.from_dict(pending_weapon_rune)
		if r != null:
			player.weapon_rune = r
	if not pending_secondary_weapon_rune.is_empty():
		var r2 := RuneData.from_dict(pending_secondary_weapon_rune)
		if r2 != null:
			player.secondary_weapon_rune = r2
	pending_weapon_path = ""
	pending_secondary_weapon_path = ""
	pending_skill_1_path = ""
	pending_skill_2_path = ""
	pending_weapon_rune = {}
	pending_secondary_weapon_rune = {}


func start_run(room_container: Node, player: Player) -> void:
	_room_container = room_container
	_player = player
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)

	var saved: Variant = SaveManager.load_in_progress_run()
	if saved is Dictionary:
		_resume_from_save(saved)
	else:
		if _continue_loop:
			_continue_loop = false
		else:
			UpgradeManager.reset()
			loop = 1
		_sequence = _generate_sequence()
		_elapsed_sec = 0.0
		_current_index = -1
		_advance()

	_run_active = true
	set_process(true)


func _process(delta: float) -> void:
	if _run_active:
		_elapsed_sec += delta


func _generate_sequence() -> Array[String]:
	var sequence: Array[String] = []
	var last_path := ""
	for i in range(ROOMS_PER_RUN):
		var choices := ROOM_SCENE_PATHS.duplicate()
		if choices.size() > 1 and last_path != "":
			choices.erase(last_path)  ## No immediate repeats.
		var pick: String = choices[randi() % choices.size()]
		sequence.append(pick)
		last_path = pick
	sequence.append(BOSS_ROOM_SCENE_PATH)
	return sequence


## Rebuilds sequence/elapsed time/player state from a SaveManager
## snapshot, then re-enters whichever room the player was actually on —
## _advance() always increments _current_index first, so this deliberately
## sets it one behind the saved value to land back on the same room
## rather than skipping past it.
func _resume_from_save(saved: Dictionary) -> void:
	var loaded_sequence: Array = saved.get("sequence", [])
	_sequence = []
	for path in loaded_sequence:
		_sequence.append(str(path))
	_elapsed_sec = saved.get("elapsed_sec", 0.0)
	var saved_map_structure: Variant = saved.get("map_structure", {})
	_map_structure_to_restore = saved_map_structure.duplicate(true) if saved_map_structure is Dictionary else {}
	# Restore upgrade state before the player state so the vitality bonus is
	# already included when the save snapshot applies the player's health.
	UpgradeManager.apply_save_state(saved.get("upgrade_state", {}))
	_player.apply_save_state(saved.get("player", {}))
	loop = int(saved.get("loop", 1))
	_current_index = int(saved.get("current_index", -1)) - 1
	_advance()
	print("Resumed run at room %d/%d (loop %d)" % [_current_index + 1, _sequence.size(), loop])


func advance_room() -> void:
	# Deferred: this is called from RoomExit's player_entered signal,
	# which fires while the physics server is still mid "flush queries"
	# (body_entered is a physics-engine callback). Everything _advance()
	# does downstream — freeing the old room, instantiating the new one,
	# and spawning enemies that add_child() new Area2Ds and toggle their
	# monitoring flag — is disallowed synchronously in that context.
	# Deferring runs the actual swap once the current physics step ends.
	call_deferred("_advance")


func regenerate_current_room() -> bool:
	if not OS.is_debug_build() or not _current_room is ProceduralRoomController or _current_index < 0:
		return false
	call_deferred("_regenerate_current_room")
	return true


func _regenerate_current_room() -> void:
	if not _current_room is ProceduralRoomController:
		return
	var old_room: Node = _current_room
	var old_parent := old_room.get_parent()
	_current_room = null
	_map_structure_to_restore.clear()
	if old_parent != null:
		old_parent.remove_child(old_room)
	old_room.queue_free()
	_current_index -= 1
	_advance()


func teleport_player_to_playtest_target(target: Variant) -> bool:
	if not OS.is_debug_build() or _player == null or not _current_room is ProceduralRoomController:
		return false
	var destination: Variant = _current_room.get_playtest_teleport_position(target)
	if not destination is Vector2:
		return false
	_player.global_position = destination
	_player.velocity = Vector2.ZERO
	return true


func _snapshot_room_start() -> void:
	_room_start_time = _elapsed_sec
	_room_start_hp = _player.current_health if _player != null else 0.0
	_room_start_qi_earned = UpgradeManager.qi_earned_total
	_room_start_qi_spent = UpgradeManager.qi_spent_total


func _log_room_completed(room_num: int) -> void:
	if not OS.is_debug_build():
		return
	var time_delta := _elapsed_sec - _room_start_time
	var current_hp := int(_player.current_health) if _player != null else 0
	var start_hp := int(_room_start_hp)
	var qi_earned_delta := int(UpgradeManager.qi_earned_total - _room_start_qi_earned)
	var qi_spent_delta := int(UpgradeManager.qi_spent_total - _room_start_qi_spent)
	print("[RUNLOG] loop=%d room=%d time=%.1f hp=%d->%d qi_earned=%d qi_spent=%d" % [
		loop, room_num, time_delta, start_hp, current_hp, qi_earned_delta, qi_spent_delta
	])


func _advance() -> void:
	if _current_index >= 0:
		_log_room_completed(_current_index + 1)

	_current_index += 1
	if _current_room != null:
		_current_room.queue_free()
		_current_room = null

	if _current_index >= _sequence.size():
		print("Run complete!")  ## No hub/meta-progression yet (out of scope, Section 7.1) — a finished run just stops here.
		_finish_run("win", _sequence.size())
		return

	var room_scene: PackedScene = load(_sequence[_current_index])
	_current_room = room_scene.instantiate()
	if _current_room is ProceduralRoomController and not _map_structure_to_restore.is_empty():
		_current_room.saved_map_structure = _map_structure_to_restore.duplicate(true)
	_map_structure_to_restore.clear()
	_room_container.add_child(_current_room)

	var controller := _current_room as RoomController
	if controller == null:
		push_error("Room %s has no RoomController on its root" % _sequence[_current_index])
		return

	controller.cleared.connect(_on_room_cleared.bind(controller), CONNECT_ONE_SHOT)
	if controller.exit != null:
		controller.exit.player_entered.connect(advance_room, CONNECT_ONE_SHOT)

	_player.global_position = controller.get_player_spawn_position()
	_autosave()
	_snapshot_room_start()


func _on_room_cleared(_controller: RoomController) -> void:
	print("Room cleared — exit unlocked")
	var hud := get_node_or_null("/root/Hud")
	if hud != null and hud.has_method("_can_open_upgrade_menu") and hud.has_method("_open_upgrade_menu"):
		if hud._can_open_upgrade_menu():
			hud._open_upgrade_menu()


func _on_player_died() -> void:
	if not _run_active:
		return
	var rooms_cleared := maxi(_current_index, 0)
	print("Run failed — you died. (%d/%d rooms reached, %.1fs)" % [rooms_cleared, _sequence.size(), _elapsed_sec])
	_finish_run("loss", rooms_cleared)


var last_run_outcome: String = ""
var last_run_rooms_cleared: int = 0
var last_run_duration_sec: float = 0.0

## Set to true in tests to prevent change_scene_to_file from being called.
var skip_scene_transitions: bool = false

## Shared by both a completed run (win) and a player death (loss) — logs
## the result, clears the resumable save (a finished run has nothing
## left to resume INTO), and stops the elapsed-time clock.
func _finish_run(outcome: String, rooms_cleared: int) -> void:
	if outcome == "loss" and _current_index >= 0:
		_log_room_completed(_current_index + 1)
	_run_active = false
	set_process(false)
	SaveManager.record_run_result(outcome, rooms_cleared, _elapsed_sec)
	SaveManager.clear_in_progress_run()
	if outcome != "win":
		UpgradeManager.reset()
		loop = 1
		_continue_loop = false
	
	last_run_outcome = outcome
	last_run_rooms_cleared = rooms_cleared
	last_run_duration_sec = _elapsed_sec
	
	if outcome == "win" and _player != null:
		pending_weapon_path = _player.weapon.resource_path if _player.weapon != null else ""
		pending_secondary_weapon_path = _player.secondary_weapon.resource_path if _player.secondary_weapon != null else ""
		pending_skill_1_path = _player.skill_1.resource_path if _player.skill_1 != null else ""
		pending_skill_2_path = _player.skill_2.resource_path if _player.skill_2 != null else ""
		pending_weapon_rune = _player.weapon_rune.to_dict() if _player.weapon_rune != null else {}
		pending_secondary_weapon_rune = _player.secondary_weapon_rune.to_dict() if _player.secondary_weapon_rune != null else {}
	
	if not skip_scene_transitions:
		get_tree().change_scene_to_file("res://scenes/ui/run_summary.tscn")

func start_next_loop() -> void:
	_continue_loop = true
	loop += 1
	if skip_scene_transitions:
		return
	get_tree().change_scene_to_file("res://scenes/world/procedural_run.tscn")


func _autosave() -> void:
	if _player == null or _current_room == null:
		return
	var map_structure: Dictionary = {}
	if _current_room is ProceduralRoomController and _current_room.map_gen != null:
		map_structure = _current_room.map_gen.to_dict()
	SaveManager.save_in_progress_run(_sequence, _current_index, _player.to_save_state(), _elapsed_sec, map_structure, UpgradeManager.to_save_state(), loop)
