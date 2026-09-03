extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var player: Player = $Player


func _ready() -> void:
	RunManager.start_run(room_container, player)
