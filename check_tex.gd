extends SceneTree
func _init():
    var tex = load("res://assets/sprites/weapons/hoa_dagger.png")
    print("Dagger size: ", tex.get_size())
    tex = load("res://assets/sprites/weapons/thuy_spear.png")
    print("Spear size: ", tex.get_size())
    quit()
