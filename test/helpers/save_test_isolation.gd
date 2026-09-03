extends RefCounted
## Shared save-path isolation helper for any test file whose code path
## touches SaveManager, directly or indirectly (Player.swap_weapon/
## swap_skill record meta-progression unlocks there — see
## save_manager.gd). Call isolate() from before_each() and restore()
## from after_each()/after_all() so these tests never read or overwrite
## the real user://save_data.json.
##
## Static-only, same convention as Elements.gd — never instantiated,
## just a preload()'d namespace for these two functions.

const TEST_SAVE_PATH := "user://test_save_data_isolated.json"


static func isolate() -> void:
	SaveManager._save_path = TEST_SAVE_PATH
	SaveManager._data = SaveManager._default_data()


static func restore(original_path: String) -> void:
	SaveManager._save_path = original_path
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("test_save_data_isolated.json"):
		dir.remove("test_save_data_isolated.json")
	SaveManager._load_from_disk()
