class_name EnemyCombatAI
extends Node2D
## Basic melee AI (Appendix A.6): aggro, chase-or-hold, telegraph, attack,
## cooldown. Composed the same way ElementalCombatant is — TestDummy
## (StaticBody2D) and PatrolDummy (CharacterBody2D) share no common
## ancestor, so this can't be a base class either.
##
## The owner stays responsible for actual movement — this component only
## decides WHETHER to chase (should_chase()) and drives its own Hitbox
## for the attack itself, same split PatrolDummy already has between its
## own patrol movement and ElementalCombatant's reaction state.
##
## Usage: create with .new(), set `stats` (and `can_chase` if the owner
## can't move) BEFORE add_child() — read once in _ready() to size the
## hitbox — then each physics frame call update(delta, player_pos) and
## read should_chase() to decide whether to move toward the player.

enum State { IDLE, CHASE, TELEGRAPH, ACTIVE, COOLDOWN }

@export var stats: EnemyStats
## False for enemies that can never move (TestDummy) — update() still
## handles aggro/attack/cooldown identically either way; only
## should_chase()'s true branch changes.
@export var can_chase: bool = true

## Fires the instant a telegraph starts — owner uses this for a colour
## flash/tell. is_special distinguishes the Charge-1 vs Charge-2 wind-up.
signal telegraph_started(is_special: bool)

var _state: State = State.IDLE
var _timer: float = 0.0
var _cooldown_timer: float = 0.0
var _attack_count: int = 0
var _current_is_special: bool = false

var _hitbox: Hitbox


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.monitoring = false
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2  ## Hurtbox layer — same convention as the player's own Hitbox.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = (stats.attack_range if stats != null else 26.0) * 0.6
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)
	# owner can only be set once the node is actually IN the tree as a
	# descendant of that owner — must come after add_child() above, not
	# before. Hitbox's self-hit guard compares hurtbox.owner == owner
	# (the Node.owner property, not get_parent()), and hit_data.source is
	# set from this same .owner, so this is what makes the enemy's own
	# Hurtbox correctly excluded AND makes ICD / bystander-exclusion /
	# Vũ's attacker lookup all resolve correctly downstream, since they
	# all key off hit_data.source.get("elemental").
	_hitbox.owner = get_parent()


func should_chase() -> bool:
	return can_chase and _state == State.CHASE


func is_engaged() -> bool:
	return _state != State.IDLE


## Call once per physics frame from the owner, passing the PLAYER's
## global position.
func update(delta: float, player_global_pos: Vector2) -> void:
	if stats == null:
		return

	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	var distance := global_position.distance_to(player_global_pos)

	match _state:
		State.IDLE:
			if distance <= stats.aggro_range:
				_state = State.CHASE
		State.CHASE:
			if distance > stats.aggro_range:
				_state = State.IDLE
			elif distance <= stats.attack_range:
				if _cooldown_timer <= 0.0:
					_start_telegraph()
				else:
					_state = State.COOLDOWN  ## In range, but still cooling down — hold, don't press in.
		State.TELEGRAPH, State.ACTIVE:
			_timer -= delta
			if _state == State.TELEGRAPH and _timer <= 0.0:
				_start_active_window()
			elif _state == State.ACTIVE and _timer <= 0.0:
				_end_attack()
		State.COOLDOWN:
			if distance > stats.aggro_range:
				_state = State.IDLE
			elif _cooldown_timer <= 0.0:
				_state = State.CHASE


func _start_telegraph() -> void:
	_attack_count += 1
	_current_is_special = (_attack_count % stats.special_attack_every) == 0
	_state = State.TELEGRAPH
	_timer = stats.special_telegraph_duration if _current_is_special else stats.telegraph_duration
	telegraph_started.emit(_current_is_special)


func _start_active_window() -> void:
	_state = State.ACTIVE
	_timer = stats.active_window
	_hitbox.damage = stats.damage
	_hitbox.knockback_strength = stats.knockback_strength
	_hitbox.element = stats.element
	_hitbox.charge = 2 if _current_is_special else 1
	_hitbox.enable()


func _end_attack() -> void:
	_hitbox.disable()
	_cooldown_timer = stats.attack_cooldown
	_state = State.COOLDOWN
