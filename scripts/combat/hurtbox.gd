class_name Hurtbox
extends Area2D
## Receives hits from a Hitbox and forwards them via signal. Decoupled from
## its owner's exact script — whoever owns this (Player, TestDummy, a
## future enemy) connects to `hit_received` in their own _ready().

signal hit_received(hit_data: HitData)

@export var invulnerable: bool = false


func take_hit(hit_data: HitData) -> void:
	if invulnerable:
		return
	hit_received.emit(hit_data)
