class_name EnemySpawnPoint
extends Node2D
## Placed inside a room template scene (see RoomController). Purely
## data — resolves itself into a real enemy the moment RoomController
## calls spawn(), then removes itself. Nothing reads this node again.

@export var enemy_scene: PackedScene  ## res://scenes/enemies/test_dummy.tscn or patrol_dummy.tscn
@export var enemy_stats: EnemyStats
@export var boss_stats: BossStats  ## Boss scenes only — leave null for a normal enemy_scene.
@export var starting_element: StringName = Elements.NONE
@export var starting_charge: int = 1


func spawn() -> Node:
	if enemy_scene == null:
		push_warning("EnemySpawnPoint at %s has no enemy_scene assigned" % global_position)
		queue_free()
		return null

	var enemy := enemy_scene.instantiate()
	# Must set these BEFORE add_child() — add_child() runs the enemy's
	# own _ready() synchronously, and _ready() is what checks
	# enemy_stats to decide whether to join the "enemies" group and
	# build combat_ai. Setting it after add_child() is too late; the
	# enemy silently never joins the group RoomController waits on.
	if "enemy_stats" in enemy:
		enemy.enemy_stats = enemy_stats
	if "boss_stats" in enemy:
		enemy.boss_stats = boss_stats
	if "starting_element" in enemy:
		enemy.starting_element = starting_element
	if "starting_charge" in enemy:
		enemy.starting_charge = starting_charge
	get_parent().add_child(enemy)
	enemy.global_position = global_position
	queue_free()
	return enemy
