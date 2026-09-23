# AGENT_PLAN.md

This is the working checklist for the project. It is intentionally structured for progress tracking, while the detailed mechanics and architecture remain in [Design.md](Design.md).

## Status legend

- [ ] Not started
- [ ] In progress
- [x] Complete

## Rules for this checklist

- Work on one phase at a time.
- Do not mark a task complete until the relevant verification has run.
- Update the checklist after each commit or verified milestone.
- Keep decisions and blockers in the notes section instead of silently skipping them.
- Use [Design.md](Design.md) as the implementation source of truth.

## Phase order

P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P11

## Current focus

### P0 — Repo hygiene and design cleanup
- [ ] Remove stray or invalid resource files and stale authoring fragments.
- [ ] Clean up project-level docs and design notes that drifted from the implemented architecture.
- [ ] Confirm the repo is in a stable baseline before gameplay work resumes.
- [ ] Verification: no broken asset references, no obvious invalid files, and no newly introduced editor warnings.

### P1 — Combat stability and mitigation
- [ ] Apply armor mitigation consistently in each `_apply_damage()` path.
- [ ] Implement `ArmorBuffEffect` with refresh-only semantics.
- [ ] Ensure tests that depend on lethal damage isolate armor from the death/phase logic.
- [ ] Verify enemy DoT application matches the design intent.
- [ ] Verification: relevant combat and death tests pass.

### P2 — Player death timing and state transitions
- [ ] Delay the player `died` signal so the death tint is visible before scene transition.
- [ ] Update death assertions to wait for the signal before checking emission state.
- [ ] Check run-manager loss tracking for duplicate record entries.
- [ ] Verification: player death tests and persistence tests pass.

### P3 — Control resistance and CC handling
- [ ] Add `CCResistance` and wire it into `ElementalCombatant`.
- [ ] Replace direct control-effect applications with the shared resistance chokepoints.
- [ ] Configure enemy default and boss-specific CC thresholds correctly.
- [ ] Confirm normal enemies remain unaffected unless the tighter profile is intentionally enabled.
- [ ] Verification: CC tests and related integration tests pass.

### P4 — Tutorial onboarding
- [ ] Add the tutorial room scene and controller.
- [ ] Implement the stage progression flow and prompt gating.
- [ ] Persist tutorial completion in `SaveManager` with an idempotent write path.
- [ ] Gate the exit until the tutorial state is complete.
- [ ] Route the tutorial exit to the next scene with the correct transition target.
- [ ] Verification: onboarding flow works and no duplicate tutorial completion writes occur.

### P5 — Rune pickups and persisted weapon state
- [ ] Add the rune pickup object and its pickup flow.
- [ ] Add rune application to the player weapon state and save/load pathing.
- [ ] Persist rune-equipped weapon state without fragile player-side base-path logic.
- [ ] Update HUD pickup routing for weapon, rune, and skill overlays.
- [ ] Validate drop overwrite behavior and pickup interaction rules.
- [ ] Verification: rune tests, save/load tests, and pickup-flow tests pass.

### P6 — Loadout selection
- [ ] Add the loadout selection scene and controller.
- [ ] Consume pending selections before run startup.
- [ ] Enforce duplicate-weapon and duplicate-skill restrictions.
- [ ] Ensure invalid selections cannot start a run.
- [ ] Verification: loadout selection tests and HUD selection tests pass.

### P7 — Run summary and finish flow
- [ ] Add the run summary scene and summary logic.
- [ ] Gate scene transitions behind a safe finish flag for testability.
- [ ] Reset per-run state before a new run or resume flow begins.
- [ ] Handle summary navigation and exit-to-menu flow cleanly.
- [ ] Verification: summary and run-manager tests pass.

### P8 — Main menu and startup scene
- [ ] Move the project entry point to the menu scene.
- [ ] Add the abandon/confirm flow and ensure it does not record a run result.
- [ ] Keep menu and gameplay HUD visibility consistent.
- [ ] Update the project docs to reflect the new startup path.
- [ ] Verification: menu flow and start-run path behave correctly.

### P9 — Room pool expansion
- [ ] Add the extra room templates and integrate them into the room pool.
- [ ] Validate each room against the room controller contract.
- [ ] Ensure spirit stats keep innate element and drop element aligned.
- [ ] Verify room generation still respects the intended layout and spawn rules.
- [ ] Verification: room template validation and generation-related tests pass.

### P10 — Qi and upgrade economy
- [ ] Create the upgrade manager and register it properly.
- [ ] Add Qi reward tracking to enemy death and reset flow.
- [ ] Implement reaction mastery and stat-upgrade purchase logic.
- [ ] Enforce specialization rules without mutating raw charge values in the resolver.
- [ ] Finish remaining effect hooks and upgrade-related side effects.
- [ ] Verification: upgrade-manager tests and affected reaction tests pass.

### P11 — Final verification and closeout
- [ ] Run the full GUT suite.
- [ ] Check static diagnostics for errors or warnings.
- [ ] Update [Design.md](Design.md) only if implementation diverges from the architecture contract.
- [ ] Capture unresolved decision items and blockers in the notes section.
- [ ] Verification: full suite is green and the final documentation matches the code.

## Active decision log

- [ ] D1 — Confirm the missing earlier draft or decide how Weapon Might and Vitality should be handled.
- [ ] D2 — Resolve the missing revised getter API naming if the design snippet is still absent.
- [ ] D3 — Finalize the upgrade-menu input and room-state gating rule.
- [ ] D4 — Confirm whether upgrades apply only to player-owned hits or to all combatants.
- [ ] D5 — Confirm that tutorial routing continues through the loadout flow unless a change is explicitly approved.
- [ ] D6 — Finalize main-menu and summary navigation behavior.
- [ ] D7 — Confirm enemy DoT application behavior in code and tests.
- [ ] D8 — Document upgrade persistence as technical debt if in-run state must remain non-persistent.

## Notes and blockers

- Keep this section updated whenever a phase reveals a blocker or a design decision that needs to be revisited.
- Examples:
  - Dependency blocked by missing design detail
  - Test failure caused by a changed architecture rule
  - Manual verification still required before moving to the next phase

## Current active scope

- [ ] P5 — rune pickups, rune persistence, and HUD overlay routing
- [ ] P6 — loadout selection and pending-loadout consumption
- [ ] P7 — run summary and finish-run transition behavior
- [ ] P8 — main menu and startup scene handoff
- [ ] P9 — room-pool expansion to six rooms
- [ ] P10 — Qi and upgrade system work

## Immediate next action

- Start with the next unchecked phase and complete the smallest verifiable chunk before moving to the next item.
- After each milestone, update this checklist and re-run the relevant verification before claiming completion.
