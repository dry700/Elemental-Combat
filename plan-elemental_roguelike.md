# Elemental Roguelike plan

## Current status

- [x] P0 — Repo hygiene and document cleanup
- [x] P1 — Armor mitigation and armor buff component
- [x] P2 — Player death delay
- [x] P3 — Control resistance and CC handling
- [x] P4 — First-time tutorial flow
- [ ] P5 — Rune pickups, persistence, and HUD overlays
- [ ] P6 — Loadout selection and pending loadout consumption
- [ ] P7 — Run summary and finish-run transitions
- [ ] P8 — Main menu and startup scene update
- [ ] P9 — Room pool expansion to six rooms
- [ ] P10(a → f) — Qi / upgrade system
- [ ] P11 — Close-out documentation and final verification

## Phase 4 summary

Status: complete and validated.

Completed work:
- Added the tutorial room scene and controller with stage prompts and room exit gating.
- Persisted the tutorial completion state via `SaveManager` with an idempotent write guard.
- Hooked the tutorial exit to mark completion and redirect to the procedural run entry scene.
- Verified the save-contract behavior and the core project suite after the tutorial flow landed.

Verification evidence:
- Full suite: 191/191 tests passed.
- Assertions: 359.
- Static diagnostics: no errors reported.

Blockers / notes:
- No blockers remained during P4; the tutorial flow was implemented and validated without regressions.
- The work is intentionally scoped to the first-time onboarding flow and the save flag only.
- Current phase boundary is deliberate: the next concrete implementation item is P5 rune pickups.

## Exact next item

Implement P5 rune pickups and HUD persistence flow:
- add the rune pickup and rune application path
- update the player save/load pathing for rune-equipped weapons
- validate the pickup flow before moving on to loadout selection

## Scope boundary

This roadmap intentionally excludes P5+ work from the current review window. The next phase starts after the P4 verification is recorded and the active scope is narrowed to the rune-pickup work only.
