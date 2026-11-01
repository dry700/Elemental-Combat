class_name ArmorBufferEnemy
extends CharacterBody2D
## A killable support enemy that periodically increases an ally's armor.

@export var enemy_stats: EnemyStats
@export var starting_element: StringName = Elements.NONE
@export var starting_armor: float = 0.0

const DEATH_TINT := Color(0.3, 0.3, 0.3)
const SUPPORT_TINT := Color(1.0, 0.82, 0.38)
const DISABLED_TINT := Color(1.0, 0.55, 0.25)
const SLOWED_TINT := Color(0.55, 0.75, 1.0)
const DamagePopup = preload("res://scripts/ui/damage_number.gd")

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
@onready var health_bar: ProgressBar = $HealthBar

var elemental := ElementalCombatant.new()
var support_ai := SupportAI.new()
var _current_health: float = 0.0
var _is_dead: bool = false
var _is_flashing: bool = false
var _is_support_glowing: bool = false
var _base_color: Color
var facing: int = 1


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color
	elemental.indicator_offset = Vector2(0, -14)
	elemental.armor = starting_armor
	elemental.innate_element = starting_element
	add_child(elemental)
	elemental.cc_resistance.configure(enemy_stats.cc_free_hits if enemy_stats != null else 999, enemy_stats.cc_window_seconds if enemy_stats != null else 8.0)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	_current_health = enemy_stats.max_health if enemy_stats != null else 30.0
	health_bar.value = 100.0
	add_to_group("enemies")
	support_ai.stats = enemy_stats
	support_ai.support_type = SupportAI.SupportType.ARMOR_BUFFER
	add_child(support_ai)
	support_ai.ally_armored.connect(_on_ally_armored)
	_update_facing()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	var dot_damage := elemental.tick(delta)
	if dot_damage > 0.0:
		_apply_damage(dot_damage)
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	support_ai.update(delta, player)
	if absf(velocity.x) > 0.1:
		facing = 1 if velocity.x > 0.0 else -1
		_update_facing()
	move_and_slide()
	if not _is_flashing and not _is_support_glowing:
		visual.set_tint(DISABLED_TINT if elemental.is_disabled() else SLOWED_TINT if elemental.is_slowed() else _base_color)


func get_health_ratio() -> float:
	if enemy_stats == null or enemy_stats.max_health <= 0.0:
		return 1.0
	return clampf(_current_health / enemy_stats.max_health, 0.0, 1.0)


func _on_hurtbox_hit(hit_data: HitData) -> void:
	if elemental.try_absorb_hit(hit_data.source):
		var absorbed_weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
		HitStop.freeze_for_weight(absorbed_weight)
		ScreenShake.shake(3.0, 0.12)
		return
	_apply_damage(hit_data.damage, hit_data.perfect)
	var weight: StringName = &"heavy" if hit_data.perfect else hit_data.weapon_weight
	HitStop.freeze_for_weight(weight)
	ScreenShake.shake_for_weight(weight)
	elemental.handle_hit(hit_data)


func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float, is_perfect: bool = false) -> void:
	var mitigated := elemental.mitigate_damage(amount)
	DamagePopup.spawn(self, mitigated, Vector2(0, -10), is_perfect)
	_flash()
	if _is_dead:
		return
	_current_health -= mitigated
	if enemy_stats != null and enemy_stats.max_health > 0.0:
		health_bar.value = 100.0 * _current_health / enemy_stats.max_health
	if _current_health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true
	visual.set_tint(DEATH_TINT)
	health_bar.visible = false
	if enemy_stats != null:
		QiOrb.spawn_burst(get_parent(), global_position, enemy_stats.qi_reward)
	await get_tree().create_timer(0.3).timeout
	queue_free()


func _flash() -> void:
	_is_flashing = true
	visual.set_tint(Color.WHITE)
	await get_tree().create_timer(0.08).timeout
	_is_flashing = false


func _on_ally_armored(_ally: Node2D) -> void:
	_is_support_glowing = true
	visual.set_tint(SUPPORT_TINT)
	await get_tree().create_timer(0.14).timeout
	_is_support_glowing = false
	if is_instance_valid(visual) and not _is_flashing:
		visual.set_tint(DISABLED_TINT if elemental.is_disabled() else SLOWED_TINT if elemental.is_slowed() else _base_color)


func _update_facing() -> void:
	visual.scale.x = absf(visual.scale.x) * facing
	visual_polygon.scale.x = absf(visual_polygon.scale.x) * facing
