class_name TestDummy
extends StaticBody2D
## Sprint 2 elemental reaction test target, now doubling as a stationary
## "turret" enemy (A.6) when enemy_stats is assigned. Static (StaticBody2D),
## so it can never chase — combat_ai.can_chase is forced false and it
## simply attacks whenever the player wanders into attack_range.

@export var flash_duration: float = 0.08
@export var starting_element: StringName = Elements.KIM
@export var starting_charge: int = 1
@export var starting_armor: float = 10.0
@export var enemy_stats: EnemyStats  ## A.6 — null keeps this a pure punching bag with zero AI, same as before.

const SLOWED_TINT: Color = Color(0.55, 0.75, 1.0)
const DISABLED_TINT: Color = Color(1.0, 0.55, 0.25)
## Telegraph tints take priority over slow/disabled — a wind-up about to
## land is the most actionable thing on screen right now (A.6's "natural
## tutorial" framing only works if the tell is legible).
const TELEGRAPH_TINT: Color = Color(1.0, 0.9, 0.3)
const SPECIAL_TELEGRAPH_TINT: Color = Color(1.0, 0.5, 0.9)

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_polygon: Polygon2D = $PlaceholderVisual
@onready var visual: SpriteVisual = $SpriteVisual
@onready var damage_label: Label = $DamageLabel

var elemental := ElementalCombatant.new()
var combat_ai: EnemyCombatAI
var _current_health: float = 0.0
var _is_dead: bool = false

var _total_damage_taken: float = 0.0
var _base_color: Color
var _is_flashing: bool = false
var _is_telegraphing: bool = false
var _telegraph_is_special: bool = false


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hurtbox_hit)
	_base_color = visual_polygon.color

	elemental.indicator_offset = Vector2(0, -52)  ## Above the DamageLabel (-36..-16).
	elemental.armor = starting_armor
	elemental.innate_element = starting_element  ## A.6 spirit re-tag — see ElementalCombatant.tick().
	add_child(elemental)
	elemental.bonus_damage_dealt.connect(_on_bonus_damage_dealt)
	elemental.apply_starting_status(starting_element, starting_charge)

	if enemy_stats != null:
		_current_health = enemy_stats.max_health
		add_to_group("enemies")  ## RoomController polls this group to know when a room is cleared.
		combat_ai = EnemyCombatAI.new()
		combat_ai.stats = enemy_stats
		combat_ai.can_chase = false
		add_child(combat_ai)
		combat_ai.telegraph_started.connect(_on_telegraph_started)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	var _dot_damage := elemental.tick(delta)

	if combat_ai != null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			combat_ai.update(delta, player.global_position)

	if not _is_flashing:
		visual.set_tint(_resting_color())


func _resting_color() -> Color:
	if _is_telegraphing:
		return SPECIAL_TELEGRAPH_TINT if _telegraph_is_special else TELEGRAPH_TINT
	if elemental.is_disabled():
		return DISABLED_TINT
	if elemental.is_slowed():
		return SLOWED_TINT
	return _base_color


func _on_hurtbox_hit(hit_data: HitData) -> void:
	_apply_damage(hit_data.damage)
	HitStop.freeze(0.05)
	elemental.handle_hit(hit_data)


## Wildfire's chain (A.7 Link) landed on this dummy.
func _on_bonus_damage_dealt(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	_total_damage_taken += amount
	damage_label.text = str(int(_total_damage_taken))
	_flash()
	if enemy_stats != null and not _is_dead:
		_current_health -= amount
		if _current_health <= 0.0:
			_die()


const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)
const DEATH_FADE_DELAY: float = 0.3

func _die() -> void:
	_is_dead = true
	hurtbox.invulnerable = true  ## Existing flag on Hurtbox — no new mechanism needed.
	visual.set_tint(DEATH_TINT)
	damage_label.text = "X"
	await get_tree().create_timer(DEATH_FADE_DELAY).timeout
	queue_free()


func _flash() -> void:
	_is_flashing = true
	visual.set_tint(Color.WHITE)
	await get_tree().create_timer(flash_duration).timeout
	_is_flashing = false
	visual.set_tint(_resting_color())


## No separate "attack ended" signal exists on EnemyCombatAI — this timer
## is sized to exactly the telegraph + active window it just started,
## same await-timer approach _flash() already uses above.
func _on_telegraph_started(is_special: bool) -> void:
	_is_telegraphing = true
	_telegraph_is_special = is_special
	var total := (combat_ai.stats.special_telegraph_duration if is_special else combat_ai.stats.telegraph_duration) + combat_ai.stats.active_window
	await get_tree().create_timer(total).timeout
	_is_telegraphing = false
