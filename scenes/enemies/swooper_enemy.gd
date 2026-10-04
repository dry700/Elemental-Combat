class_name SwooperEnemy
extends CharacterBody2D
## A fragile, aggressive flying melee enemy. It hovers above the player,
## telegraphs, and then violently dashes (swoops) through the air with a
## melee hitbox, punishing players who don't roll or parry.

@export var max_health: float = 12.0
@export var float_speed: float = 55.0
@export var swoop_speed: float = 350.0
@export var aggro_range: float = 220.0
@export var attack_range: float = 140.0
@export var attack_cooldown: float = 3.0
@export var telegraph_duration: float = 0.4
@export var swoop_duration: float = 0.35
@export var recover_duration: float = 0.7
@export var damage: float = 12.0
@export var knockback_strength: float = 150.0
@export var starting_element: StringName = Elements.NONE
@export var starting_charge: int = 1
@export var qi_reward: float = 5.0
@export var starting_armor: float = 0.0

const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)
const TELEGRAPH_TINT: Color = Color(1.0, 0.9, 0.3)
const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
@onready var health_bar: ProgressBar = $HealthBar

var elemental := ElementalCombatant.new()
var _current_health: float = 0.0
var _is_dead: bool = false
var _cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _base_color: Color
var _is_flashing: bool = false

enum State { HOVER, TELEGRAPH, SWOOP, RECOVER }
var _state: State = State.HOVER
var _swoop_dir: Vector2 = Vector2.ZERO

var _hitbox: Hitbox
const DamagePopup = preload("res://scripts/ui/damage_number.gd")

func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color
	
	elemental.indicator_offset = Vector2(0, -14)
	elemental.armor = starting_armor
	elemental.innate_element = starting_element
	add_child(elemental)
	elemental.cc_resistance.configure(999, 8.0)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(starting_element, starting_charge)
	
	_current_health = max_health
	health_bar.value = 100.0
	add_to_group("enemies")
	
	# Setup native Hitbox for the swoop attack
	_hitbox = Hitbox.new()
	_hitbox.monitoring = false
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2  # Hurtbox layer
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)
	_hitbox.owner = self

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)
		
	if not _is_flashing:
		visual.set_tint(_resting_color())
		
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	
	if elemental.is_disabled():
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var player := get_tree().get_first_node_in_group("player") as Node2D
	
	match _state:
		State.HOVER:
			_process_hover(player, delta)
		State.TELEGRAPH:
			_state_timer -= delta
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_start_swoop(player)
		State.SWOOP:
			_state_timer -= delta
			# Keeps flying in the swoop direction
			velocity = _swoop_dir * swoop_speed * elemental.get_speed_multiplier()
			if _state_timer <= 0.0:
				_end_swoop()
		State.RECOVER:
			_state_timer -= delta
			# Skid to a stop (looks more natural than instantly freezing)
			velocity = velocity.move_toward(Vector2.ZERO, swoop_speed * delta * 3.0)
			if _state_timer <= 0.0:
				_state = State.HOVER
				_cooldown_timer = attack_cooldown
				
	move_and_slide()

func _process_hover(player: Node2D, delta: float) -> void:
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, float_speed * delta * 5.0)
		return
		
	var dist = global_position.distance_to(player.global_position)
	var sight_blocked := SteamCloud.blocks_vision(global_position, player.global_position)
	
	if not sight_blocked and dist <= aggro_range:
		var hover_target = player.global_position + Vector2(0, -90)
		var dist_to_hover = global_position.distance_to(hover_target)
		
		# If close enough and off cooldown, prepare to dive!
		if dist <= attack_range and _cooldown_timer <= 0.0:
			_state = State.TELEGRAPH
			_state_timer = telegraph_duration
			return
			
		# Otherwise, fly towards the hover position
		if dist_to_hover > 10.0:
			var dir = (hover_target - global_position).normalized()
			velocity = dir * float_speed * elemental.get_speed_multiplier()
		else:
			velocity = velocity.move_toward(Vector2.ZERO, float_speed * delta * 5.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, float_speed * delta * 5.0)

func _start_swoop(player: Node2D) -> void:
	_state = State.SWOOP
	_state_timer = swoop_duration
	if is_instance_valid(player):
		_swoop_dir = (player.global_position - global_position).normalized()
	else:
		_swoop_dir = Vector2.DOWN
		
	# Enable the melee hitbox
	_hitbox.damage = damage
	_hitbox.knockback_strength = knockback_strength
	_hitbox.element = starting_element
	_hitbox.charge = starting_charge
	_hitbox.weapon_weight = &"medium"
	_hitbox.enable()

func _end_swoop() -> void:
	_hitbox.disable()
	_state = State.RECOVER
	_state_timer = recover_duration

func _resting_color() -> Color:
	if _state == State.TELEGRAPH:
		return TELEGRAPH_TINT
	if elemental.is_disabled():
		return DISABLED_TINT
	if elemental.is_slowed():
		return SLOWED_TINT
	return _base_color

func _on_hurtbox_hit(hit_data: HitData) -> void:
	_apply_damage(hit_data.damage)
	HitStop.freeze_for_weight(hit_data.weapon_weight)
	ScreenShake.shake_for_weight(hit_data.weapon_weight)
	elemental.handle_hit(hit_data)

func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)

func _apply_damage(amount: float) -> void:
	var mitigated := elemental.mitigate_damage(amount)
	_flash()
	DamagePopup.spawn(self, mitigated, Vector2(0, -10))
	if not _is_dead:
		_current_health -= mitigated
		health_bar.value = (_current_health / max_health) * 100.0
		if _current_health <= 0.0:
			_die()

func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true
	_hitbox.disable()
	visual.set_tint(DEATH_TINT)
	health_bar.visible = false
	QiOrb.spawn_burst(get_parent(), global_position, qi_reward)
	if starting_element != Elements.NONE:
		var rune := RunePickup.new()
		rune.set_rune(RuneRoller.default().roll(RunePickup.roll_spirit_element(starting_element), RuneData.Target.WEAPON))
		rune.global_position = global_position
		get_parent().add_child.call_deferred(rune)
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _flash() -> void:
	_is_flashing = true
	visual.set_tint(Color.WHITE)
	await get_tree().create_timer(0.08).timeout
	_is_flashing = false
	visual.set_tint(_resting_color())
