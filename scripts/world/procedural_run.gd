extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var player: Player = $Player


func _ready() -> void:
	RunManager.consume_pending_loadout(player)
	RunManager.start_run(room_container, player)
