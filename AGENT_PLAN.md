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

## Phase status

### P0 — Repo hygiene and design cleanup
- [x] Remove stray or invalid resource files and stale authoring fragments.
- [x] Clean up project-level docs and design notes that drifted from the implemented architecture.
- [x] Confirm the repo is in a stable baseline before gameplay work resumes.
- [x] Verification: no broken asset references, no obvious invalid files, and no newly introduced editor warnings.

### P1 — Combat stability and mitigation
- [x] Apply armor mitigation consistently in each `_apply_damage()` path.
- [x] Implement `ArmorBuffEffect` with refresh-only semantics.
- [x] Ensure tests that depend on lethal damage isolate armor from the death/phase logic.
- [x] Verify enemy DoT application matches the design intent.
- [x] Verification: relevant combat and death tests pass.

### P2 — Player death timing and state transitions
- [x] Delay the player `died` signal so the death tint is visible before scene transition.
- [x] Update death assertions to wait for the signal before checking emission state.
- [x] Check run-manager loss tracking for duplicate record entries.
- [x] Verification: player death tests and persistence tests pass.

### P3 — Control resistance and CC handling
- [x] Add `CCResistance` and wire it into `ElementalCombatant`.
- [x] Replace direct control-effect applications with the shared resistance chokepoints.
- [x] Configure enemy default and boss-specific CC thresholds correctly.
- [x] Confirm normal enemies remain unaffected unless the tighter profile is intentionally enabled.
- [x] Verification: CC tests and related integration tests pass.

### P4 — Tutorial onboarding
- [x] Add the tutorial room scene and controller.
- [x] Implement the stage progression flow and prompt gating.
- [x] Persist tutorial completion in `SaveManager` with an idempotent write path.
- [x] Gate the exit until the tutorial state is complete.
- [x] Route the tutorial exit to the next scene with the correct transition target.
- [x] Verification: onboarding flow works and no duplicate tutorial completion writes occur.

### P5 — Runes, pickup swap HUD, and Charge readability

#### P5a — Rune data and pickup foundation (complete)
- [x] Add `RuneData`, `RuneModifierDef`, `RuneRoller` (1–2 modifiers, 25% placeholder for two, saved as dict).
- [x] Add `RunePickup` (one script, square/circle frame by target, `rune_pickups` group).
- [x] Wire drops: spirit, boss and room-clear baseline roll full runes (weapon target only).
- [x] Verification: 198/198 tests passed, 374 assertions. RuneRoller refactored to instance-based (preload-safe); production callers updated to `RuneRoller.default().roll()`; boss test guarded against rune drop in test context.

#### P5b — Player slot runes and persistence
- [ ] Add `weapon_rune`/`secondary_weapon_rune`, `apply_rune`, `can_apply_rune`, `swap_weapon(..., new_rune)`.
- [ ] `resolve_swing(rune)` and `_resolve_skill_charge()` read slot runes with authored-`rune_element` fallback.
- [ ] Persist rune dicts in `to_save_state()`/`apply_save_state()`; tolerate missing keys and unknown modifier ids.
- [ ] Weapons carry their rune when swapped or dropped; overwritten runes drop as pickups.
- [ ] Verification: rune, swap, save/load and existing skill-charge tests pass.

#### P5c — Pickup swap HUD, inputs and font
- [ ] Add `swap` (Tab) and `inspect` (I) actions; keyboard only.
- [ ] Rework Hud flow: F direct-equip into an empty slot (never overwrites), Tab chooser, hidden invalid slots, no-op suppression.
- [ ] Weapon/skill/rune cards, badges (glyph + Charge pips, second badge for a different-element rune), plain DPS via `get_display_dps()`.
- [ ] Rune inspect pane (world prompt + chooser), two-step Esc.
- [ ] Import Monogram, add `hud_theme.tres`, set `gui/theme/custom_font`, remove per-label size overrides.
- [ ] Verification: `test_hud_pickup_overlay.gd` / `test_hud_pickup_prompts.gd` pass unchanged; new tests for hidden slots, F-never-overwrites, DPS.

#### P5d — Charge and Vũ readability
- [ ] Add `ElementalStatus.set_charge()`/`charge_changed`; route `KHAC_PARTIAL` through it.
- [ ] `ElementIndicator.set_status()` with 1–3 Charge pips.
- [ ] `reversed_hit_taken` signal and "Reversed!" popup.
- [ ] Playtest checkpoint: with Charge 3 reachable, judge Thừa/Vũ feel and revisit the same-element overwrite decision (§4.2).
- [ ] Verification: status and Vũ reaction tests pass.

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
- [x] D9 — Rune modifiers are rolled at drop time and saved in the save file.
- [x] D10 — Weapon runes get modifiers in the first pass; runes carry 1–2 modifiers.
- [x] D11 — Same-element Charge overwrite stays; fix through visibility (pips + "Reversed!" popup).
- [x] D12 — Separate weapon/skill rune pickups (square/circle), no toggle key; `I` inspects from prompt and chooser.
- [x] D13 — Runes live on the Player slot; weapon/skill Resources are never duplicated.
- [x] D14 — Keyboard only; plain DPS stays, delta chip dropped; Monogram only; duplicate-weapon slot hidden.
- [ ] D15 — Confirm the key flow: F direct-equips into an empty slot and never overwrites; Tab opens the chooser.
- [ ] D16 — Confirm that a rune travels with its weapon on swap/drop.
- [ ] D17 — Confirm one `RunePickup` script with a `target` field (vs two scripts).
- [ ] D18 — Tune the two-modifier chance (25% placeholder) in Sprint 3.
- [ ] D19 — Write the modifier catalogue (weapon first, then skill); decide global vs per-element pools.
- [ ] D20 — Fix the stray files: `enemy_stats.gd` fragment and `training_staff.tres` vs `training_staff (1).tres`.

## Notes and blockers

- Keep this section updated whenever a phase reveals a blocker or a design decision that needs to be revisited.
- Examples:
  - Dependency blocked by missing design detail
  - Test failure caused by a changed architecture rule
  - Manual verification still required before moving to the next phase
- Godot executable found at `E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe` (use this path for headless GUT runs).
- P5a verification passed: 198/198 tests, 374 assertions, 0 failures, 1 warning (expected push_error in sprite_visual test). Synced: 2026-09-25.
- RuneRoller refactored from static methods to instance-based with `RuneRoller.default()` singleton; production callers updated; test uses preloaded script to instantiate.

## Current active scope

- [x] P5a — rune data, roller, and pickup foundation (**verified**)
- [ ] P5b — player slot runes and persistence (now unblocked)
- [ ] P5c — pickup swap HUD, inputs, and Monogram theme (blocked by P5b)
- [ ] P5d — Charge pips, Vũ readability, and playtest checkpoint (blocked by P5c)
- [ ] P6 onward — deferred until P5d verification is complete

## Immediate next action

- Start P5b: add `weapon_rune` and `secondary_weapon_rune` to Player, implement `apply_rune()` / `can_apply_rune()`, carry runes through `swap_weapon()` and dropped `WeaponPickup` instances, and add save/load persistence with missing-key and unknown-id tolerance.
