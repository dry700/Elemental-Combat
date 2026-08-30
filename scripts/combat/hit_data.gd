class_name HitData
extends RefCounted
## Carries information about a single hit from a Hitbox to a Hurtbox.
##
## The weapon_weight/element/charge fields are placeholders for the
## Sprint 2 elemental reaction system (Appendix A.2/A.3) — deliberately
## unused in Sprint 1. Defining the full shape now means Hitbox/Hurtbox
## don't need to change later, only the resolver logic that reads these
## fields does.

var damage: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var source: Node = null

## Sprint 2+ fields — not read by anything yet.
var weapon_weight: StringName = &"none"  # "light", "medium", "heavy"
var element: StringName = &"none"        # "hoa", "thuy", "moc", "kim", "tho"
var charge: int = 0


func _init(p_damage: float = 0.0, p_knockback: Vector2 = Vector2.ZERO, p_source: Node = null) -> void:
	damage = p_damage
	knockback = p_knockback
	source = p_source
