extends GutTest

## Maid's Sweep (plan-shop-and-skills §7): an energy-gated skill whose meter
## fills from player-triggered reactions involving its element (Thổ), and a
## refresh-only timed buff that forces Thổ swings with bigger reach/hitbox
## and a damage multiplier. Mirrors test_maid_guard.gd's structure.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MAID_SWEEP_PATH := "res://scripts/resources/skills/maid_sweep.tres"
const DAGGER_PATH := "res://scripts/resources/weapons/training_dagger.tres"
const CombatantOwner := preload("res://test/helpers/combatant_owner.gd")

var player: Player


func before_each() -> void:
	player = load(PLAYER_SCENE_PATH).instantiate() as Player
	player.position = Vector2.ZERO
	player.elemental.show_debug_readout = false
	add_child_autofree(player)
	player.set_physics_process(false)


func _add_enemy(position: Vector2) -> CombatantOwner:
	var enemy := CombatantOwner.new()
	enemy.position = position
	enemy.add_to_group("enemies")
	add_child_autofree(enemy)
	enemy.elemental = ElementalCombatant.new()
	enemy.elemental.show_debug_readout = false
	enemy.add_child(enemy.elemental)
	return enemy


func test_maid_sweep_resource_loads_with_energy_fields() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	assert_not_null(skill)
	assert_true(skill.uses_energy)
	assert_almost_eq(skill.energy_max, 100.0, 0.01)
	assert_eq(skill.element, Elements.THO)
	assert_eq(skill.function, SkillData.Function.APPLY_SWEEP_BUFF)
	assert_almost_eq(skill.buff_duration, 15.0, 0.01)
	assert_almost_eq(skill.sweep_damage_mult, 1.4, 0.01)
	assert_almost_eq(skill.sweep_reach_mult, 1.5, 0.01)


func test_skill_resource_dispatches_maid_sweep_and_resets_energy() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill
	player._skill_energy[skill] = skill.energy_max  ## fill to full
	Input.action_release("skill_1")
	Input.action_press("skill_1")

	player._try_cast_skill(skill, "skill_1")

	Input.action_release("skill_1")
	assert_true(player.elemental.sweep_buff.active)
	assert_almost_eq(player.elemental.sweep_buff.get_remaining_duration(), 15.0, 0.01)
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 0.0, 0.01, "cast resets the meter")
	assert_false(player._skill_cooldowns.has(skill), "energy skills set no cooldown")


func test_cast_blocked_until_meter_full() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill
	player._skill_energy[skill] = 50.0  ## half full
	Input.action_release("skill_1")
	Input.action_press("skill_1")

	player._try_cast_skill(skill, "skill_1")

	Input.action_release("skill_1")
	assert_false(player.elemental.sweep_buff.active, "should not cast below full energy")
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 50.0, 0.01, "meter untouched on blocked cast")


func test_energy_fills_from_matching_tho_reaction() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill

	player.on_reaction_caused(Reactions.Outcome.SINH_TIER_1, [Elements.HOA, Elements.THO])

	assert_almost_eq(player._skill_energy.get(skill, 0.0), 10.0, 0.01)


func test_energy_does_not_fill_from_non_matching_element() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill

	# Condensation (Kim+Thủy) involves no Thổ, so Maid's Sweep must not fill.
	player.on_reaction_caused(Reactions.Outcome.SINH_TIER_1, [Elements.KIM, Elements.THUY])

	assert_almost_eq(player._skill_energy.get(skill, 0.0), 0.0, 0.01)


func test_energy_excludes_reversed_outcomes() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill

	# Silt reversed (Thổ overcomes Thủy, incoming 1 vs remaining 3 = Vũ) — the
	# pair contains Thổ, but Vũ must NOT fill the meter (plan §7.1).
	player.on_reaction_caused(Reactions.Outcome.KHAC_VU, [Elements.THO, Elements.THUY])

	assert_almost_eq(player._skill_energy.get(skill, 0.0), 0.0, 0.01)


func test_reaction_energy_amounts_by_outcome() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill

	player.on_reaction_caused(Reactions.Outcome.KHAC_PARTIAL, [Elements.MOC, Elements.THO])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 5.0, 0.01)

	player._skill_energy[skill] = 0.0
	player.on_reaction_caused(Reactions.Outcome.SINH_TIER_1, [Elements.HOA, Elements.THO])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 10.0, 0.01)

	player._skill_energy[skill] = 0.0
	player.on_reaction_caused(Reactions.Outcome.KHAC_FULL_CLEAR, [Elements.MOC, Elements.THO])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 10.0, 0.01)

	player._skill_energy[skill] = 0.0
	player.on_reaction_caused(Reactions.Outcome.SINH_TIER_2, [Elements.HOA, Elements.THO])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 20.0, 0.01)

	player._skill_energy[skill] = 0.0
	player.on_reaction_caused(Reactions.Outcome.KHAC_THUA, [Elements.THO, Elements.THUY])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 20.0, 0.01)

	# Caps at energy_max.
	player._skill_energy[skill] = 95.0
	player.on_reaction_caused(Reactions.Outcome.SINH_TIER_2, [Elements.HOA, Elements.THO])
	assert_almost_eq(player._skill_energy.get(skill, 0.0), 100.0, 0.01)


func test_buff_expires_after_duration() -> void:
	player.elemental.cast_sweep_buff(15.0, 1.4, 1.5)
	assert_true(player.elemental.sweep_buff.active)

	player.elemental.tick(14.9)
	assert_true(player.elemental.sweep_buff.active, "still active just before expiry")

	player.elemental.tick(0.1)
	assert_false(player.elemental.sweep_buff.active)


func test_refresh_extends_buff_without_stacking() -> void:
	player.elemental.cast_sweep_buff(15.0, 1.4, 1.5)
	player.elemental.sweep_buff.tick(5.0)
	player.elemental.cast_sweep_buff(15.0, 1.4, 1.5)

	assert_almost_eq(player.elemental.sweep_buff.get_remaining_duration(), 15.0, 0.01)
	assert_true(player.elemental.sweep_buff.active)


func test_swing_element_is_tho_and_scales_while_buff_active() -> void:
	var dagger := load(DAGGER_PATH) as WeaponStats
	player.weapon = dagger
	player._start_attack(player.weapon)  ## configures hitbox without sweep
	var base_damage := player.hitbox.damage
	var base_reach := player.hitbox.weapon_reach
	assert_ne(player.hitbox.element, Elements.THO, "baseline weapon is not Thổ")

	player.elemental.cast_sweep_buff(15.0, 1.4, 1.5)
	player._start_attack(player.weapon)  ## re-configures with the buff active

	assert_eq(player.hitbox.element, Elements.THO, "sweep forces Thổ swings")
	assert_gt(player.hitbox.damage, base_damage, "sweep multiplies damage")
	assert_gt(player.hitbox.weapon_reach, base_reach, "sweep multiplies reach")


func test_charge_unchanged_while_buff_active() -> void:
	# §7.2 — the buff never raises reaction Charge (base weapon Charge stays).
	var dagger := load(DAGGER_PATH) as WeaponStats
	player.weapon = dagger
	player._start_attack(player.weapon)
	var base_charge := player.hitbox.charge

	player.elemental.cast_sweep_buff(15.0, 1.4, 1.5)
	player._start_attack(player.weapon)

	assert_eq(player.hitbox.charge, base_charge, "base weapon Charge is untouched by the sweep")


func test_player_caused_reaction_fills_meter_via_handle_hit() -> void:
	# Full pipeline: the player attacks an enemy, a Thổ-involving Khắc reaction
	# (Root Break: Mộc overcomes Thổ) fires, and the source hook reaches the
	# player's meter.
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill
	var target := _add_enemy(Vector2(40.0, 0.0))
	target.elemental.status.apply(Elements.THO, 1)

	var hit := HitData.new(0.0, Vector2.ZERO, player)
	hit.element = Elements.MOC
	hit.charge = 2
	target.elemental.handle_hit(hit)

	assert_almost_eq(player._skill_energy.get(skill, 0.0), 10.0, 0.01, "KHAC_FULL_CLEAR fills 10")


func test_enemy_caused_reaction_does_not_fill_player_meter() -> void:
	# Structural exclusion: only the attacker's own on_reaction_caused is
	# called. An enemy attacking another enemy triggers a reaction, but the
	# player (not the source) never has its meter touched.
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill
	var target := _add_enemy(Vector2(40.0, 0.0))
	var attacker_enemy := _add_enemy(Vector2(0.0, 0.0))
	target.elemental.status.apply(Elements.THO, 1)

	var hit := HitData.new(0.0, Vector2.ZERO, attacker_enemy)
	hit.element = Elements.MOC
	hit.charge = 2
	target.elemental.handle_hit(hit)

	assert_almost_eq(player._skill_energy.get(skill, 0.0), 0.0, 0.01, "enemy-caused reactions never reach the player meter")


func test_energy_meter_survives_save_and_resume() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	player.skill_1 = skill
	player._skill_energy[skill] = 60.0

	var saved := player.to_save_state()
	assert_true(saved.has("skill_energy"))
	assert_almost_eq(float(saved.skill_energy[skill.resource_path]), 60.0, 0.01)

	# Fresh player restores from the snapshot.
	var resumed := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(resumed)
	resumed.set_physics_process(false)
	resumed.apply_save_state(saved)

	assert_eq(resumed.skill_1.resource_path, skill.resource_path)
	assert_almost_eq(resumed._skill_energy.get(resumed.skill_1, 0.0), 60.0, 0.01, "meter restores keyed by the reloaded instance")


func test_legacy_snapshot_without_energy_key_starts_empty() -> void:
	var skill := load(MAID_SWEEP_PATH) as SkillData
	var legacy := {
		"current_health": 100, "max_health": 100, "armor": 10.0,
		"weapon_path": "", "secondary_weapon_path": "",
		"skill_1_path": MAID_SWEEP_PATH, "skill_2_path": "",
	}
	var resumed := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(resumed)
	resumed.set_physics_process(false)

	resumed.apply_save_state(legacy)

	assert_eq(resumed.skill_1.resource_path, MAID_SWEEP_PATH)
	assert_almost_eq(resumed._skill_energy.get(resumed.skill_1, 0.0), 0.0, 0.01, "missing energy key starts at 0")
