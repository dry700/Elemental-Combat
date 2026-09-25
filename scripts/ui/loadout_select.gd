extends Control

const STARTING_WEAPON_PATHS: Array[String] = [
	"res://scripts/resources/weapons/training_dagger.tres",
	"res://scripts/resources/weapons/training_spear.tres",
	"res://scripts/resources/weapons/training_staff.tres",
	"res://scripts/resources/weapons/training_greatsword.tres",
	"res://scripts/resources/weapons/training_hammer.tres",
]

const STARTING_SKILL_PATHS: Array[String] = [
	"res://scripts/resources/skills/ignite_dart.tres",
	"res://scripts/resources/skills/overgrowth_snare.tres",
	"res://scripts/resources/skills/cleansing_tide.tres",
	"res://scripts/resources/skills/rending_edge.tres",
	"res://scripts/resources/skills/stoneguard.tres",
]

@onready var weapon_1_vbox: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/Weapon1/VBoxContainer
@onready var weapon_2_vbox: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/Weapon2/VBoxContainer
@onready var skill_1_vbox: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/Skill1/VBoxContainer
@onready var skill_2_vbox: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/Skill2/VBoxContainer

@onready var start_button: Button = $MarginContainer/VBoxContainer/BottomRow/StartButton
@onready var error_label: Label = $MarginContainer/VBoxContainer/BottomRow/ErrorLabel

var _weapon_pool: Array[String] = []
var _skill_pool: Array[String] = []

var _selected_weapon_1: String = ""
var _selected_weapon_2: String = ""
var _selected_skill_1: String = ""
var _selected_skill_2: String = ""

func _ready() -> void:
	_build_pools()
	_populate_column(weapon_1_vbox, _weapon_pool, func(path): _selected_weapon_1 = path; _validate())
	_populate_column(weapon_2_vbox, _weapon_pool, func(path): _selected_weapon_2 = path; _validate())
	_populate_column(skill_1_vbox, _skill_pool, func(path): _selected_skill_1 = path; _validate())
	_populate_column(skill_2_vbox, _skill_pool, func(path): _selected_skill_2 = path; _validate())
	
	start_button.pressed.connect(_on_start_pressed)
	_validate()


func _build_pools() -> void:
	_weapon_pool = STARTING_WEAPON_PATHS.duplicate()
	for p in SaveManager.get_unlocked_weapon_paths():
		if not _weapon_pool.has(p):
			_weapon_pool.append(p)
			
	_skill_pool = STARTING_SKILL_PATHS.duplicate()
	for p in SaveManager.get_unlocked_skill_paths():
		if not _skill_pool.has(p):
			_skill_pool.append(p)


func _populate_column(vbox: VBoxContainer, pool: Array[String], on_selected: Callable) -> void:
	for path in pool:
		var btn := Button.new()
		# Load the resource to get its name
		var res_name = path.get_file().get_basename().replace("_", " ").capitalize()
		var res = load(path)
		if res != null:
			if "weapon_name" in res:
				res_name = res.weapon_name
			elif "skill_name" in res:
				res_name = res.skill_name
				
		btn.text = res_name
		btn.toggle_mode = true
		btn.pressed.connect(func():
			# Untoggle other buttons in the same column
			for child in vbox.get_children():
				if child is Button and child != btn:
					child.button_pressed = false
			# If user tries to untoggle, force it back to pressed
			if not btn.button_pressed:
				btn.button_pressed = true
			on_selected.call(path)
		)
		vbox.add_child(btn)


func _validate() -> void:
	var ready_to_start := true
	var error_msg := ""
	
	if _selected_weapon_1 == "" or _selected_weapon_2 == "" or _selected_skill_1 == "" or _selected_skill_2 == "":
		ready_to_start = false
		error_msg = "Please select an option for all 4 slots."
	elif _selected_weapon_1 == _selected_weapon_2:
		ready_to_start = false
		error_msg = "Pick two different weapons."
	elif _selected_skill_1 == _selected_skill_2:
		ready_to_start = false
		error_msg = "Pick two different skills."
		
	start_button.disabled = not ready_to_start
	error_label.text = error_msg


func _on_start_pressed() -> void:
	RunManager.pending_weapon_path = _selected_weapon_1
	RunManager.pending_secondary_weapon_path = _selected_weapon_2
	RunManager.pending_skill_1_path = _selected_skill_1
	RunManager.pending_skill_2_path = _selected_skill_2
	
	get_tree().change_scene_to_file("res://scenes/world/procedural_run.tscn")
