extends SceneTree

func _init():
    var root = StaticBody2D.new()
    root.name = "OneWayPlatform"
    root.set_collision_layer_value(1, false)
    root.set_collision_layer_value(3, true)
    
    var script = GDScript.new()
    script.source_code = "class_name OneWayPlatform\nextends StaticBody2D\n\n@export var width_tiles: int = 3:\n\tset(value):\n\t\twidth_tiles = value\n\t\t_update_shape()\n\nfunc _ready() -> void:\n\t_update_shape()\n\nfunc _update_shape() -> void:\n\tvar col = get_node_or_null(\"CollisionShape2D\")\n\tvar vis = get_node_or_null(\"Visual\")\n\tif col == null or vis == null:\n\t\treturn\n\tvar w = width_tiles * 16.0\n\tvar rect = col.shape as RectangleShape2D\n\tif rect != null:\n\t\trect.size = Vector2(w, 8.0)\n\tcol.position = Vector2(w / 2.0, 4.0)\n\tvis.polygon = PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(w,8), Vector2(0,8)])\n"
    ResourceSaver.save(script, "res://scripts/world/one_way_platform.gd")
    
    root.set_script(load("res://scripts/world/one_way_platform.gd"))
    
    var shape = CollisionShape2D.new()
    shape.name = "CollisionShape2D"
    var rect = RectangleShape2D.new()
    rect.size = Vector2(48.0, 8.0)
    shape.shape = rect
    shape.one_way_collision = true
    shape.position = Vector2(24.0, 4.0)
    root.add_child(shape)
    shape.owner = root
    
    var vis = Polygon2D.new()
    vis.name = "Visual"
    vis.color = Color(0.4, 0.6, 0.4, 1.0)
    vis.polygon = PackedVector2Array([Vector2(0,0), Vector2(48,0), Vector2(48,8), Vector2(0,8)])
    root.add_child(vis)
    vis.owner = root
    
    var packed = PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, "res://scenes/world/one_way_platform.tscn")
    print("OneWayPlatform created with proper collision layer 3!")
    quit()
