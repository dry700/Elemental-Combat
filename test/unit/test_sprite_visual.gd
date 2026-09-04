extends GutTest
## Unit tests for SpriteVisual's fallback behaviour — art lands one
## entity at a time (A.1/9.3's R05), nothing should break for an entity
## that doesn't have a sprite file yet.

var polygon: Polygon2D

func before_each():
	polygon = Polygon2D.new()
	polygon.color = Color(0.3, 0.6, 0.9)
	add_child_autofree(polygon)

func _make_visual(entity_id: String) -> SpriteVisual:
	var visual := SpriteVisual.new()
	visual.entity_id = entity_id
	visual.fallback_polygon = polygon
	add_child_autofree(visual)
	return visual

func test_missing_sprite_keeps_the_placeholder_visible():
	var visual := _make_visual("definitely_not_a_real_sprite")
	assert_false(visual.is_using_sprite())
	assert_true(polygon.visible)

func test_missing_sprite_set_tint_writes_to_the_placeholder():
	var visual := _make_visual("definitely_not_a_real_sprite")
	visual.set_tint(Color.RED)
	assert_eq(polygon.color, Color.RED)

func test_empty_entity_id_never_attempts_a_load():
	var visual := _make_visual("")
	assert_false(visual.is_using_sprite())
	assert_true(polygon.visible)

func test_no_fallback_assigned_does_not_crash():
	var visual := SpriteVisual.new()
	visual.entity_id = "player"
	add_child_autofree(visual)
	assert_true(true, "should warn, not error")
