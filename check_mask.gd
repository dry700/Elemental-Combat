extends SceneTree
func _init():
    var player_scene = load("res://scenes/player/player.tscn")
    var player = player_scene.instantiate()
    print("Player mask: ", player.collision_mask)
    quit()
