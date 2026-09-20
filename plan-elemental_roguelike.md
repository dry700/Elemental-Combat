# Elemental Roguelike plan

## Current status

- [x] P0 — Repo hygiene and document cleanup
- [x] P1 — Armor mitigation and armor buff component
- [x] P2 — Player death delay
- [ ] P3 — Control resistance and CC handling
- [ ] P4 — First-time tutorial flow
- [ ] P5 — Rune pickups, persistence, and HUD overlays
- [ ] P6 — Loadout selection and pending loadout consumption
- [ ] P7 — Run summary and finish-run transitions
- [ ] P8 — Main menu and startup scene update
- [ ] P9 — Room pool expansion to six rooms
- [ ] P10(a → f) — Qi / upgrade system
- [ ] P11 — Close-out documentation and final verification

## Phase 2 summary

Status: complete and validated.

Completed work:
- Delayed player death fade/tint flow added in the player controller.
- `died` is emitted only after the 0.6s delay and the `_is_dead` guard remains intact.
- Player death and RunManager persistence tests were updated to await the delayed signal.
- Full Godot GUT validation passed with the current worktree.

Verification evidence:
- Full suite: 188/188 tests passed.
- Assertions: 347.
- Static diagnostics: no errors reported.

Blockers / notes:
- No blocker for P2. The implementation is scoped to the delayed death flow and leaves later gameplay phases out of scope.
- Current phase boundary is deliberate: the next concrete implementation item is P3 control resistance.

## Exact next item

Implement P3 control resistance and CC handling:
- add `CCResistance` and its state tracking
- configure default enemy tier / CC windows
- reroute gameplay slow and disable applications through the shared resistance system
- add focused tests for free-hit windows and control immunity
- rerun the full GUT suite before moving on

## Scope boundary

This roadmap intentionally excludes P3+ work from the current review window. The next phase starts after the P2 validation evidence is recorded and the active scope is narrowed to the control-resistance work only.
