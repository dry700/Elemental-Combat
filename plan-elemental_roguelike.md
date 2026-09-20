# Elemental Roguelike plan

## Current status

- [x] P0 — Repo hygiene and document cleanup
- [x] P1 — Armor mitigation and armor buff component
- [x] P2 — Player death delay
- [x] P3 — Control resistance and CC handling
- [ ] P4 — First-time tutorial flow
- [ ] P5 — Rune pickups, persistence, and HUD overlays
- [ ] P6 — Loadout selection and pending loadout consumption
- [ ] P7 — Run summary and finish-run transitions
- [ ] P8 — Main menu and startup scene update
- [ ] P9 — Room pool expansion to six rooms
- [ ] P10(a → f) — Qi / upgrade system
- [ ] P11 — Close-out documentation and final verification

## Phase 3 summary

Status: complete and validated.

Completed work:
- Shared `CCResistance` tracker added for diminishing-returns control immunity.
- `ElementalCombatant` now ticks, applies, and consumes the shared control budget through `apply_control()` and `apply_control_slow()`.
- Enemy/boss config now exposes `cc_free_hits` / `cc_window_seconds` defaults for tier-aware resistance budgets.
- The broad regression from the initial tracker implementation was traced to a compile-time class-resolution issue and fixed by switching to direct `preload()` instantiation.
- The full Godot GUT suite passed with the P3 implementation in place.

Verification evidence:
- Full suite: 190/190 tests passed.
- Assertions: 355.
- Static diagnostics: no errors reported.

Blockers / notes:
- The only real blocker during P3 was a class-loading regression in the new tracker, not a design issue in the control math itself.
- The fix is now in place and the project is stable again.
- Current phase boundary is deliberate: the next concrete implementation item is P4 tutorial flow.

## Exact next item

Implement P4 first-time tutorial flow:
- add the tutorial room and its stage progression
- add the save-manager tutorial completion flag and persistence path
- validate the first-time setup flow before moving on to runes and loadout selection

## Scope boundary

This roadmap intentionally excludes P4+ work from the current review window. The next phase starts after the P3 verification is recorded and the active scope is narrowed to the tutorial-flow work only.
