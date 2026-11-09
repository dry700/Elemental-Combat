extends RoomController

var boss: Boss
var _active_wave_enemies: Array[Node] = []
var _wave_active: bool = false
var _cleaning_after_boss_death: bool = false


func _ready() -> void:
	super._ready()

	var boss_nodes := find_children("*", "Boss", false, false)
	if boss_nodes.is_empty():
		push_error("BossRoomController on %s could not find its spawned Boss" % scene_file_path)
		return

	boss = boss_nodes[0] as Boss
	if boss == null:
		push_error("BossRoomController on %s found an invalid Boss node" % scene_file_path)
		return

	var retreat_anchor := get_node_or_null("BossRetreatAnchor") as Node2D
	if retreat_anchor != null:
		boss.set_retreat_position(retreat_anchor.global_position)

	boss.wave_triggered.connect(_on_wave_triggered)
	boss.passive_window_ended.connect(_on_passive_window_ended)
	boss.boss_died.connect(_on_boss_died)


func _on_wave_triggered(wave_index: int) -> void:
	var wave_container := get_node_or_null("Wave%dSpawns" % wave_index) as Node
	if wave_container == null:
		push_error("Boss room has no spawn container for wave %d" % wave_index)
		return

	_active_wave_enemies.clear()
	_wave_active = true
	for child in wave_container.get_children():
		if not child is EnemySpawnPoint:
			continue
		var enemy := (child as EnemySpawnPoint).spawn()
		if enemy == null:
			continue
		_active_wave_enemies.append(enemy)
		enemy.tree_exiting.connect(_on_wave_enemy_exiting.bind(enemy))

	if _active_wave_enemies.is_empty():
		_wave_active = false
		push_error("Boss room wave %d did not spawn any enemies" % wave_index)


func _on_wave_enemy_exiting(enemy: Node) -> void:
	if _cleaning_after_boss_death or not _wave_active:
		return
	_active_wave_enemies.erase(enemy)
	if _active_wave_enemies.is_empty() and boss != null and boss.is_passive:
		_wave_active = false
		boss.end_passive_window(true)


func _on_passive_window_ended(_was_early_clear: bool) -> void:
	_wave_active = false
	_active_wave_enemies.clear()


func _on_boss_died() -> void:
	_cleaning_after_boss_death = true
	_wave_active = false
	_active_wave_enemies.clear()
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		if is_ancestor_of(projectile):
			projectile.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != boss and is_ancestor_of(enemy):
			enemy.queue_free()
