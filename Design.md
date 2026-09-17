# Design.md — Architecture Reference

Living document. Source of truth for **how the system actually works**,
correcting/merging with `COMP1682_Project_Proposal (1).docx` Appendix A
where implementation diverged from spec. When code and Appendix A
disagree, **this file wins** — Appendix A is the original design intent,
this is the as-built, corrected contract. Update this file in the same
commit/PR that changes the architecture it describes; a stale Design.md
is worse than none. Section 10 is deliberately for the report — no
changes needed there for the Final Report beyond good writing.

---

## 1. Architectural Principles

- **Composition over inheritance.** `Player` (CharacterBody2D), `TestDummy`
  (StaticBody2D), `PatrolDummy`/`Boss` (CharacterBody2D) share no common
  ancestor. Everything reaction-related lives in one composed component,
  `ElementalCombatant`, added as a child via `.new()`. Everything
  combat-AI-related lives in `EnemyCombatAI`, same pattern. Never add a
  base class to unify these three — add another composed component instead.
- **Autoloads are script-only singletons**, registered in `project.godot`:
  `InputSetup`, `HitStop`, `VisionBlocker`, `SaveManager`, `RunManager`,
  `Hud`. None have a scene — built in `_ready()`/`_init()` in code.
- **No tilemap, no world-state system, anywhere.** Rooms are whole
  hand-authored `.tscn` templates (PCG "room-placement" category, not
  BSP/cellular-automata). Terrain effects (Zone/Burst) are spawned trigger
  objects, not level mutations. Don't introduce a tile-grid for anything.
- **Refresh-only, never stacking.** `ElementalStatus`, `DotEffect`,
  `SlowEffect`, `DisableEffect` — every timed effect component follows
  this: a new `apply()` fully replaces the old one, it never adds on top.
  Reaction Charge is never additive either (A.3).
- **AoE bystander exclusion.** Every AoE reaction effect
  (`_apply_overgrowth_aoe`, `_propagate_wildfire`, `_apply_cinder_bloom_burn`,
  `_apply_sever_burst`, `_apply_root_break_burst`) excludes the attacker's
  *own* `ElementalCombatant` via `_bystander_attacker()`, but never
  excludes a genuine self-inflicted case (attacker == self). Follow this
  pattern for any new AoE reaction.
	Two deliberate exceptions, where the attacker is the *intended* target
  of a redirected effect rather than a bystander to protect from it:
  `KHAC_VU`'s reversed graze (A.3), and Wildfire's Overload explosion
  (§4.8.7). Don't "fix" either by adding bystander exclusion — that
  would silently defang the mechanic.
- **No real physics-based AoE.** Every "nearby combatants" check is a
  plain `distance_to()` against `ElementalCombatant.ALL_COMBATANTS_GROUP`
  — not a second Area2D/collision layer. Stay consistent with this rather
  than adding new collision layers per effect.
- **Duck-typing at the attacker/owner boundary.** `hit_data.source.get("elemental")`,
  `hurtbox.owner.get("elemental")` — works because `Player`/`TestDummy`/
  `PatrolDummy`/`Boss` each declare a plain `elemental` property, not
  because of a shared interface. `test/helpers/combatant_owner.gd` exists
  purely to fake this shape in unit tests.

---

## 2. System Map

| System | Key files | Owns |
|---|---|---|
| Movement/combat core | `scenes/player/player.gd`, `scripts/combat/{hitbox,hurtbox,hit_data}.gd`, `autoloads/hit_stop.gd` | Player state machine, melee resolution, hit-stop |
| Weapon system | `scripts/resources/weapons/weapon_stats.gd` + `.tres` assets | Combo/lunge/reach, rune fork, per-swing Charge |
| Elemental core | `scripts/reactions/{elements,elemental_status,reaction_resolver}.gd` | Vocabulary, one status per combatant, Sinh/Khắc decision logic (category only) |
| Elemental effects | `scripts/reactions/ElementalCombatant.gd` | All 10 named reactions' unique effects, ICD, Break-Free hook, skill cast entry points |
| Timed-effect components | `scripts/reactions/{dot_effect,slow_effect,disable_effect}.gd` | DoT, slow, stagger/stun/root — reused by every reaction |
| Terrain footprint | `scripts/reactions/reaction_zone.gd`, `scripts/reactions/steam_cloud.gd`, `autoloads/vision_blocker.gd` | A.7 Zone, Douse's cloud, player screen-darkening |
| Projectiles | `scripts/combat/base_projectile.gd` + `fragment_projectile.gd` (Ore Surge) + `skill_projectile.gd` (Ignite Dart) | Travel/lifetime/collision, per-type hit resolution |
| Skills | `scripts/resources/skills/skill_data.gd` + `.tres` assets | A.5 function dispatch, called from `player.gd._try_cast_skill` |
| Enemy AI | `scenes/enemies/enemy_combat_ai.gd`, `scenes/enemies/enemy_stats.gd` | Aggro/telegraph/attack/cooldown state machine, shared by all enemy types |
| Enemy bodies | `scenes/enemies/{test_dummy,patrol_dummy,boss}.gd` | Health/death/flash, wires `ElementalCombatant` + `EnemyCombatAI` together |
| Boss | `scripts/resources/enemies/boss_stats.gd`, `scenes/enemies/boss.gd` | Phase-based two-element fight |
| Rooms/run | `scripts/world/{room_controller,enemy_spawn_point,room_exit}.gd`, `autoloads/run_manager.gd` | Room lifecycle, run sequencing, autosave hook |
| Save data | `autoloads/save_manager.gd` | Meta-progression, run history, mid-run resume — local JSON |
| HUD | `autoloads/hud.gd` | HP/boss bar, equip slots, pickup selection overlay — entirely code-built, no `.tscn` |
| Pickups | `scripts/items/{weapon_pickup,skill_pickup}.gd` | Proximity tracking only; all input now lives on `Hud` |
| Visuals | `scripts/visuals/sprite_visual.gd`, `scripts/ui/element_indicator.gd`, `scripts/combat/{slash_vfx,hit_spark}.gd` | Sprite/placeholder swap, A.1 pattern glyphs, one-shot VFX |
| Input | `autoloads/input_setup.gd` | All input actions defined in code, not Project Settings |
| Upgrade system | `autoloads/upgrade_manager.gd` (planned) | Qi economy, per-run numeric/behavioral buffs — **not yet implemented**, see §4.8 |
---

## 3. Core Combat Loop

`Player` is a single `enum State` machine: `IDLE, RUN, JUMP, FALL, DODGE,
ATTACK, DISABLED`. `Hud.is_overlay_active()` freezes all voluntary input
(movement/jump/dodge/attack/skills) but leaves gravity and
`elemental.tick()` running, so opening the pickup menu doesn't fully pause
the game.

**Attack pipeline:** `_try_start_attack` → `_start_attack` (fresh swing or
combo chain, decided by `_combo_window_timer` + weapon's `combo_length`) →
`_process_attack` drives the hitbox active window from
`WeaponStats.active_window` → `_configure_hitbox_for_current_swing` calls
`weapon.resolve_swing()` for this swing's element/Charge, sets hitbox
reach/radius/damage (scaled by `_combo_damage_multiplier()`) → `Hitbox`
overlaps a `Hurtbox` → builds `HitData` → `Hurtbox.take_hit()` →
`hit_received` signal → owner's `_on_hurtbox_hit` applies raw
damage/knockback + `HitStop.freeze(0.05)` + `elemental.handle_hit(hit_data)`.

Every enemy body (`TestDummy`/`PatrolDummy`/`Boss`) repeats this exact
`_on_hurtbox_hit` shape. `EnemyCombatAI` drives its own internal `Hitbox`
the same way, through its own `TELEGRAPH → ACTIVE → COOLDOWN` states.

### 3.1 Armor Mitigation

`ElementalCombatant.mitigate_damage(raw_damage: float) -> float`:

	effective_armor := armor + armor_buff.get_bonus_armor()
	return raw_damage * (100.0 / (100.0 + effective_armor))

Diminishing-returns curve — 10 armor ≈ 9% reduction, 100 armor ≈ 50%,
armor never fully negates a hit. Applies **uniformly** to every damage
source that reaches `_apply_damage()` — weapon hits, DoT ticks, and
`bonus_damage_dealt` (Wildfire chain, Rusted Chunk) all pass through the
same mitigation, no exceptions carved out for DoT bypassing armor. This
is a deliberate simplicity call, not a balance-tested one — revisit if
playtesting says DoT should ignore armor thematically.

**Call site — every owner's `_apply_damage()` needs this one-line change**
(four files, no shared base class to patch once):

```gdscript
# player.gd, test_dummy.gd, patrol_dummy.gd, boss.gd — same edit shape in each
func _apply_damage(amount: float) -> void:
	var mitigated := elemental.mitigate_damage(amount)
	# ...existing health/counter logic, but reduce by `mitigated`, not `amount`
```

`_total_damage_taken` (the on-screen counter on the three enemy types)
should also display `mitigated`, not `amount` — otherwise the number
shown contradicts the health actually lost.

**Test fallout — must be fixed alongside this, not after:**

`test_player_death.gd` and `test_boss_phase_transition.gd` call
`_apply_damage(player.max_health)` / `_apply_damage(boss_stats.max_health * 0.6)`
expecting *exact* thresholds (`current_health <= 0.0`, phase-transition
ratio). With default armor (10), `max_health` raw damage mitigates down
to ~90.9% of `max_health` — **the lethal-damage test would silently stop
being lethal.** Fix: both files' `before_each()` should set
`player.elemental.armor = 0` / the boss's starting armor to 0 before
those specific assertions — they're testing death/phase-transition
*logic*, not mitigation math, so neutralizing armor there is the correct
isolation, not a workaround.
---

## 4. Elemental Reaction System

### 4.1 Data flow (the one diagram to know)

```
Hitbox/Projectile/Skill
		│  builds HitData{element, charge, source}
		▼
ElementalCombatant.handle_hit(hit_data)
		│  1. ICD check (attacker, element) — may block here
		│  2. Reactions.resolve(element, charge, self.status)  ── pure decision, no side effects
		▼
   Outcome enum ──────────────────────────────┐
   NO_REACTION → status.apply()               │
   SINH_TIER_1/2 → per-pair effect branch      │  all effect branches live in
   KHAC_FULL_CLEAR/THUA → status.clear() +     │  ElementalCombatant.handle_hit()'s
						  per-pair effect       │  match statement — Reactions.gd
   KHAC_PARTIAL → charge -= incoming + graze   │  never touches DotEffect/SlowEffect/
   KHAC_VU → attacker takes the graze instead  │  DisableEffect/armor/groups directly
```

`Reactions.resolve()` is deliberately pure — it only names the outcome
*category* and the unordered pair. It has zero knowledge of the 10 named
reactions' actual effects; that split is intentional (unit-testable logic
vs. integration-tested effects). **Never add DoT/slow/disable calls to
`reaction_resolver.gd`.**

### 4.2 Charge — canonical rules (corrects/confirms A.3)

| Source | Charge | Notes |
|---|---|---|
| Light/Medium weapon hit | 1 | +1 with a same-element rune (→2, ceiling for this weight) |
| Heavy weapon hit | 2 | +1 with a same-element rune (→3, the only way to reach 3) |
| Active skill | 2 | +1 if an equipped weapon carries a same-element rune matching the skill's element (→3) |
| Zone tick | 1, fixed | never scaled, refresh-only |
| Basic enemy attack | 1 | `EnemyCombatAI._start_active_window` |
| Special/telegraphed enemy attack | 2 | every `special_attack_every`-th attack, fixed rhythm not random |

Khắc 3×3 grid (confirmed by `test_reaction_resolver.gd`, all 9 cells):

| incoming ↓ / remaining → | 1 | 2 | 3 |
|---|---|---|---|
| **1** | Full clear | Partial | **Vũ** (reversed onto attacker) |
| **2** | Full clear | Full clear | Partial |
| **3** | **Thừa** (overwhelm) | Full clear | Full clear |

### 4.3 ICD (Internal Cooldown)

Keyed on **(attacker instance id, element)** only, tracked per-target
(each `ElementalCombatant` owns its own `_icd_windows` dict, so
per-target-ness falls out for free — no explicit target key needed).
Duration `0.4s`. Gates reaction *resolution* only, never raw damage.
Skills and Zone ticks bypass it entirely (`handle_hit(hit_data, true)`).

### 4.4 The 10 reactions — implementation index

| Reaction | Pair | Handler branch in `ElementalCombatant.handle_hit` | AoE helper | Footprint |
|---|---|---|---|---|
| Condensation | Kim+Thủy (Sinh) | inline | — | — |
| Overgrowth | Thủy+Mộc (Sinh) | inline | `_apply_overgrowth_aoe` (radius 75) | Link (group tag) |
| Wildfire | Mộc+Hỏa (Sinh) | inline | `_propagate_wildfire` (radius 110) | Link consumed + Zone(Earth) |
| Cinder Bloom | Hỏa+Thổ (Sinh) | inline | `_apply_cinder_bloom_burn` (radius 65) | Zone(Earth) via `spawn_zone` |
| Ore Surge | Thổ+Kim (Sinh) | inline | `_spawn_ore_surge_fragments` (6-way piercing `Projectile`) | Zone(Metal) via `spawn_zone` |
| Molten | Hỏa+Kim (Khắc) | inline | — | — |
| Silt | Thổ+Thủy (Khắc) | inline | — | — |
| Root Break | Mộc+Thổ (Khắc) | `_apply_root_break_burst` (radius 50) | — | Burst |
| Sever | Kim+Mộc (Khắc) | `_apply_sever_burst` (radius 50) | — | Burst |
| Douse | Thủy+Hỏa (Khắc) | `_spawn_steam_cloud` | — | **`SteamCloud`, not `ReactionZone`** — see §10 |

### 4.5 Break-Free

`DisableEffect` unifies root/stagger/stun/lock. Floor set once at
`apply()` time (per-reaction, never past baseline). Reduction is
event-based (`player.gd._unhandled_input`, `event.is_action_pressed("jump",
false)` — the `false` disables OS key-repeat echo) so a press count, not
press speed, matters (WCAG 2.2.1). `BREAK_FREE_REDUCTION = 0.4s` per
genuine press, lives on `ElementalCombatant.break_free_press()`.

### 4.6 Skills

`SkillData.Function` enum dispatches in `player.gd._try_cast_skill`:
`APPLY_SELF` / `REMOVE_APPLY_SELF` (bypass Charge entirely) /
`APPLY_SINGLE_TARGET` (now a real `SkillProjectile`, not instant hitscan —
routes through the *same* `handle_hit()` pipeline on first contact) /
`REMOVE_ENEMY` (bypass Charge) / `APPLY_AREA` (spawns a Zone at caster).
All five entry points live on `ElementalCombatant` (`cast_*` methods), not
`Player`, so a future enemy skill-caster reuses them unchanged.

### 4.7 Projectiles

`BaseProjectile` owns travel/lifetime/collision/"never hit own wielder."
Two subclasses, genuinely different hit behaviour:
- `Projectile` (Ore Surge fragments) — pierces multiple targets, bypasses
  `handle_hit()`'s full resolution entirely (applies shred+status directly).
- `SkillProjectile` (Ignite Dart) — single-hit, calls the real
  `handle_hit()`, ICD-bypassed.

### 4.8 Stage Upgrade System (Qi Economy) — PLANNED, not yet implemented

Per-run-only power growth, paid for with an in-run currency ("Qi"),
spent at will rather than forced on room clear. Resets completely on
death or new run — never touches `SaveManager`, never persists.

**Constraints (read before implementing — these protect the tested
reaction logic):**

- **Never mutate raw Charge directly.** Charge (1–3) is load-bearing
  input to `Reactions.resolve()` — the 3×3 Khắc grid and Thừa/Wu
  thresholds are tuned against exact int values
  (`test_reaction_resolver.gd` asserts all 9 cells). A "+1 Charge"
  upgrade must compute into the charge value the *same way the rune
  bonus already does* — before `Reactions.resolve()` is called, as a
  plain capped int — never as a bypass inside the resolver itself.
- **Numeric ("Tier 1") upgrades apply at the effect-application layer**
  — multiply the final damage/DoT/slow/stagger numbers already computed
  in `ElementalCombatant.handle_hit()`'s match branches. Never touch
  `reaction_resolver.gd`.
- **Behavioral ("Tier 2") upgrades are read as flags/multipliers by the
  caller**, not baked into the resolver — e.g. "Sinh always resolves
  Tier 2" = clamp the effective charge fed *into* `resolve()` to ≥2,
  not a new branch inside it.

#### 4.8.1 Currency — earning Qi

`EnemyStats` gains `qi_reward: float`, read from the existing `_die()`
path on every enemy body (no new pickup/physics needed):

| Enemy tier | `qi_reward` (starting value, tune in Sprint 3) |
|---|---|
| Normal (`neutral_brawler_stats`) | 6 |
| Elemental spirit (`kim_spirit_stats`, etc.) | 12 |
| Boss (`ember_tide_boss_stats`) | 50 |

A typical 3-room + boss run (~2–4 enemies/room) nets roughly **90–130 Qi**
total. Deliberately sized so a player can max **one** category or spread
thin across two or three — not everything in one run. That scarcity is
the actual design goal, not a balance accident.

#### 4.8.2 Categories

Three categories now, not four — the old "Aftermath" (flat Khắc
magnitude boost) is superseded by Khắc Specialization below, which does
the same job with more build identity. **A** and **D→C (Vitality)** are
unchanged from the earlier draft.

**A. Weapon Might** — unchanged, see previous draft.

**B. Reaction Mastery** — replaces "Charge Flow." Never touches Charge
values at all (this is what resolves 4.8.4's original tension — see
below). Instead, each of the 10 named reactions is independently
purchasable, **re-pickable across different reactions**, choice locked
in per-reaction once made. No cap on how many different reactions a
player specializes into — budget is the only limiter.

**Sinh Branching** (5 reactions) — Rank 1 forces this specific reaction
to always resolve at Tier 2 magnitude, regardless of actual Charge.
Rank 2 lets the player permanently pick ONE of the pair's two elements
to favor, adding a themed bonus on top of Tier 2 — not just bigger
numbers (a deliberate, flagged exception to A.3's "Tier 2 is same
effect, larger magnitude only" rule — see the template note below).

| Reaction | Pair | Generated | Favor generated element (lean into signature effect) | Favor the other element (themed cross-effect) |
|---|---|---|---|---|
| Condensation | Kim+Thủy | Thủy | **Tidal Wave** — instant AoE burst at the reaction point: 10 damage + slow (×0.5 for 3.5s, Condensation's own Tier 2 numbers) to every combatant within 65px radius, bystander-excluded per the standard AoE pattern (§4.4). Reuses `bonus_damage_dealt` — no new signal. | **Rusted Chunk** — see §4.8.5, new object type |
| Overgrowth | Thủy+Mộc | Mộc | **The Vine** — one shared Vine per trigger. Mộc hits (only Mộc counts) build toward explosion; a Thủy hit blooms it instead. See §4.8.6. | **Watering** — same Vine, alternate fate. See §4.8.6. |
| Wildfire | Mộc+Hỏa | Hỏa | **Overload** — see §4.8.7. | **Remnant → Spiked Ground** — see §4.8.8. |
| Cinder Bloom | Hỏa+Thổ | Thổ | **Cinderstorm** — see §4.8.9. | **Boulder** — see §4.8.9. |
| Ore Surge | Thổ+Kim | Kim | **Armor Sunder** — see §4.8.10. | **Caltrops** — see §4.8.10. |

*Template rule (for Sprint 2's stretch categories and any future
reaction): the "generated-element" branch always amplifies the
reaction's existing numbers — safe, consistent with A.3. The "other-
element" branch always borrows that element's established thematic
domain elsewhere in the system (Thổ→Zone/terrain, Kim→armor/shred,
Thủy→slow, Mộc→AoE reach, Hỏa→DoT/damage) — keeps branches principled
instead of ad hoc.*

**Khắc Specialization** (5 reactions) — Rank 1 "erases the graze": this
specific reaction's `KHAC_PARTIAL` outcome is upgraded to resolve as
`KHAC_FULL_CLEAR` instead (A.3's guaranteed-counterplay graze no longer
applies to *this* reaction — the player traded reliability for power on
a pair they've specialized into). Rank 2 forces every clear of this
reaction to apply at Thừa (overwhelm) magnitude, even on a 1v1/2v1/2v2
that would normally be base-magnitude.

| Reaction | Pair | Base effect that gets forced to overwhelm-tier |
|---|---|---|
| Molten | Hỏa+Kim | DoT always 5.0/tick (Thừa's number), never the base 3.0 |
| Silt | Thổ+Thủy | Slow always ×0.4, never base ×0.6 |
| Root Break | Mộc+Thổ | Stagger always 1.1s, never base 0.6s |
| Sever | Kim+Mộc | Armor shred always 6.0, never base 3.0 |
| Douse | Thủy+Hỏa | Cloud always Thừa radius/stun (65px / 0.5s), never base (45px / 0.3s) |

**Costs** (placeholder, tune in Sprint 3, same status as every other
number in this section):

| Rank | Cost | Cumulative for one fully-specialized reaction |
|---|---|---|
| Rank 1 (force Tier 2 / erase graze) | 20 Qi | 20 |
| Rank 2 (branch / force overwhelm) | 45 Qi | 65 |

Against the ~90–130 Qi/run estimate (§4.8.1), that's roughly **two
fully-mastered reactions per run**, or Rank-1-only breadth across four.
Matches the same scarcity goal Weapon Might/Vitality were built around.

**C. Vitality** — unchanged from the earlier draft (was Category D).

#### 4.8.3 Getter API (revised)


Removed: `get_charge_bonus`, `get_khac_magnitude_multiplier`,
`has_lingering` — all superseded by the pair-keyed getters above.

**Read sites, precisely (so this never leaks into `reaction_resolver.gd`):**

- `sinh_tier2_forced`/`sinh_favored_element`: read inside each of the 5
  Sinh match branches in `ElementalCombatant.handle_hit()`, exactly
  where `sinh_tier2` is already computed —
  `var sinh_tier2 := result.outcome == Reactions.Outcome.SINH_TIER_2 or UpgradeManager.sinh_tier2_forced(result.reaction_pair)`.
  Favored-element bonus is an additional `if` inside that same branch,
  after the existing tier2-scaled effect.
- `khac_graze_erased`: a **pre-dispatch rewrite**, done once, right
  after `Reactions.resolve()` returns and before the `match` statement:
	
  `Reactions.gd` itself never sees this — it still returns `KHAC_PARTIAL`
  honestly; only the caller's dispatch is rewritten.
- `khac_overwhelm_forced`: read exactly where `thua` is already computed
  in the shared `KHAC_FULL_CLEAR, KHAC_THUA` match arm —
  `var thua := result.outcome == Reactions.Outcome.KHAC_THUA or UpgradeManager.khac_overwhelm_forced(result.reaction_pair)`.
  Never touches `KHAC_VU`'s separate arm — Vũ's reversal logic is
  untouched by this system entirely.

#### 4.8.4 Open design tension — RESOLVED

No longer manipulates Charge in any form, so it never contradicts A.4's
weapon-class Charge ceiling. Closed, not just flagged.

#### 4.8.5 Rusted Chunk (Condensation, favor-Kim)

First object in the project that is both a projectile and a pickup —
doesn't fit `BaseProjectile` (no landing state) or `WeaponPickup`/
`SkillPickup` (no flight phase). New class:
`scripts/reactions/rusted_chunk.gd`, `class_name RustedChunk extends Node2D`.

**State machine:** `FLYING → LANDED → (picked up | decayed)`

- **Spawn:** at the Condensation reaction's position. Direction =
  `-hit_data.knockback.normalized()` (the "knocked loose" feel — reuses
  the knockback vector already on `HitData`, no new field needed).
  Fallback to `Vector2.RIGHT` if knockback is zero-approx (synthetic
  skill hits), same guard `Hitbox._on_area_entered` already uses.
- **FLYING:** `collision_mask = 2` (Hurtbox layer, `BaseProjectile`
  convention). Speed 140, travels for 0.6s (~84px) unless it connects
  first. The player's own Hurtbox is excluded from hits (this is their
  reward, not self-damage) — same shape as `BaseProjectile.attacker`
  exclusion, hardcoded to whichever combatant triggered the reaction.
  On hitting an enemy Hurtbox: resolve owner's `ElementalCombatant`,
  emit `bonus_damage_dealt(8.0)` on it (bypasses full reaction
  resolution entirely — flat bonus damage, same philosophy as
  `Projectile`/Ore Surge, not a new elemental application), then
  `queue_free()`. Consumed — no pickup chance once it deals damage.
- **On FLYING lifetime expiring without a hit:** switches to LANDED
  instead of freeing — `collision_mask = 1` (player body layer,
  `WeaponPickup` convention), starts a 12s landed-lifetime timer.
- **LANDED:** auto-pickup on player contact (`body_entered`, no F-press
  — this is a passive proc reward, not an equipment choice like
  `WeaponPickup`/`SkillPickup`). On pickup: calls
  `player.elemental.armor_buff.apply(8.0, 15.0)` (see `ArmorBuffEffect`
  below), then `queue_free()`. If the 12s landed timer runs out unpicked,
  it just `queue_free()`s — no effect granted.

**New component — `ArmorBuffEffect`** (`scripts/reactions/armor_buff_effect.gd`),
same shape as every other timed component (`SlowEffect`/`DotEffect`/
`DisableEffect`): `apply(amount, duration)` / `tick(delta)` /
`get_bonus_armor()` / `expired` signal. **Refresh-only** — a second
pickup while one is active resets the duration to 15s, does not stack
the +8 magnitude, consistent with §1's "refresh-only, never stacking"
principle. Lives as a new field on `ElementalCombatant`
(`var armor_buff := ArmorBuffEffect.new()`), ticked alongside
status/slow/disable in `ElementalCombatant.tick()`. It's an **additive
layer on top of base `armor`**, not merged into it — Sever's shred
targets base `armor` only, never touches the buff layer.

#### 4.8.6 The Vine (Overgrowth)

One `Vine` (new class, `scripts/reactions/vine.gd`) spawns at the
reaction point when Overgrowth triggers with this branch active.
Requires `_apply_overgrowth_aoe()` to start **returning**
`Array[ElementalCombatant]` of everyone it actually rooted — currently
void — so the Vine knows exactly whose root it's authorized to end
early. Existing callers ignore the new return value; no break.

**Structure:** own `Hurtbox` child (so `Hitbox`'s existing one-hit-per-
active-window guard, `_already_hit`, naturally paces this — no new
debounce needed), own `_moc_hits: int` counter, holds the affected-
combatants list from spawn.

- **Mộc hits only count.** A non-Mộc hit still deals normal weapon
  damage (ordinary `Hurtbox.take_hit()`), just never advances the
  counter.
- **3rd Mộc hit → explode:** clears `disable_effect` on every combatant
  in the held list (ends their root early), spawns a lingering Mộc Zone
  at the Vine's position (`spawn_zone(Elements.MOC)`, default
  radius/lifetime), `queue_free()`s the Vine.
- **1st Thủy hit → water (mutually exclusive with the explode path):**
  releases the same list the same way, then spawns 2 `FlowerTurret`
  instances (new class, `scripts/reactions/flower_turret.gd`) near the
  Vine's position instead of exploding. Turrets live 10–15s (random
  per spawn), `attack_cooldown` ramping from 1.2s down to 0.4s linearly
  over that lifetime, targeting the nearest non-player combatant in
  `ALL_COMBATANTS_GROUP` within ~90px, dealing ~5 damage per shot.
  `queue_free()`s both turrets when their lifetime ends.

**First non-hostile autonomous combatant in the project.** Every
existing `ALL_COMBATANTS_GROUP` member today is either the player or
hostile to them — nothing currently filters "hostile" vs. "ally,"
because nothing needed to. `FlowerTurret` targeting "nearest, excluding
the player" is correct today by coincidence, not by a real faction
system — flag this as the first place that assumption is load-bearing,
in case allied NPCs are ever added later.

**Deferred, not resolved:** whether/how Break-Free's resistance applies
differently against the Vine's own root specifically (raised early in
this design pass, never actually answered). Ships using the existing
universal Break-Free rule until a decision is made.

#### 4.8.7 Overload (Wildfire, favor-Hỏa)

New tracked state per target, `WildfireOverload` (RefCounted, same
shape family as `ArmorBuffEffect`/`SlowEffect`): `level: int` (0–3),
`_sustain_timer`, `_source: Node` (whoever's hit last contributed).

- Any Hỏa hit landing on a target that already carries Wildfire's own
  Hỏa status increments `level` (capped at 3) and resets
  `_sustain_timer` to 10s; stores that hit's `hit_data.source`.
- DoT magnitude scales `+1.5` per level on top of Wildfire's existing
  tier1/tier2 base (2.5/3.5).
- No refreshing hit within the 10s sustain window → `level -= 1`,
  timer restarts at the new level; repeats down to 0.
- **Level reaches 3 → auto-explodes:** `status.clear()` (erases the
  fire status entirely), AoE damage (~15) via `bonus_damage_dealt` in a
  ~55px burst — **deliberately including `_source`** (the attacker who
  pushed it to 3), per §1's now-documented exception. Not
  bystander-excluded on purpose.
- **A fresh Wildfire Sinh trigger on this target resets `level` to 0**
  — consistent with the project's existing refresh-only philosophy
  (§1): a new base application always wins over accumulated auxiliary
  state, same as `ElementalStatus.apply()` already does.

#### 4.8.8 Remnant → Spiked Ground (Wildfire, favor-Mộc)

New class `WildfireRemnant` (`scripts/reactions/wildfire_remnant.gd`),
same two-state shape as `RustedChunk` (§4.8.5) — `REMNANT → SPIKED_GROUND`,
just renamed for this context, reusing whatever that pattern learns.

- **Drop:** any Mộc hit landing on a target currently carrying
  Wildfire's Hỏa status spawns a `WildfireRemnant` at that target's
  position — gated by its own new per-attacker cooldown (not the
  existing per-target ICD dict, since remnants are spawned world
  objects, not a status on a combatant), 1.0s.
- **REMNANT state:** expires after 8s if untouched. **Global cap of 4**,
  oldest evicts — same convention as `MAX_ACTIVE_ZONES`/
  `MAX_ACTIVE_CLOUDS`.
- **Revive (player action):** a Mộc hit on an active Remnant transitions
  it to `SPIKED_GROUND` — collision/behavior swap, same shape as
  `RustedChunk`'s `FLYING→LANDED` mask swap.
- **SPIKED_GROUND state:** periodic damage tick (interval 1.0s, ~3.0
  damage) to anything standing on it, own separate 6s expiry
  (independent of the Remnant state's 8s). **Local cluster cap: max 4
  within ~60px of each other** (a new density-check pattern, distinct
  from the Remnant's global-count cap above — this object type uses
  both conventions, one per state). *Assumption, flagged not confirmed:*
  exceeding the local cap **blocks** a Remnant from converting (it stays
  a Remnant) rather than evicting a neighbor — revisit if that reads
  wrong in play.
- **Recursion guard:** Spiked Ground's own damage tick must never be
  routed through the same "Mộc hit on a Wildfire target" check that
  drops Remnants in the first place — implementation guardrail, not a
  runtime check, since the two code paths simply shouldn't call into
  each other.
  
#### 4.8.9 Cinder Bloom Branches — Boulder & Cinderstorm

Cheapest branch pair so far: **one new class** (`Boulder`) and **one
additive field** on an existing class. No new projectile type for
either branch — both reuse `Projectile` (Ore Surge's fragment class,
`scripts/combat/fragment_projectile.gd`) directly.

**`Projectile` gets one new exported field:** `damage_amount: float = 0.0`.
In `_resolve_hit()`, after the existing armor/status lines, add:
`if damage_amount > 0.0: combatant.bonus_damage_dealt.emit(damage_amount)`.
Default 0 means Ore Surge's own fragments are completely unaffected —
this is additive, not a behavior change to tested code.

**Boulder (favor-Thổ):** targets specifically the enemy Cinder Bloom's
Sinh reaction just triggered on (not the wider AoE burn radius). New
class `scripts/reactions/boulder.gd`, `class_name Boulder extends Node2D`
— spawns above that target, waits 0.4s (`await get_tree().create_timer`,
same one-shot-delayed-effect shape `TestDummy._flash()` already uses),
then: emits `bonus_damage_dealt(14.0)` on the target directly + refreshes
its Thổ status, and spawns 5 `Projectile` fragments in the existing
even radial spread (`(TAU / count) * i`, same loop
`_spawn_ore_surge_fragments` already uses) with `element = Elements.THO`,
`shred_amount = 0.0`, `damage_amount = 3.0`. No dodge-window concerns —
this lands on an enemy, not the player, so the telegraph is pure juice.

**Cinderstorm (favor-Hỏa):** no new class at all — a new helper method,
`ElementalCombatant._spawn_cinderstorm_motes()`, spawns up to 4
`Projectile` instances, each aimed (smart-aim-at-spawn, same resolution
`Player._find_skill_target()`/Ignite Dart's aim already uses — not true
homing) at a *different* nearby enemy within 90px, excluding the direct
Cinder Bloom target (already hit) and excluding whichever enemy an
earlier mote in the same volley already claimed. Fewer eligible targets
than 4 → spawns fewer motes, never a wasted/aimless one. Each:
`element = Elements.HOA`, `shred_amount = 0.0`, `damage_amount = 4.0` —
refreshes Hỏa burn on whoever it hits, distinct from the direct target's
own Thổ status.

#### 4.8.10 Ore Surge Branches — Armor Sunder & Caltrops

Ore Surge's *base* Sinh effect is already the piercing-fragment
mechanic (A.2), so neither branch can just be "more fragments" —
that's what Tier 2 already is. Also worth knowing: `Projectile` never
calls `queue_free()` on a hit (`_resolve_hit()` doesn't free itself) —
it already pierces indefinitely until its own lifetime runs out, so
"pierce more" was never actually available as an upgrade.

**Shared prerequisite — one small refactor to `BaseProjectile`:**
its `_process()` currently calls `queue_free()` directly when
`_lifetime_timer >= lifetime`. Replace that call with a new virtual
`_on_expired()`, implemented in `BaseProjectile` itself as
`queue_free()` (identical default — `SkillProjectile` and Ore Surge's
un-branched fragments are completely unaffected). `Projectile`
overrides it to check the new flag below before falling back to the
same default.

**Armor Sunder (favor-Kim):** `Projectile` gets one new field,
`sunder_bonus_damage: float = 0.0` (default 0 — normal Ore Surge
fragments never set it, unaffected). In `_resolve_hit()`, check
`combatant.armor` **before** applying the shred: if it's already
`<= 0.0`, skip the (would-be-wasted) shred and instead
`combatant.bonus_damage_dealt.emit(sunder_bonus_damage)` (6.0) —
status still applies either way. Only a fragment landing on an
*already*-zero-armor target gets the bonus; the fragment that brings
armor to exactly 0 does not (matches the existing floor-state
convention, not a special transition trigger). First real combo payoff
in this pass — Sever (or a prior Ore Surge volley) into a follow-up
Ore Surge now has a reason to be sequenced deliberately, not just
flavor.

**Caltrops (favor-Thổ):** `Projectile` gets a second new field,
`leaves_hazard_on_expiry: bool = false` (default false — same
non-interference guarantee). Its `_on_expired()` override: if true,
spawn a new `Caltrop` (`scripts/reactions/caltrop.gd`,
`class_name Caltrop extends Node2D`) at the fragment's current
position before freeing. `Caltrop` is a **one-time-trigger** hazard —
matches the real-world object more than a lingering field would, and
is the simpler build: small radius (15px), distance-check against
`ALL_COMBATANTS_GROUP` on `_process` (no physical Area2D, consistent
with §1's "no real physics-based AoE" principle), first combatant to
come within range triggers `SlowEffect.apply(0.6, 2.5)` on them (Silt's
own numbers, reused) then immediately `queue_free()`s. Untriggered, it
decays after 10s. *Assumption, flagged not confirmed:* one-shot trigger
rather than a repeating zone — revisit if it reads as too weak in play.
Every fragment that doesn't connect with an enemy during its 0.8s
flight seeds one of these — Ore Surge against a lone target now
scatters a ring of hazards instead of just wasting the rest of the
volley.

---

## 5. Enemies & Bosses

`EnemyStats` (Resource) drives `EnemyCombatAI`'s `IDLE → CHASE →
TELEGRAPH → ACTIVE → COOLDOWN` state machine, shared verbatim by
`TestDummy` (`can_chase=false`), `PatrolDummy` (`can_chase=true`, own
patrol movement when *not* engaged), and `Boss` (`can_chase=true`, no
patrol). `SteamCloud.blocks_vision()` gates aggro/chase — checked once
per `update()` call, never mid-telegraph/active.

`BossStats extends EnemyStats`, adds `phase_2_element` +
`phase_transition_health_ratio` (default 0.5) + a runtime-only
`attack_cooldown_multiplier` (never mutates the shared `.tres` directly).
`Boss._enter_phase_2()` re-tags `elemental.innate_element`, force-applies
the new status (bypasses reaction resolution — a scripted shift, not a
reaction), retargets `EnemyCombatAI.element_override`. Fires once,
guarded by `_current_phase`. Dual-simultaneous-element attacks: **not
implemented**, stays an explicit stretch goal.

---

## 6. World & Run Structure

`RoomController` resolves `EnemySpawnPoint` children into real enemies on
`_ready()`, polls the `"enemies"` group each frame, unlocks `RoomExit`
once empty. `RunManager` (autoload) owns sequencing: `ROOMS_PER_RUN = 3`
random (no immediate repeat) + `BOSS_ROOM_SCENE_PATH` always last, never
part of the random pool. Autosaves after every room transition via
`SaveManager`, deliberately **not** mid-room precise (enemies always
respawn fresh — see `run_manager.gd`'s own header for the reasoning).

---

## 7. Save System

One JSON file at `user://save_data.json`, three independent concerns:
meta-progression (`unlocked_weapons`/`unlocked_skills`, by resource path,
recorded in `Player.swap_weapon`/`swap_skill`), run history (capped at 50,
oldest dropped), and a single mid-run snapshot (room sequence + index +
elapsed time + `Player.to_save_state()`). Test isolation via
`test/helpers/save_test_isolation.gd` — **always use this in any new test
that touches `SaveManager`**, never the real save path.

Qi and purchased upgrade tiers are **never** written to `SaveManager` —
per-run only, reset by `RunManager` the same as `_elapsed_sec`. If this
ever changes to a meta-currency, it needs its own explicit design
decision (see §4.8's per-run-only rationale) before touching this file.	
---

## 8. HUD & Input

`Hud` (autoload, `CanvasLayer`, layer 110) is entirely code-built —
deliberate, avoids the `.tscn` NodePath-drop bug class this project has
hit more than once (see `RoomController._ready()`'s own defensive
`find_child` fallback, same root cause). Owns **all** pickup input now;
`WeaponPickup`/`SkillPickup` only track proximity. `UI_SCALE = 0.5`
compensates for the project's viewport-stretch display settings — retune
this one constant if `project.godot`'s stretch ratio ever changes, not
the per-element pixel values.

`InputSetup` (autoload) defines every input action in code
(`InputMap.add_action`), not via Project Settings, specifically so a
malformed `project.godot` can't break input configuration.

---

## 9. Visuals

`SpriteVisual` is a drop-in tint-target: real `Sprite2D` if
`res://assets/sprites/<entity_id>.png` exists, else keeps the flat-colour
`PlaceholderVisual` `Polygon2D` visible. Missing art is never an error —
art lands one entity at a time. `ElementIndicator` draws the five A.1
pattern glyphs (diamond/spiral/wave/zigzag/dot-grid) procedurally, no
sprite dependency — wire it to `ElementalStatus.status_applied/cleared`,
never call `set_element()` from reaction-handling code directly.

---

## 10. Deviations from Appendix A — corrected canonical spec

*Use this table for the Final Report's implementation chapter — it's
already framed as "spec said X, build does Y, here's why."*

| Appendix A said | Implementation does | Why / verdict |
|---|---|---|
| A.7: Douse's footprint is "Zone (Water)" | Douse spawns a `SteamCloud`, a distinct one-shot-stun-then-passive-visual node — **not** a periodic-retick `ReactionZone` | Correct call: A.2's actual Douse text ("vision-block + stun") needs one-time stun + persistent vision-block, not `Zone`'s repeated re-application. **Canonical going forward: Douse = SteamCloud, not Zone.** Update A.7's table if this doc's the report source. |
| A.7 risk note: "soft cap of 2–3 active zones" | `ReactionZone.MAX_ACTIVE_ZONES = 4` | Untracked drift, not a deliberate call — pick one and update either the constant or the report language. |
| A.3: architecture text implies ICD is keyed on `(attacker, target, element)` | Keyed on `(attacker, element)` only, living per-target because the dict lives *on* the target's own `ElementalCombatant` | Behaviourally equivalent to spec, just achieved structurally instead of via an explicit target key. No fix needed — worth the one-line clarification in the report. |
| A.2: Overgrowth "roots enemies" (plural) | Was originally single-target; now genuine AoE (`_apply_overgrowth_aoe`, radius 75) | Corrected to match spec — flag as a fixed gap in the report's testing/iteration section, not a deviation. |
| Appendix A: no general armor/defense model specified | `ElementalCombatant.armor` exists purely so Sever has something real to shred | Invented stat, scoped narrowly, not a general defense system — document as a deliberate minimal addition. |
| Appendix A: silent on HUD, save/resume mechanics beyond Section 6.2's tech-stack row | Full `Hud` + `SaveManager` + `RunManager` systems, undocumented in Appendix A | Pure addition, not a deviation — Appendix A never scoped these at the mechanic level. This Design.md is now their only spec. |
| A.4: rune alternation (`_next_swing_uses_innate`) | Runtime-only bool stored **on the shared `WeaponStats` Resource instance itself** | Works today because only `Player` ever wields a `WeaponStats`. **Latent bug if any second caster (future enemy, co-op) ever equips the same `.tres` asset** — state would leak between wielders. Flag in §11. |
| `run_manager.gd`'s comment cites "Section 7.1" for excluding hub/meta-progression, but 7.1's Out-of-Scope column never actually says this | Hub/meta-progression stays deferred by decision, not by the cited section | Comment is misleading, not wrong in outcome. §4.8's Qi system is per-run and deliberately avoids needing a hub at all — fix the comment to reference this doc instead of a section that doesn't cover it. |
---

## 11. Known issues / tech debt

- **Shared-Resource rune state** (see §10 last row) — if enemies ever get
  weapons, move `_next_swing_uses_innate` off the Resource and into the
  wielder.
- `ReactionZone.MAX_ACTIVE_ZONES` vs. A.7's "2–3" note — pick one, update
  the other.
- `test_elemental_combatant_reactions.gd` already documents a dead
  defensive branch: every `KHAC_PARTIAL` cell in the current grid leaves
  `charge - incoming = 1`, never 0, so `handle_hit()`'s
  `if status.charge <= 0: status.clear()` is currently unreachable. Not a
  bug, just flagged so nobody "fixes" it into something that breaks the
  grid.
- No enemy Charge-3 path exists yet (A.3's own note) — Wu against an
  enemy-applied status is out of scope until A.6 enemy Charge sources are
  tuned in Sprint 3.
- ~~Armor has no mitigation effect~~ **Resolved (§3.1)** — diminishing-
  returns formula added, `get_armor_bonus()` (Vitality Rank 2) and
  `armor_buff` (Rusted Chunk, §4.8.5) are both mechanically live now.
  Outstanding: the four `_apply_damage()` call sites + two test files
  above still need the actual edit — not done as part of this doc pass.

---

## 12. Conventions for new code

1. New timed effect → own component under `scripts/reactions/`, refresh-only,
   `apply()`/`tick()`/`clear()`/an `expired` signal — mirror `DotEffect`.
2. New AoE reaction effect → private `_apply_x_aoe`/`_burst` helper on
   `ElementalCombatant`, bystander-excluded via `_bystander_attacker()`,
   radius-queries `ALL_COMBATANTS_GROUP`.
3. New reaction *category* logic → `reaction_resolver.gd`, pure, no side
   effects, unit test in `test/unit/test_reaction_resolver.gd`.
4. New reaction *effect* → `ElementalCombatant.handle_hit()`'s match
   statement, integration test in
   `test/integration/test_elemental_combatant_reactions.gd`.
5. New enemy type → compose `ElementalCombatant` + `EnemyCombatAI`, don't
   inherit from an existing enemy script.
6. Touching `SaveManager` in a test → always go through
   `save_test_isolation.gd`.
7. New upgrade tier (Qi economy, §4.8) → numeric tiers touch effect
   *output* only (damage/DoT/slow/stagger multipliers); behavioral tiers
   feed an adjusted charge *into* `Reactions.resolve()`, never modify
   `reaction_resolver.gd` itself. Add a resolver unit test first if a
   behavioral tier changes what counts as Thừa/Wu at the boundary.
---

## 13. Maintenance

Update this file when: a new reaction/system lands, an Appendix A number
changes, or a §11 tech-debt item gets fixed (move it to a "Resolved"
note, don't just delete the row — keeps the report's iteration narrative
honest).
