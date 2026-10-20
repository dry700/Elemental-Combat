# Plan: Shop Rooms, Interactive Exits, Reaction Clues, Maid's Skills, Heavy Hit

Status: **planning only, no code written.** Every number below is a placeholder to tune in playtesting.
Source of truth for existing systems is [Design.md](docs/Design.md); when this plan is implemented, fold it into docs/Design.md as new sections.

---

## 0. Decisions at a glance

| # | Area | Decision |
|---|---|---|
| 1 | Shop placement | A shop after every normal room and after the boss. The boss shop has two exits: **Stop** (end run, show summary) and **Go deeper** (next loop). It replaces the old boss-loop summary. |
| 2 | Tab menu | Room-clear Tab upgrade menu is **removed**. Upgrades are bought only at the shop's Upgrade station. |
| 3 | Currency | Qi for everything. Refresh cost **escalates per category**. |
| 4 | Weapon offers | 3 random weapons from the pool. Slot chooser opens on purchase. |
| 5 | Rune offers | Author starter `RuneModifierDef` assets **first**, then build the shop. |
| 6 | Save/resume | Shop stock and refresh counts are saved and restored. |
| 7 | Exits | All exits (normal, shop, boss shop, tutorial) are interactive: stand on it, press **F**. |
| 8 | Reaction clues | All three: shop cards, combat trigger popup/glow, HUD strip. |
| 9 | Maid's Guard | Skill (cooldown). One-hit absorb, then explodes. |
| 10 | Maid's Sweep | Burst (energy-gated, no cooldown). ~15s Thổ weapon buff. |
| 11 | Energy meter | Per-skill meter, filled only by player-triggered reactions involving that skill's element. |
| 12 | Heavy hit | Hold attack, release to strike, dodge cancels. Bow, greatsword, hammer only. Hold time is per weapon. |
| 13 | Skill station | Fourth shop station (Upgrade / Weapon / Skill / Rune). Maid's Guard and Maid's Sweep are rare offers there. |
| 14 | Support enemies | New enemies that support other enemies, starting with a shielder. See section 12. |

Naming rule: reaction **Charge** (1 to 3) is core to Sinh/Khắc. Never call the new features "charge" in code or UI. Use **energy** (skills) and **windup / heavy hit** (weapons).

---

## 1. Rune modifier catalogue (prerequisite)

The catalogue is empty today (docs/Design.md §11), so shop runes would have no modifiers.

- Author starter `RuneModifierDef` `.tres` assets in `scripts/resources/runes/modifiers/`.
- Weapon modifiers (all act at the effect layer, **never raw Charge**, per §4.8):
  - `damage_pct`: bonus weapon damage.
  - `reach`: hitbox reach.
  - `hitbox_size`: hitbox radius.
  - `knockback`: knockback strength.
  - (optional) `attack_speed`: shorter `attack_duration`.
- Skill modifiers deferred (skill runes do not drop yet, §16.2).
- Load the catalogue into `RuneRoller.default()` at startup (currently nothing calls `set_catalogue` for the shared instance).
- Add one read-site per modifier in `Player._configure_hitbox_for_current_swing()`.
- Tests: extend `test_rune_roller.gd`; add effect read-site tests.

---

## 2. Interactive exits (press F)

Currently `RoomExit` advances on `body_entered`.

- `RoomExit` tracks `_player_in_range`, draws an "F" prompt (same pattern as pickups), and emits `player_entered` only when F is pressed while in range and unlocked. Keep the signal name so `RunManager` and `tutorial_room.gd` keep working.
- A locked exit shows no prompt and ignores F.
- Remove `_check_already_inside()`; it is no longer needed.
- **Priority:** if a pickup and an exit overlap, the pickup wins.
- Input ownership: follow the pickup convention (Hud owns input) or poll in `RoomExit`. Decide at implementation; Hud ownership makes the priority rule easy.
- Add an export `label` (and an `exit_kind` enum: `NEXT`, `STOP`, `DEEPER`) so the boss shop can show "Stop" and "Go deeper".
- `ProceduralRoomController` builds its exit in code, so it must set the new fields there too.
- Tests: new `test_room_exit.gd` (prompt on enter, F emits, locked ignores F, pickup priority). Update any test relying on walk-in advance.

---

## 3. Shop room

### 3.1 Scene and flow

- New `scenes/world/rooms/shop_room.tscn` + `scripts/world/shop_room.gd` (extends `RoomController`). Hand-authored like `room_boss.tscn`: ground, `PlayerSpawn`, `Exit`, four station nodes laid out Upgrade / Weapon / Skill / Rune (the first sketch showed three; Skill is added as a fourth).
- No enemies, so the room starts cleared and the exit unlocked.
- **Must override `_check_cleared()`** so it does **not** spawn the baseline rune (the current base class spawns one whenever the enemy group is empty).
- Boss shop: same scene or a variant with **two exits** (Stop, Go deeper). Stop calls `_finish_run("win", ...)` and shows the summary; Go deeper calls `start_next_loop()`.

### 3.2 Stations

- `scripts/items/shop_station.gd` (`Area2D`): proximity + prompt, same pattern as `WeaponPickup`/`SkillPickup`. Exports a `category` enum (`UPGRADE`, `WEAPON`, `SKILL`, `RUNE`).
- `Hud` owns F input and opens the shop popup for the nearby station.

### 3.3 Popup (second sketch)

- Generalise the existing room-clear upgrade panel into a **shop panel**: 3 option cards + Refresh bar.
- Upgrade offers come from the existing `_all_upgrade_options` logic.
- Weapon offers: 3 random from `STARTING_WEAPON_PATHS` + `SaveManager.get_unlocked_weapon_paths()`, excluding duplicates via `Player.would_duplicate_weapon()` (§15.4). On purchase, open the existing slot chooser (`_open_overlay`).
- Skill offers: 3 random from `STARTING_SKILL_PATHS` + `SaveManager.get_unlocked_skill_paths()`. **Maid's Guard and Maid's Sweep are rare entries** (about 10% chance per Skill station roll, tune later). Skills already equipped in either slot are excluded (two identical skills would share one cooldown, per §15.2). On purchase, the skill chooser path opens (`_open_overlay` SKILL kind) and `swap_skill()` records the unlock.
- Rune offers: rolled with `RuneRoller` (random element, target WEAPON). On purchase, slot chosen via the chooser.
- Keep the stable names Hud tests rely on where possible (`_open_overlay`, `_confirm_overlay_selection`, etc.).

### 3.4 Prices and refresh (placeholders)

- Upgrade: existing costs (Weapon Might / Vitality curves, reaction ranks 20 / 45).
- Weapon and rune prices: flat per offer, tune later.
- Refresh: base 10 Qi, **+10 per refresh, per category**, reset when entering a new shop.
- Qi economy needs a re-check: shops after every room mean more spending opportunities than the ~90 to 130 Qi/run estimate (§4.8.1) assumed.

### 3.5 Remove the old Tab menu

- Remove the room-clear auto-open in `RunManager._on_room_cleared()` and the `swap`-key open path in `Hud._handle_room_clear_upgrade_input()`.
- `UpgradeManager` is unchanged.
- Rewrite `test/unit/test_room_clear_upgrade_menu.gd` against the shop panel.

---

## 4. Run sequence and save/resume

### 4.1 Sequence

`_generate_sequence()` becomes: `room, shop, room, shop, room, shop, boss, boss_shop`.

- Update `ROOMS_PER_RUN` semantics and `test_run_manager_sequence.gd` (length and "boss is last" assertions change; add "a shop follows every normal room" and "boss shop is final").
- `rooms_cleared` is currently derived from `_current_index`; shops must **not** count as cleared rooms. Fix that calculation.
- `RunManager._on_room_cleared` no longer opens a menu.
- Boss-loop summary replaced: the boss shop's two exits take over the stop/continue choice. `run_summary` stays as the Stop destination and the death screen.

### 4.2 Shop state in the save

- Add shop state (per category: stock, refresh count, purchased flags) to the in-progress snapshot via `SaveManager.save_in_progress_run`.
- Weapons and skills by `resource_path`; runes via `RuneData.to_dict()` / `from_dict()`; missing keys mean "roll fresh".
- Autosave on every purchase and refresh, not just room transitions, so resume cannot be exploited.
- Qi and ranks already persist through `UpgradeManager.to_save_state()`.
- Tests: save/resume round trip in `test_run_manager_persistence.gd`; legacy snapshots without shop state still load.

---

## 5. Reaction upgrade visual clues

All three read from `UpgradeManager`. Add a small `reaction_rank(pair)` getter (0, 1, 2). None of this touches `reaction_resolver.gd`.

1. **Shop cards:** two `ElementIndicator` glyphs for the pair plus rank pips (I / II) on the card. For Sinh Rank 2, highlight the favored element's glyph. Shape and pips carry the meaning, color is secondary (A.1).
2. **Combat trigger:** in `ElementalCombatant`'s reaction popup, append the rank for upgraded pairs (e.g. "Overgrowth II"), plus a short glow ring in the generated element's color. Rank 2 is stronger than Rank 1.
3. **HUD strip:** compact row of upgraded reaction pairs only, each with glyphs and rank pips. Updates on purchase and on resume.

Tests: rank getter; popup text includes rank; HUD strip lists only upgraded pairs.

---

## 6. Maid's Guard (skill)

Placeholder name; may change.

- Cooldown skill. New `SkillData.Function.APPLY_SHIELD`, new `.tres` asset.
- New component `scripts/reactions/shield_effect.gd` (refresh-only, `apply()` / `tick()` / `clear()` / signal), living on `ElementalCombatant` as `shield`.
- **Absorbs one weapon or projectile hit:** damage, knockback and the elemental reaction are all negated. **DoT ticks and `bonus_damage_dealt` pass through.**
- Hook point: `Player._on_hurtbox_hit()`, before `_apply_damage`, `velocity += knockback` and `elemental.handle_hit()`. If the shield absorbs, skip all of them.
- **Explodes** when it breaks **or** expires (~12s), identical either way: fixed damage burst (via `bonus_damage_dealt`) plus a short stagger (`apply_control`) on nearby enemies. Radius check via `distance_to` against `ALL_COMBATANTS_GROUP`, bystander-excluded per §1.
- Placeholders: duration 12s, damage 12, radius 45px, stagger 0.5s, cooldown 18s.
- Entry point: `ElementalCombatant.cast_apply_shield()`, dispatched from `Player._try_cast_skill()`.
- Interactions to check: dodge i-frames, `playtest_invincible`, hit-stop and screen shake on an absorbed hit (probably still play a distinct feedback).
- Tests: absorbs exactly one hit, DoT passes through, reaction not applied on absorbed hit, explosion on break, explosion on expiry, bystander exclusion, refresh-only.

---

## 7. Energy system and Maid's Sweep

### 7.1 Energy meter

- New optional `SkillData` fields: `uses_energy: bool`, `energy_max: float`. Energy skills have no cooldown.
- Each energy skill has **its own meter**, tracked on Player keyed by the `SkillData` instance (same convention as `_skill_cooldowns`).
- **Fill rule:** a reaction the **player triggers on an enemy** that **involves the skill's own element** (e.g. any Thổ reaction fills Maid's Sweep). Excludes Vũ (reversed) outcomes.
- Hook: after `reaction_triggered.emit(...)` in `ElementalCombatant.handle_hit()`, if `hit_data.source` has an `on_reaction_caused(pair)` method, call it (duck-typed, consistent with how `elemental` is read elsewhere). Player implements it and fills matching meters.
- **Amounts (placeholders, `energy_max` 100):** Khắc partial 5, basic Sinh Tier 1 and Khắc full clear 10, Sinh Tier 2 and Thừa 20. Higher-quality reactions fill faster.
- Meter persists for the whole run, is saved on resume, and resets only on a new run.
- Cast resets that skill's meter to 0.
- HUD: **radial fill around the skill icon**, with a glow when full. Add a non-color cue for full (thicker outline or pulse) so it isn't color-only.
- Save: include meters in `Player.to_save_state()`.

### 7.2 Maid's Sweep

- Energy-gated, no cooldown. Cast when the meter is full.
- Timed buff (~15s) via a new refresh-only component (e.g. `SweepBuffEffect`): while active, weapon swings become **Thổ**, with bigger hitbox/reach and a damage multiplier.
- Read at `Player._configure_hitbox_for_current_swing()` only. Never touches raw reaction Charge (base weapon Charge stays).
- Decide how the element override interacts with different-element rune alternation (`resolve_swing`); simplest is to override and skip alternation while active.
- Placeholders: duration 15s, damage x1.4, reach x1.5, energy_max tuned so a few Thổ reactions fill it.
- Tests: meter fills only from matching-element reactions, not from Vũ or enemy-caused reactions, cast resets meter, buff expires, swing element is Thổ while active.

---

## 8. Heavy hit (weapon-specific)

- Applies to **bow, greatsword, hammer** only. New optional fields on `WeaponStats` (weapons without it are untouched): `has_heavy_attack`, hold min/max time, damage multiplier, reach bonus, knockback multiplier.
- **Input:** hold the attack button. A short press starts the normal swing; the heavy windup begins only if the button is still held after a threshold (~0.25 to 0.3s), so combo feel and buffering are unchanged.
- Release strikes. Longer hold scales the hit up to a cap. **Dodge cancels** the windup.
- Full-power hold time is **per weapon** (bow quickest, hammer slowest). Placeholders after the ~0.25s threshold: bow 0.6s, greatsword 1.0s, hammer 1.3s.
- New `Player.State` value appended to the enum (e.g. `HEAVY_WINDUP`) so existing tests are unaffected. A disable (stagger/stun) cancels the windup.
- Scales damage, reach or knockback, and for the bow, arrow speed/damage. **Never raises reaction Charge** (would make Thừa/Vũ trivial).
- Reuse heavy `HitStop`/`ScreenShake` presets for impact.
- Tell: the weapon sprite pulses and tints while winding up, with a bright flash at full power.
- Accessibility: offer a toggle or tap-to-charge option (the project already cites WCAG for Break-Free).
- Both slots can hold (left and right click); the existing "expected action" buffering check already distinguishes them.
- Tests: threshold enters windup, release strikes, dodge cancels, disable cancels, weapons without the field ignore holding, damage scales and caps, Charge unchanged.

---

## 9. Resolved decisions (from the question round)

| Question | Answer |
|---|---|
| Energy per reaction | More for Thừa and Sinh Tier 2, less for basic and partial. |
| Meter reset | Persists for the whole run, saved on resume, resets on a new run. |
| HUD meter | Radial fill around the skill icon, glow when full. |
| Heavy-hit hold time | Per weapon (bow quicker, hammer slower). |
| Heavy-hit tell | Weapon sprite pulses and tints, bright flash at full power. |
| Obtaining Maid's skills | Rare offers in the shop's Skill station. |

---

## 10. Build order

1. Rune modifier assets and effect read-sites.
2. `RoomExit` press-F rework (including tutorial and procedural exits).
3. Shop room scene, four stations (Upgrade, Weapon, Skill, Rune), shop popup, stock, refresh costs, cards with reaction glyphs.
4. `RunManager` sequence changes, boss shop with two exits, shop save/resume.
5. Remove the Tab room-clear menu and rewrite its tests.
6. `ShieldEffect` and Maid's Guard.
7. Energy meter and Maid's Sweep.
8. Heavy hit for bow, greatsword, hammer.
9. Support enemies (shielder first), after Maid's Guard since it reuses `ShieldEffect`.
10. Combat trigger clue and HUD upgrade strip.
11. Update docs/Design.md, plan.md, README; run the full GUT suite.

## 11. Files likely touched

New: `shop_room.tscn/.gd`, `shop_station.gd`, `support_ai.gd`, `shielder_enemy.tscn/.gd`, `shield_effect.gd`, `sweep_buff_effect.gd`, rune modifier `.tres` files, Maid's Guard / Maid's Sweep `.tres`, new tests per section.

Changed: `room_exit.gd`, `room_controller.gd` (or shop override), `procedural_room_controller.gd`, `tutorial_room.gd`, `run_manager.gd`, `hud.gd`, `upgrade_card.gd/.tscn`, `upgrade_manager.gd` (rank getter), `skill_data.gd`, `weapon_stats.gd`, `player.gd`, `ElementalCombatant.gd`, `rune_roller.gd` (catalogue loading), `save_manager.gd`, `run_summary.gd`, and the weapon `.tres` files for bow, greatsword, hammer.

Also changed for support enemies: the hit callback in every enemy body (`test_dummy`, `patrol_dummy`, `boss`, `flying_enemy`, `shooter_enemy`, `swooper_enemy`) gets one shared absorb check, `build_chunks.gd`, and `enemy_stats.gd`.

Tests to update: `test_run_manager_sequence.gd`, `test_room_clear_upgrade_menu.gd`, `test_run_manager_persistence.gd`, `test_rune_roller.gd`, Hud overlay tests if names change.

---

## 12. Support enemies

Goal: enemies that help other enemies, starting with a **shielder**. Later types, decided: **armor buffer** (reuses `ArmorBuffEffect`), **cleanser** (clears an ally's elemental status, which interacts with Khắc play), and **summoner**. **No healer.**

### 12.1 Shielder

- Composition, per convention: `ElementalCombatant` plus a new `SupportAI` component. Do not extend `EnemyCombatAI` or another enemy script.
- It applies the same `ShieldEffect` used by Maid's Guard to a nearby ally on a cooldown. One component, two users.
- **Enemy shield:** plain one-hit absorb, **no explosion** (the explosion is a player-skill feature only).
- **Behavior:** shields the nearest unshielded ally in range, then keeps its distance from the player. It stays killable for room clear.
- Stats via new `EnemyStats` fields (e.g. `support_range`, `support_cooldown`, `shield_duration`), authored as a `.tres`.

### 12.2 What this needs from the codebase

- **Ally awareness:** today "hostile" is just "not the Player" (Flower Turret's own note flags this as load-bearing). Supports need "other enemies" as allies. Use the existing `"enemies"` group and add one small helper to find the nearest ally in range. This is the first real faction logic; keep it group-based.
- **Shared absorb check:** each enemy body repeats its own `_on_hurtbox_hit`, and there is no base class. Put the absorb logic in one method on `ElementalCombatant` (e.g. `try_absorb_hit()`) and add a single call in each body, the same shape of edit as armor mitigation (§3.1). Player uses the same method.
- **Room clear:** supports are in the `"enemies"` group, so they must be killed for the exit to unlock. They must not hide or flee out of reach.
- **Placement:** add them to chunk spawn points (`build_chunks.gd` and the chunk `.tscn` files).
- **Reaction interplay:** a shielded ally negates the reaction on the absorbed hit, so shields delay status setup. Light weapons waste a hit on a shield, which makes heavy hits and projectiles more valuable.

---

## 13. Resolved decisions (support enemies and Skill station)

| Question | Answer |
|---|---|
| Enemy shield on break | Plain one-hit absorb, no explosion. |
| Shielder behavior | Shields the nearest unshielded ally in range, then keeps its distance from the player. |
| Later support types | Armor buffer, cleanser, summoner. No healer. |
| Maid's skills rarity | About 10% per Skill station roll. |

No open questions remain. Details still to tune in playtesting: all numbers marked as placeholders, and the summoner's spawn limits when it is designed.
