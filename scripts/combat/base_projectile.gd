class_name BaseProjectile
extends Area2D
## Shared travel/lifetime/collision plumbing for every traveling combat
## projectile in this project — previously duplicated near-verbatim
## across Projectile (Ore Surge's fragments) and SkillProjectile
## (Ignite Dart): movement, lifetime countdown, collision shape setup,
## and the "never hit your own wielder" guard. Size (`radius`), speed,
## lifetime, element/charge, and travel `direction` are all set per
## spawn call or defaulted per child class — nothing here is hardcoded
## to one projectile's numbers.
##
## Subclasses implement two things only:
##   _resolve_hit(hurtbox) — what a valid hit actually does, and
##                            whether this projectile is spent or keeps
##                            flying (Ore Surge pierces multiple
##                            targets per A.2; Ignite Dart resolves once
##                            through the full reaction pipeline and is
##                            done) — a genuine behavioural difference,
##                            deliberately not unified here.
##   _draw()               — its own visual.
##
## No wall/terrain collision — same known, deliberate simplification
## every projectile in this project has always made; nothing here
## reacts to Ground/Platform bodies.

@export var speed: float = 400.0
@export var lifetime: float = 0.8
@export var element: StringName = Elements.NONE
@export var charge: int = 1
@export var radius: float = 5.0  ## Collision shape size — set per spawn call, or defaulted in a child's _init().

var direction: Vector2 = Vector2.RIGHT
var attacker: Node = null  ## Never hits its own wielder — same guard on every projectile type.

var _lifetime_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  ## Hurtbox layer — matches Hitbox's own convention.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return
	var hurtbox := area as Hurtbox
	if hurtbox.owner == attacker:
		return  # Never hit your own wielder.
	_resolve_hit(hurtbox)


## Override point. Base does nothing — a projectile with no override
## simply flies through everything until its lifetime expires.
func _resolve_hit(_hurtbox: Hurtbox) -> void:
	pass
