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

### P10 design clarification

- Reaction specializations are one-time rank purchases: Rank 1 and Rank 2
	are the maximum for each named reaction.
- Vitality (maximum HP) and Weapon Might (Damage) are repeatable purchases.
	Each category tracks its own rank and increases its next Qi price after
	every successful purchase.
- Exact HP/Damage increments and escalating price curves are tuning work for
	the playable upgrade menu; failed purchases must not change Qi or rank.
- [ ] P11 — Close-out documentation and final verification

## New progression decision

- A run is an endless sequence of loops, each containing three normal
	rooms followed by one boss; the first-time tutorial is excluded.
- Boss defeat shows a short summary with a proceed/stop choice.
- Proceeding starts the next loop with increased enemy/boss stats and one
	newly unlocked move for that loop's enemies and boss.
- The full loadout UI is pickup-driven for weapon/skill slot selection,
	not shown automatically between loops.
- Runtime implementation belongs in the relevant P5-P7 work and must be
	verified before these rules are marked complete.

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
