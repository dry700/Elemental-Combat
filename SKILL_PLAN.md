# Skill System Plan (post-P12)

Depends on P12 being done (shop chunk and `ShopStation`). Independent of the Perfect Hit work in `docs/WEAPON_BACKLOG.md`.
Follow the same agent rules as `P12_RUN_OPTIMIZATION_PLAN.md` section 0 (run the full GUT suite per phase, one commit per phase,
no edits to `reaction_resolver.gd`, never mutate shared `.tres`, `SaveTestIsolation` in any test touching `SaveManager`).

## Decisions

| Topic | Decision |
|---|---|
| Skill mix | A mix of reaction tools, damage skills, and movement/defense skills |
| Count | About **10 new** skills, two per element (15 total with the existing 5). If you meant 10 total, drop one per element from the roster below |
| Acquisition | **Shop skill stall** and **drops** (spirits, boss) |
| Sustain | Skills never heal. Restore (shop) stays the only healing |
| Damage model | Skill damage is **flat bonus damage** through `bonus_damage_dealt` (armor-mitigated by the target's `_apply_damage`, no hit-stop). Perfect Hit and Weapon Might do **not** apply to skills (see open decisions) |
| Charge | Skills keep the current rule: Charge 2, or 3 with a same-element weapon rune. Charge is never changed by a skill upgrade |

## What exists today (for reference)

- `SkillData` has `skill_name`, `element`, `function`, `cooldown`, `cast_range`, `zone_radius`, `zone_lifetime`.
- `SkillData.Function`: `APPLY_SELF`, `REMOVE_APPLY_SELF`, `APPLY_SINGLE_TARGET`, `REMOVE_ENEMY`, `APPLY_AREA`.
- Dispatch: hardcoded `match` in `Player._try_cast_skill`, calling `ElementalCombatant.cast_*`.
- Cooldowns: `Player._skill_cooldowns`, keyed by the `SkillData` instance (a swapped-out skill loses its cooldown).
- Existing skills: Ignite Dart (Hỏa), Overgrowth Snare (Mộc), Cleansing Tide (Thủy), Rending Edge (Kim), Stoneguard (Thổ).
- Loadout pool: `LoadoutSelect.STARTING_SKILL_PATHS` plus `SaveManager.get_unlocked_skill_paths()`.

---

## Phase S0 - Prep and bug fixes

**S0.1 `SkillData` schema** (`scripts/resources/skills/skill_data.gd`). Add fields (all with safe defaults so existing `.tres` files keep loading):
```gdscript
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var damage: float = 0.0            # flat bonus damage per target / projectile
@export var radius: float = 0.0            # AREA_BURST
@export var control_duration: float = 0.0  # stagger/stun applied by a burst (apply_control)
@export var slow_multiplier: float = 1.0   # < 1.0 applies apply_control_slow
@export var slow_duration: float = 0.0
@export var projectile_count: int = 1
@export var spread_deg: float = 0.0
@export var projectile_speed: float = 220.0
@export var projectile_lifetime: float = 0.5
@export var pierce: bool = false
@export var shred_amount: float = 0.0
@export var armor_bonus: float = 0.0       # BUFF_ARMOR
@export var buff_duration: float = 0.0
@export var dash_distance: float = 0.0     # DASH
@export var dash_iframes: float = 0.0
```
Keep `zone_radius` / `zone_lifetime` for `APPLY_AREA`.

**S0.2 Fix the skill card crash.** `PickupCard.set_skill()` reads `skill.description`, which does not exist on `SkillData` today, so opening the overlay on a skill pickup errors. S0.1 fixes it; also set `_icon_tex.texture = skill.icon`. Add a test that builds a `PickupCard` from a `SkillData` and calls `set_skill()`.

**S0.3 Overlay passes the wrong rune.** In `Hud._update_overlay_visuals()` the skill branch passes `_player.weapon_rune` / `secondary_weapon_rune` as the skill's rune. Skill runes do not exist (deferred), so pass `null`.

**S0.4 Skill pool.** New `scripts/resources/skills/skill_pool.gd` (`class_name SkillPool`, static only, same convention as `Elements`): one list of all skill paths, `static func by_element(element) -> Array[String]`, and `static func roll(exclude_paths: Array, element := Elements.NONE) -> SkillData`. `LoadoutSelect` keeps its own starting-five list; shop and drops use `SkillPool`.

**S0.5 Duplicate guard.** Add `Player.would_duplicate_skill(is_primary, candidate)` (compare `resource_path`, ignore empty paths), same rule as weapons (docs/Design.md 15.4). Cooldowns are keyed by the resource, so two copies would silently share one cooldown. Call it from `SkillPickup._do_pickup` and the Hud overlay.

**S0.6 Cooldown readout API.** `Player.get_skill_cooldown_ratio(skill) -> float` (0 = ready, 1 = just cast), and keep `_skill_cooldowns` private.

**Tests:** `description`/icon on card, `would_duplicate_skill`, cooldown ratio, existing skill tests unchanged.

---

## Phase S1 - New cast behaviors

Goal: every new skill is a `.tres` file. Add only four new `Function` values; existing ones are reused.

| New `Function` | What it does | Reuses |
|---|---|---|
| `AREA_BURST` | Instant radius pulse centered on the caster: optional flat damage, optional `apply_control` / `apply_control_slow`, optional element apply through `handle_hit(..., true)` (ICD bypassed, like all skills) | `_bystander_attacker` pattern (exclude the caster's own combatant), `ALL_COMBATANTS_GROUP` distance checks |
| `PROJECTILE_FAN` | Spawns `projectile_count` projectiles across `spread_deg`. Non-pierce uses an extended `SkillProjectile`; `pierce = true` uses `Projectile` | `BaseProjectile`, `Projectile.shred_amount` / `damage_amount` |
| `DASH` | Short movement burst with i-frames, optional own-slow clear | Player `DODGE` state (parameterize speed/duration/i-frames instead of duplicating it); runs in `Player`, not `ElementalCombatant` |
| `BUFF_ARMOR` | `armor_buff.apply(armor_bonus, buff_duration)` | `ArmorBuffEffect` (refresh-only) |

Rules:
- Add one entry point per behavior on `ElementalCombatant` (`cast_area_burst`, `cast_projectile_fan`, `cast_buff_armor`); `DASH` lives in `player.gd`. Keep the `cast_*` convention so a future enemy skill-caster can reuse them.
- `SkillProjectile` gets an optional `damage` field; when `> 0` it emits `bonus_damage_dealt(damage)` on the target's combatant **in addition to** the existing `handle_hit` (still ICD-bypassed, still single-hit, still never hits its wielder).
- Slim the dispatch: each `match` arm in `Player._try_cast_skill` should be a single call. Do not grow `Player` per skill.
- `DASH`: do not start the normal dodge cooldown; the skill's own cooldown applies. Reuse the existing enemy collision-exception logic during i-frames. Skills cannot be cast from `ATTACK`/`DODGE`/`DISABLED` (unchanged).
- Damage-over-time, summons, and heals are out of scope for this phase.

**Tests:** extend `test_elemental_combatant_skills.gd` and `test_skill_projectile.gd`: burst hits only targets in radius and excludes the caster; burst applies control through `cc_resistance`; fan spawns N projectiles with correct angles and does not error without `current_scene`; buff refreshes without stacking; dash i-frames apply and clear.

---

## Phase S2 - HUD

- `Hud._fill_skill_slot()`: show `skill.icon` in a `TextureRect` (same approach as weapon slots) and a cooldown overlay (`ColorRect` whose height follows `get_skill_cooldown_ratio`). Fall back to the first letter if no icon.
- Show the Q/E key label on each slot. The current `_skill_*_prompt` labels read "1" / "2" and are only used for pickup prompts.
- `SkillPickup._draw()`: draw the icon when present; keep the Q/E circle otherwise.
- Tests: slot shows ready vs cooling state (no pixel tests; assert the overlay's size or visibility).

---

## Phase S3 - The 10 new skills (`.tres` files)

Names are working titles with suggested Vietnamese flavor names; check the Vietnamese with someone who knows the terms. Numbers are starting points, tune from playtests.

| # | Skill (VN flavor) | Element | Role | Function | Starting parameters | Cooldown |
|---|---|---|---|---|---|---|
| 1 | Ember Burst (Liệt Diễm) | Hỏa | Damage | `AREA_BURST` | radius 45, damage 14, applies Hỏa | 10 s |
| 2 | Flame Dash (Hỏa Bộ) | Hỏa | Movement | `DASH` | distance 70, i-frames 0.2 s | 8 s |
| 3 | Undertow (Ám Lưu) | Thủy | Reaction tool | `AREA_BURST` | radius 60, slow x0.5 for 3 s, applies Thủy, no damage | 12 s |
| 4 | Tide Step (Lăng Ba) | Thủy | Movement | `DASH` | distance 80, i-frames 0.25 s, clears own slow | 9 s |
| 5 | Thorn Volley (Cức Tiễn) | Mộc | Damage | `PROJECTILE_FAN` | 5 projectiles, +-20 deg, damage 5 each, applies Mộc | 11 s |
| 6 | Barkskin (Mộc Giáp) | Mộc | Defense | `BUFF_ARMOR` | +15 armor for 6 s | 16 s |
| 7 | Throwing Blades (Phi Đao) | Kim | Damage | `PROJECTILE_FAN` (pierce) | 3 projectiles, +-8 deg, damage 7, shred 1 each | 10 s |
| 8 | Shard Field (Kim Sa) | Kim | Reaction tool | `APPLY_AREA` (existing) | radius 55, lifetime 8 s | 14 s |
| 9 | Seismic Slam (Địa Chấn) | Thổ | Damage | `AREA_BURST` | radius 40, damage 16, stagger 0.5 s, applies Thổ | 14 s |
| 10 | Earthen Bulwark (Thổ Thuẫn) | Thổ | Defense | `BUFF_ARMOR` | +25 armor for 5 s | 18 s |

Balance notes:
- Mix across all 15: reaction and utility tools 7 (the existing five plus Undertow and Shard Field), damage 4, movement 2, defense 2. The new ten lean toward damage and mobility because the existing five already cover reaction setup. Adjust if the mix feels lopsided.
- Skill damage is burst-sized (about 14-35 per cast) against weapon DPS of about 33-42, so skills support rather than replace weapons.
- Cooldowns sit in the same 8-22 s band as the existing five.
- Each skill needs a `description` string and ideally an icon (placeholder icon is fine).

---

## Phase S4 - Acquisition (shop and drops)

**Shop** (extends P12 Phase 5)
- `scripts/items/shop_skill_pickup.gd`: `class_name ShopSkillPickup extends SkillPickup`, with `price`. `_do_pickup`: return if `would_duplicate_skill`, return if `not UpgradeManager.spend_qi(price)`, else `super`. `_draw` adds "F %d Qi".
- One skill stall per shop, random from `SkillPool` excluding skills the player holds. Starting price 60 Qi (tune against the Qi economy in P12 Phase 7; skills are stronger than stat upgrades per Qi, so price them above weapons).
- Shop layout (local x in the 416 px chunk, walls take about 32 px each side): weapon stall 80, free rune 140, station 208, skill stall 276, weapon stall 336. Keep at least about 60 px between interactables so F prompts never overlap.

**Drops**
- Spirit enemies (`enemy_stats.element != NONE`): small chance (start 8%) to drop a `SkillPickup` of the spirit's element from `SkillPool.by_element`.
- Boss: one guaranteed skill pickup in the boss's element (or `phase_2_element`, 50/50, like `RunePickup.roll_boss_element`). Spawn it in `Boss._die()` next to the existing rune drop.
- Each enemy script has its own `_die()` (no shared base), so use one static helper `SkillPickup.spawn_drop(parent, position, element)` and call it from each, same edit shape as the rune drop.
- Dropped skills use `call_deferred("add_child", ...)` like rune drops.
- `Player.swap_skill()` already records the unlock, so found skills join the loadout pool for later runs.

**Tests:** shop skill stall buy / cannot afford / duplicate blocked; drop helper spawns a pickup with the right element; boss drop present on death; `SkillPool.roll` excludes held skills.

---

## Phase S5 - Docs and verification

- `docs/Design.md`: 4.6 (new functions and damage model), section 2 system map (skills row), section 8 (HUD cooldown), P12 shop section (skill stall), section 11 (the `description` fix).
- `README.md`, `plan.md`: new test counts.
- Full suite green, then manual playtest: cast each skill once in `test_arena`, then check the shop stall and boss drop in a run.

## Open decisions

1. **Skill damage scaling.** Flat damage falls behind as loops scale enemy HP by 25% per loop. Options: leave flat, scale skill damage with Weapon Might, or scale it with the loop number. Current plan: flat, revisit after loop playtests.
2. **Count.** 10 new (15 total) is assumed. Confirm or cut to 10 total.
3. **Healing skills.** Excluded so Restore stays the only sustain. Confirm.
4. **Spirit drop rate (8%) and skill price (60 Qi)** are placeholders; both depend on the P12 economy numbers.
5. **Future, not in scope:** skill runes (docs/Design.md 16.2: build together with the modifier catalogue), DoT/summon skills, enemy skill casters, and skill upgrades in the shop.

## P14 verification record

- Automated GUT suite: **287/287 passed**, **1,841 assertions**, **0 failures**; two expected headless warnings.
- Coverage includes skill data/card compatibility, duplicate and cooldown APIs, burst/fan/dash/armor behavior, HUD cooldown rendering, all 15 resources, shop purchase rules, pool exclusions, and matching-element drop helpers/boss drops.
- Interactive playtest was not available in the headless session. In `test_arena`, cast each skill once, then inspect shop spacing/purchase behavior and a boss skill drop before balance tuning.
