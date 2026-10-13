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
	var s: float = 1.0 + 0.25 * (RunManager.loop - 1)
	var final_enemy_stats: EnemyStats = enemy_stats
	var final_boss_stats: BossStats = boss_stats

	if s > 1.0:
		if final_enemy_stats != null:
			final_enemy_stats = final_enemy_stats.duplicate() as EnemyStats
			final_enemy_stats.max_health *= s
			final_enemy_stats.damage *= s
		if final_boss_stats != null:
			final_boss_stats = final_boss_stats.duplicate() as BossStats
			final_boss_stats.max_health *= s
			final_boss_stats.damage *= s
		if "max_health" in enemy:
			enemy.max_health *= s
		if "damage" in enemy:
			enemy.damage *= s

	# Must set these BEFORE add_child() — add_child() runs the enemy's
	# own _ready() synchronously, and _ready() is what checks
	# enemy_stats to decide whether to join the "enemies" group and
	# build combat_ai. Setting it after add_child() is too late; the
	# enemy silently never joins the group RoomController waits on.
	if "enemy_stats" in enemy:
		enemy.enemy_stats = final_enemy_stats
	if "boss_stats" in enemy:
		enemy.boss_stats = final_boss_stats
	if "starting_element" in enemy:
		enemy.starting_element = starting_element
	if "starting_charge" in enemy:
		enemy.starting_charge = starting_charge
	get_parent().add_child(enemy)
	enemy.global_position = global_position
	queue_free()
	return enemy
