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

P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P11

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
- [ ] Update [Design.md](Design.md) only if the implemented contract diverges from design.
- [ ] Capture blockers and decisions before the final handoff.

## Active decision log

- [x] D1 — Weapon Might and Vitality are repeatable per-run upgrades with escalating prices.
- [x] D2 — `UpgradeManager` getter names are stable and the resolver remains unchanged.
- [x] D3 — The room-cleared upgrade-menu input rule is Tab-based while the room is cleared and the HUD owns the flow.
- [x] D4 — The upgrade flow remains player-owned and scoped to the current run's player state path.
- [x] D9 — Rune modifiers are rolled at drop time and saved with the run.
- [x] D10 — Runes carry 1–2 modifiers and weapon resources remain unduplicated.
- [x] D11 — Same-element Charge overwrite remains intentional and is communicated visually.
- [x] D12 — Weapon and skill pickup shapes stay separate and the inspect flow remains keyboard-only.
- [x] D13 — Runes live on player slots, not in duplicated weapon resources.
- [x] D14 — Monogram UI and plain DPS stay in place; hidden invalid slots remain the default.

## Notes and blockers

- `Design.md` remains the source of truth for behavior and architecture.
- `PlaytestMode` remains debug-only and does not replace the final room-cleared upgrade flow.
- D3/D4 are resolved in the current implementation: the room-cleared upgrade menu is Tab-based, room-gated, and scoped to the player-owned run state.
- Current verification: 225/225 tests passed, 501 assertions, 0 failures, 2 expected warnings.

## Immediate next action

- Move to P11 closeout: final documentation clean-up and repo polish after the completed room-cleared upgrade-menu implementation.
