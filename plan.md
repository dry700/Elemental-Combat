# Current Implementation Plan

Source of truth: [Design.md](Design.md). Execution order and repository rules are tracked in [AGENT_PLAN.md](AGENT_PLAN.md).

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
- [ ] P12 — Run optimization and economy tuning (Phase 6 complete; Phase 7 next)

## Verified current state

- `CCResistance` is implemented and wired through `ElementalCombatant`.
- `UpgradeManager` is registered as a script-only autoload and owns per-run Qi/rank state.
- Enemy kills award Qi, `RunManager` resets per-run state correctly, and the playtest harness remains debug-only.
- Procedural rooms contain a shop station, a Restore option, a free baseline rune, and two distinct priced weapon stalls.
- Pressing F near the shop station opens its menu; pickups retain input priority over the shop interaction.
- Shop weapon purchases reject duplicates and insufficient Qi without equipping or charging.
- Qi, Restore use counts, and weapon prices are managed through `UpgradeManager` purchase APIs.
- Procedural map layout persists and resumes as designed; legacy snapshots remain compatible.
- Loop persistence and scaling (P12 Phase 6) is implemented: `RunManager` tracks loops, winning runs carry over Qi, upgrades, weapons, and runes; enemy HP and damage scale by `1.0 + 0.25 * (loop - 1)` via `EnemySpawnPoint`; death resets to loop 1.
- P12 remains active; Phase 6 is verified (256/256 tests passed) and Phase 7 economy numbers is next.

## Historical scope: P10b

### Implemented P10b support tools

- [x] Add debug-build-only `PlaytestMode` with invincibility, room regeneration, teleport, Qi grants, and upgrade purchases.
- [x] Keep Qi, rank purchases, and Vitality bonuses out of persistent run snapshots.
- [x] Add focused coverage for the panel, generated room transitions, save/resume, and upgrade manager state.
- [x] Add the room-cleared purchase menu in the combat HUD using the Tab input path while a room is cleared.
- [x] Verify the full GUT suite against the current worktree.

### Completed P10b work

- [x] Resolve D3 and D4: the normal room-cleared upgrade flow uses the Tab-based room-clear menu and keeps upgrades scoped to the player-owned state path.
- [x] Implement the normal room-cleared upgrade UI and gating flow.
- [x] Wire the verified purchase APIs into the HUD purchase path.
- [x] Add focused coverage for the menu gating and weapon-might purchase flow.
- [x] Expand the room-clear shop into a repeatable upgrade panel with a larger presentation and a Refresh Shop option.
- [x] Expose Sinh and Khắc Rank 1/Rank 2 purchases in the paged room-clear UI, including both Sinh favored-element choices.

### P10b closeout record

- `PlaytestMode` remains a development tool and does not replace the in-run shop flow.

## Verification gate

- [x] Full GUT suite: 256/256 tests passed, 1,657 assertions, 0 failures.
- [x] Targeted diagnostics: `test_loop_scaling.gd` clean, all 7 loop scaling unit tests passing.
- [ ] Final Design.md reconciliation: reserved for P12 Phase 9 as directed by the P12 plan.

## Exact next item

- Move to P12 Phase 7: apply economy numbers and tune costs/rewards.

## Deferred work

- P12 Phases 7–9 remain; update Design.md and run the final verification during Phase 9.
- Refine the tutorial room's layout and presentation in a later pass.
- Retired unused hand-placed normal-room scenes; procedural rooms remain the active run path.
- No further gameplay scope should be treated as complete without fresh verification.

## Key verification record

- Full suite command: `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- Result: 256 passing tests, 1,657 assertions, 0 failures. Two GUT warnings remain.
- Static analysis: changed run manager, save manager, enemy spawn point, and loop scaling test files are clean.
