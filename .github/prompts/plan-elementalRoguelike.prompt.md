## Plan: Elemental Roguelike execution roadmap

TL;DR: Build the project in ordered, reviewable phases that match the dependency chain in AGENT_PLAN.md. Keep every phase narrow enough to verify with the project’s Godot GUT command before moving to the next one, and treat unresolved design gaps as explicit decisions rather than silent assumptions.

## Ground rules
- [ ] One phase = one commit.
- [ ] After each phase, run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
- [ ] Never edit scripts/reactions/reaction_resolver.gd.
- [ ] Follow the physics-callback rule for Area2D-based spawned nodes.
- [ ] Keep hand-edited .tscn files path-only and preserve find_child fallbacks.
- [ ] Never hand-write .uid files.
- [ ] Use save isolation helpers for SaveManager tests.
- [ ] Treat unresolved design gaps as explicit defaults from AGENT_PLAN.md.

## Dependency order
1. [ ] P0
2. [ ] P1
3. [ ] P2
4. [ ] P3
5. [ ] P4
6. [ ] P5
7. [ ] P6
8. [ ] P7
9. [ ] P8
10. [ ] P9
11. [ ] P10(a → f)
12. [ ] P11

## Phase breakdown

### P0 — Repo hygiene and document cleanup
- [ ] Delete the stray enemy_stats fragment and invalid training_staff resource.
- [ ] Rename the training_staff duplicate to the expected canonical path.
- [ ] Fix the design-document wording issues called out in AGENT_PLAN.md.
- [ ] Confirm the project rules around .tscn authoring and .uid handling are being followed.
- [ ] Verify the repository is clean enough for gameplay changes.
- [ ] Run GUT and fix any regressions before moving on.

### P1 — Armor mitigation and armor buff component
- [ ] Add ArmorBuffEffect mirroring the SlowEffect contract.
- [ ] Update ElementalCombatant to track armor buffs and use a shared mitigation function.
- [ ] Apply mitigated damage in the player and enemy damage handlers.
- [ ] Handle the TestDummy/PatrolDummy DoT exception if D7 is accepted.
- [ ] Add unit coverage for armor identity, scaling, buff semantics, and Sever behavior.
- [ ] Fix persistence tests where lethal damage was previously masked by default armor.
- [ ] Run targeted tests and then the project GUT suite.

### P2 — Player death delay
- [ ] Replace the current player death flow with the delayed fade/tint sequence.
- [ ] Ensure the died signal is emitted once after the fade delay.
- [ ] Update tests to wait for the death signal before asserting final state.
- [ ] Confirm run-loss persistence still records only once.
- [ ] Run relevant tests and then the full suite.

### P3 — Control resistance and CC handling
- [ ] Add CCResistance and its associated state tracking.
- [ ] Set default enemy tier and CC values in enemy_stats.
- [ ] Adjust the Ember Tide boss defaults.
- [ ] Wire control resistance through ElementalCombatant and the affected reaction call sites.
- [ ] Keep debug test effects direct while routing gameplay control effects through the new system.
- [ ] Add tests for free-hit windows, slow/disable sharing, and immunity boundaries.
- [ ] Run targeted tests and the project suite.

### P4 — First-time tutorial flow
- [ ] Create the tutorial room scene and controller.
- [ ] Add tutorial completion tracking in SaveManager.
- [ ] Ensure the tutorial advances in the required staged order without false progression.
- [ ] Lock the exit until tutorial completion and route to the next scene per the chosen default.
- [ ] Prevent repeat tutorials after completion.
- [ ] Update SaveManager tests for default false and single-write completion.
- [ ] Playtest the tutorial flow and confirm the second-run behavior.
- [ ] Run the project GUT suite.

### P5 — Rune pickups, persistence, and HUD overlays
- [ ] Add RunePickup behavior and dropped-rune spawning with deferred child creation.
- [ ] Update weapon persistence to use persistent paths instead of transient instance state.
- [ ] Ensure rune application preserves both weapon slots correctly.
- [ ] Update HUD pickup overlays to distinguish weapon, skill, and rune overlays.
- [ ] Confirm active pickup refresh includes rune pickups with the proper priority.
- [ ] Add tests for apply behavior, overwrite behavior, and distribution sanity.
- [ ] Run focused tests and then the full suite.

### P6 — Loadout selection and pending loadout consumption
- [ ] Create the loadout select scene and controller.
- [ ] Extend RunManager with pending loadout state and a consume method.
- [ ] Ensure procedural_run consumes pending loadout before starting a run.
- [ ] Update duplicate checks to compare persistent paths.
- [ ] Restrict start-run activation until all four picks are valid and non-duplicate.
- [ ] Update HUD selection feedback and inline blocking messages.
- [ ] Add tests covering pending assignment, clear behavior, and duplicate validation.
- [ ] Run targeted tests and full project validation.

### P7 — Run summary and finish-run transitions
- [ ] Create the run summary scene and script.
- [ ] Extend RunManager with last-run tracking and a finish-run transition guard.
- [ ] Reset room state before generating or resuming a run.
- [ ] Fix time formatting without integer-division warnings.
- [ ] Add the Main Menu button path as defined, while keeping it hidden until the menu exists.
- [ ] Verify summary tests still pass when transitions are disabled in unit tests.
- [ ] Run the full GUT suite.

### P8 — Main menu and startup scene update
- [ ] Create the main menu scene and script.
- [ ] Update the project main scene to the menu entry point.
- [ ] Add the abandon confirmation flow without recording a run result.
- [ ] Decide whether HUD gameplay visibility should be toggled in menu and summary scenes.
- [ ] Update README to reflect the menu-first entry point and editor-only dev path.
- [ ] Validate the fresh-save flow through tutorial, loadout, run, summary, and menu transitions.
- [ ] Run final verification after menu changes.

### P9 — Room pool expansion to six rooms
- [ ] Create room_d, room_e, and room_f from the approved template.
- [ ] Extend RunManager room paths without changing ROOMS_PER_RUN.
- [ ] Confirm enemy element consistency for all spirit templates.
- [ ] Add room template validation tests for root type, exit presence, and spawn layout.
- [ ] Confirm the room pool still yields valid progression and boss-room integration.
- [ ] Run the relevant integration tests and full GUT suite.

### P10a — Qi foundations and upgrade manager setup
- [ ] Add UpgradeManager as a persistent autoload near SaveManager.
- [ ] Track Qi totals and reaction ranks keyed by reaction id.
- [ ] Add the reaction-id mapping logic without placing it in the resolver.
- [ ] Wire Qi rewards into enemy deaths and the HUD label.
- [ ] Reset Qi at run start and finish.
- [ ] Add upgrade-manager unit tests.
- [ ] Run targeted checks and the full suite.

### P10b — Khắc specialization rules
- [ ] Implement the pre-dispatch rewrite for KHAC_PARTIAL outcomes using the Khắc upgrade hooks.
- [ ] Ensure the result object is mutable without modifying the resolver.
- [ ] Add integration tests for the Khắc specialization behavior.
- [ ] Validate no regressions in the broader reaction tests.
- [ ] Run full GUT verification before continuing.

### P10c — Sinh Rank 1
- [ ] Apply Sinh Rank 1 forced-branch overrides in the relevant reaction branches.
- [ ] Validate the Tier 2 upgrade expectations and reaction scaling.
- [ ] Add or update tests for the affected branch behavior.
- [ ] Run relevant tests and the full suite.

### P10d — Vitality upgrade path
- [ ] Confirm whether D1 resolves or remains blocked.
- [ ] If available, add the armor-bonus logic to the mitigation pipeline.
- [ ] Add vitality tests.
- [ ] If blocked, record the blocker and exclude the phase from implementation.
- [ ] Run validation after any changes.

### P10e — Weapon Might upgrade path
- [ ] Confirm whether D1 resolves or remains blocked.
- [ ] If available, wire the Weapon Might stat changes into the damage path.
- [ ] Add or update tests for the new modifiers.
- [ ] If blocked, record the status and exclude the phase from implementation.
- [ ] Run validation after changes.

### P10f — Sinh Rank 2 branches and reaction-specific effects
- [ ] Implement Cinder Bloom damage and hazard behavior.
- [ ] Implement Ore Surge projectile expiration and caltrop behavior.
- [ ] Implement Condensation tidal wave and RustedChunk behavior.
- [ ] Implement Wildfire overload and remnant behavior.
- [ ] Implement Overgrowth vine and flower turret behavior with any required source filtering.
- [ ] Add integration tests for each new reaction class and effect path.
- [ ] Run targeted tests and the full GUT suite before closing out the upgrade phase.

### P11 — Close-out documentation and final verification
- [ ] Update Design.md for autoloads, system map, and implemented/partial status headings.
- [ ] Record the D7 and D8 decisions and any new architecture notes.
- [ ] Refresh README with the menu entry point, controls table, and test count.
- [ ] Verify AGENT_PLAN.md and Design.md remain aligned with the final state.
- [ ] Run the full project GUT suite and confirm a green result.
- [ ] Perform the required manual playtest checklist for tutorial and menu flow.

## Key decisions to preserve while implementing
- [ ] D1 defaults to skipping Weapon Might and Vitality unless specifically clarified.
- [ ] D2 defaults to the read-site-derived names if the missing getter API block is not restored.
- [ ] D3 defaults to a Tab-based upgrade menu while the room is cleared.
- [ ] D4 makes upgrade effects apply only when the source is the player.
- [ ] D5 prefers the tutorial-to-loadout route unless corrected.
- [ ] D6 adds a Main Menu path and keeps the quit behavior explicit.
- [ ] D7 adopts the TestDummy/PatrolDummy DoT wiring change.
- [ ] D8 follows the literal save rule and documents the technical debt note.

## Verification cadence
- [ ] After each phase, run the same project-level validation command: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
- [ ] Only move to the next phase after the relevant tests or the full suite pass.
- [ ] If a phase reveals a new architectural decision, record it before continuing.

## Scope boundaries
- [ ] Included: all phases and checks listed in AGENT_PLAN.md.
- [ ] Excluded: speculative work beyond the approved dependency chain.
- [ ] Explicitly forbidden: editing scripts/reactions/reaction_resolver.gd.
