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
- [ ] P11 — Final verification and documentation closeout

## Verified current state

- `CCResistance` is implemented and wired through `ElementalCombatant`.
- `UpgradeManager` is registered as a script-only autoload and owns per-run Qi/rank state.
- Enemy kills award Qi, `RunManager` resets per-run state correctly, and the playtest harness remains debug-only.
- The HUD owns the room-cleared upgrade menu while the room is cleared, gated to the Tab key and the existing purchase APIs.
- The room-clear shop is now larger, easier to read, stays open for repeated purchases within the same room, and includes a paid Refresh Shop action.
- Procedural map layout persists and resumes as designed; legacy snapshots remain compatible.
- The implemented contract is now aligned with the active P10b scope and the verified runtime.

## Current scope: P10b

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

### Known blockers

- The room-cleared upgrade menu is complete for the active scope, but P11 remains the documentation and closeout pass.
- `PlaytestMode` remains a development tool and does not replace the final in-run room-clear flow.

## Verification gate

- [x] Full GUT suite: 230/230 tests passed, 537 assertions, 0 failures, 2 warnings.
- [x] Static diagnostics: no errors found in the workspace during the current check.
- [x] The repo is consistent with the currently implemented code and the active design contract in [Design.md](Design.md).

## Exact next item

- Move to P11 closeout: final docs and repo polish after the verified room-cleared upgrade menu is complete.

## Deferred work

- P11 remains the final verification/documentation step after the active P10b task is closed.
- Refine the tutorial room's layout and presentation in a later pass.
- Retired unused hand-placed normal-room scenes; procedural rooms remain the active run path.
- No further gameplay scope should be treated as complete without fresh verification.

## Key verification record

- Full suite command: `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- Result: 230 passing tests, 537 assertions, 0 failures, 2 warnings.
- Static analysis: no errors found in the workspace.
