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
- In-run pause menu: Esc pauses gameplay and displays both equipped weapon and skill slots; Continue resumes, while Save and Exit persists a resumable snapshot and returns to the main menu. Save failures keep the pause menu open.
- Step 7 energy system and Maid's Sweep: each energy-gated skill has a per-skill meter filled only by player-triggered reactions involving its element (Vũ and enemy-caused reactions excluded; 5/10/20 by tier); Maid's Sweep consumes the full meter to apply a refresh-only Thổ weapon buff (×1.4 damage, ×1.5 reach/hitbox, ~15s) read only at the hitbox-config site, never on raw Charge. Meters persist across save/resume; the HUD shows a radial energy ring with a non-color full cue.

## Verification gate

- [x] Full GUT suite: 291/291 tests passed, 1,845 assertions, 0 failures.
- [x] Boss phase transitions, armor/charge wiring, and stats verified.
- [x] Loop scaling and persistence verified with dedicated unit tests.
- [x] Final docs/Design.md reconciliation complete.

## Exact next item

- Next automated implementation: Step 9 (support enemies, starting with the shielder) in `plan-shop-and-skills.md`. Step 8 (heavy hit for bow, greatsword, and hammer) is implemented and focused `test_heavy_attack.gd` passes (6 tests, 32 assertions). Steps 1–7, including shop-state persistence, are implemented. The P14 in-game skill visual checkpoint remains pending manual playtesting in `test_arena`.

## Deferred work

- P14 implementation and test-arena playtest tooling are complete; finish the recorded interactive checkpoint before gameplay balance tuning.
- Shop and Skills Expansion: Steps 1–3, Step 4.1 (interleaved room/shop run sequence), Step 4.2 (shop-state persistence), Step 5 (reaction-upgrade visual clues), Step 6 (Maid's Guard one-hit shield), and Step 7 (energy system and Maid's Sweep) are implemented.
- Shop & Skills Expansion Step 5 (reaction-upgrade visual clues) is implemented. Its focused UpgradeManager, shop HUD, combat reaction, and run-persistence tests pass. At Step 5 completion, the suite had 340/340 tests and 2,109 assertions; the SpriteVisual fallback error is expected by its negative-path test.
- Step 6 (Maid's Guard) passes 7 focused tests with 27 assertions. Latest full suite: 355/355 tests, 2,236 assertions, 0 failures.
- Shop & Skills Expansion Step 3 adds hand-authored shop and boss-shop rooms, categorized stations, category-specific offers and slot-chooser purchases. Focused shop, upgrade-menu, exit, and active-shop loop-handoff tests pass (33 tests, 163 assertions); per-visit offers remain fixed under D19's no-refresh decision.
- Refine the tutorial room's layout and presentation in a later pass.
- Retired unused hand-placed normal-room scenes; procedural rooms remain the active run path.

## Key verification record

- Full suite command: `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- Latest full suite: 370 tests passed, 2,280 assertions, 0 failures. The SpriteVisual fallback error is expected by its negative-path test; headless shutdown still reports resource diagnostics.
- P13 result: 269 passing tests, 1,756 assertions, 0 failures. Two expected headless warnings remain.
- Static analysis: clean across all workspace files.
