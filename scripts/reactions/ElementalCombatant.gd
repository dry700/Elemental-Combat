class_name ElementalCombatant
extends Node2D
## Composed component — NOT a base class. Player is a CharacterBody2D and
## TestDummy is a StaticBody2D (PatrolDummy is CharacterBody2D too, but
## the split already rules out a single shared ancestor), so inheritance
## doesn't reach across all three. This holds everything about an
## entity's elemental reaction state instead: status, DoT/Slow/Disable,
## armor, the A.1 element-pattern indicator, and the A.7 Overgrowth/
## Wildfire Link tag. All ten reactions' unique effects live in
## handle_hit() — previously duplicated nearly verbatim across Player,
## TestDummy, and PatrolDummy; this is the single copy.
##
## Usage: create with .new(), optionally set indicator_offset and armor,
## add_child() it onto the owner, then each physics frame call tick(delta)
## and apply the returned DoT damage to the owner's own health/display,
## and call handle_hit(hit_data) from the owner's hurtbox callback.
##
## Deliberately NOT responsible for: raw hit damage, health, or how it's
## displayed — those differ too much between Player (a health float) and
## the dummies (a damage-taken counter + label + flash) to unify without
## a bigger health-system refactor nobody's asked for. bonus_damage_dealt
## exists specifically to hand Wildfire's chain damage back up to
## whichever health system the owner actually uses.

## Wildfire's chain (A.7 Link) landed on this combatant — owner applies
## the amount to its own health/display however it normally does.
signal bonus_damage_dealt(amount: float)

## Fires the instant DisableEffect actually ends — natural decay, or
## Break-Free reducing it all the way past zero (only possible if a
## reaction's floor is 0; every currently-wired one has floor > 0, so in
## practice this only fires from natural decay right now). Deliberately
## NOT fired just for reaching the floor — reaching the floor means
## Break-Free is done helping, not that the lock is over (A.3's "never
## erase it entirely"). Re-exposes DisableEffect's own `expired` signal
## so the owner reacts the instant it fires rather than depending on
## polling elemental.is_disabled() at the right point in _physics_process.
signal disabled_expired

## Sever shreds this. How armor mitigates incoming damage isn't specified
## anywhere in Appendix A (which only covers the elemental system, not a
## general stat/defense model) — it exists purely so Sever has something
## real to shred, same reasoning as current_health existing purely so
## DotEffect had something real to damage.
@export var armor: float = 10.0

## Local offset for the A.1 element-pattern indicator above this entity.
## Set this right after ElementalCombatant.new(), before add_child() —
## it's read once in _ready().
@export var indicator_offset: Vector2 = Vector2(0, -15)

## DEBUG ONLY — shows remaining duration of each active timed effect
## (Disable/Slow/DoT) above the entity, stacked above the element
## indicator. Purely a debugging aid: doesn't affect any actual game
## logic, and costs nothing when an entity has no effects active (label
## just stays hidden). Flip off once this stops being actively useful —
## nothing else in the class depends on it existing.
@export var show_debug_readout: bool = true

## A.6: elemental spirits carry one element as an innate, self-sustaining
## trait, not just a one-off status pickup. Whenever their status is
## empty (natural decay, OR a player successfully Khắc'd it away), this
## re-tags them after a short delay rather than leaving them permanently
## blank. That delay IS the "vulnerable window" A.6 implies by calling
## Khắc "a natural tutorial for one reaction" — a real, visible beat
## where the reaction just worked, before the creature re-arms itself.
@export var innate_element: StringName = Elements.NONE
@export var innate_charge: int = 1
const INNATE_RECHARGE_DELAY: float = 1.5
var _innate_recharge_timer: float = 0.0

## A.7 Link footprint: not physical geometry, just a group membership
## used as a status tag. Overgrowth adds a combatant to this group;
## Wildfire radius-queries it to chain outward and clear the tag. Fixed
## now that every combatant is the same class — no more owner-side
## duplication of this constant.
const OVERGROWTH_GROUP: StringName = &"overgrowth_linked"
const WILDFIRE_CHAIN_RADIUS: float = 110.0

## Every ElementalCombatant joins this in _ready(), tagged or not — lets
## an AoE effect (currently just Overgrowth) radius-query "every nearby
## combatant" generically. Distinct from OVERGROWTH_GROUP, which only
## holds combatants ALREADY tagged — Overgrowth needs to reach ones that
## aren't tagged yet in order to tag them in the first place.
const ALL_COMBATANTS_GROUP: StringName = &"elemental_combatants"

## AoE range for Overgrowth's root/DoT/tag spread. A.2's own wording is
## "roots ENEMIES in place" (plural) and "tags ROOTED ENEMIES for chain
## propagation" (also plural) — this was previously single-target only,
## which undersold exactly what makes Wildfire's chain worth building at
## all. No radius is given in the proposal; this is a reasonable pick,
## deliberately smaller than WILDFIRE_CHAIN_RADIUS above (Overgrowth
## roots what's immediately around the hit; Wildfire's payoff reaches
## further out through the tagged group afterward).
const OVERGROWTH_RADIUS: float = 75.0

var status := ElementalStatus.new()
var dot_effect := DotEffect.new()
var slow_effect := SlowEffect.new()
var disable_effect := DisableEffect.new()

var _element_indicator: ElementIndicator
var _debug_label: Label


func _ready() -> void:
	add_to_group(ALL_COMBATANTS_GROUP)
	_element_indicator = ElementIndicator.new()
	_element_indicator.position = indicator_offset
	add_child(_element_indicator)
	status.status_applied.connect(func(element: StringName, _charge: int) -> void: _element_indicator.set_element(element))
	status.status_cleared.connect(func(_element: StringName) -> void: _element_indicator.set_element(Elements.NONE))
	disable_effect.expired.connect(func() -> void: disabled_expired.emit())

	if show_debug_readout:
		_debug_label = Label.new()
		_debug_label.custom_minimum_size = Vector2(50, 0)
		_debug_label.position = indicator_offset + Vector2(-25, -15)
		_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_debug_label.add_theme_font_size_override("font_size", 6)
		_debug_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug_label.add_theme_constant_override("outline_size", 3)
		_debug_label.visible = false
		add_child(_debug_label)


## Call once per physics frame from the owner. Ticks status/slow/disable
## and returns any DoT damage due this frame.
func tick(delta: float) -> float:
	status.tick(delta)
	slow_effect.tick(delta)
	disable_effect.tick(delta)
	_tick_icd(delta)
	var dot_damage := dot_effect.tick(delta)
	if show_debug_readout:
		_update_debug_readout()
	if innate_element != Elements.NONE:
		if status.has_status():
			_innate_recharge_timer = INNATE_RECHARGE_DELAY
		else:
			_innate_recharge_timer -= delta
			if _innate_recharge_timer <= 0.0:
				status.apply(innate_element, innate_charge)
	return dot_damage


## DEBUG ONLY — one line per active timed effect, hidden entirely when
## nothing is active. Reads the getters added to each effect component
## specifically to support this (DisableEffect already had one for
## Break-Free's own debug print; Slow/DoT didn't need one until now).
func _update_debug_readout() -> void:
	var lines: Array[String] = []
	if disable_effect.is_active():
		lines.append("Disable: %.1fs" % disable_effect.get_remaining_duration())
	if slow_effect.active:
		lines.append("Slow: %.1fs" % slow_effect.get_remaining_duration())
	if dot_effect.active:
		lines.append("DoT: %.1fs" % dot_effect.get_remaining_duration())
	_debug_label.text = "\n".join(lines)
	_debug_label.visible = not lines.is_empty()


func is_disabled() -> bool:
	return disable_effect.is_active()


func is_slowed() -> bool:
	return slow_effect.active


func get_speed_multiplier() -> float:
	return slow_effect.get_speed_multiplier()


## For an owner's starting/default status (e.g. TestDummy's Kim start).
func apply_starting_status(element: StringName, charge: int) -> void:
	if element != Elements.NONE:
		status.apply(element, charge)


## The "universal graze/stagger" that both KHAC_PARTIAL and KHAC_VU use
## (A.3) — deliberately generic and reaction-agnostic. A.3 is explicit
## that Vũ is "no new effect to design, only a redirected target," so
## this is the ONE graze implementation both outcomes call into, not two
## separate ones. Floor equals duration: there's no Thừa-style second
## tier a graze could ever be extended from, so Break-Free has nothing
## to claw back here — consistent with how a non-Thừa stagger elsewhere
## in this file already sits at its own floor.
const GRAZE_DURATION: float = 0.25


func apply_graze() -> void:
	disable_effect.apply(GRAZE_DURATION, GRAZE_DURATION)


## Resolves an attacker Node to its ElementalCombatant for splash-exclusion
## purposes only. Returns null — meaning "nothing to exclude" — both when
## there's no attacker at all, AND when the attacker IS this very
## combatant (a genuine self-inflicted application, e.g. a future
## self-cast skill routed through this same handle_hit() pipeline, should
## still react against its own caster normally, never be treated as a
## bystander to exclude). Only an attacker that is some OTHER combatant,
## incidentally caught in splash from a hit that landed on someone else,
## gets excluded. Used by both Overgrowth's AoE and Wildfire's chain.
func _bystander_attacker(attacker: Node) -> ElementalCombatant:
	if attacker == null:
		return null
	var attacker_elemental := attacker.get("elemental") as ElementalCombatant
	if attacker_elemental == self:
		return null
	return attacker_elemental


## Internal Cooldown on Element Application (ICD, A.3). Keyed on
## (attacker, element) only — "target" is implicit, since this table
## lives on the target's own ElementalCombatant, so per-target tracking
## (A.3: "per-target, not global") falls out for free: each target only
## ever sees hits landing on itself, independent of every other target.
## A different element from the same attacker is a different key
## entirely and is never blocked by this — that's what keeps legitimate
## Sinh combos (two different elements landing close together) working;
## keying on attacker+target alone would block the combo the whole
## system is built around, not just the spam it's meant to stop.
##
## Duration sits between a Light weapon's attack cycle (the dagger:
## 0.25s) and a Heavy weapon's (greatsword/hammer: 0.45s+): long enough
## that a fast Light weapon spamming the SAME element WILL clip its own
## cooldown swing-to-swing — matching A.3's "light weapons trade potency
## for hit frequency, not reaction frequency" — but short enough that a
## Heavy weapon's naturally slower rhythm is never gated by this at all.
const ICD_DURATION: float = 0.4

var _icd_windows: Dictionary = {}  ## "<attacker instance id>:<element>" -> remaining seconds


func _tick_icd(delta: float) -> void:
	var expired: Array = []
	for key in _icd_windows:
		_icd_windows[key] -= delta
		if _icd_windows[key] <= 0.0:
			expired.append(key)
	for key in expired:
		_icd_windows.erase(key)


func _icd_key(attacker: Node, element: StringName) -> String:
	return "%d:%s" % [attacker.get_instance_id(), element]


## Runs the full reaction resolution for an incoming hit. Call from the
## owner's hurtbox-hit callback, after the owner has already applied raw
## hit_data.damage and knockback itself (this method is elemental-only —
## ICD below gates everything in here, never the damage the owner already
## dealt before calling this).
func handle_hit(hit_data: HitData, bypass_icd: bool = false) -> void:
	if hit_data.element == Elements.NONE:
		return

	if not bypass_icd and hit_data.source != null:
		var icd_key := _icd_key(hit_data.source, hit_data.element)
		if _icd_windows.has(icd_key):
			print("ICD: ", hit_data.element, " from ", hit_data.source.name, " blocked — still on cooldown")
			return
		_icd_windows[icd_key] = ICD_DURATION

	var result := Reactions.resolve(hit_data.element, hit_data.charge, status)
	match result.outcome:
		Reactions.Outcome.NO_REACTION:
			status.apply(hit_data.element, hit_data.charge)
		Reactions.Outcome.SINH_TIER_1, Reactions.Outcome.SINH_TIER_2:
			print("Sinh: ", result.reaction_pair, " -> ", Reactions.Outcome.keys()[result.outcome])
			var sinh_tier2 := result.outcome == Reactions.Outcome.SINH_TIER_2
			# Every branch below applies the GENERATED element — fixed by
			# the Ngũ Hành cycle direction (e.g. Thủy sinh Mộc always
			# leaves Mộc behind) — rather than hit_data.element, whichever
			# element happened to be incoming. A Kim weapon triggering
			# Condensation against a Thủy-carrying target should leave
			# Thủy behind, not Kim, since Thủy is literally what that
			# generation produces; is_sinh_pair matches the pair in
			# either direction, but the generation itself is one-way.
			var generated := Elements.sinh_generated_element(result.reaction_pair)
			if Elements.pair_is(result.reaction_pair, Elements.KIM, Elements.THUY):
				# Condensation: slows the target, and the Water status this
				# hit just applied sticks around longer than the default
				# 5s decay (A.2). Tier 2 scales both numbers, same effect
				# only — Sinh only ever has two tiers, no Thừa/Vũ equivalent.
				status.apply(generated, hit_data.charge, ElementalStatus.DECAY_SECONDS * (1.6 if sinh_tier2 else 1.3))
				slow_effect.apply(0.5 if sinh_tier2 else 0.7, 3.5 if sinh_tier2 else 2.5)
			elif Elements.pair_is(result.reaction_pair, Elements.THUY, Elements.MOC):
				# Overgrowth: roots ENEMIES (plural, A.2's own wording) in
				# place around wherever this triggered, with a DoT for as
				# long as each stays rooted, and tags each one for
				# Wildfire to chain into later (A.7 Link) — an AoE spread,
				# not just the single directly-hit target. Every affected
				# combatant, including the direct target, now also picks
				# up the generated Mộc status itself — the whole area
				# should read as "now carrying Wood," not just "rooted."
				# The attacker is excluded from the AoE as a bystander —
				# UNLESS the attacker is this very combatant (a genuine
				# self-inflicted case), which is never excluded.
				var base_root := 1.6
				var root_duration := 2.5 if sinh_tier2 else base_root
				var root_dot_dps := 2.5 if sinh_tier2 else 1.5
				_apply_overgrowth_aoe(root_duration, base_root, root_dot_dps, generated, hit_data.charge, hit_data.source)
			elif Elements.pair_is(result.reaction_pair, Elements.MOC, Elements.HOA):
				# Wildfire: applies its own (generated Hỏa) status, plus a
				# DoT — A.2's table text only says "bonus damage" without
				# specifying a DoT, but this is a Hỏa reaction and every
				# other Hỏa effect here (Molten, Overgrowth's rooted DoT)
				# burns over time rather than hitting once. Then chains
				# outward to any Overgrowth-linked (Mộc-carrying)
				# combatants within radius (A.7 Link) — each one
				# effectively catches fire the same way the direct target
				# did, not just takes a lump of damage. Attacker excluded
				# from the chain as a bystander, same caveat as Overgrowth.
				status.apply(generated, hit_data.charge)
				dot_effect.apply(3.5 if sinh_tier2 else 2.5, 1.0, 4.5 if sinh_tier2 else 3.5)
				_propagate_wildfire(sinh_tier2, generated, hit_data.charge, hit_data.source)
			elif Elements.pair_is(result.reaction_pair, Elements.HOA, Elements.THO):
				# Cinder Bloom: "AoE burn; scorched terrain spreads Earth
				# status to enemies who stand on it" (A.2) — two distinct
				# parts. The AoE burn is an immediate DoT to everyone
				# currently nearby (bystander attacker excluded, same
				# caveat as Overgrowth/Wildfire). The scorched terrain is
				# a genuine A.7 Zone: it persists after this hit and can
				# still affect combatants that walk into it much later,
				# which a one-shot radius check can't represent.
				status.apply(generated, hit_data.charge)
				_apply_cinder_bloom_burn(sinh_tier2, hit_data.source)
				spawn_zone(generated)
			elif Elements.pair_is(result.reaction_pair, Elements.THO, Elements.KIM):
				# Ore Surge: "Armor-shredding projectiles pierce multiple
				# enemies, spreading Metal status to each hit" (A.2) — a
				# genuine traveling, piercing hit, not a radius check;
				# "pierce multiple enemies" describes something that
				# flies and can hit several different targets along its
				# path, which is exactly what Projectile does and Hitbox
				# (one swing, one resolved hit) doesn't. A.7 separately
				# classifies Ore Surge's FOOTPRINT as Zone (Metal) too —
				# the scattered debris left behind, distinct from the
				# fragments themselves.
				status.apply(generated, hit_data.charge)
				_spawn_ore_surge_fragments(generated, hit_data.charge, hit_data.source)
				spawn_zone(generated)
		Reactions.Outcome.KHAC_FULL_CLEAR, Reactions.Outcome.KHAC_THUA:
			print("Khắc: ", result.reaction_pair, " -> ", Reactions.Outcome.keys()[result.outcome])
			status.clear()
			var thua := result.outcome == Reactions.Outcome.KHAC_THUA
			if Elements.pair_is(result.reaction_pair, Elements.HOA, Elements.KIM):
				# Molten: removes metal armor (status.clear() above) + DoT.
				if thua:
					dot_effect.apply(5.0, 1.0, 6.0)
				else:
					dot_effect.apply(3.0, 1.0, 4.0)
			elif Elements.pair_is(result.reaction_pair, Elements.THO, Elements.THUY):
				# Silt: slows movement. Telegraph-obscure deferred (A.7 —
				# no telegraph system exists yet).
				slow_effect.apply(0.4 if thua else 0.6, 5.0 if thua else 3.5)
			elif Elements.pair_is(result.reaction_pair, Elements.MOC, Elements.THO):
				# Root Break: removes earth shield (status.clear() above),
				# then staggers — floor always the base duration, since
				# Break-Free (A.3) can only claw an overwhelmed lock back
				# to baseline, never past it. A.7: Burst footprint — an
				# instant radius pulse, not just the single directly-hit
				# target (previously single-target only; no longer
				# deferred now that rooms spawn multiple enemies).
				var base_stagger := 0.6
				var thua_stagger := 1.1
				_apply_root_break_burst(thua_stagger if thua else base_stagger, base_stagger, hit_data.source)
			elif Elements.pair_is(result.reaction_pair, Elements.KIM, Elements.MOC):
				# Sever: strips Wood status (status.clear() above), then
				# shreds armor. A.7: Burst footprint — same AoE upgrade
				# as Root Break above.
				var shred_amount := 6.0 if thua else 3.0
				_apply_sever_burst(shred_amount, hit_data.source)
			elif Elements.pair_is(result.reaction_pair, Elements.THUY, Elements.HOA):
				# Douse: removes burn (status.clear() above), then emits
				# a steam cloud (A.2). The stun is AoE now, not just the
				# direct target — same bystander-exclusion pattern as
				# every other AoE here — and its DisableEffect duration
				# (0.3s base) IS the "stuns for the first 0.3s it exists"
				# window; the cloud keeps existing, purely visually, for
				# the rest of its 5s lifetime after that. Thừa scales per
				# A.2's own table: "Larger cloud radius, longer stun."
				_spawn_steam_cloud(thua, hit_data.source)
		Reactions.Outcome.KHAC_PARTIAL:
			print("Khắc partial: ", result.reaction_pair)
			status.charge = maxi(status.charge - hit_data.charge, 0)
			if status.charge <= 0:
				status.clear()
			apply_graze()
		Reactions.Outcome.KHAC_VU:
			print("Vũ! Reversed — attacker takes the graze instead.")
			# Target's status is deliberately untouched — no status.apply()
			# or .clear() here, per A.3 ("the target's status is
			# untouched, and the attacker instead takes the ... graze").
			# hit_data.source is the attacking Node (Player/TestDummy/
			# PatrolDummy) — reach its ElementalCombatant via duck-typed
			# get(), since those three share no common base class. Safe:
			# get() returns null (not an error) if the property doesn't
			# exist, and `as ElementalCombatant` on a mismatched type
			# also yields null rather than crashing.
			if hit_data.source != null:
				var attacker_elemental := hit_data.source.get("elemental") as ElementalCombatant
				if attacker_elemental != null:
					attacker_elemental.apply_graze()


## Overgrowth's AoE spread (A.2: "roots enemies in place" / "tags rooted
## enemies", both plural). Radius-queries every combatant in the scene
## (ALL_COMBATANTS_GROUP, not just already-tagged ones — that's the whole
## point, this is what DOES the tagging) and roots/DoTs/tags/applies the
## generated element to anything within range, including self: distance
## from self to self is 0, so the directly-hit combatant is naturally
## included without a separate special case. The attacker is excluded as
## a bystander — see _bystander_attacker for why a genuine self-inflicted
## case is never excluded even though it looks the same at first glance.
func _apply_overgrowth_aoe(root_duration: float, base_root: float, dot_dps: float, generated_element: StringName, charge: int, attacker: Node) -> void:
	var bystander := _bystander_attacker(attacker)
	for node in get_tree().get_nodes_in_group(ALL_COMBATANTS_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == bystander:
			continue
		if global_position.distance_to(other.global_position) <= OVERGROWTH_RADIUS:
			other.disable_effect.apply(root_duration, base_root)
			other.dot_effect.apply(dot_dps, 0.5, root_duration)
			other.add_to_group(OVERGROWTH_GROUP)
			other.status.apply(generated_element, charge)


## A.7 Link: radius-queries the Overgrowth tag group from wherever this
## combatant's Wildfire just triggered, chains bonus damage into anything
## nearby still carrying the tag. Every combatant is the same class now,
## so this is a typed call, not has_method() duck typing. Each chained
## target gets the instant burst (bonus_damage_dealt, A.2's "bonus
## damage"), a DoT (fire chaining through Overgrowth-linked enemies
## should keep burning them, not just tick once and move on), and now
## the generated Hỏa status itself — status.apply() naturally overwrites
## whatever Mộc status Overgrowth left, which is the correct outcome
## here: the target's Wood catches fire and becomes Fire, it doesn't go
## blank. Attacker excluded as a bystander, same caveat as Overgrowth's
## AoE (_bystander_attacker never excludes a genuine self-inflicted case).
func _propagate_wildfire(tier2: bool, generated_element: StringName, charge: int, attacker: Node) -> void:
	var bystander := _bystander_attacker(attacker)
	var bonus_damage := 12.0 if tier2 else 8.0
	for node in get_tree().get_nodes_in_group(OVERGROWTH_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == self or other == bystander:
			continue
		if global_position.distance_to(other.global_position) <= WILDFIRE_CHAIN_RADIUS:
			other.remove_from_group(OVERGROWTH_GROUP)
			other.status.apply(generated_element, charge)
			other.bonus_damage_dealt.emit(bonus_damage)
			other.dot_effect.apply(3.5 if tier2 else 2.5, 1.0, 4.5 if tier2 else 3.5)


## Cinder Bloom's immediate half — an AoE burn to everyone currently
## nearby the hit, same bystander-exclusion pattern as Overgrowth's AoE
## and Wildfire's chain. The OTHER half, the lingering scorched terrain,
## is _spawn_zone() below — this only covers "AoE burn," not "scorched
## terrain spreads Earth status" (A.2).
const CINDER_BLOOM_BURN_RADIUS: float = 65.0

func _apply_cinder_bloom_burn(tier2: bool, attacker: Node) -> void:
	var bystander := _bystander_attacker(attacker)
	var burn_dps := 4.0 if tier2 else 2.5
	for node in get_tree().get_nodes_in_group(ALL_COMBATANTS_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == bystander:
			continue
		if global_position.distance_to(other.global_position) <= CINDER_BLOOM_BURN_RADIUS:
			other.dot_effect.apply(burn_dps, 1.0, 3.0)

## A.7 Burst: "an instant radius pulse with no duration or spawned
## object lifetime to manage" — Sever's armor shred and Root Break's
## stagger both use this footprint (A.7's own table). Deliberately
## smaller than Overgrowth/Cinder Bloom's own AoE radii — a "pulse"
## should read as tighter and more immediate than a lingering AoE, and
## Khắc reactions are meant to read as disruption, not a big area clear.
const BURST_RADIUS: float = 50.0


## Sever's Burst: shreds armor on everyone caught in the pulse, not just
## the single directly-hit target — the Wood-status STRIP itself stays
## single-target (only the reacting entity had that status to strip;
## status.clear() above already handled that), but the armor-shred half
## of the effect radiates outward, same bystander-exclusion pattern as
## every other AoE in this file. Distance-to-self is 0, so the direct
## target is naturally included without a separate special case.
func _apply_sever_burst(shred_amount: float, attacker: Node) -> void:
	var bystander := _bystander_attacker(attacker)
	for node in get_tree().get_nodes_in_group(ALL_COMBATANTS_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == bystander:
			continue
		if global_position.distance_to(other.global_position) <= BURST_RADIUS:
			other.armor = maxf(other.armor - shred_amount, 0.0)


## Root Break's Burst — same shape as Sever's above, staggering instead
## of shredding. The earth-shield status REMOVAL stays single-target
## (status.clear() above); the stagger radiates.
func _apply_root_break_burst(stagger_duration: float, base_stagger: float, attacker: Node) -> void:
	var bystander := _bystander_attacker(attacker)
	for node in get_tree().get_nodes_in_group(ALL_COMBATANTS_GROUP):
		var other := node as ElementalCombatant
		if other == null or other == bystander:
			continue
		if global_position.distance_to(other.global_position) <= BURST_RADIUS:
			other.disable_effect.apply(stagger_duration, base_stagger)

## Spawns an A.7 Zone at this combatant's current position — the
## "scorched terrain" (Cinder Bloom) / scattered debris (Ore Surge's own
## footprint classification, separate from its projectile burst) both
## reactions leave behind. Per A.7's own definition: Charge fixed at 1
## (never scaled by the triggering hit), decaying after ~6-10s (8s used
## here, the middle of that range) — this reads the definition literally
## rather than reusing the triggering hit's own charge/duration numbers.
func spawn_zone(element: StringName, radius: float = -1.0, lifetime: float = -1.0) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var zone := ReactionZone.new()
	zone.global_position = global_position
	zone.element = element
	if radius > 0.0:
		zone.radius = radius
	if lifetime > 0.0:
		zone.lifetime = lifetime
	scene_root.add_child(zone)


## Ore Surge's piercing burst — fragments radiate outward in an even
## spread (not a single directional shot) since A.2 describes "fragments"
## piercing "multiple enemies", which reads as shrapnel bursting outward
## rather than one aimed projectile. Each fragment can independently
## pierce several different combatants along its own path (Projectile
## handles the piercing itself, not this loop).
const ORE_SURGE_FRAGMENT_COUNT: int = 6
const ORE_SURGE_FRAGMENT_SPEED: float = 200.0
const ORE_SURGE_FRAGMENT_LIFETIME: float = 0.8
const ORE_SURGE_SHRED_PER_FRAGMENT: float = 2.0

func _spawn_ore_surge_fragments(element: StringName, charge: int, attacker: Node) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for i in range(ORE_SURGE_FRAGMENT_COUNT):
		var angle := (TAU / ORE_SURGE_FRAGMENT_COUNT) * i
		var fragment := Projectile.new()
		fragment.global_position = global_position
		fragment.direction = Vector2.RIGHT.rotated(angle)
		fragment.speed = ORE_SURGE_FRAGMENT_SPEED
		fragment.lifetime = ORE_SURGE_FRAGMENT_LIFETIME
		fragment.element = element
		fragment.charge = charge
		fragment.shred_amount = ORE_SURGE_SHRED_PER_FRAGMENT
		fragment.attacker = attacker
		scene_root.add_child(fragment)


## Douse's steam cloud spawn. Radius/stun both scale on Thừa per A.2's
## own table row for Douse ("Larger cloud radius, longer stun") — 0.3s
## base stun matches "the first 0.3s it exists" exactly; Thừa's longer
## version and the larger radius are my own reasonable scaling, since
## A.2 only says "larger"/"longer" without giving numbers.
const STEAM_CLOUD_LIFETIME: float = 5.0
const STEAM_CLOUD_BASE_RADIUS: float = 45.0
const STEAM_CLOUD_THUA_RADIUS: float = 65.0
const STEAM_CLOUD_BASE_STUN: float = 0.3
const STEAM_CLOUD_THUA_STUN: float = 0.5

func _spawn_steam_cloud(thua: bool, attacker: Node) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var cloud := SteamCloud.new()
	cloud.global_position = global_position
	cloud.lifetime = STEAM_CLOUD_LIFETIME
	cloud.radius = STEAM_CLOUD_THUA_RADIUS if thua else STEAM_CLOUD_BASE_RADIUS
	cloud.stun_duration = STEAM_CLOUD_THUA_STUN if thua else STEAM_CLOUD_BASE_STUN
	cloud.excluded_combatant = _bystander_attacker(attacker)
	scene_root.add_child(cloud)


## DEBUG ONLY — mirrors what used to be Player's own debug key handler
## exactly, just relocated here so owners don't need direct access to
## slow_effect/disable_effect/dot_effect anymore.
func debug_apply_test_effects() -> void:
	slow_effect.apply(0.5, 3.0)
	disable_effect.apply(1.5, 0.5)
	dot_effect.apply(5.0, 0.5, 3.0)


## A.3 Break-Free: each genuine (non-echo) press removes this much
## remaining lock duration, regardless of pacing — the whole point is
## that spacing presses out across the lock reduces it exactly as much
## as a rapid burst would (WCAG 2.2.1, see player.gd's input handler for
## why this is event-based rather than a polled just-pressed check).
## The floor itself already lives in DisableEffect (set per-reaction at
## apply time), so this never needs to know which reaction caused the
## lock — matches A.3's "one rule, no per-reaction special-casing."
const BREAK_FREE_REDUCTION: float = 0.4


## Input detection deliberately does NOT live here: every ElementalCombatant
## in the scene shares this class, and if this method were called from a
## global key listener on the component itself, one Space press would
## reduce every disabled combatant's lock at once — player and staggered
## enemies alike. The owner (Player) detects its own input and calls this;
## non-player combatants simply never call it.
func break_free_press() -> void:
	disable_effect.reduce_duration(BREAK_FREE_REDUCTION)
	
	## --- A.5 Skill effects ---
## Player-facing entry points, called from player.gd's Q/E handling.
## Kept here rather than on Player because every one touches state that
## already lives on this component — and A.5 frames skills as shared
## between player and elemental enemies/bosses, so a future enemy
## skill-caster reuses these exact methods instead of duplicating them.

## Stoneguard: applies straight to THIS combatant's own status, bypassing
## Reactions.resolve() — building a status on yourself, not reacting to
## an incoming hit. This is what makes the A.3 Wu-bait case possible:
## self-apply at Charge 3, then a later weak enemy hit resolves as Vũ
## (reversed) against this pre-set status via the normal handle_hit path.
func cast_apply_self(element: StringName, charge: int) -> void:
	status.apply(element, charge)


## Cleansing Tide. A.3 draws a hard line between cleanse (answers the
## elemental status itself) and Break-Free (answers the lock/disable
## component) — "two tools for two different problems" — so this only
## ever touches `status`, never slow/disable/dot, same as every Khắc
## handler above already leaves those alone unless it explicitly applies
## its own. Clearing first means the follow-up apply can't itself trigger
## a reaction — nothing left to react against.
func cast_cleanse_and_apply_self(element: StringName, charge: int) -> void:
	status.clear()
	status.apply(element, charge)


## Ignite Dart, cast on an enemy: routed through the SAME handle_hit()
## pipeline a weapon swing uses, via a synthetic zero-damage HitData —
## A.5 only says "no weapon hit needed" to deliver it, not that it skips
## reaction resolution. This is the cross-source "weapon + skill" combo
## A.4 calls out as the reward for coordinating tools. ICD bypassed per
## A.3 ("skills... self-limit via their own cooldowns"). get_parent() is
## the owning Node, matching how Hitbox sets HitData.source to its owner.
func cast_apply_enemy(target: ElementalCombatant, element: StringName, charge: int) -> void:
	var hit_data := HitData.new(0.0, Vector2.ZERO, get_parent())
	hit_data.element = element
	hit_data.charge = charge
	target.handle_hit(hit_data, true)


## Ignite Dart's actual cast path (A.5) as of its projectile conversion —
## spawns a traveling SkillProjectile aimed in `direction` instead of
## resolving instantly via cast_apply_enemy above. cast_apply_enemy
## itself is unchanged and still the generic "apply straight through the
## full reaction pipeline onto an already-known target" primitive — it's
## also still exactly what SkillProjectile calls (via handle_hit()) the
## moment it actually connects. This method only changes WHEN and
## WHETHER that resolution happens, not how. `direction` is resolved by
## the caller (Player — see _try_cast_skill) since no aim/targeting
## system exists anywhere else in this project, same reasoning
## SkillData.cast_range's own doc comment already gives.
const IGNITE_DART_SPEED: float = 260.0
const IGNITE_DART_LIFETIME: float = 0.6

func cast_apply_projectile(element: StringName, charge: int, direction: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var dart := SkillProjectile.new()
	dart.global_position = global_position
	dart.direction = direction
	dart.speed = IGNITE_DART_SPEED
	dart.lifetime = IGNITE_DART_LIFETIME
	dart.element = element
	dart.charge = charge
	dart.attacker = get_parent()
	scene_root.add_child(dart)


## Rending Edge: strips the target's status outright — "bypasses Charge,
## no damage" (A.5), same cleanse-exemption family as Cleansing Tide,
## aimed instead of self-cast. Only touches status, same reasoning above.
func cast_remove_enemy(target: ElementalCombatant) -> void:
	target.status.clear()


## Overgrowth Snare: spawns an A.7 Zone centred on the caster — no
## separately-aimed location, since nothing else in this project aims
## (Hitbox is melee-proximity, Ore Surge radiates in a fixed spread).
func cast_apply_area(element: StringName, radius: float, lifetime: float) -> void:
	spawn_zone(element, radius, lifetime)
