extends RoomController

var boss: Boss
var _active_wave_enemies: Array[Node] = []
var _wave_active: bool = false
var _cleaning_after_boss_death: bool = false
var _intro_active: bool = false
var _intro_finished: bool = false
var _intro_tween: Tween
var _intro_player: Player
var _intro_camera: Camera2D
var _intro_original_zoom: Vector2
var _intro_original_offset: Vector2
var _intro_original_boss_process_mode: int
var _intro_overlay: CanvasLayer


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
	_intro_player = RunManager._player if RunManager != null else null
	if _intro_player == null:
		_intro_player = get_tree().get_first_node_in_group("player") as Player
	if _intro_player == null:
		return
	_intro_camera = _intro_player.get_node_or_null("Camera2D") as Camera2D
	if _intro_camera == null:
		return
	_start_boss_intro()


func _start_boss_intro() -> void:
	_intro_active = true
	_intro_finished = false
	_intro_player.cutscene_input_locked = true
	_intro_player.velocity.x = 0.0
	_intro_player.state = Player.State.IDLE if _intro_player.is_on_floor() else Player.State.FALL
	_intro_original_zoom = _intro_camera.zoom
	_intro_original_offset = _intro_camera.offset
	_intro_original_boss_process_mode = boss.process_mode
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	_intro_overlay = _create_intro_overlay()
	_play_intro()


func _play_intro() -> void:
	var wide_zoom := _intro_original_zoom * 0.82
	var framing_offset := Vector2(120.0, 0.0)
	if not await _tween_intro_camera(wide_zoom, framing_offset, 0.55):
		return
	if not await _wait_intro(0.35):
		return
	_play_boss_stomp()
	if not await _wait_intro(0.75):
		return
	_set_intro_title_alpha(1.0)
	if not await _wait_intro(1.1):
		return
	_set_intro_title_alpha(0.0)
	if not await _wait_intro(0.2):
		return
	if not await _tween_intro_camera(_intro_original_zoom, _intro_original_offset, 0.55):
		return
	_finish_boss_intro()


func _tween_intro_camera(target_zoom: Vector2, target_offset: Vector2, duration: float) -> bool:
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(_intro_camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(_intro_camera, "offset", target_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return await _wait_intro(duration)


func _wait_intro(duration: float) -> bool:
	var elapsed := 0.0
	while elapsed < duration:
		if _intro_finished:
			return false
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	return not _intro_finished


func _create_intro_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "BossIntroOverlay"
	layer.layer = 20
	add_child(layer)
	var card := Control.new()
	card.name = "TitleCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var title := Label.new()
	title.name = "BossTitle"
	title.text = "THỔ NGƯU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43))
	title.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.02, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.anchor_left = 0.15
	title.anchor_right = 0.85
	title.anchor_top = 0.60
	title.anchor_bottom = 0.70
	title.modulate.a = 0.0
	card.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "BossSubtitle"
	subtitle.text = "◆  EARTHBOUND BULL  ◆"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.76, 0.55))
	subtitle.anchor_left = 0.15
	subtitle.anchor_right = 0.85
	subtitle.anchor_top = 0.70
	subtitle.anchor_bottom = 0.76
	subtitle.modulate.a = 0.0
	card.add_child(subtitle)
	var skip_hint := Label.new()
	skip_hint.name = "SkipHint"
	skip_hint.text = "Q / ENTER  •  SKIP"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82, 0.85))
	skip_hint.anchor_left = 0.35
	skip_hint.anchor_right = 0.65
	skip_hint.anchor_top = 0.88
	skip_hint.anchor_bottom = 0.94
	skip_hint.modulate.a = 0.0
	card.add_child(skip_hint)
	return layer


func _set_intro_title_alpha(alpha: float) -> void:
	if _intro_overlay == null:
		return
	var card := _intro_overlay.get_node_or_null("TitleCard")
	if card == null:
		return
	for child in card.get_children():
		var tween := create_tween()
		tween.tween_property(child, "modulate:a", alpha, 0.2)


func _play_boss_stomp() -> void:
	if boss == null:
		return
	var burst := SkillCastVFX.new()
	burst.set_element(Elements.THO)
	add_child(burst)
	burst.global_position = boss.global_position + Vector2(0.0, 10.0)
	var particles := CPUParticles2D.new()
	particles.amount = 12
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 24.0
	particles.initial_velocity_max = 58.0
	particles.gravity = Vector2(0.0, 90.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(0.92, 0.68, 0.28, 0.9)
	add_child(particles)
	particles.global_position = burst.global_position
	particles.emitting = true
	var boss_visual := boss.get_node_or_null("SpriteVisual") as Node2D
	if boss_visual != null:
		var stomp_tween := create_tween()
		stomp_tween.tween_property(boss_visual, "scale", Vector2(1.12, 0.86), 0.14)
		stomp_tween.tween_property(boss_visual, "scale", Vector2(0.94, 1.12), 0.12)
		stomp_tween.tween_property(boss_visual, "scale", Vector2.ONE, 0.18)
	ScreenShake.shake(5.0, 0.22)


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active or _intro_finished:
		return
	if event.is_action_pressed("skill_1", false) or event.is_action_pressed("ui_accept", false):
		_finish_boss_intro()
		get_viewport().set_input_as_handled()


func _finish_boss_intro() -> void:
	if _intro_finished:
		return
	_intro_finished = true
	_intro_active = false
	if _intro_tween != null and _intro_tween.is_running():
		_intro_tween.kill()
	if is_instance_valid(_intro_camera):
		_intro_camera.zoom = _intro_original_zoom
		_intro_camera.offset = _intro_original_offset
	if is_instance_valid(_intro_overlay):
		_intro_overlay.queue_free()
	if is_instance_valid(boss):
		boss.process_mode = _intro_original_boss_process_mode
	if is_instance_valid(_intro_player):
		_intro_player.cutscene_input_locked = false
		_intro_player._jump_buffer_timer = 0.0
		_intro_player.velocity.x = 0.0
	if is_instance_valid(_intro_player):
		_intro_player.state = Player.State.IDLE if _intro_player.is_on_floor() else Player.State.FALL


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
