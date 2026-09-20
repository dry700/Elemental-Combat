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


func _ready() -> void:
	super._ready()
	_spawn_player_if_needed()
	if exit != null:
		exit.locked = true
		exit.player_entered.connect(_on_exit_entered, CONNECT_ONE_SHOT)
	_connect_enemy_status_signals()
	_refresh_stage_prompt()


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
