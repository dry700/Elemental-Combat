extends SceneTree

func _init():
    var tex = GradientTexture2D.new()
    tex.width = 16
    tex.height = 16
    var grad = Gradient.new()
    grad.set_color(0, Color(0.4, 0.4, 0.5))
    tex.gradient = grad
    ResourceSaver.save(tex, "res://scenes/world/chunks/placeholder_tile.tres")
    
    var ts = TileSet.new()
    ts.tile_size = Vector2i(16, 16)
    ts.add_physics_layer(0)
    
    var source = TileSetAtlasSource.new()
    source.texture = tex
    source.texture_region_size = Vector2i(16, 16)
    ts.add_source(source, 1)
    
    source.create_tile(Vector2i(0, 0))
    
    var td = source.get_tile_data(Vector2i(0,0), 0)
    td.add_collision_polygon(0)
    var poly = PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)])
    td.set_collision_polygon_points(0, 0, poly)
    
    ResourceSaver.save(ts, "res://scenes/world/chunks/chunk_tileset.tres")
    print("Tileset collision added successfully!")
    quit()
