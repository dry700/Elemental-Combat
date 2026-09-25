extends Control

@onready var primary_button: Button = $MarginContainer/VBoxContainer/PrimaryButton
@onready var abandon_button: Button = $MarginContainer/VBoxContainer/AbandonButton
@onready var abandon_confirm: ConfirmationDialog = $AbandonConfirmDialog
@onready var history_label: Label = $MarginContainer/VBoxContainer/HistoryLabel

func _ready() -> void:
	abandon_confirm.dialog_text = "Abandon your current run? This cannot be undone."
	abandon_confirm.confirmed.connect(_on_abandon_confirmed)
	abandon_button.pressed.connect(func(): abandon_confirm.popup_centered())
	primary_button.pressed.connect(_on_primary_button_pressed)
	
	_refresh_history_summary()
	_refresh_ui()


func _refresh_ui() -> void:
	var has_resume := SaveManager.has_in_progress_run()
	primary_button.text = "Continue" if has_resume else "New Run"
	abandon_button.visible = has_resume  # only exists when there's something to abandon


func _on_primary_button_pressed() -> void:
	if SaveManager.has_in_progress_run():
		get_tree().change_scene_to_file("res://scenes/world/procedural_run.tscn")
	else:
		_start_new_run()


func _start_new_run() -> void:
	if not SaveManager.has_completed_tutorial():
		get_tree().change_scene_to_file("res://scenes/world/tutorial_room.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/loadout_select.tscn")


func _on_abandon_confirmed() -> void:
	SaveManager.clear_in_progress_run()
	_start_new_run()


func _refresh_history_summary() -> void:
	var history := SaveManager.get_run_history()
	if history.is_empty():
		history_label.text = "No runs yet"
		return
		
	var wins := 0
	var best_rooms := 0
	for entry in history:
		if entry.get("outcome") == "win":
			wins += 1
		best_rooms = maxi(best_rooms, int(entry.get("rooms_cleared", 0)))
		
	history_label.text = "Total Runs: %d   ·   Wins: %d   ·   Best: %d rooms" % [history.size(), wins, best_rooms]
