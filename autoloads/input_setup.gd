extends Node
## Defines all input actions in code rather than via Project Settings > Input Map.
##
## Why: hand-editing project.godot's [input] section directly is verbose,
## easy to get subtly wrong, and a malformed project.godot can fail to open
## entirely. Defining actions here is just GDScript — safe, versioned in
## the script itself, and requires no manual setup when opening the project
## for the first time.
##
## To change a key binding, edit the KEYCODE constants below and re-run.
## This runs once, before any other scene, because it's registered as an
## autoload in project.godot.

const MOVE_LEFT_KEYS: Array[Key] = [KEY_A, KEY_LEFT]
const MOVE_RIGHT_KEYS: Array[Key] = [KEY_D, KEY_RIGHT]
const DROP_DOWN_KEYS: Array[Key] = [KEY_S, KEY_DOWN]
const JUMP_KEYS: Array[Key] = [KEY_SPACE]
const DODGE_KEYS: Array[Key] = [KEY_SHIFT]
const ATTACK_KEYS: Array[MouseButton] = [MOUSE_BUTTON_LEFT]
const ATTACK_SECONDARY_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_RIGHT]
const SKILL_1_KEYS: Array[Key] = [KEY_Q]
const SKILL_2_KEYS: Array[Key] = [KEY_E]
const PICKUP_KEYS: Array[Key] = [KEY_F]
const DEBUG_TEST_EFFECTS_KEYS: Array[Key] = [KEY_T]


func _init() -> void:
	_register_action("move_left", MOVE_LEFT_KEYS)
	_register_action("move_right", MOVE_RIGHT_KEYS)
	_register_action("drop_down", DROP_DOWN_KEYS)
	_register_action("jump", JUMP_KEYS)
	_register_action("dodge", DODGE_KEYS)
	_register_mouse_action("attack", ATTACK_KEYS)
	_register_mouse_action("attack_secondary", ATTACK_SECONDARY_BUTTONS)
	_register_action("debug_test_effects", DEBUG_TEST_EFFECTS_KEYS)
	_register_action("skill_1", SKILL_1_KEYS)
	_register_action("skill_2", SKILL_2_KEYS)
	_register_action("pickup", PICKUP_KEYS)

func _register_action(action_name: String, keys: Array[Key]) -> void:
	if InputMap.has_action(action_name):
		# Already defined (e.g. re-running in the editor without a full
		# restart) — clear old events first so we don't stack duplicates.
		InputMap.action_erase_events(action_name)
	else:
		InputMap.add_action(action_name)

	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)


func _register_mouse_action(action_name: String, buttons: Array[MouseButton]) -> void:
	if InputMap.has_action(action_name):
		InputMap.action_erase_events(action_name)
	else:
		InputMap.add_action(action_name)

	for button in buttons:
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action_name, event)
