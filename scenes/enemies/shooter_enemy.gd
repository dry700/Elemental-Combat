class_name ShooterEnemy
extends CharacterBody2D

@export var max_health: float = 25.0
@export var move_speed: float = 50.0
@export var aggro_range: float = 200.0
@export var attack_range: float = 160.0
@export var can_move: bool = true
@export var attack_cooldown_moving: float = 2.5
@export var attack_cooldown_still: float = 1.0
@export var telegraph_duration: float = 0.5
@export var damage: float = 10.0
@export var projectile_speed: float = 200.0
@export var starting_element: StringName = Elements.NONE
@export var starting_charge: int = 1
@export var qi_reward: float = 5.0
@export var starting_armor: float = 5.0

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
var _is_telegraphing: bool = false
var _base_color: Color
var _is_flashing: bool = false
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

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)
		
	if not _is_flashing:
		visual.set_tint(_resting_color())
		
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	
	if elemental.is_disabled() or _is_telegraphing:
		velocity.x = 0.0
		move_and_slide()
		return
		
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var dist = global_position.distance_to(player.global_position)
		var sight_blocked := SteamCloud.blocks_vision(global_position, player.global_position)
		
		if not sight_blocked and dist <= aggro_range:
			if dist <= attack_range:
				velocity.x = 0.0
				if _cooldown_timer <= 0.0:
					_start_attack(player)
			elif can_move:
				var dir = sign(player.global_position.x - global_position.x)
				velocity.x = dir * move_speed * elemental.get_speed_multiplier()
			else:
				velocity.x = 0.0
		else:
			velocity.x = 0.0
	else:
		velocity.x = 0.0
		
	move_and_slide()

func _start_attack(player: Node2D) -> void:
	_is_telegraphing = true
	await get_tree().create_timer(telegraph_duration).timeout
	if _is_dead or elemental.is_disabled():
		_is_telegraphing = false
		return
		
	if is_instance_valid(player):
		var raw_dir = player.global_position - global_position
		var snapped_dir: Vector2
		# Snap to 4-way cardinal direction
		if abs(raw_dir.x) > abs(raw_dir.y):
			snapped_dir = Vector2(sign(raw_dir.x), 0)
		else:
			snapped_dir = Vector2(0, sign(raw_dir.y))
			
		_shoot(snapped_dir)
		
	_is_telegraphing = false
	_cooldown_timer = attack_cooldown_moving if can_move else attack_cooldown_still

func _shoot(dir: Vector2) -> void:
	var proj = ArrowProjectile.new()
	proj.global_position = global_position
	proj.direction = dir
	proj.speed = projectile_speed
	proj.damage = damage
	proj.element = starting_element
	proj.attacker = self
	proj.weapon_weight = &"light"
	proj.charge = 1
	get_tree().current_scene.add_child(proj)

func _resting_color() -> Color:
	if _is_telegraphing:
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
