class_name ShopRoom
extends RoomController
## Enemy-free shop room. Unlike a combat room, clearing it must not add
## the baseline rune pickup beside the exit.

@export var stop_exit: RoomExit
@export var deeper_exit: RoomExit


func _ready() -> void:
	if stop_exit == null:
		stop_exit = get_node_or_null("Exit") as RoomExit
	if deeper_exit == null:
		deeper_exit = get_node_or_null("DeeperExit") as RoomExit
	super._ready()


func _check_cleared() -> void:
	if _is_cleared:
		return
	if get_tree() != null and not get_tree().get_nodes_in_group("enemies").is_empty():
		return

	_is_cleared = true
	if exit != null:
		exit.locked = false
	if stop_exit != null:
		stop_exit.locked = false
	if deeper_exit != null:
		deeper_exit.locked = false
	cleared.emit()
	set_process(false)


func get_player_spawn_position() -> Vector2:
	for child in get_children():
		if child.is_in_group("player_spawn"):
			return child.global_position
	push_warning("Shop room %s has no player_spawn marker" % scene_file_path)
	return Vector2.ZERO
