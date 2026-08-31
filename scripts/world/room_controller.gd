class_name RoomController
extends Node2D
## Attached to the root of every room template scene. Resolves that
## room's spawn points into real enemies on load, tracks how many are
## still alive via the shared "enemies" group, and unlocks the exit once
## the last one is gone. RunManager only ever talks to this controller —
## never reaches into a room's children directly.
##
## Design note (PCG, Section 4.1): this reuses the "room-placement"
## category from Viana and dos Santos' (2021) survey — whole, hand-
## authored room templates chosen and sequenced at runtime — rather than
## BSP/cellular-automata tile-grid subdivision. There's no tilemap
## anywhere in this project; A.7 already made the same no-world-state
## call for terrain footprint, so this stays consistent with that
## instead of introducing a tile-grid system just to serve rooms alone.

signal cleared

@export var exit: RoomExit

var _spawn_points: Array[EnemySpawnPoint] = []
var _is_cleared: bool = false


func _ready() -> void:
	# Defensive fallback: a hand-edited/resaved .tscn can silently drop a
	# typed Node-export's NodePath assignment without any parse error,
	# leaving `exit` null while everything else keeps working — which is
	# exactly why RunManager's "cleared" print can fire while the actual
	# RoomExit node never unlocks. find_child() recovers from that case;
	# the push_error below makes a genuinely missing Exit node loud
	# instead of failing silently like this did.
	if exit == null:
		exit = find_child("Exit", true, false) as RoomExit
	if exit == null:
		push_error("RoomController on %s has no Exit node — the room will never advance" % scene_file_path)

	for child in get_children():
		if child is EnemySpawnPoint:
			_spawn_points.append(child)

	if exit != null:
		exit.locked = not _spawn_points.is_empty()  ## An empty room starts already unlocked.

	for spawn_point in _spawn_points:
		spawn_point.spawn()

	_check_cleared()


func _process(_delta: float) -> void:
	if not _is_cleared:
		_check_cleared()


func _check_cleared() -> void:
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_is_cleared = true
		if exit != null:
			exit.locked = false
		cleared.emit()
		set_process(false)


func get_player_spawn_position() -> Vector2:
	for child in get_children():
		if child.is_in_group("player_spawn"):
			return child.global_position
	push_warning("Room %s has no player_spawn marker" % scene_file_path)
	return Vector2.ZERO
