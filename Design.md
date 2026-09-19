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

```gdscript
const DEATH_TINT: Color = Color(0.3, 0.3, 0.3)  ## Same value as every enemy's own DEATH_TINT.
const DEATH_FADE_DELAY: float = 0.6

func _die() -> void:
    _is_dead = true
    hurtbox.invulnerable = true
    visuals.modulate = DEATH_TINT
    await get_tree().create_timer(DEATH_FADE_DELAY).timeout
    died.emit()
    print("Player died")
```

`died` now fires **after** the delay, not immediately — `_is_dead` still
flips synchronously (so `_apply_damage()`'s early-return guard and every
other death-gated check still work exactly as before), only the signal
that `RunManager` listens for is deliberately deferred. This is what
actually makes the tint visible: `RunManager._on_player_died()` doesn't
even hear about the death, let alone transition scenes, until the tint's
already been on screen for `DEATH_FADE_DELAY`.

**Required test fallout — two tests currently assert `died` synchronously,
right after `_apply_damage()` returns, and will fail until updated to
wait for it:**

`test_lethal_damage_triggers_death()` and `test_died_signal_fires_only_once()`
in `test_player_death.gd` need `await wait_for_signal(player, "died", 1.0)`
inserted before their `assert_signal_emitted`/`assert_signal_emit_count`
calls — GUT supports awaiting inside test functions the same way any
other function can. The other three tests in that file
(`test_damage_below_max_health_does_not_die`,
`test_further_damage_after_death_does_not_reduce_health_further`,
`test_current_health_never_goes_negative`) only check `_is_dead`/health
values, both still synchronous — **unaffected**.

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

### 3.2 Control Resistance

Rolling diminishing-returns resistance against control effects
(`DisableEffect` root/stagger/stun/graze **and** `SlowEffect`), tracked
by one shared counter per target — a Disable and a Slow both count
against the same track, and immunity (once reached) blocks both alike.
This exists specifically to close a gap a per-reaction ICD can't:
`DisableEffect` is refresh-only, so spamming *one* reaction already
can't stack duration — but nothing stops chaining *different* reactions
(Root Break's Burst → Vine's root → Douse's stun...) back-to-back,
since none of them share an ICD channel with each other. This system
caps *total* control uptime regardless of source.

**New component**, `scripts/reactions/cc_resistance.gd`:

```gdscript
class_name CCResistance
extends RefCounted

var free_hits: int = 999          # effectively unlimited by default —
var window_seconds: float = 8.0   # Player/Normal/Spirit unaffected unless configured

var _recent_count: int = 0
var _window_timer: float = 0.0

func configure(p_free_hits: int, p_window_seconds: float) -> void:
    free_hits = p_free_hits
    window_seconds = p_window_seconds

func tick(delta: float) -> void:
    if _recent_count <= 0:
        return
    _window_timer -= delta
    if _window_timer <= 0.0:
        _recent_count = 0

## Called once per control application ATTEMPT, before the underlying
## effect is applied. 0.0 means fully immune — caller skips the apply()
## entirely, not even the floor duration.
func consume_and_get_multiplier() -> float:
    var multiplier := 1.0 if _recent_count < free_hits else (0.5 if _recent_count == free_hits else 0.0)
    _recent_count += 1
    _window_timer = window_seconds
    return multiplier
```

**`ElementalCombatant` gets:** `var cc_resistance := CCResistance.new()`,
ticked in `tick(delta)` alongside status/slow/disable. Two new
chokepoint methods, replacing every direct `disable_effect.apply()` /
`slow_effect.apply()` call:

```gdscript
func apply_control(duration: float, floor_duration: float = 0.0) -> void:
    var m := cc_resistance.consume_and_get_multiplier()
    if m <= 0.0:
        return
    disable_effect.apply(duration * m, minf(floor_duration, duration * m))

func apply_control_slow(speed_multiplier: float, duration: float) -> void:
    var m := cc_resistance.consume_and_get_multiplier()
    if m <= 0.0:
        return
    slow_effect.apply(speed_multiplier, duration * m)
```

**Call sites to redirect (7 total — same shape of edit as armor
mitigation's four `_apply_damage()` sites):**
`apply_graze()`, Overgrowth's `_apply_overgrowth_aoe`, Root Break's
`_apply_root_break_burst`, `SteamCloud._apply_initial_stun` (Douse) →
`apply_control(...)`. Condensation's and Silt's `slow_effect.apply(...)`
calls, and Caltrops' (§4.8.10) → `apply_control_slow(...)`.
`debug_apply_test_effects()` stays direct — a dev tool, deliberately
bypasses resistance.

**`EnemyStats` gains:**

```gdscript
enum Tier { NORMAL, ELITE }
@export var tier: Tier = Tier.NORMAL
@export var cc_free_hits: int = 999
@export var cc_window_seconds: float = 8.0
```

`BossStats` inherits these automatically — no new fields needed there.
Elite is **not a new class** — it's a new authoring convention on the
same `EnemyStats` shape Normal/Spirit already share (their own
distinction is likewise just "does `element` get set," never a
separate class). An Elite is just an `EnemyStats` `.tres` with `tier`
set and tighter `cc_free_hits`, same way `kim_spirit_stats.tres` differs
from `neutral_brawler_stats.tres` purely by authored numbers.

**Proposed numbers** (placeholder, tune in Sprint 3 like everything
else here):

| Tier | `cc_free_hits` | `cc_window_seconds` | Curve |
|---|---|---|---|
| Normal / Spirit (unset) | 999 | 8.0 | Never triggers — fully comboable, unchanged from today |
| Elite | 5 | 8.0 | Hits 1–5 full duration, hit 6 at 50%, hit 7+ immune |
| Boss | 3 | 8.0 | Hits 1–3 full duration, hit 4 at 50%, hit 5+ immune |

**Wiring:** `TestDummy`/`PatrolDummy`/`Boss`'s existing
`if enemy_stats != null:` block gets one added line each —
`elemental.cc_resistance.configure(enemy_stats.cc_free_hits, enemy_stats.cc_window_seconds)`
(Boss: `boss_stats.` instead).

**No existing test fallout expected** — unlike armor mitigation, every
default (`999` free hits) preserves today's behavior exactly, and no
current test configures a tighter profile. New behavior needs its own
new test file (`test_cc_resistance.gd`, per §12's convention) rather
than touching existing ones.

**Deferred, not resolved:** Elite gets no HUD/visual distinction yet
(no name tag, no tint) — purely a stats-and-resistance tier for now.
Whether Disable and Slow *should* share one counter vs. two independent
tracks is the interpretation taken here, not a settled call — revisit
if resisting a stagger shouldn't also cost resistance against a later
slow, or vice versa.
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

## 14. First-Time Tutorial

Plays once per save, ever — not per run. Teaches only the three
requested verbs (movement, combat, one guaranteed reaction) and
deliberately stops there: no Charge, no Tier, no ICD, no Break-Free, no
Cheng/Thừa/Wu naming. Those stay entirely discoverable through play,
same spirit A.6 always intended for elemental spirits generally, just
made literal for the actual first few minutes.

### 14.1 Persistence

`SaveManager._default_data()` gains `"tutorial_completed": false`.
New methods, same convention as `record_weapon_unlock`:

```gdscript
func has_completed_tutorial() -> bool:
    return _data.get("tutorial_completed", false)

func mark_tutorial_completed() -> void:
    if _data.get("tutorial_completed", false):
        return
    _data["tutorial_completed"] = true
    _save_to_disk()
```

### 14.2 The Tutorial Room

New scene `scenes/world/tutorial_room.tscn` + script
`scripts/world/tutorial_room.gd`. Self-contained — own `Ground`, own
`Player` instance (weapon explicitly set to `training_dagger.tres`,
same pattern `test_arena.tscn`/`procedural_run.tscn` already use), two
`TestDummy` instances, and a `RoomExit` reused directly, locked until
all three stages complete.

```gdscript
enum Stage { MOVEMENT, COMBAT, REACTION, DONE }
var _stage: Stage = Stage.MOVEMENT
var _has_moved := false
var _has_jumped := false
var _has_dodged := false
```

- **MOVEMENT:** poll each frame — `Input.get_axis("move_left","move_right") != 0.0`
  sets `_has_moved`; `Input.is_action_just_pressed("jump")` sets
  `_has_jumped`; `Input.is_action_just_pressed("dodge")` sets
  `_has_dodged`. All three true → advance. Prompt:
  `"A/D to Move  ·  Space to Jump  ·  Shift to Dodge"` — matches Sprint
  1's own core-feel goals (GUIDE.md §3) exactly: movement, jump, and
  dodge are the three things that Sprint was built to make feel right,
  so the tutorial teaches precisely that set, nothing more or less.
- No skip path, by design — deliberately omitted, not deferred.
  `_has_jumped`. Both true → advance. Prompt: `"A/D to Move  ·  Space to Jump"`.
- **COMBAT:** an elementless `TestDummy` (`starting_element = &"none"`)
  is active; `hurtbox.hit_received` firing once on it advances. Prompt:
  `"Left Click to Attack"`.
- **REACTION:** a second `TestDummy` at its literal default config
  (Kim, Charge 1) becomes active; its `elemental.status.status_cleared`
  firing once advances. Prompt: `"Elements react when they meet — try it"`
  — deliberately vague, names no mechanic.
- **DONE:** `RoomExit.locked = false`. Walking through it calls
  `SaveManager.mark_tutorial_completed()`, then
  `get_tree().change_scene_to_file("res://scenes/world/procedural_run.tscn")`.

**This is the first actual scene-tree-level scene change anywhere in
the project.** Every existing transition (`RunManager` between rooms)
swaps children *within* one persistent scene — this is the first place
`change_scene_to_file` gets called at all. Worth testing in isolation
before assuming it behaves like the room-swap pattern already does.

Prompts render as plain `Label` nodes authored directly in the `.tscn`
(not code-built like `Hud`) — this scene only ever exists once, code-
building it the way `Hud` does for reusability-across-every-scene
would be solving a problem this doesn't have.

### 14.3 Deferred entry-point wiring

`project.godot`'s `run/main_scene` stays `test_arena.tscn` for now —
that's the dev/playtesting default (README's own framing), and this
tutorial is built and testable in isolation without touching it.
Wiring the *real* boot sequence (fresh save → Tutorial →
`procedural_run.tscn`; returning save → straight to a run, or a main
menu) is explicitly tied to the still-open main-menu decision flagged
earlier in this document — solving one without the other would mean
redoing this wiring twice. Revisit both together.

## 15. Loadout Select

Two fully independent selectors, one per weapon slot — not the
existing `WeaponPickup`/`Hud` overlay's "choose which slot" flow, which
solves a different problem (you found one new thing, put it somewhere).
This solves "pick both slots before the run even starts."

Shown before every **new** run, skipped entirely when resuming
(`SaveManager.has_in_progress_run()` — a resumed run's weapons come
back via `Player.apply_save_state()` exactly as they do today; letting
the player re-pick mid-resume would contradict what "resume" means).
Tied to the same deferred entry-point/main-menu question as §14.3 — the
thing that decides "show Tutorial or not" is the same thing that should
decide "show Loadout Select or not."

### 15.1 Pool

```gdscript
const STARTING_WEAPON_PATHS: Array[String] = [
    "res://scripts/resources/weapons/training_dagger.tres",
    "res://scripts/resources/weapons/training_spear.tres",
    "res://scripts/resources/weapons/training_staff.tres",
    "res://scripts/resources/weapons/training_greatsword.tres",
    "res://scripts/resources/weapons/training_hammer.tres",
]
```

```gdscript
const STARTING_SKILL_PATHS: Array[String] = [
    "res://scripts/resources/skills/ignite_dart.tres",
    "res://scripts/resources/skills/overgrowth_snare.tres",
    "res://scripts/resources/skills/cleansing_tide.tres",
    "res://scripts/resources/skills/rending_edge.tres",
    "res://scripts/resources/skills/stoneguard.tres",
]
```

Same pool-building shape as weapons: starting five +
`SaveManager.get_unlocked_skill_paths()`, deduped.

Both slots draw from the **identical** pool (starting five +
`SaveManager.get_unlocked_weapon_paths()`, deduped) — chosen
independently per slot, matching the diagram exactly.

### 15.2 New scene

`scenes/ui/loadout_select.tscn` + `scripts/ui/loadout_select.gd`, root
`Control`. Authored `.tscn` (not code-built like `Hud`) — same
reasoning as Tutorial Room: this exists once, isn't reused across every
scene, doesn't need `Hud`'s reusability shape. Four `VBoxContainer` columns now, not two — Weapon 1, Weapon 2,
Skill 1, Skill 2 — each populated the same way (one clickable row per
pool entry). **Validation differs by pair, not identical across all
four:** the weapon columns impose no cross-check at all (duplicate
picks allowed, confirmed harmless — no shared state between
`weapon`/`secondary_weapon`). The skill columns **do** cross-check —
"Start Run" stays disabled if `skill_1`'s pick == `skill_2`'s pick,
since `Player._skill_cooldowns` is keyed by the `SkillData` resource
itself, not by slot: two identical skills would silently share one
cooldown, collapsing Q and E into one button instead of two real
choices. A short inline message ("pick two different skills") shows
when this blocks confirmation, rather than silently disabling with no
explanation. A "Start Run"
button, disabled until both columns have a selection. The weapon columns now cross-check too, same rule as skills but simpler
reasoning: "Start Run" stays disabled if Weapon 1's pick == Weapon 2's
pick (compared by `resource_path`, matching how `SaveManager` already
tracks weapons/skills throughout — not object identity, since Godot
caches loaded resources and two `load()` calls to the same path can
return the same instance). Same inline-message pattern as the skill
check.

### 15.3 Hand-off — reuses `RunManager`, no new autoload

```gdscript
# RunManager — four pending fields now, not two
var pending_weapon_path: String = ""
var pending_secondary_weapon_path: String = ""
var pending_skill_1_path: String = ""
var pending_skill_2_path: String = ""

func consume_pending_loadout(player: Player) -> void:
    if pending_weapon_path != "":
        var w := load(pending_weapon_path) as WeaponStats
        if w != null:
            player.weapon = w
    if pending_secondary_weapon_path != "":
        var w2 := load(pending_secondary_weapon_path) as WeaponStats
        if w2 != null:
            player.secondary_weapon = w2
    if pending_skill_1_path != "":
        var s1 := load(pending_skill_1_path) as SkillData
        if s1 != null:
            player.skill_1 = s1
    if pending_skill_2_path != "":
        var s2 := load(pending_skill_2_path) as SkillData
        if s2 != null:
            player.skill_2 = s2
    pending_weapon_path = ""
    pending_secondary_weapon_path = ""
    pending_skill_1_path = ""
    pending_skill_2_path = ""
```

`procedural_run.gd._ready()` is unchanged from the earlier draft — same
single `RunManager.consume_pending_loadout(player)` call before
`start_run()` now hands off all four, not two. Same resume-safety
reasoning holds: a resumed run's later `apply_save_state()` still wins
over anything pending, unchanged.
Order matters: calling this *before* `start_run()` means a resumed
run's later `apply_save_state()` call correctly overwrites it if both
paths happen to be set — resume always wins, loadout choice only ever
applies to a genuinely fresh run.

Deliberately **not persisted to `SaveManager`** — this is in-memory
hand-off between two scenes in the same session, not save data. If the
player quits between selecting and the run actually starting, losing
that specific pending choice is fine; they just pick again next launch.
### 15.4 Duplicate-weapon rule, extended to in-run pickups

`Player` gets the authoritative check — the guard that actually
prevents a duplicate, everything else below is UX on top of it:

```gdscript
## Compared by resource_path (matches SaveManager's tracking
## convention throughout, not object identity). Empty resource_path —
## a runtime WeaponStats.new() fallback/debug instance — is never
## treated as a duplicate; it can't be meaningfully compared.
func would_duplicate_weapon(is_primary: bool, candidate: WeaponStats) -> bool:
    if candidate == null or candidate.resource_path == "":
        return false
    var other := secondary_weapon if is_primary else weapon
    return other != null and other.resource_path == candidate.resource_path
```

`Hud._confirm_overlay_selection()` gets one added guard for
weapon-kind overlays: if `_player.would_duplicate_weapon(_overlay_selected_primary, pickup.weapon)`,
don't confirm — show the same inline "(duplicate)" message pattern
already used for the skill check (§15.2), leave the overlay open.
`_update_overlay_visuals()` additionally grays out whichever slot
option would trigger this, so the block is visible before the player
even tries to confirm, not just after.

Not retroactively enforced — an existing save from before this rule
existed could still hold two identical weapons; the rule only stops a
*new* duplicate from being created going forward, it doesn't auto-fix
one that's already there.
## 16. Runes

New pickup, `scripts/items/rune_pickup.gd`,
`class_name RunePickup extends Area2D` — mirrors `WeaponPickup`/
`SkillPickup` exactly: proximity-only (`_player_in_range`), all input
via `Hud`'s existing overlay, no new input action. One field:
`@export var rune_element: StringName = Elements.NONE`.

**`Hud`'s overlay gets a third kind**, not just weapon/skill —
`_overlay_kind: enum { WEAPON, SKILL, RUNE }` replacing the current
`_overlay_is_weapon: bool`. RUNE reuses the exact same "slot 1 / slot 2"
shape as WEAPON (runes only ever target weapon slots, never skills,
matching A.4), just confirms into `apply_rune()` instead of
`swap_weapon()`.

**Application — `Player.apply_rune()`:**

```gdscript
func apply_rune(is_primary: bool, new_rune_element: StringName) -> void:
    var target := weapon if is_primary else secondary_weapon
    if target == null:
        return
    var runed := target.duplicate() as WeaponStats
    runed.rune_element = new_rune_element
    if is_primary:
        weapon = runed
        # _weapon_base_path (below) is deliberately UNCHANGED — same
        # base weapon, just now runed.
    else:
        secondary_weapon = runed
```

**Save/resume fix — required alongside this, not optional.** `Player`
gains two new tracked fields, `_weapon_base_path` /
`_secondary_weapon_base_path`, set whenever a *real* weapon (non-empty
resource_path) is assigned via `swap_weapon()` or
`consume_pending_loadout()` — **never** touched by `apply_rune()`,
since the base weapon type doesn't change, only its rune does.

`to_save_state()` saves `_weapon_base_path` (not `weapon.resource_path`
directly anymore) plus a new `weapon_rune_element` field
(`weapon.rune_element` — this value duplicate()s correctly even though
the path doesn't). `apply_save_state()`'s `_load_weapon_path()` loads
the base asset by path as before, then re-applies the saved rune only
if it differs from what that asset already bakes in:

```gdscript
func _load_weapon_path(path: String, rune_element: StringName, is_primary: bool) -> void:
    if path == "":
        return
    var loaded := load(path) as WeaponStats
    if loaded == null:
        push_warning("Player.apply_save_state: could not load weapon at %s" % path)
        return
    if rune_element != &"none" and rune_element != loaded.rune_element:
        loaded = loaded.duplicate() as WeaponStats
        loaded.rune_element = rune_element
    if is_primary:
        weapon = loaded
        _weapon_base_path = path
    else:
        secondary_weapon = loaded
        _secondary_weapon_base_path = path
```

`consume_pending_loadout()` (§15.3) needs the matching update — setting
`_weapon_base_path`/`_secondary_weapon_base_path` alongside
`player.weapon`/`player.secondary_weapon`, not just the weapon fields
alone, or a loadout-selected weapon would itself fail to survive a
resume.

**Visual — reuses the A.1 glyph language, not a slot number.** Unlike
`WeaponPickup`/`SkillPickup` (square-with-"1"/"2", circle-with-"Q"/"E"
— their identity is *which slot*), a rune's identity is *which
element*. `RunePickup._draw()` renders the same pattern glyph
`ElementIndicator` already draws for status icons (diamond/spiral/
wave/zigzag/dot-grid), tinted by the same `ElementIndicator.ELEMENT_COLOR`
map — directly reusing the accessibility pattern language A.1
established, rather than inventing a fourth pickup shape/color scheme.
"Press F" prompt stays identical to the other two, for consistency.

**Default slot targeting, mirroring `_default_target_is_primary`'s
exact shape:** prefers whichever weapon slot currently has **no**
rune (`rune_element == Elements.NONE`), falls back to whichever slot
has a *different* element than the one being picked up, falls back to
the pickup's own preferred slot only once both are already occupied by
the same element. Smarter than weapons' plain empty-slot check, since
"already runed" is a meaningfully different state than "empty" here.

**Resolved:** overwriting an existing rune **does** leave the old one
behind as a new `RunePickup` at the same position — same reasoning
`WeaponPickup` already states outright ("a swap is always reversible,
never a one-way trade the player didn't mean to make"). Reuses the
identical `_spawn_dropped`-shaped helper, just for runes instead of
weapons — cheap, since the pattern already exists twice in this
codebase (`WeaponPickup`, `SkillPickup`) and this is a third use of the
same shape, not a new one.
### 16.1 Acquisition

**Elemental spirits (`TestDummy`/`PatrolDummy`/`Boss` with
`enemy_stats.element != Elements.NONE`)** drop exactly one `RunePickup`
on death — the drop itself is guaranteed, only the *element* is
weighted:

```gdscript
# static on RunePickup — centralizes the weighting so TestDummy/
# PatrolDummy/Boss's three separate _die() methods (no shared base
# class, same reason every other enemy hook in this project is
# duplicated three times) don't each reimplement it.
const SPIRIT_OWN_ELEMENT_WEIGHT: float = 0.6  # 60% own element, 10% each of the other 4

static func roll_spirit_element(own_element: StringName) -> StringName:
    if randf() < SPIRIT_OWN_ELEMENT_WEIGHT:
        return own_element
    var others := Elements.ALL.duplicate()
    others.erase(own_element)
    return others[randi() % others.size()]
```

`_die()` in `TestDummy`/`PatrolDummy` (and `Boss`, see below), same
"same edit shape, three call sites" pattern as Qi's `_die()` hook
(§4.8.1) and armor mitigation's `_apply_damage()` (§3.1):

```gdscript
if enemy_stats != null and enemy_stats.element != Elements.NONE:
    var rune := RunePickup.new()
    rune.rune_element = RunePickup.roll_spirit_element(enemy_stats.element)
    rune.global_position = global_position
    get_tree().current_scene.add_child(rune)
```

**Room clear (`RoomController._check_cleared()`)** additionally spawns
one baseline `RunePickup` near the `Exit`, element chosen **uniformly**
across all 5 (not weighted — this is the non-themed baseline, its whole
point is covering all-Normal rooms that have no spirit to drop
anything):

```gdscript
var baseline := RunePickup.new()
baseline.rune_element = Elements.ALL[randi() % Elements.ALL.size()]
baseline.global_position = exit.global_position + Vector2(-15, 0)
get_parent().add_child(baseline)
```

A room with an elemental spirit in it now yields **two** runes total
(the spirit's weighted drop + the room's baseline) — deliberately
generous, matches the "themed bonus on top of a guaranteed floor"
framing this combo was chosen for.

**Interpretation taken, not explicitly stated by you:** the spirit's
drop chance itself is 100% — only which element rolls is weighted.
Flagging in case you actually meant "chance to drop *at all*" is also
supposed to be less than certain.

**Still open:**
**Boss drop — resolved.** One rune, dropped once, after death — not
per-phase, not two separate drops. A distinct roll shape from spirits'
5-way weighting: confined to just the boss's own two elements, 50/50,
since a boss only ever embodies two (A.6), never the other three.

```gdscript
# RunePickup — new static method alongside roll_spirit_element
static func roll_boss_element(phase_1_element: StringName, phase_2_element: StringName) -> StringName:
    return phase_1_element if randf() < 0.5 else phase_2_element
```

`Boss._die()`, guarded for the two degenerate cases (no element at all
→ no drop; single-element boss with no `phase_2_element` → always that
one, never a coin-flip against nothing):

```gdscript
func _die() -> void:
    _is_dead = true
    hurtbox.invulnerable = true
    visual.set_tint(DEATH_TINT)
    damage_label.text = "X"
    if boss_stats.element != Elements.NONE:
        var rune := RunePickup.new()
        rune.rune_element = (RunePickup.roll_boss_element(boss_stats.element, boss_stats.phase_2_element)
            if boss_stats.phase_2_element != Elements.NONE else boss_stats.element)
        rune.global_position = global_position
        get_tree().current_scene.add_child(rune)
    await get_tree().create_timer(DEATH_FADE_DELAY).timeout
    queue_free()
```

A boss room still separately triggers the room-clear baseline drop
(§16.1) on top of this — a boss kill can yield **two** runes total (its
own two-element roll + the room's uniform baseline), consistent with
the "themed bonus on top of a guaranteed floor" reasoning already
established for ordinary spirit rooms.

**Resolved:** overwriting an existing rune **does** leave the old one
behind as a new `RunePickup` at the same position — same reasoning
`WeaponPickup` already states outright ("a swap is always reversible,
never a one-way trade the player didn't mean to make"). Reuses the
identical `_spawn_dropped`-shaped helper, just for runes instead of
weapons — cheap, since the pattern already exists twice in this
codebase (`WeaponPickup`, `SkillPickup`) and this is a third use of the
same shape, not a new one.

  ### 16.2 Skill Runes (architecture decided, content deferred)

Skills will get their own independent rune slot eventually — a new
`SkillData.rune_element` field, a separate `Player.apply_skill_rune()`
application flow (mirroring §16's weapon version, own save/resume
fields), and their own `Hud` overlay target alongside `WEAPON`/`SKILL`/
`RUNE`. **Locked in as the eventual shape; the actual minor-attribute
table (what a rune on a skill does) is explicitly deferred** — same
"logged as scoped-out future work, not implemented" treatment A.2
already gives its own deferred cross-cycle reactions. Do not build the
slot without the table, or vice versa — they're one feature, just not
this pass.

## 17. Death/Run-Summary Screen

Minimal scope — shows exactly what `SaveManager.run_history` already
tracks (outcome, rooms cleared, duration), nothing that needs new
instrumentation anywhere else. New scene, `scenes/ui/run_summary.tscn`
+ `scripts/ui/run_summary.gd` — same one-time-authored-`.tscn` reasoning
as Tutorial/Loadout Select.

**Hand-off, same `RunManager`-fields pattern as §15.3, fourth use now:**

```gdscript
# RunManager
var _last_run_outcome: String = ""
var _last_run_rooms_cleared: int = 0
var _last_run_duration_sec: float = 0.0

func _finish_run(outcome: String, rooms_cleared: int) -> void:
    _run_active = false
    set_process(false)
    SaveManager.record_run_result(outcome, rooms_cleared, _elapsed_sec)
    SaveManager.clear_in_progress_run()
    _last_run_outcome = outcome
    _last_run_rooms_cleared = rooms_cleared
    _last_run_duration_sec = _elapsed_sec
    get_tree().change_scene_to_file("res://scenes/ui/run_summary.tscn")
```

Not cleared after being read (unlike the pending-loadout fields in
§15.3) — these represent "the most recent finished run," naturally
overwritten by the next one, not a one-time-consume intent.

**Screen itself:**

```gdscript
extends Control

@onready var outcome_label: Label = $OutcomeLabel
@onready var rooms_label: Label = $RoomsLabel
@onready var duration_label: Label = $DurationLabel
@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
    var won := RunManager._last_run_outcome == "win"
    outcome_label.text = "Run Complete!" if won else "You Died"
    outcome_label.modulate = Color(0.4, 0.9, 0.45) if won else Color(0.85, 0.3, 0.3)
    rooms_label.text = "Rooms Cleared: %d" % RunManager._last_run_rooms_cleared
    duration_label.text = "Time: %s" % _format_duration(RunManager._last_run_duration_sec)
    continue_button.pressed.connect(_on_continue_pressed)

func _format_duration(seconds: float) -> String:
    var total := int(seconds)
    return "%d:%02d" % [total / 60, total % 60]

func _on_continue_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/loadout_select.tscn")
```

**Continue chains directly into Loadout Select** — doesn't need the
still-deferred main-menu decision (§14.3) resolved to function. If a
main menu ever gets built, it slots in before this whole chain starts,
not instead of it. Fourth use of `change_scene_to_file` in the project
now (Tutorial → Run, Loadout Select → Run, Player death → this screen,
this screen → Loadout Select).

**Richer stats (enemies killed, reactions triggered, Qi earned) explicitly
deferred** — same treatment as skill runes (§16.2): logged as a known
future expansion, not designed here, since none of that data is tracked
anywhere in the codebase yet.

## 18. Main Menu

New scene, `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd` — same
authored-`.tscn` convention as Tutorial/Loadout Select/Run Summary.
**Becomes `project.godot`'s actual entry point** (see §18.3) — the
resolution every deferred entry-point note since §14.3 has been
pointing toward.

### 18.1 Routing

One primary button, not two — text and action both decided by
`SaveManager.has_in_progress_run()`:

```gdscript
func _refresh_ui() -> void:
    var has_resume := SaveManager.has_in_progress_run()
    primary_button.text = "Continue" if has_resume else "New Run"
    abandon_button.visible = has_resume  # only exists when there's something to abandon

func _on_primary_button_pressed() -> void:
    if SaveManager.has_in_progress_run():
        get_tree().change_scene_to_file("res://scenes/world/procedural_run.tscn")
    else:
        _start_new_run()

func _start_new_run() -> void:
    if not SaveManager.has_completed_tutorial():
        get_tree().change_scene_to_file("res://scenes/world/tutorial_room.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/ui/loadout_select.tscn")
```

`_start_new_run()` is shared with the abandon flow below rather than
duplicated — "start fresh" means the same thing whether you got there
by having no run at all, or by just discarding one.

### 18.2 Abandon, with confirmation

Uses Godot's built-in `ConfirmationDialog` node directly rather than a
hand-rolled panel — first use of it in the project, but it's exactly
what it's for.

```gdscript
@onready var abandon_confirm: ConfirmationDialog = $AbandonConfirmDialog

func _ready() -> void:
    abandon_confirm.dialog_text = "Abandon your current run? This cannot be undone."
    abandon_confirm.confirmed.connect(_on_abandon_confirmed)
    abandon_button.pressed.connect(func(): abandon_confirm.popup_centered())
    _refresh_history_summary()
    _refresh_ui()

func _on_abandon_confirmed() -> void:
    SaveManager.clear_in_progress_run()
    _start_new_run()
```

**Deliberately never calls `record_run_result()`** — abandoning is
neither a win nor a loss, and shouldn't count as either in the history
glance below. An abandoned run simply vanishes, same as if the save
file had been deleted manually (README's existing testing escape
hatch), just reachable without leaving the game.

### 18.3 Run History Glance

Aggregates data `SaveManager.run_history` already tracks — no new
instrumentation, unlike the run-summary screen's deferred richer stats
(§17). Different scope tier entirely; this one's nearly free:

```gdscript
func _refresh_history_summary() -> void:
    var history := SaveManager.get_run_history()
    if history.is_empty():
        history_label.text = "No runs yet"
        return
    var wins := 0
    var best_rooms := 0
    for entry in history:
        if entry.get("outcome") == "win":
            wins += 1
        best_rooms = maxi(best_rooms, int(entry.get("rooms_cleared", 0)))
    history_label.text = "Total Runs: %d   ·   Wins: %d   ·   Best: %d rooms" % [history.size(), wins, best_rooms]
```

`MAX_RUN_HISTORY_ENTRIES` (50, `save_manager.gd`) caps how far back this
can see — "Total Runs" reads as "total of the most recent 50," not a
lifetime count, past that point. Not worth a fix; a fresh save won't
hit this for a very long time.

### 18.4 Entry point change
project.godot, [application] section
run/main_scene="res://scenes/world/test_arena.tscn"
run/main_scene="res://scenes/ui/main_menu.tscn"

`test_arena.tscn` still exists and is still directly runnable in the
editor for dev/playtesting — this only changes what a shipped build
actually boots into, per README's own framing of that scene as the
dev default. The full chain is now genuinely closed end-to-end: Main
Menu → (Tutorial, first time only) → Loadout Select → Run →
Death/Summary → Loadout Select → ... → Main Menu (via Quit, or by
finishing/abandoning back to it).

## 19. Room Authoring & Selection

### 19.1 Room Template Checklist

Every new normal room `.tscn` needs, matching `room_a/b/c`'s existing
shared shape exactly:

- Root `Node2D`, `RoomController` script attached, `exit` NodePath set
  (or left for `RoomController._ready()`'s own `find_child("Exit")`
  fallback to recover it).
- `Ground` (`StaticBody2D`), width 350–450px — the range every existing
  room already falls in; nothing enforces this, it's a convention to
  hold to for pacing consistency, not a hard constraint.
- Exactly one `PlayerSpawn` marker, in the `"player_spawn"` group.
- 1+ `EnemySpawnPoint` nodes, each with `enemy_scene` +
  `enemy_stats` set (`starting_element`/`starting_charge` only if the
  enemy should start already carrying a status — most shouldn't).
- One `Exit` (`RoomExit` script), `locked = true` by default —
  `RoomController._ready()` unlocks it automatically if the room has
  no spawn points, otherwise `RoomController` handles unlocking on
  clear.

Nothing here is new architecture — this section exists purely so the
next room built follows the pattern without re-deriving it from reading
three existing `.tscn` files side by side.

### 19.2 Selection & Scope (current pass)

- **`ROOMS_PER_RUN` stays 3.** No change to run length/pacing — this
  pass is about pool variety, not run structure (that's a separate,
  already-deferred topic).
- **Selection algorithm unchanged.** Uniform random + no-immediate-
  repeat-within-a-run already scales correctly as the pool grows — no
  code change needed, just longer `ROOM_SCENE_PATHS`. Cross-run memory
  (avoiding the same set showing up in back-to-back runs) stays an
  explicit future-work item, same treatment as skill runes (§16.2) and
  the run-summary screen's richer stats (§17) — logged, not built.
- **Target pool: 6 total** (double the current 3) — the smallest
  reasonable step, matching "for now" rather than committing to a
  bigger content target while solo pixel-art production is still the
  binding constraint (R05). Revisit once 6 exist and it's clear whether
  that's actually enough variety in practice.