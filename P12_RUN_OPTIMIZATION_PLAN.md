# P12 — Run Optimization (agent brief)

Source of truth for architecture: `docs/Design.md`. Execution log: `plan.md` / `AGENT_PLAN.md`.
This file is a task list for a CLI coding agent. Do the phases **in order**; each phase must leave the
game runnable and the full GUT suite green before moving on. One commit per phase.

## 0. Rules for the agent

- Baseline first: run the full suite and record the count (last known: 230 tests / 537 assertions, 2 warnings).
  ```
  & "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
  ```
- Follow docs/Design.md §1 and §12: composition over inheritance, no new base classes, never edit `reaction_resolver.gd`,
  never mutate a shared `.tres` at runtime (`duplicate()` first), no real physics AoE.
- Any test touching `SaveManager` or `Player.swap_weapon/swap_skill` must use `test/helpers/save_test_isolation.gd`.
- Keep these names/signatures stable (existing tests call them): `Hud._open_overlay`, `_overlay_selected_primary`,
  `_confirm_overlay_selection`, `_on_overlay_option_gui_input`, `_can_open_overlay`, `_open_upgrade_menu`,
  `_confirm_upgrade_selection`, `_set_upgrade_selection`, `_all_upgrade_options`, `_upgrade_page_offset`.
- Do not hand-edit `.uid` files. New scripts get a `.uid` when Godot imports them; commit those.
- Every phase: update/add tests listed in its "Tests" line. Update `docs/Design.md` only in Phase 9 (one pass).
- Qi/upgrade state stays out of meta-progression. It may be written to the in-progress run snapshot only
  (already the case via `upgrade_state`).

## 1. Decisions locked

| Topic | Decision |
|---|---|
| Room exit | Normal procedural rooms: exit **open from the start** (Dead Cells style). Boss room: locked until boss dies. |
| Shop | **Every normal room** has one shop on a guaranteed dead-end branch. Boss room has none. |
| Sustain | Paid **Restore** card in the shop: heals 30% max HP, 20 Qi, +10 Qi per use within a run. No other healing. |
| Weapons | Shop weapon rack: 2 weapons per shop, priced by weight, paid in Qi. |
| Loops | Upgrades, Qi and runes **carry across loops**; enemy/boss HP and damage scale `1 + 0.25 * (loop - 1)`. Loss resets everything. |
| Qi economy | Cut rewards and raise costs moderately (numbers in Phase 7). |
| Refresh Shop | Removed. |

Assumptions the agent should keep (flag in the PR if they change): the boss room has no shop; Qi earned from the
boss carries into the next loop's shops; skills are not sold (future work).

## 2. Targets (what "optimized" means)

- Run length 8–12 minutes (3 normal rooms + boss).
- Arrive at boss at 40–60% HP on average.
- Boss fight 25–40 s.
- Player can afford roughly two fully mastered reactions, or Restore + one weapon + stat upgrades, per run.

---

## Phase 1 — Bug fixes (no design decisions)

**T1.1 Boss stats wiring**
- `scripts/resources/enemies/boss_stats.gd`: add
  `@export var armor: float = 10.0` and `@export_range(1, 3) var innate_charge: int = 1`.
- `scenes/enemies/boss.gd` `_ready()`: replace the duck-typed lines with
  `elemental.armor = boss_stats.armor`, `elemental.innate_charge = boss_stats.innate_charge` (set before `add_child(elemental)`),
  and `elemental.apply_starting_status(boss_stats.element, boss_stats.innate_charge)`.
- `scripts/resources/enemies/ember_tide_boss_stats.tres`: move `qi_reward` below `script`; set
  `max_health = 700.0`, `armor = 15.0`, `innate_charge = 2`, `phase_2_attack_cooldown_multiplier = 0.65`
  (leave `qi_reward` for Phase 7).
- Tests: extend `test_boss_phase_transition.gd` — armor and charge read from stats; existing tests unchanged
  (they zero armor after `add_child_autofree`).

**T1.2 Vitality applies immediately**
- `autoloads/hud.gd` `_confirm_upgrade_selection()`, `"vitality"` case: after a successful purchase and if `_player != null`,
  `_player.max_health += 10.0; _player.current_health = minf(_player.current_health + 10.0, _player.max_health)`
  (mirrors `PlaytestMode._on_buy_vitality_pressed`).
- Tests: in `test_room_clear_upgrade_menu.gd`, assert player `max_health` increases by 10 after buying.

**T1.3 Remove Refresh Shop**
- `hud.gd`: delete `ROOM_CLEAR_REFRESH_COST`, the `"refresh"` append in `_rebuild_all_upgrade_options`, the `"refresh"` case
  in `_confirm_upgrade_selection`, and the unused `_upgrade_option_types` seeding in `_build_upgrade_menu`.
- Tests: rewrite `test_room_clear_shop_allows_multiple_purchases_and_refresh` (drop the refresh half, keep the multi-purchase half).

**T1.4 Resume order bug**
- `autoloads/run_manager.gd` `_resume_from_save()`: call `UpgradeManager.apply_save_state(...)` **before**
  `_player.apply_save_state(...)`. Currently the Player adds `vitality_hp_bonus()` while it is still 0, so resumed runs lose the HP bonus.
- Tests: `test_run_manager_persistence.gd` — save with vitality rank 2, resume, assert `player.max_health == base + 20`.

**T1.5 Test hygiene**
- `test/unit/test_room_clear_upgrade_menu.gd` `before_each`: the `return` after the `push_error` block is unconditional,
  so everything after it never runs. Fix the indentation/logic.
- Delete the stray `scripts/resources/weapons/training_staff (1).tres` if `training_staff.tres` loads fine in the editor.

**Done when:** suite green; boss has real armor/charge in a manual run.

---

## Phase 2 — UpgradeManager economy API

All in `autoloads/upgrade_manager.gd` (+ Hud consumers).

- Add `weapon_might_cost() -> float` and `vitality_cost() -> float`; use them inside `purchase_*` **and** in
  `Hud._rebuild_all_upgrade_options` (currently the formula is duplicated there as `BASE + rank * 10.0`).
- Add `spend_qi(amount: float) -> bool` (deduct, emit `qi_changed`, track spent total; return false if insufficient).
- Add Restore: `RESTORE_BASE_COST = 20.0`, `RESTORE_COST_STEP = 10.0`, `RESTORE_HEAL_FRACTION = 0.3`,
  `_restore_uses: int`, `restore_cost() -> float`, `purchase_restore() -> bool` (deducts Qi, increments uses; healing is done by Hud).
- Add counters `qi_earned_total` / `qi_spent_total` (incremented in `award_qi` / on every spend; cleared in `reset()`).
  Used by Phase 8 logging.
- Include `_restore_uses` (and the two counters if you want) in `to_save_state()` / `apply_save_state()` (missing key → 0).
- New cost numbers are applied in Phase 7; here just move them behind the getters.
- Tests: `test_upgrade_manager.gd` — `spend_qi`, `restore_cost` escalation, reset clears uses, save/restore round trip.

---

## Phase 3 — Open gate

- `scripts/world/room_controller.gd`: add `@export var exit_open_from_start: bool = false`; in `_ready()` use
  `exit.locked = not exit_open_from_start and not _spawn_points.is_empty()`.
- `scripts/world/map_gen/procedural_room_controller.gd`: its `_ready()` has its **own copy** of the lock logic —
  set `exit.locked = false` there (normal procedural rooms only). Boss room (`room_boss.tscn`, plain `RoomController`) is untouched.
- Set `_baseline_rune_spawned = true` in `ProceduralRoomController._ready()` so the old "room cleared" baseline rune does not fire
  (Phase 5 spawns it free in the shop instead). Boss room keeps the existing behaviour.
- `autoloads/run_manager.gd` `_on_room_cleared()`: remove the auto-open of the upgrade menu (keep the print; the signal stays).
- `autoloads/hud.gd`: remove the Tab-opens-menu path (`_can_open_upgrade_menu` / `_is_room_cleared_for_upgrade` / `_debug_room_clear_state`)
  — replaced in Phase 5 by shop-station proximity. Keep `_set_debug_room_clear_state` as a no-op or delete with its test callers.
- Tests: new — procedural room instantiated in tree has `exit.locked == false`; boss-room scene still locked (spawn point present).
  Rewrite `test_room_clear_upgrade_menu.gd` to open via `hud._open_upgrade_menu()` directly.

**Done when:** you can walk straight to the exit of a fresh procedural room with enemies alive.

---

## Phase 4 — Generator: guaranteed dead-end shop

Files: `scripts/world/map_gen/map_generator.gd`, `procedural_room_controller.gd`.

**Data**
- `var shop_cell: Vector2i = Vector2i(-1, -1)`. Serialize in `to_dict()` as `"shop_cell": [x, y]`; in `load_layout()` read it
  if present, else leave `(-1, -1)` (legacy snapshots stay loadable, just no shop). Validate it is in `grid`.
- `build_map()`: `chunk_node.add_to_group("shop_chunk")` when `cell == shop_cell`.

**Algorithm** (replaces the random 0–1 branch and `_carve_branch` use)
1. Split `generate()` into `_generate_main_path() -> Array` (existing logic up to `finish_cell`) and `_try_place_shop(path, allow_vertical) -> bool`.
2. `_try_place_shop`: candidates = every path cell **except** `start_cell` / `finish_cell` × 4 directions where the neighbor is in bounds and not in `grid`.
   - Skip vertical directions unless `allow_vertical`.
   - Score: +2 for horizontal, +1 if `chunk_pool.has(grid[parent] | dir)` (parent keeps an authored chunk with enemies). Pick randomly among the top score.
   - Carve one step: `grid[parent] |= dir`, `grid[shop] = opposite(dir)`, `shop_cell = shop`.
   - Set `chunk_paths[shop_cell] = ""` right away. `build_map()` then skips the pool lookup (saved-assignment path) and uses `_build_fallback_chunk`,
     so the shop can never roll `chunk_start` / `chunk_end` (mask 2 / 8) with enemies.
3. `generate()`: loop up to 8 attempts of path + shop (horizontal only); on the last attempt allow vertical. Never leave a room without a shop.
4. Why exclude start/finish: their masks match authored chunks; adding a door changes the mask.
5. Why horizontal preferred: side doors sit at floor level in the fallback chunk, so the shop is flat and walkable.
6. Vertical shop (rare last resort): in `_build_fallback_chunk`, for a `DIR_DOWN`-only door add a one-way platform over the hole
   (`add_plat(h_door_start, 18.0, door_width_tiles)`) so the shop has a floor; `DIR_UP` already gets the staircase.
- Remove/keep `_carve_branch` only if still used; do not leave dead code.
- Tests: `test_map_generator_snapshot.gd` — round trip includes `shop_cell`; legacy dict without it loads. New generator test over 100 runs:
  exactly one shop, in `grid`, not start/finish, single-bit mask, `chunk_paths[shop] == ""`, reachable from start (BFS over mask bits).
- Optional: add a "Shop" teleport target in `get_playtest_cells` / `PlaytestMode`.

---

## Phase 5 — Shop contents (station, Restore, weapon rack, free rune)

**Status: Complete** — shop station input, Restore, priced weapon stalls, and shop population
are covered by the full GUT run (249 tests, 1,627 assertions, 0 failures).

**T5.1 `ShopStation`** — new `scripts/items/shop_station.gd`, `class_name ShopStation extends Area2D`.
Built in code like `WeaponPickup`: `monitoring = true`, `collision_layer = 0`, `collision_mask = 1`, circle radius ~14, joins group `shop_stations`,
tracks `_player_in_range`, draws a simple glyph and `"F Shop"` when in range.

**T5.2 Populate the shop** — `ProceduralRoomController._ready()`, after spawn points are found:
`_populate_shop()` finds the child in group `shop_chunk` and adds (local coords, `floor_y = CHUNK_H - 32 - 15`, pickups at `floor_y + 9`):
- `ShopStation` at `x = CHUNK_W / 2`
- Free baseline rune: `RunePickup` with `RuneRoller.default().roll(random element, RuneData.Target.WEAPON)` at `x ≈ 160`
- Two `ShopWeaponPickup` stalls at `x ≈ 100` and `x ≈ 316` (≥ 3 tiles from the station so prompts never overlap)
- If no `shop_chunk` exists (legacy snapshot), skip silently.
- Shop stock is not persisted; resuming re-rolls it (acceptable, enemies also respawn).

**T5.3 Hud opens the menu from the station**
- In `_refresh_active_pickups()` also find `_active_shop_station` from group `shop_stations`.
- In `_handle_room_clear_upgrade_input()`: if the menu is closed and `_active_shop_station != null` and no weapon/skill/rune pickup is active and
  `_can_open_overlay()` is true, pressing `pickup` (F) calls `_open_upgrade_menu()`. Menu close/up/down/confirm handling stays as is.
- Weapon/skill/rune pickups keep priority for F.

**T5.4 Restore card**
- `_rebuild_all_upgrade_options()`: insert `{type "restore", label "RESTORE", desc "Heal 30% max HP\nUsed N times\nCost: X Qi", cost restore_cost()}`
  at **index 2** (after Vitality) so existing index-based tests for 0 and 1 still hold.
- `_confirm_upgrade_selection()` `"restore"` case: if `_player == null` or HP is already full, return **without charging**
  (desc shows `[Full HP]`); else `purchased = UpgradeManager.purchase_restore()` and heal
  `_player.current_health = minf(current + max_health * RESTORE_HEAL_FRACTION, max_health)`.

**T5.5 Weapon rack**
- `Player.would_duplicate_weapon(is_primary, candidate) -> bool` per docs/Design.md §15.4 (compare `resource_path`, ignore empty paths).
- `scripts/items/shop_weapon_pickup.gd`: `class_name ShopWeaponPickup extends WeaponPickup`, `var price: int`.
  - `_do_pickup(player, is_primary)`: return if `player.would_duplicate_weapon(...)`; return if `not UpgradeManager.spend_qi(price)`; else `super(...)`.
  - `_draw()`: `super._draw()`, then `"F %d Qi"` (dim when unaffordable).
- Stock rule (helper on `ProceduralRoomController` or a small static `ShopStock`): pool = `LoadoutSelect.STARTING_WEAPON_PATHS` + `SaveManager.get_unlocked_weapon_paths()`,
  minus weapons the player already holds, minus any `runed_*` fixtures; pick 2 distinct. Price by weight: LIGHT 35, MEDIUM 45, HEAVY 55 (placeholders).
- **Do not stock `runed_greatsword.tres` / `runed_dagger.tres`**: `runed_greatsword.tres` has `combo_steps = null` (modulo-by-zero in
  `_current_combo_step_data`) and no textures.
- Swapped-out weapons drop as plain free `WeaponPickup`s (existing `_spawn_dropped`); that is fine.

**Tests**
- `ShopWeaponPickup`: insufficient Qi → not equipped, Qi unchanged; sufficient → equipped and Qi deducted; duplicate → blocked, Qi unchanged.
- Restore: heals and charges; at full HP does not charge; cost escalates.
- Hud: station in range + F opens the menu; weapon pickup in range takes priority.
- Procedural room: shop chunk contains exactly one station, two stalls, one rune.

---

## Phase 6 — Loop persistence and scaling

**T6.1 RunManager**
- `var loop: int = 1`, `var _continue_loop: bool = false`.
- `start_next_loop()`: if `skip_scene_transitions` return; set `_continue_loop = true`, `loop += 1`, then change scene.
- `_finish_run()`: on `"win"` do **not** call `UpgradeManager.reset()` (keep Qi/ranks for the next loop); on `"loss"` reset upgrades and set `loop = 1`.
- `start_run()` fresh branch: `if _continue_loop: _continue_loop = false` else `UpgradeManager.reset(); loop = 1`.
- Resume: save `loop` in the snapshot (`SaveManager.save_in_progress_run(..., loop: int = 1)` as a trailing default param so existing callers/tests keep working) and restore it in `_resume_from_save`.

**T6.2 Carry weapons/runes**
- Add pending rune dicts next to `pending_*_path` (`pending_weapon_rune`, `pending_secondary_weapon_rune`, each `RuneData.to_dict()` or empty).
  `_finish_run("win")` fills them; `consume_pending_loadout()` applies `RuneData.from_dict()` and clears them.

**T6.3 Enemy scaling**
- `scripts/world/enemy_spawn_point.gd` `spawn()`: `var s := 1.0 + 0.25 * (RunManager.loop - 1)`; when `s > 1.0`:
  - `enemy_stats` / `boss_stats`: assign `stats.duplicate()` and multiply `max_health` and `damage` (never mutate the shared `.tres`).
  - Nodes with their own exports (`FlyingEnemy`, `ShooterEnemy`, `SwooperEnemy`): multiply `enemy.max_health` and `enemy.damage` when `"max_health" in enemy`.
  - All before `add_child` (comment in the file explains why).
- Tests: loop 3 → stats ×1.5, the shared resource unchanged; loop 1 → untouched; `start_next_loop` increments and keeps upgrades; loss resets both.

---

## Phase 7 — Economy numbers

Apply, then tune from Phase 8 logs. One change at a time.

| Item | Now | New |
|---|---|---|
| Neutral brawler `qi_reward` | 10 | 5 |
| Kim spirit `qi_reward` | 10 | 8 |
| Flyer / shooter / swooper `@export qi_reward` | 5 | 3 |
| Boss `qi_reward` | 50 | 30 |
| Kim spirit `max_health` | 100 | 50 |
| Weapon Might / Vitality cost | 15 + 10/rank | 20 + 12/rank |
| Reaction Rank 1 / Rank 2 | 20 / 45 | 25 / 55 |
| Restore | — | 20 + 10/use, heals 30% |
| Weapon stall prices | — | 35 / 45 / 55 |

Update the constants/tests that assert old costs (`test_upgrade_manager.gd`, `test_room_clear_upgrade_menu.gd` Qi totals and cost expectations;
prefer finding options by `type` over fixed indices).

---

## Phase 8 — Instrumentation

- In `RunManager._advance()` (and `_finish_run`), when `OS.is_debug_build()`, print one line per completed room:
  `[RUNLOG] loop=%d room=%d time=%.1f hp=%d->%d qi_earned=%d qi_spent=%d`
  using `_elapsed_sec` deltas, player health snapshots, and `UpgradeManager.qi_earned_total/qi_spent_total` deltas.
- No new autoload, no persistence.

---

## Phase 9 — Docs and final verification

**Status: Complete** — Documentation reconciled across `docs/Design.md`, `plan.md`, `AGENT_PLAN.md`, `plan-elemental_roguelike.md`, and `README.md`. Full GUT test suite is completely green (257/257 passing tests, 1,658 assertions, 0 failures).

- `docs/Design.md`: §4.8.1 (reward table), §4.8.2 (costs, Restore), §6 (open gate, loop persistence, scaling), §8 (shop station input),
  §19 (shop branch algorithm, shop contents), §11 (move resolved items). Stale "Refresh Shop" references resolved.
- `plan.md`, `plan-elemental_roguelike.md`, `README.md`: P12 marked complete, test counts updated (257 passing tests, 1,658 assertions).
- Full suite green; zero errors in the Godot output.

## Playtest checklist (manual, use F12: invincibility, teleport, +1000 Qi)

1. Generate 10 rooms (F12 → regenerate): every one has a reachable dead-end shop; no shop ever contains enemies; start/finish chunks unchanged.
2. Walk to the exit with enemies alive: exit is open. Boss room exit stays locked until the boss dies.
3. Shop: F opens menu near the station only; Restore at full HP does not charge; weapon stall F → slot overlay → buys; duplicates blocked.
4. Quit mid-run and resume: Vitality HP, Qi, loop number restored.
5. Beat boss → Continue: loop 2 keeps upgrades/Qi/weapons/runes; enemies visibly tougher; loss returns to loop 1 with nothing.
6. Read `[RUNLOG]` over 5 runs; compare with the Targets section; tune Phase 7 numbers.

## Risks / watch list

- `ProceduralRoomController._ready()` duplicates `RoomController._ready()` logic — keep both in sync (Phase 3).
- Parent of the shop branch may fall back to an empty procedural chunk if its new mask has no authored chunk; the scoring avoids this when possible.
- Boss at 700 HP/armor 15 is a starting guess; tune `max_health` to hit 25–40 s.
- Restore + open gate means skipping fights lowers Qi (and healing). That tension is intended; confirm it feels fair in logs.
- Not in scope: skill shop, skill runes, richer run summary, dual-element boss attacks, boss move set.
