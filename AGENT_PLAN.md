# AGENT_PLAN.md — CLI agent execution plan

Source of truth: `Design.md` (wins over Appendix A). This file only says
**what order to do things in, what Design.md leaves out or gets wrong, and
what must be decided first.** Detailed code lives in Design.md; don't
duplicate it here.

## 0. Ground rules (apply to every phase)

- R1. One phase = one commit. After each: run
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
  and fix before moving on. Update Design.md in the same commit.
- R2. Never edit `scripts/reactions/reaction_resolver.gd`.
- R3. **Physics-callback rule.** `handle_hit()` and every enemy `_die()` run
  inside `Hitbox.area_entered` (physics flush). Anything containing an
  `Area2D`/`CollisionShape2D` spawned from there (RunePickup, Vine,
  RustedChunk, WildfireRemnant) must be added with
  `parent.add_child.call_deferred(node)`. Plain `Node2D` with distance checks
  (Boulder, Caltrop, FlowerTurret, ReactionZone, SteamCloud) is fine.
  `BaseProjectile` already defers its own collision setup.
- R4. Hand-edited `.tscn`: use `path=` refs only (no `uid=`/`unique_id`/`load_steps`),
  and give every script that reads a NodePath export a `find_child()`
  fallback (same as `RoomController._ready()`).
- R5. Never hand-write `.uid` files; let Godot generate them and commit them.
- R6. Any test touching `SaveManager` uses `test/helpers/save_test_isolation.gd`.
- R7. Any test that applies lethal `_apply_damage()` sets `elemental.armor = 0.0` (after P1).
- R8. Qi/upgrades never touch `SaveManager` (Design §7) — see D8.

## 1. Decisions needed before the marked phases

| ID | Gap | Blocks | Default if unanswered |
|---|---|---|---|
| D1 | §4.8.2 says Weapon Might and Vitality are "unchanged from the earlier draft" — the draft isn't in Design.md | P10 (those two categories) | Skip them; build Reaction Mastery only |
| D2 | §4.8.3 "Getter API (revised)" code block is missing | P10 | Derive names from the read-sites: `sinh_tier2_forced(pair)`, `sinh_favored_element(pair)`, `khac_graze_erased(pair)`, `khac_overwhelm_forced(pair)` |
| D3 | No UI/input defined for *spending* Qi | P10b+ (playable) | Hud overlay pattern, new action `upgrade_menu` (Tab), openable only while the room is cleared |
| D4 | `handle_hit()` runs for enemies hitting the player too — do upgrades apply to those? | P10b+ | Only when `hit_data.source is Player` |
| D5 | §14.2 sends Tutorial → `procedural_run`; §18.4 says Tutorial → Loadout Select | P4 | Follow §18.4 (route via a `NEXT_SCENE` const, flipped in P6) |
| D6 | Run Summary only continues to Loadout Select; nothing returns to Main Menu; §18.4 mentions a "Quit" button §18.1 never defines | P7/P8 | Add "Main Menu" button on summary, "Quit" on menu |
| D7 | `TestDummy`/`PatrolDummy` do `var _dot_damage := elemental.tick(delta)` and **discard DoT damage** (only Player and Boss apply it). §3.1 claims DoT reaches `_apply_damage` on all four | P1 | Wire it (`if _dot_damage > 0.0: _apply_damage(_dot_damage)`) and note the behaviour change in Design.md |
| D8 | §7 forbids persisting Qi/ranks, but mid-run resume then silently wipes purchased upgrades | P10a | Follow Design.md literally, add a §11 tech-debt note |

## 2. Dependency order

```
P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10(a→f) → P11
            (P6 needs P5's WeaponStats.base_path; P8 needs P4,P6,P7; P10 needs P1,P3,P5)
```

## P0 — Repo hygiene (no gameplay change)

- DELETE `scripts/resources/enemies/enemy_stats.gd` and its `.uid` — a stray fragment
  (only `@export` lines, no `extends`); the real class is `scenes/enemies/enemy_stats.gd`.
- `scripts/resources/weapons/training_staff.tres` uses invalid `.tres` syntax
  (`ComboStepData(style=SWING, ...)`). DELETE it, RENAME `training_staff (1).tres`
  → `training_staff.tres` (Loadout Select §15.1 references that exact path).
- Design.md text fixes only:
  - §3: `HitStop.freeze(0.05)` → `HitStop.freeze_for_weight()` + `ScreenShake.shake_for_weight()`; `combo_length` → `combo_steps.size()`.
  - §14.2: delete the stray orphan bullet ("No skip path… Prompt: `A/D to Move · Space to Jump`").
  - §15.2: delete the contradictory "weapon columns impose no cross-check" sentence (later text wins: both pairs cross-check; Start Run needs all four picks).
  - §16.1: delete the duplicated "Resolved: overwriting…" paragraph and the dangling "Still open:".
  - §18.4: show the `run/main_scene` change as a single diff, not both lines.

## P1 — Armor mitigation (§3.1) + ArmorBuffEffect component

NEW `scripts/reactions/armor_buff_effect.gd` (mirror `SlowEffect`: `apply/tick/get_bonus_armor/clear`, `expired`, refresh-only).

`scripts/reactions/ElementalCombatant.gd`
```gdscript
var armor_buff := ArmorBuffEffect.new()          # next to disable_effect
# in tick(): armor_buff.tick(delta)              # next to slow_effect.tick
func mitigate_damage(raw_damage: float) -> float:
	var effective_armor := armor + armor_buff.get_bonus_armor()
	return raw_damage * (100.0 / (100.0 + effective_armor))
```
(No `UpgradeManager.get_armor_bonus()` yet — added in P10 if D1 unblocks Vitality.)

`_apply_damage()` — same edit in 4 files:
- `scenes/player/player.gd`: `current_health = maxf(current_health - elemental.mitigate_damage(amount), 0.0)`
- `scenes/enemies/test_dummy.gd`, `patrol_dummy.gd`, `boss.gd`: first line `var mitigated := elemental.mitigate_damage(amount)`; use `mitigated` for `_total_damage_taken` and `_current_health -=`.
- If D7 = yes: `test_dummy.gd` / `patrol_dummy.gd` `_physics_process`: `var dot_damage := elemental.tick(delta)` + `if dot_damage > 0.0: _apply_damage(dot_damage)`.

Tests
- NEW `test/unit/test_armor_mitigation.gd` (0 armor = identity; 10 ≈ ×0.909; 100 = ×0.5; buff adds on top; Sever shreds base only).
- NEW `test/unit/test_armor_buff_effect.gd` (apply, tick expiry, refresh-not-stack).
- EDIT `before_each` (add `X.elemental.armor = 0.0` after `add_child_autofree`) in:
  `test/unit/test_player_death.gd`, `test/integration/test_boss_phase_transition.gd`,
  **`test/integration/test_run_manager_persistence.gd`** ← Design.md §3.1 missed this one; its lethal `_apply_damage(player.max_health)` calls stop being lethal at armor 10.

## P2 — Player death delay (§3)

`scenes/player/player.gd` — replace `_die()`; add `DEATH_TINT`, `DEATH_FADE_DELAY = 0.6`;
tint `visuals.modulate`, `await get_tree().create_timer(DEATH_FADE_DELAY).timeout`, then `died.emit()`.

Test fallout (add `await wait_for_signal(player, "died", 1.0)` before the assertion):
- `test_player_death.gd`: `test_lethal_damage_triggers_death`, `test_died_signal_fires_only_once`.
- `test_run_manager_persistence.gd`: `test_player_death_triggers_a_loss_record`, `test_death_after_run_already_finished_does_not_double_record` ← also missed by Design.md.

## P3 — Control resistance (§3.2)

NEW `scripts/reactions/cc_resistance.gd` (code in Design §3.2).
EDIT `scenes/enemies/enemy_stats.gd`: `enum Tier`, `tier`, `cc_free_hits = 999`, `cc_window_seconds = 8.0`.
EDIT `scripts/resources/enemies/ember_tide_boss_stats.tres`: `cc_free_hits = 3`.
EDIT `ElementalCombatant.gd`: `var cc_resistance := CCResistance.new()`, tick it, add `apply_control()` / `apply_control_slow()`, then swap these 6 lines:

| old | new |
|---|---|
| `disable_effect.apply(GRAZE_DURATION, GRAZE_DURATION)` | `apply_control(GRAZE_DURATION, GRAZE_DURATION)` |
| `other.disable_effect.apply(root_duration, base_root)` | `other.apply_control(root_duration, base_root)` |
| `other.disable_effect.apply(stagger_duration, base_stagger)` | `other.apply_control(stagger_duration, base_stagger)` |
| `slow_effect.apply(0.5 if sinh_tier2 else 0.7, 3.5 if sinh_tier2 else 2.5)` | `apply_control_slow(0.5 if sinh_tier2 else 0.7, 3.5 if sinh_tier2 else 2.5)` |
| `slow_effect.apply(0.4 if thua else 0.6, 5.0 if thua else 3.5)` | `apply_control_slow(0.4 if thua else 0.6, 5.0 if thua else 3.5)` |
| `scripts/reactions/steam_cloud.gd`: `combatant.disable_effect.apply(stun_duration, stun_duration)` | `combatant.apply_control(stun_duration, stun_duration)` |

(7th site — Caltrops — lands in P10f.) `debug_apply_test_effects()` stays direct.

Wiring, inside each `if enemy_stats != null:` block of `test_dummy.gd`, `patrol_dummy.gd`:
`elemental.cc_resistance.configure(enemy_stats.cc_free_hits, enemy_stats.cc_window_seconds)`;
`boss.gd` (unconditional, after `add_child(elemental)`): same with `boss_stats.`.

Tests: NEW `test/unit/test_cc_resistance.gd` (free hits → 0.5 → 0.0, window reset),
NEW `test/integration/test_control_resistance.gd` (Disable and Slow share one counter; immunity blocks both). Existing tests unaffected (default 999).

## P4 — First-time tutorial (§14)

NEW: `scenes/world/tutorial_room.tscn`, `scripts/world/tutorial_room.gd`.
EDIT `autoloads/save_manager.gd`: `"tutorial_completed": false` in `_default_data()`, `has_completed_tutorial()`, `mark_tutorial_completed()`.
EDIT `test/unit/test_save_manager.gd`: default false; mark persists to disk; mark twice = one write.

Notes for the agent (deviations from Design §14.2, with reasons):
- REACTION stage: advance on `dummy2.elemental.dot_effect.applied` (Molten from dagger Hỏa vs Kim), **not** `status_cleared` — Kim's own 5 s decay also emits `status_cleared` and would advance the stage falsely. If the hit lands in Kim's 1.5 s recharge gap nothing fires; the player just hits again.
- Hide dummy 2 and set `hurtbox.invulnerable = true` until the REACTION stage.
- Prompts: `Label`s under a `CanvasLayer` in the `.tscn` (world-space labels scroll with the camera). Small font — viewport is 576×324.
- Exit: reuse `RoomExit`, `locked = true` until DONE. Connect `player_entered` → `mark_tutorial_completed()` → `change_scene_to_file(NEXT_SCENE)`. `const NEXT_SCENE := "res://scenes/world/procedural_run.tscn"` for now; P6 flips it to `loadout_select.tscn`.
- Do not call RunManager from this scene.
- Playtest checklist (no GUT): stages advance in order; exit locked until DONE; second launch never reaches this scene (P8).

## P5 — Runes (§16)

NEW `scripts/items/rune_pickup.gd`. EDITS: `scripts/resources/weapons/weapon_stats.gd`, `scenes/player/player.gd`, `autoloads/hud.gd`, `test_dummy.gd`, `patrol_dummy.gd`, `boss.gd`, `scripts/world/room_controller.gd`.

**Simplification of Design §16's save fix.** Design proposes `_weapon_base_path` on Player, but direct assignment (`player.weapon = load(...)`, which `test_player_save_state.gd` does, and scene exports) bypasses it, and a dropped runed weapon re-picked from a pickup loses it. Instead put the base on the resource:
```gdscript
# weapon_stats.gd
@export var base_path: String = ""   # set only on rune-duplicated copies
func get_persistent_path() -> String:
	return resource_path if resource_path != "" else base_path
# player.gd apply_rune(): after duplicate → runed.base_path = target.get_persistent_path()
# to_save_state(): use weapon.get_persistent_path() for weapon_path / secondary_weapon_path
#   + "weapon_rune_element", "secondary_weapon_rune_element"   ← Design lists only the primary
# _load_weapon_path(path, rune_element, is_primary): as in Design §16, no Player-side base-path fields
```
Existing `test_player_save_state.gd` keeps passing unchanged.

RunePickup:
- Glyph: add an `ElementIndicator` child and call `set_element(rune_element)`, scaled ×2 — `_draw_*` are instance-private, so this reuses the glyphs with zero refactor.
- Drops: `roll_spirit_element` / `roll_boss_element` as in Design §16.1. Spawn with `get_tree().current_scene.add_child.call_deferred(rune)` (R3).
- `RoomController._check_cleared()` baseline drop: only if `not _spawn_points.is_empty()` (an empty room clears in `_ready()` and would drop instantly).
- Overwrite leaves the old rune behind (dropped copy uses the same `_spawn_dropped` shape).

Hud (`autoloads/hud.gd`):
- `enum OverlayKind { WEAPON, SKILL, RUNE }` replaces `_overlay_is_weapon`.
- `_open_overlay(pickup)` derives kind from the pickup's class → **update the 5 `Hud._open_overlay(pickup, true)` calls in `test_hud_pickup_overlay.gd`**.
- `_refresh_active_pickups()` also scans group `"rune_pickups"`; priority weapon > skill > rune.
- RUNE reuses the weapon slot names and confirms into `apply_rune()`.

Tests: NEW `test/unit/test_player_rune.gd` (apply, base_path, save/resume round trip both slots), NEW `test/integration/test_rune_pickup.gd` (proximity, default slot preference, overwrite drops old), plus roll-distribution sanity (seeded).

## P6 — Loadout Select (§15)

NEW: `scenes/ui/loadout_select.tscn`, `scripts/ui/loadout_select.gd`.
EDIT: `autoloads/run_manager.gd` (4 `pending_*` fields + `consume_pending_loadout(player)`), `scripts/world/procedural_run.gd`, `scenes/player/player.gd` (`would_duplicate_weapon`), `autoloads/hud.gd` (`_confirm_overlay_selection` guard + message label + greyed option), `scripts/world/tutorial_room.gd` (`NEXT_SCENE` → loadout_select).

- `procedural_run.gd._ready()`: `RunManager.consume_pending_loadout(player)` **before** `RunManager.start_run(...)`.
- Because of P5, `consume_pending_loadout` needs no base-path bookkeeping (assigned resources have real `resource_path`).
- `would_duplicate_weapon` must compare `get_persistent_path()` (not `resource_path`) or a runed copy would never register as a duplicate.
- Pools: starting five + `SaveManager.get_unlocked_*_paths()`, deduped, skip any path that fails `load()`.
- Start Run enabled only when all 4 picks are made, weapon 1 ≠ weapon 2, skill 1 ≠ skill 2 (compare by `resource_path`); inline message when blocked.
- Tests: NEW `test/unit/test_run_manager_loadout.gd` (consume assigns + clears; unset fields leave scene defaults), EDIT `test_hud_pickup_overlay.gd` (+ blocked-duplicate test using two `load()`ed `.tres` weapons), `test_player_weapon_swap.gd` (+ `would_duplicate_weapon` cases).

## P7 — Run Summary (§17)

NEW: `scenes/ui/run_summary.tscn`, `scripts/ui/run_summary.gd`.
EDIT `autoloads/run_manager.gd`:
- `_last_run_*` fields + scene change at the end of `_finish_run()` (Design §17).
- **`var _transition_on_finish: bool = true`** and gate `change_scene_to_file` on it. Design misses this: `test_run_manager_persistence.gd` calls `_finish_run()` and would otherwise switch scenes mid-test. Tests set it `false` in `before_each`, `true` in `after_all`.
- **`start_run()` must reset** `_current_room = null` and `_current_index = -1` before generating/resuming — after a scene change `_current_room` points at a freed node and `_advance()` would call `queue_free()` on it.
- Avoid the integer-division warning: `floori(seconds / 60.0)` and `int(seconds) % 60`.
- D6: add a "Main Menu" button (goes to `main_menu.tscn` once P8 exists; until then hide it).

## P8 — Main Menu (§18)

NEW: `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`.
EDIT `project.godot`:
```
-run/main_scene="res://scenes/world/test_arena.tscn"
+run/main_scene="res://scenes/ui/main_menu.tscn"
```
- `ConfirmationDialog` for Abandon; never calls `record_run_result()`.
- Optional (recommended): `Hud` shows HP bar/equip slots on every scene, including menus. Add `Hud.set_gameplay_visible(bool)` and call it from menu/summary/loadout `_ready()`; otherwise ignore.
- Update `README.md`: entry point is now the menu; `test_arena.tscn` is still runnable directly from the editor for dev.
- Playtest checklist: fresh save → Tutorial → Loadout → Run → die → Summary → Loadout; quit mid-room → menu shows Continue; Abandon → confirm → new run path; win path.

## P9 — Room pool 3 → 6 (§19)

NEW `scenes/world/rooms/room_d.tscn`, `room_e.tscn`, `room_f.tscn` (copy `room_b.tscn` as the template — it uses `path=` only).
EDIT `autoloads/run_manager.gd`: extend `ROOM_SCENE_PATHS`. `ROOMS_PER_RUN` stays 3.
OPTIONAL NEW `scripts/resources/enemies/{hoa,thuy,moc,tho}_spirit_stats.tres` (copy `kim_spirit_stats.tres`, change `element`) so runes/reactions get variety.

Authoring gotchas:
- `TestDummy`/`PatrolDummy` use the spawn point's `starting_element` for their `innate_element`, while attacks and rune drops use `enemy_stats.element`. **For every spirit, set both to the same element** or the spirit self-recharges the wrong element.
- Follow §19.1 checklist; ground 350–450 px; exactly one `PlayerSpawn`.
- NEW `test/integration/test_room_templates.gd`: for every path in `ROOM_SCENE_PATHS` + `BOSS_ROOM_SCENE_PATH`, `instantiate()` (don't add to tree) and assert root is `RoomController`, `find_child("Exit")` is a `RoomExit`, one child in group `player_spawn`, ≥1 `EnemySpawnPoint`.

## P10 — Qi / upgrade system (§4.8) — sub-phases, in order

Read D1–D4 and D8 first. Skip anything marked BLOCKED.

- **10a Foundations (unblocked).** NEW `autoloads/upgrade_manager.gd`; register in `project.godot` after `SaveManager`. State: `qi`, `ranks: Dictionary` keyed by reaction id. Add `reaction_id(pair) -> StringName` (maps a pair to one of the 10 names via `Elements.pair_is`; do NOT put this in the resolver). `add_qi()`, `reset()` (called from `RunManager.start_run()` and `_finish_run()`).
  `EnemyStats.qi_reward = 6.0`; set `12.0` in `kim_spirit_stats.tres` and any spirit stats, `50.0` in `ember_tide_boss_stats.tres`. One line in each enemy `_die()`: `UpgradeManager.add_qi(<stats>.qi_reward)`. Small Qi label on `Hud`. Tests: NEW `test/unit/test_upgrade_manager.gd` (call `reset()` in `before_each` — it's a persistent autoload).
- **10b Khắc Specialization (needs D3, D4).** Pre-dispatch rewrite in `handle_hit()` right after `Reactions.resolve()`: if `outcome == KHAC_PARTIAL` and `khac_graze_erased(pair)` → `result.outcome = KHAC_FULL_CLEAR` (the result object's field is mutable; resolver stays untouched). `var thua := … or UpgradeManager.khac_overwhelm_forced(result.reaction_pair)`. Tests in `test_elemental_combatant_reactions.gd` style; use a new file `test/integration/test_khac_specialization.gd`.
- **10c Sinh Rank 1.** `var sinh_tier2 := … or UpgradeManager.sinh_tier2_forced(result.reaction_pair)` in each of the 5 Sinh branches.
- **10d Vitality — BLOCKED on D1.** Would add `get_armor_bonus()` to `mitigate_damage`.
- **10e Weapon Might — BLOCKED on D1.**
- **10f Sinh Rank 2 branches**, easiest first. All read `sinh_favored_element(pair)` inside the existing branch after the tier-scaled base effect.
  1. **Cinder Bloom.** `Projectile.damage_amount` (default 0; add the `bonus_damage_dealt.emit` line in `_resolve_hit`). NEW `scripts/reactions/boulder.gd` (guard `is_instance_valid(target)` after the 0.4 s await). NEW `_spawn_cinderstorm_motes()` on `ElementalCombatant`.
  2. **Ore Surge.** `BaseProjectile._process`: replace `queue_free()` with virtual `_on_expired()` (default `queue_free()`). `Projectile`: `sunder_bonus_damage`, `leaves_hazard_on_expiry`. NEW `scripts/reactions/caltrop.gd` (distance check, uses `apply_control_slow(0.6, 2.5)` = 7th P3 call site). Clarification the doc lacks: a fragment that pierces (hit) something still reaches expiry — drop a Caltrop only if `_already_hit.is_empty()` ("doesn't connect").
  3. **Condensation.** Tidal Wave = distance AoE with `bonus_damage_dealt(10)` + `apply_control_slow(0.5, 3.5)`, bystander-excluded. NEW `scripts/reactions/rusted_chunk.gd` (spawn deferred, R3; uses P1's `armor_buff`).
  4. **Wildfire.** NEW `wildfire_overload.gd` (component on `ElementalCombatant`, ticked in `tick()`; hook the increment where a Hỏa hit resolves as `NO_REACTION` against an existing Hỏa status; re-apply the DoT with `+1.5*level` each level change; explosion includes `_source` on purpose, Design §1). NEW `wildfire_remnant.gd` (deferred spawn, global cap 4, per-attacker 1.0 s cooldown, local cluster cap blocks conversion).
  5. **Overgrowth (last, most complex).** `_apply_overgrowth_aoe()` returns `Array[ElementalCombatant]`. NEW `vine.gd` (own Hurtbox, `owner` set after `add_child`, deferred spawn) and `flower_turret.gd` (exclude `other.get_parent() is Player`; damage via `bonus_damage_dealt.emit(5.0)`). Note: enemy Mộc hits can also advance the Vine unless filtered by D4 — filter to `hit_data.source is Player`.
- Test file per class: `test_rusted_chunk`, `test_vine`, `test_wildfire_overload`, `test_wildfire_remnant`, `test_boulder`, `test_caltrop` under `test/integration/`.

## P11 — Close-out

- Design.md: §1 autoload list (+ `UpgradeManager`), §2 system map (Qi row → implemented), §4.8 headings "PLANNED" → "IMPLEMENTED (partial)" listing D1/D3 status, §11 (resolve armor item; add D7/D8 notes and the `TestDummy` DoT change), §10 (any new deviations).
- README.md: new entry point, controls table (`Tab` if D3 default used), test count.
- Full GUT run must be green; playtest checklists from P4 and P8 pass.