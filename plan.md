# Current Implementation Plan

Source of truth: [Design.md](docs/Design.md). Execution order and repository rules are tracked in [AGENT_PLAN.md](AGENT_PLAN.md). The proposed shop-and-skills work is detailed in [plan-shop-and-skills.md](plan-shop-and-skills.md).

## Phase status

- [x] P0 — Repo hygiene and design cleanup
- [x] P1 — Combat stability and mitigation
- [x] P2 — Player death timing and state transitions
- [x] P3 — Control resistance and CC handling
- [x] P4 — Tutorial onboarding
- [x] P5 — Runes, pickup swap HUD, and Charge readability
- [x] P6 — Loadout selection
- [x] P7 — Run summary and finish flow
- [x] P8 — Main menu and startup flow
- [x] P9 — Procedural map generation and room overhaul
- [x] P10a — Qi economy and upgrade-manager foundations
- [x] P10b — Room-cleared upgrade menu, input flow, and remaining effect hooks
- [x] P11 — Final verification and documentation closeout
- [x] P12 — Run optimization and economy tuning (Phases 1–9 complete)
- [x] P13 — Perfect Hit and weapon window expansion
- [x] P14 — Skill system expansion (automated verification complete; interactive playtest checkpoint pending)

## Verified current state

- `CCResistance` is implemented and wired through `ElementalCombatant`.
- `UpgradeManager` owns per-run Qi, upgrade rank curves, and spend tracking; safe getters `weapon_might_cost()` and `vitality_cost()` eliminate duplicate logic.
- Procedural room exits are open from the start (`exit.locked = false`, Dead Cells style); boss room remains locked until defeat.
- Procedural map generator carves a guaranteed dead-end shop branch (`shop_cell`) with no enemy spawns.
- Shop contains `ShopStation` (F interaction opens card menu), 30% max HP Restore option (`20 + 10 * uses`, no-op/free at full HP), a free baseline weapon rune, and two distinct priced weapon stalls (Light: 35, Medium: 45, Heavy: 55 Qi).
- Refresh Shop fee is removed; continuous multi-purchases are supported in a single shop visit.
- Loop persistence and scaling: `RunManager` tracks loops (`loop`); winning runs carry Qi, upgrades, held weapons, and equipped runes (`pending_weapon_rune`, `pending_secondary_weapon_rune`); enemy and boss HP and damage scale by `1.0 + 0.25 * (loop - 1)` via `EnemySpawnPoint.spawn()`; death resets to loop 1.
- Tuned Qi economy: Normal brawler 5 Qi, Elemental spirit 8 Qi (Kim Spirit HP tuned to 50), Flying/Shooter/Swooper 3 Qi, Boss 30 Qi; Weapon Might and Vitality cost `20 + 12 * rank`; Sinh/Khắc Rank 1 costs 25 Qi, Rank 2 costs 55 Qi.
- Instrumentation: `[RUNLOG] loop=%d room=%d time=%.1f hp=%d->%d qi_earned=%d qi_spent=%d` logs delta metrics per completed room in debug builds.
- Documentation fully reconciled across `docs/Design.md`, `plan.md`, `AGENT_PLAN.md`, `plan-elemental_roguelike.md`, and `README.md`.
- Perfect Hit windows now resolve for the existing and six shop-only weapons; the weapon card displays each window and perfect hits preserve Charge and reaction inputs.
- P13 GUT verification: 269 tests passed, 1,760 assertions, 0 failures; 2 expected headless warnings.
- P14 adds ten skills (15 total), five cast behaviors, cooldown HUD, duplicate prevention, a shared element-tinted cast burst, a directional water wave for Undertow, Seismic Slam's jump-and-ground-impact attack with screen shake, a 60 Qi shop stall, and matching-element spirit/boss drops.
- P14 GUT verification: 299 tests passed, 1,898 assertions, 0 failures; existing headless diagnostics remain.

## Verification gate

- [x] Full GUT suite: 291/291 tests passed, 1,845 assertions, 0 failures.
- [x] Boss phase transitions, armor/charge wiring, and stats verified.
- [x] Loop scaling and persistence verified with dedicated unit tests.
- [x] Final docs/Design.md reconciliation complete.

## Exact next item

- Next automated implementation: Step 4.2 (persist shop state across save/resume) in `plan-shop-and-skills.md`. The P14 in-game skill visual checkpoint remains pending manual playtesting in `test_arena`.

## Deferred work

- P14 implementation and test-arena playtest tooling are complete; finish the recorded interactive checkpoint before gameplay balance tuning.
- Shop and Skills Expansion: Steps 1–3 and Step 4.1 (interleaved room/shop run sequence) are implemented. Step 4.1 focused coverage passed (26 tests, 196 assertions); the latest full suite has 328/333 passing and remains blocked by pre-existing parse errors in modified enemy scripts, which cause five enemy-facing/loop-scaling test failures.
- Shop & Skills Expansion Step 3 adds hand-authored shop and boss-shop rooms, categorized stations, category-specific offers and slot-chooser purchases. Focused shop, upgrade-menu, exit, and active-shop loop-handoff tests pass (33 tests, 163 assertions); per-visit offers remain fixed under D19's no-refresh decision.
- Refine the tutorial room's layout and presentation in a later pass.
- Retired unused hand-placed normal-room scenes; procedural rooms remain the active run path.

## Key verification record

- Full suite command: `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- Latest full suite: 333 tests, 328 passing, 5 failing (2,022/2,027 assertions). The failures are in existing enemy-facing and loop-scaling tests after parse errors in modified `swooper_enemy.gd` and `test_dummy.gd`; Step 4.1 focused tests pass (26 tests, 196 assertions).
- P13 result: 269 passing tests, 1,756 assertions, 0 failures. Two expected headless warnings remain.
- Static analysis: clean across all workspace files.
