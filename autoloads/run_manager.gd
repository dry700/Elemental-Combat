extends Node
## Sequences a single run's rooms (Section 2.3: "run-based progression").
## Deliberately linear, not branching — a small, contained addition
## rather than a full level-graph system. Paths listed as constants,
## matching this project's existing autoload convention (input_setup.gd's
## KEYCODE constants) — a script-only autoload has no Inspector to set
## exports on anyway.

const ROOM_SCENE_PATHS: Array[String] = [
	"res://scenes/world/rooms/room_a.tscn",
	"res://scenes/world/rooms/room_b.tscn",
	"res://scenes/world/rooms/room_c.tscn",
]

const ROOMS_PER_RUN: int = 3

var _sequence: Array[String] = []
var _current_index: int = -1
var _current_room: Node = null
var _room_container: Node = null
var _player: Node = null


func start_run(room_container: Node, player: Node) -> void:
	_room_container = room_container
	_player = player
	_sequence = _generate_sequence()
	_current_index = -1
	_advance()


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
	return sequence


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


func _on_room_cleared(_controller: RoomController) -> void:
	print("Room cleared — exit unlocked")
