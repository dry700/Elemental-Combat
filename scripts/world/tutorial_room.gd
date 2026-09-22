extends RoomController

const NEXT_SCENE := "res://scenes/world/procedural_run.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const STARTER_PRIMARY_WEAPON := "res://scripts/resources/weapons/training_greatsword.tres"
const STARTER_SECONDARY_WEAPON := "res://scripts/resources/weapons/training_hammer.tres"

@onready var stage_label: Label = $CanvasLayer/StageLabel
@onready var helper_label: Label = $CanvasLayer/HelperLabel

var _stage_index: int = 0
var _completed: bool = false
var _triggered_enemies: Array[Node] = []

## Above-the-player movement/jump prompt — tracks the player directly
## (same pattern DamageLabel already uses on TestDummy/PatrolDummy/Boss:
## a Label parented straight onto a Node2D follows its transform for
## free). Independent of the reaction-stage prompts in the fixed
## CanvasLayer above. Shows the move prompt first, switches to the jump
## prompt once movement is detected, and disappears once both are done.
var _player_prompt_label: Label
var _has_moved: bool = false
var _has_jumped: bool = false


func _ready() -> void:
	super._ready()
	_spawn_player_if_needed()
	_setup_movement_prompt()
	if exit != null:
		exit.locked = true
		exit.player_entered.connect(_on_exit_entered, CONNECT_ONE_SHOT)
	_connect_enemy_status_signals()
	_refresh_stage_prompt()


func _process(delta: float) -> void:
	super._process(delta)  ## Preserve RoomController's own clear-check polling.
	_update_movement_prompt()


func _spawn_player_if_needed() -> void:
	if get_node_or_null("Player") != null:
		return
	var player_scene := PLAYER_SCENE.instantiate() as Player
	if player_scene == null:
		return
	player_scene.weapon = load(STARTER_PRIMARY_WEAPON)
	player_scene.secondary_weapon = load(STARTER_SECONDARY_WEAPON)
	player_scene.position = get_player_spawn_position()
	add_child(player_scene)


func _setup_movement_prompt() -> void:
	var player := get_node_or_null("Player") as Player
	if player == null:
		return
	_player_prompt_label = Label.new()
	_player_prompt_label.text = "Use 'A', 'D' to Move"
	_player_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_prompt_label.position = Vector2(-40, -46)
	_player_prompt_label.size = Vector2(80, 16)
	_player_prompt_label.add_theme_font_size_override("font_size", 10)
	_player_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_player_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_player_prompt_label.add_theme_constant_override("outline_size", 3)
	player.add_child(_player_prompt_label)


func _update_movement_prompt() -> void:
	if _player_prompt_label == null:
		return

	if not _has_moved and Input.get_axis("move_left", "move_right") != 0.0:
		_has_moved = true

	if not _has_jumped and Input.is_action_just_pressed("jump"):
		_has_jumped = true

	if _has_moved and _has_jumped:
		_player_prompt_label.visible = false
	elif _has_moved:
		_player_prompt_label.text = "Use 'Space Bar' to Jump"
	else:
		_player_prompt_label.text = "Use 'A', 'D' to Move"


func _connect_enemy_status_signals() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var combatant := enemy.get("elemental") as ElementalCombatant
		if combatant == null:
			continue
		if not combatant.status.status_applied.is_connected(_on_enemy_status_applied):
			combatant.status.status_applied.connect(_on_enemy_status_applied.bind(enemy))


func _on_enemy_status_applied(_element: StringName, _charge: int, enemy: Node) -> void:
	if _completed or enemy == null or _triggered_enemies.has(enemy):
		return
	_triggered_enemies.append(enemy)
	_stage_index += 1
	_refresh_stage_prompt()
	if _stage_index >= 2:
		_completed = true
		if exit != null:
			exit.locked = false


func _refresh_stage_prompt() -> void:
	match _stage_index:
		0:
			stage_label.text = "Stage 1 — Learn the reaction"
			helper_label.text = "Land a basic reaction on the dummy to unlock the next step."
		1:
			stage_label.text = "Stage 2 — Confirm the loop"
			helper_label.text = "Trigger another reaction on the second dummy, then continue."
		_:
			stage_label.text = "Tutorial complete"
			helper_label.text = "The exit is unlocked — step through to start the run."


func _on_exit_entered() -> void:
	SaveManager.mark_tutorial_completed()
	get_tree().change_scene_to_file(NEXT_SCENE)