extends GutHookScript
## Reconfigures the window BEFORE any tests run, so GUT's own result
## panel renders at readable native resolution instead of being forced
## through project.godot's low-res-then-stretch pixel-art pipeline
## (576x324 native, built for 16px sprites — not test output text).
## This only touches the window for THIS gut run; project.godot's
## actual settings, and the real game, are never modified.

func run():
	var root := (Engine.get_main_loop() as SceneTree).root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO  # was the missing piece — without this, the viewport can keep its old 576x324 base even after content_scale_mode changes
	root.size = Vector2i(1000, 700)

	if DisplayServer.get_screen_count() > 1:
		var second_screen := DisplayServer.screen_get_usable_rect(1)
		root.position = second_screen.position
