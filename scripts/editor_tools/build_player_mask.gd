extends SceneTree

func _init():
    var scene = load("res://scenes/player/player.tscn")
    var root = scene.instantiate()
    root.collision_mask = 5
    var packed = PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, "res://scenes/player/player.tscn")
    print("Player mask updated to 5")
    quit()
