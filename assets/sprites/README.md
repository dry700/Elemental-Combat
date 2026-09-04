# Sprite Assets (Appendix A.1)

16×16 pixel art, one file per entity, loaded by `SpriteVisual`
(`scripts/visuals/sprite_visual.gd`) via a fixed naming convention:

	res://assets/sprites/<entity_id>.png

`entity_id` is set per-scene on that entity's `SpriteVisual` node —
"player", "test_dummy", "patrol_dummy", "boss".

A missing file is not an error: `SpriteVisual` silently keeps that
entity's existing flat-colour `Polygon2D` placeholder until real art
lands for it, so this folder can fill in one sprite at a time (R05,
Section 9.3) without anything breaking in between.

Export at 16×16, no padding — `SpriteVisual` upscales with a fixed
factor (`PIXEL_SCALE`) and nearest-neighbour filtering, not per-sprite
manual scaling.
