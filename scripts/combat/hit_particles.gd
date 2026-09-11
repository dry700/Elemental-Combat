class_name HitParticles
extends GPUParticles2D
## Diamond-shard burst — a companion to HitSpark (the flash) that sprays
## a handful of small diamond shards outward from the hit, biased AWAY
## from the attacker (same direction Hitbox already computes for
## knockback) rather than a symmetric radial burst, so it reads as
## debris kicked off the impact rather than a generic firework.
##
## First GPU-particle VFX in this project — everything else (SlashVFX,
## ThrustVFX, HitSpark) animates a plain Sprite2D via Tween.
## GPUParticles2D's own one-shot emission + `finished` signal does the
## same "spawn, play, clean up" job those Tweens do, just via the
## particle system instead — no Tween needed here.

const LIFETIME: float = 0.35
const TEXTURE_PATH: String = "res://assets/sprites/vfx/diamond_particle.png"

var element: StringName = Elements.NONE
var away_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	texture = load(TEXTURE_PATH) as Texture2D
	amount = 8
	lifetime = LIFETIME
	one_shot = true
	explosiveness = 1.0  ## All 8 fire at once, not trickled over the lifetime.

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(away_direction.x, away_direction.y, 0.0)
	mat.spread = 45.0  ## A cone away from the attacker, not a full 180° radial burst.
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 55.0
	mat.gravity = Vector3.ZERO
	# Wider range than a typical size jitter — this IS the "random length"
	# knob now that the texture itself is an elongated shard rather than
	# a symmetric diamond: a bigger random scale reads as a longer streak,
	# a smaller one as a short stubby fleck, instead of just "bigger blob."
	mat.scale_min = 0.4
	mat.scale_max = 2.0
	mat.damping_min = 30.0
	mat.damping_max = 50.0
	# Rotates each particle's local Y axis (the shard's long axis, by how
	# the texture above is drawn) to match ITS OWN velocity direction —
	# without this, every shard would face the same way regardless of
	# which way it's actually flying, undercutting the "random length
	# streak flying outward" look this is going for.
	mat.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	process_material = mat

	ElementIndicator.apply_element_tint(self, element)

	emitting = true
	finished.connect(queue_free)
