# Current Implementation Plan

Source of truth: [Design.md](Design.md). Execution order and repository rules are tracked in [AGENT_PLAN.md](AGENT_PLAN.md).

## Phase status

- [x] P0 — Repo hygiene and design cleanup
- [x] P1 — Armor mitigation and armor buff component
- [x] P2 — Player death delay
- [x] P3 — Control resistance and CC handling
- [x] P4 — First-time tutorial flow
- [x] P5a — Rune data, roller, and pickup foundation
- [x] P5b — Player slot runes and persistence
- [x] P5c — Pickup swap HUD, inputs, and Monogram theme
- [x] P5d — Charge pips, Vũ readability, and playtest checkpoint
- [x] P6 — Loadout selection and pending-loadout consumption
- [x] P7 — Run summary and finish-run transitions
- [x] P8 — Main menu and startup scene
- [x] P9 — Room-pool expansion
- [ ] P10 — Qi and upgrade system
- [ ] P11 — Final verification and documentation closeout

## Completed current task: P10a follow-up — Persist procedural map layout

- [x] Serialize generated grid cells, door masks, start/finish cells, and chosen chunk scene paths.
- [x] Store the map structure in `in_progress_run` without changing the existing player/enemy snapshot boundary.
- [x] Restore the saved structure before the procedural room enters the tree; keep legacy saves compatible.
- [x] Add generator round-trip and RunManager resume integration tests.

### Verification gate

- [x] Focused map snapshot tests: 2/2 passed, 7 assertions.
- [x] RunManager persistence tests: 6/6 passed, 12 assertions.
- [x] Full GUT suite: 219/219 tests passed, 470 assertions, 0 failures, 2 expected warnings.
- [x] Static diagnostics: no errors in the changed scripts/tests.

## Current scope: P10b — Upgrade menu, input, and remaining effect hooks

### P10b playtest tools (implemented)

- [x] Add debug-build-only `PlaytestMode`, toggled with F12.
- [x] Add full-hit Player invincibility and freeze voluntary input while the panel is open.
- [x] Add current procedural map regeneration and start/finish/any-chunk teleport targets.
- [x] Add Qi grants and purchase controls for Vitality, Weapon Might, and selected reaction ranks.
- [x] Keep Qi, ranks, and Vitality bonuses out of persistent run snapshots.
- [x] Add unit and integration coverage for panel actions, cheat grants, teleport, and regeneration.
- [x] Verification: 224/224 full-suite tests passed, 492 assertions, 0 failures, 2 expected warnings; touched scripts have no static errors.

### Remaining P10b scope

- [ ] Resolve D3/D4 and implement the normal room-cleared upgrade menu and remaining combat effect hooks.

- [x] Register `UpgradeManager` as an autoload after `SaveManager`.
- [x] Track per-run Qi and reset it at new-run and run-finish boundaries.
- [x] Award Qi from enemy death rewards.
- [x] Implement one-time Rank 1/Rank 2 reaction purchases.
- [x] Implement repeatable Weapon Might and Vitality purchases with rising prices.
- [x] Expose reaction and stat getter APIs without changing the reaction resolver.
- [x] Add focused UpgradeManager coverage, including reset-state isolation.

### P10a verification gate

- [x] Full GUT suite: 215/215 tests passed, 460 assertions, 0 failures.
- [x] Static diagnostics: no errors reported in the changed upgrade/run/player files.
- [x] Fixed reset leakage by clearing favored Sinh elements with other per-run state.

### Next P10 item

- [ ] Start P10b: add the room-cleared upgrade menu/input flow and wire the
	verified purchase state into the remaining player/reaction effect hooks.

## Completed P5 scope

### Rune data

- [x] Add `RuneData` with element, target, modifier list, `to_dict()`, `from_dict()`, and description lines.
- [x] Add `RuneModifierDef` resource fields and target/element filtering.
- [x] Add `RuneRoller` with one or two distinct modifiers and the current 25% two-modifier placeholder.
- [x] Return an empty rune with a warning when the filtered modifier pool is empty.

### Rune pickup

- [x] Add one `RunePickup` script with a runtime `rune` field and no exported runtime data.
- [x] Use a square frame for weapon runes and a circle frame for skill runes.
- [x] Add the rune element indicator and `rune_pickups` group membership.
- [x] Keep pickup logic limited to proximity and prompt state; Hud owns chooser input.
- [x] Roll complete weapon runes for spirit, boss, and room-clear baseline drops.
- [x] Keep skill-target rune drops disabled until the skill modifier catalogue exists.

### P5a verification gate

- [x] Add `test_rune_data.gd` round-trip and invalid-data cases.
- [x] Add `test_rune_roller.gd` count, distinct-id, target filtering, and empty-pool cases.
- [x] Add rune pickup integration coverage.
- [x] Run and observe the relevant GUT subset before starting P5b.

## P5b — Player slot runes and persistence (complete)

- [x] Add `weapon_rune` and `secondary_weapon_rune` to Player.
- [x] Implement `get_weapon_rune()`, `can_apply_rune()`, and `apply_rune()`.
- [x] Keep weapon Resources unduplicated; preserve their `resource_path` values.
- [x] Carry a weapon's rune through `swap_weapon()` and dropped `WeaponPickup` instances.
- [x] Resolve effective rune elements with the slot rune first and authored `rune_element` as fixture fallback.
- [x] Apply same-element Charge bonuses without changing raw Charge rules in the resolver.
- [x] Save rune dictionaries in the Player snapshot and tolerate missing or unknown modifier ids.
- [x] Drop the previous rune as a rolled pickup on chooser-only overwrite.

### P5b verification gate (verified)

- [x] Pass rune application, weapon swap, skill-charge, and Player save/load tests.
- [x] Confirm old saves load with no rune when rune keys are missing.
- [x] Confirm unknown modifier ids warn and are skipped rather than crashing.


## P5c — Pickup swap HUD, input, and font

- [x] Add `swap` on Tab and `inspect` on I through `InputSetup`.
- [x] Preserve existing pickup, menu, slot, and cancel bindings; do not add joypad events.
- [x] Make F equip directly only into the first empty valid slot; F never overwrites.
- [x] Make Tab open the chooser when at least one valid slot exists.
- [x] Hide duplicate or no-op weapon slots instead of dimming them.
- [x] Suppress prompts when no valid slot exists.
- [x] Add weapon, skill, and rune cards with glyphs, Charge pips, modifier tags, and plain DPS.
- [x] Add the rune inspect pane and two-step Esc behavior.
- [x] Keep the existing tested Hud method names and signatures stable.
- [x] Import Monogram and apply it through `hud_theme.tres` and the project default theme.
- [x] Remove new per-label font-size overrides.

### P5c verification gate

- [x] Pass existing pickup overlay and pickup prompt tests without changing their call signatures.
- [x] Add coverage for hidden slots, F never overwriting, rune inspection, and DPS display.
- [x] Confirm chooser keyboard flow manually at the project viewport size.

## P5d — Charge and Vũ readability

- [x] Add `ElementalStatus.set_charge()` and `charge_changed`.
- [x] Route Khắc partial charge reduction through the setter.
- [x] Add Charge pips to `ElementIndicator` for values 1–3.
- [x] Add `reversed_hit_taken` and the “Reversed!” popup.
- [x] Reach Charge 3 in a playtest and assess Thừa/Vũ readability and feel.
- [x] Record the result and any balance/design decision before closing P5.

### P5d verification gate

- [x] Pass status, Charge, and Vũ reaction tests.
- [x] Complete the manual Charge 3 playtest checkpoint.
- [x] Update Design.md only if the playtest changes the architecture contract.

## Deferred phases

P10b+ and P11 remain out of the current implementation scope until the P10a
gate is complete. Do not mark later phases complete based on planning work alone.

## Decisions and blockers

- [ ] D15 — Confirm F direct-equips into an empty slot and Tab opens the chooser.
- [ ] D16 — Confirm a rune travels with its weapon on swap and drop.
- [ ] D17 — Confirm one `RunePickup` script with a target field remains the chosen shape.
- [ ] D18 — Tune the two-modifier chance after the first playable rune pass.
- [ ] D19 — Define the first modifier catalogue and whether pools are global or per-element.
- [ ] D20 — Remove or reconcile the stray enemy stats fragment and duplicate training-staff resource.

### Verification record

- P4 baseline: 191/191 tests passed, 359 assertions, no IDE errors reported.
- P5a verification: 198/198 tests passed, 374 assertions, 0 failures. GUT command: `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s "res://addons/gut/gut_cmdln.gd" -gdir=res://test -ginclude_subdirs -gexit`
- RuneRoller refactored from static to instance-based (`RuneRoller.default().roll()`); production callers updated; test uses preload to instantiate.
- Boss integration test guarded against rune drop spawning on empty catalogue during headless tests.
- P5a gate: **closed**.
- P9 map-generation and room-overhaul implementation: verified in the current
	worktree; full-suite result recorded above.
- P10a upgrade foundations: **closed**, 215/215 tests and 460 assertions.
- P5b gate: **closed**. Player slot runes and persistence verified.
- P5c gate: **closed**. HUD swap and inputs verified.
- P6, P7, P8 features implemented (Loadout Select, Run Summary, Main Menu). Tutorial logic fixed. Drops parented to rooms for proper despawning.
- P5d is now the active scope.
