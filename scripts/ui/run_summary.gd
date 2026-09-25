extends Control

@onready var outcome_label: Label = $MarginContainer/VBoxContainer/OutcomeLabel
@onready var rooms_label: Label = $MarginContainer/VBoxContainer/RoomsLabel
@onready var duration_label: Label = $MarginContainer/VBoxContainer/DurationLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	var won := RunManager.last_run_outcome == "win"
	outcome_label.text = "Run Complete!" if won else "You Died"
	outcome_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.45) if won else Color(0.85, 0.3, 0.3))
	
	rooms_label.text = "Rooms Cleared: %d" % RunManager.last_run_rooms_cleared
	duration_label.text = "Time: %s" % _format_duration(RunManager.last_run_duration_sec)
	continue_button.pressed.connect(_on_continue_pressed)

func _format_duration(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

func _on_continue_pressed() -> void:
	if RunManager.last_run_outcome == "win":
		# start_next_loop()
		if RunManager.has_method("start_next_loop"):
			RunManager.start_next_loop()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
