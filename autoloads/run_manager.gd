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
	"res://scenes/world/rooms/room_a.tscn",
	"res://scenes/world/rooms/room_b.tscn",
	"res://scenes/world/rooms/room_c.tscn",
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


func start_run(room_container: Node, player: Player) -> void:
	_room_container = room_container
	_player = player
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)

	var saved: Variant = SaveManager.load_in_progress_run()
	if saved is Dictionary:
		_resume_from_save(saved)
	else:
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
	_player.apply_save_state(saved.get("player", {}))
	_current_index = int(saved.get("current_index", -1)) - 1
	_advance()
	print("Resumed run at room %d/%d" % [_current_index + 1, _sequence.size()])


func advance_room() -> void:
	# Deferred: this is called from RoomExit's player_entered signal,
	# which fires while the physics server is still mid "flush queries"
	# (body_entered is a physics-engine callback). Everything _advance()
	# does downstream — freeing the old room, instantiating the new one,
	# and spawning enemies that add_child() new Area2Ds and toggle their
	# monitoring flag — is disallowed synchronously in that context.
	# Deferring runs the actual swap once the current physics step ends.
	call_deferred("_advance")


func _advance() -> void:
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


func _on_room_cleared(_controller: RoomController) -> void:
	print("Room cleared — exit unlocked")


func _on_player_died() -> void:
	if not _run_active:
		return
	var rooms_cleared := maxi(_current_index, 0)
	print("Run failed — you died. (%d/%d rooms reached, %.1fs)" % [rooms_cleared, _sequence.size(), _elapsed_sec])
	_finish_run("loss", rooms_cleared)


## Shared by both a completed run (win) and a player death (loss) — logs
## the result, clears the resumable save (a finished run has nothing
## left to resume INTO), and stops the elapsed-time clock.
func _finish_run(outcome: String, rooms_cleared: int) -> void:
	_run_active = false
	set_process(false)
	SaveManager.record_run_result(outcome, rooms_cleared, _elapsed_sec)
	SaveManager.clear_in_progress_run()


func _autosave() -> void:
	if _player == null or _current_room == null:
		return
	SaveManager.save_in_progress_run(_sequence, _current_index, _player.to_save_state(), _elapsed_sec)
