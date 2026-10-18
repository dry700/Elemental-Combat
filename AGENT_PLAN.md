# AGENT_PLAN.md

This is the working checklist for the project. It remains intentionally lightweight while the detailed mechanics live in [Design.md](Design.md).

## Status legend

- [ ] Not started
- [ ] In progress
- [x] Complete

## Rules

- Work on one phase at a time.
- Do not mark a task complete without the relevant verification result.
- Keep design decisions and blockers in the notes section.
- Use [Design.md](Design.md) as the implementation source of truth.

## Phase order

P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P11 → P12 → P13 (Perfect Hit) → P14 (Skill system)

## Phase status

### P0 — Repo hygiene and design cleanup
- [x] Remove stale resource fragments and invalid authoring leftovers.
- [x] Clean up drift between docs and implementation.
- [x] Confirm the repository is stable before gameplay work resumes.

### P1 — Combat stability and mitigation
- [x] Apply armor mitigation consistently in each `_apply_damage()` path.
- [x] Implement `ArmorBuffEffect` with refresh-only semantics.
- [x] Verify enemy DoT application follows the design intent.

### P2 — Player death timing and state transitions
- [x] Delay the player `died` signal so the tint is visible before scene transition.
- [x] Update assertions to wait on the `died` signal before checking emission state.
- [x] Verify run-manager loss tracking does not double-record outcomes.

### P3 — Control resistance and CC handling
- [x] Add `CCResistance` and wire it through `ElementalCombatant`.
- [x] Replace direct control-effect applications with the shared resistance chokepoints.
- [x] Configure enemy default and boss-specific CC thresholds correctly.
- [x] Verification: CC tests and related integration tests pass.

### P4 — Tutorial onboarding
- [x] Add the tutorial room and controller.
- [x] Implement stage progression and prompt gating.
- [x] Persist tutorial completion in `SaveManager` with an idempotent write path.
- [x] Route exits to the correct scene target.

### P5 — Runes, pickup swap HUD, and Charge readability

#### P5a — Rune data and pickup foundation
- [x] Add `RuneData`, `RuneModifierDef`, and `RuneRoller`.
- [x] Add targeted `RunePickup` behavior and `rune_pickups` grouping.
- [x] Wire room, boss, and spirit drops to full rune rolls.
- [x] Verification: focused rune tests pass.

#### P5b — Player slot runes and persistence
- [x] Add `weapon_rune` and `secondary_weapon_rune` to `Player`.
- [x] Add `apply_rune`, `can_apply_rune`, and slot-aware weapon swap logic.
- [x] Persist rune dictionaries in save/apply state with compatibility guards.
- [x] Verification: rune, swap, and save/load tests pass.

#### P5c — Pickup swap HUD, inputs, and font
- [x] Add Tab-based swap and I-based inspect flow in `InputSetup`.
- [x] Keep F direct-equip non-destructive and never overwrite valid slots.
- [x] Implement chooser cards, rune inspect pane, and Monogram theming.
- [x] Verification: overlay and pick-up prompt tests pass without signature churn.

#### P5d — Charge and Vũ readability
- [x] Add `ElementalStatus.set_charge()` and the charge-change signal.
- [x] Render 1–3 Charge pips in `ElementIndicator`.
- [x] Add the reversed-hit popup and playtest checkpoint.
- [x] Verification: status and Vũ reaction tests pass.

### P6 — Loadout selection
- [x] Add the loadout selection scene and controller.
- [x] Consume pending selections before run startup.
- [x] Enforce duplicate-weapon and duplicate-skill restrictions.
- [x] Verification: loadout tests pass.

### P7 — Run summary and finish flow
- [x] Add the run summary scene and summary logic.
- [x] Gate scene transitions behind a safe finish flag for testing.
- [x] Reset per-run state cleanly before new runs or resumes.
- [x] Verification: summary and run-manager tests pass.

### P8 — Main menu and startup scene
- [x] Move the project entry point to the menu scene.
- [x] Add the abandon/confirm flow without recording a bogus result.
- [x] Keep menu and gameplay HUD visibility consistent.
- [x] Verification: menu flow and start-run tests pass.

### P9 — Procedural map generation and room overhaul
- [x] Implement the 4x3 chunk-based generator and `procedural_room` flow.
- [x] Create the chunk variants and collisions/drop-through platform logic.
- [x] Verify room generation, resume, and combat integration behavior.

### P10 — Qi and upgrade economy
- [x] P10a — Add `UpgradeManager`, per-run Qi tracking, and purchase APIs.
- [x] P10a — Reward Qi from enemy deaths and reset it correctly at run boundaries.
- [x] P10a — Add reaction rank and stat-upgrade logic without mutating the resolver.
- [x] P10a follow-up — persist procedural map structure and restore it on resume.
- [x] Playtest infrastructure — debug-only panel for invincibility, regeneration, teleport, Qi grants, and purchases.
- [x] P10b — Implement the room-cleared upgrade menu and completed the active upgrade flow for the current phase.

### P11 — Final verification and closeout
- [x] Run the full GUT suite.
- [x] Confirm static diagnostics are clean.
- [x] Update [Design.md](Design.md) only if the implemented contract diverges from design.
- [x] Capture blockers and decisions before the final handoff.

### P12 — Run optimization and economy tuning
- [x] Implement the run-optimization pass described in [P12_RUN_OPTIMIZATION_PLAN.md](P12_RUN_OPTIMIZATION_PLAN.md) and keep the work aligned with [Design.md](Design.md).
- [x] Fix the bug sweep in Phase 1: boss armor/charge wiring, restore-via-vitality, refresh removal, resume-order HP loss, and test hygiene.
- [x] Move Qi economy costs and purchase logic behind `UpgradeManager` API getters and spend tracking.
- [x] Open the gate and generator changes for procedural-room flow, shop dead-end placement, and normal-room transitions.
- [x] Complete P12 Phase 5 shop contents: station interaction, Restore, free rune, and two priced distinct weapon stalls; full GUT suite passes.
- [x] Implement loop persistence and scaling in Phase 6: carry upgrades/weapons/runes, scale enemy HP/damage `1 + 0.25 * (loop - 1)`.
- [x] Apply economy numbers in Phase 7: tuned Qi rewards and costs.
- [x] Add Phase 8 instrumentation: per-room delta logging in debug builds.
- [x] Phase 9 documentation reconciliation and final verification.

### P13 — Perfect Hit and weapon window expansion
- [x] Implement the shared Perfect Hit hit/window resolution, feedback, and dagger streak behavior.
- [x] Add the existing-weapon windows and multiplier bands without altering Charge or the reaction resolver.
- [x] Add six shop-only weapon resources, shop stock wiring, and target health getters.
- [x] Cover window behavior, multiplier handling, scattershot spread, and streak edge cases.
- [x] Verification: 269/269 GUT tests passed, 1,760 assertions, 0 failures; two expected headless warnings.

### P14 — Skill system expansion
- [x] Implement the skill roadmap in [SKILL_PLAN.md](SKILL_PLAN.md) after the run optimization work is stable.
- [x] Add the expanded `SkillData` schema, duplicate guards, cooldown readout, and `SkillPool` loader.
- [x] Add the new cast behaviors, HUD slot rendering, and skill roster in phase order.
- [x] Verify all new skill behaviors and compatibility checks with the full GUT suite: 287/287 passed, 1,841 assertions, 0 failures.

## Active decision log

- [x] D1 — Weapon Might and Vitality are repeatable per-run upgrades with escalating prices.
- [x] D2 — `UpgradeManager` getter names are stable and the resolver remains unchanged.
- [x] D3 — ShopStation proximity interaction (F) replaces room-cleared Tab menu.
- [x] D4 — The upgrade flow remains player-owned and scoped to the current run's player state path.
- [x] D9 — Rune modifiers are rolled at drop time and saved with the run.
- [x] D10 — Runes carry 1–2 modifiers and weapon resources remain unduplicated.
- [x] D11 — Same-element Charge overwrite remains intentional and is communicated visually.
- [x] D12 — Weapon and skill pickup shapes stay separate and the inspect flow remains keyboard-only.
- [x] D13 — Runes live on player slots, not in duplicated weapon resources.
- [x] D14 — Monogram UI and plain DPS stay in place; hidden invalid slots remain the default.
- [x] D15 — Normal procedural room exit is open from the start; boss room locked until defeat.
- [x] D16 — Shop is placed on a guaranteed dead-end branch with an empty fallback chunk (no enemies).
- [x] D17 — Paid Restore card provides run sustain (30% max HP, 20 + 10/use Qi, free/no-op at full HP).
- [x] D18 — Loop scaling persists Qi/upgrades/runes on victory, scales stats by `1 + 0.25 * (loop - 1)`, resets on death.
- [x] D19 — Refresh Shop is permanently removed; multi-purchases allowed in a single visit.

## Notes and blockers

- `Design.md` remains the source of truth for behavior and architecture.
- `PlaytestMode` remains debug-only and does not replace the in-run shop flow.
- P12 is fully verified and documented. No blockers remaining.
- P12 verification: 257/257 tests passed, 1,658 assertions, 0 failures, 2 expected warnings.
- P13 verification: 269/269 tests passed, 1,760 assertions, 0 failures, 2 expected warnings.
- P14 verification: 287/287 tests passed, 1,841 assertions, 0 failures, 2 expected warnings; headless shutdown emits resource leak diagnostics. Manual gameplay checkpoint remains pending.

## Immediate next action

- P14 follow-up: playtest each skill, shop stall spacing, and boss/spirit drops in game.
