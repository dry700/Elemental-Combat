# Elemental Roguelike Plan

This roadmap is synchronized with [Design.md](Design.md) and [AGENT_PLAN.md](AGENT_PLAN.md). The current implementation boundary is P10a; P10b remains deferred until the upgrade-menu scope is started.

## Current status

- [x] P0 — Repo hygiene and document cleanup
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
- [x] P8 — Main menu and startup scene update
- [x] P9 — Room-pool expansion
- [ ] P10 — Qi and upgrade system
- [ ] P11 — Closeout documentation and final verification

## P10a design contract

- `UpgradeManager` is a script-only autoload and owns per-run Qi/rank state.
- Reaction specializations are one-time Rank 1/Rank 2 purchases.
- Weapon Might and Vitality are repeatable purchases with category-local
	escalating prices.
- Qi and upgrade ranks never enter `SaveManager`.
- P10a exposes data and purchase APIs; UI/input and remaining effect hooks are
	P10b+ work.

## P5 design contract

- Runes are rolled at drop time, carry one or two modifiers, and are stored on Player slots rather than weapon Resources.
- `RuneData`, `RuneModifierDef`, and `RuneRoller` own rune data, catalogue definitions, and deterministic roll behavior.
- A single `RunePickup` supports weapon and skill targets. Weapon frames are square; skill frames are circular.
- Weapon Resources are never duplicated. Save state keeps `weapon_path` and stores rune dictionaries separately.
- Missing rune keys in older saves mean no rune. Unknown modifier ids warn and are skipped.
- F equips only an empty valid slot. Tab opens the chooser. Overwrite is chooser-only and drops the replaced rune with its rolled data.
- Hud owns all pickup chooser input. Pickup scripts only track proximity and expose prompt state.
- Same-element rune Charge bonuses remain the only Charge change; modifiers act at the effect layer and never mutate raw Charge in the resolver.
- Monogram is the project UI font, applied through the HUD theme and project default theme.

## P5 execution order

### P5a — Data and pickup foundation

- [x] Implement `RuneData` serialization and validation.
- [x] Implement `RuneModifierDef` and `RuneRoller` filtering, distinct modifier selection, and empty-pool behavior.
- [x] Implement `RunePickup` target framing, glyph, group, and proximity behavior.
- [x] Roll full weapon runes for spirit, boss, and room-clear baseline drops.
- [x] Add unit and integration coverage.
- [x] Observe the focused suite result before advancing to P5b.

### P5b — Player slots and persistence (complete)

- [x] Add primary and secondary weapon rune slots and the public rune APIs.
- [x] Carry runes through weapon swaps and dropped weapon pickups.
- [x] Resolve slot rune elements with authored weapon fallback for existing fixtures.
- [x] Save and restore rune dictionaries with missing-key and unknown-id tolerance.
- [x] Add overwrite pickup behavior and verify focused save/swap tests.

### P5c — HUD and input

- [x] Add Tab chooser and I inspect actions through `InputSetup`.
- [x] Keep F direct-equip behavior non-destructive.
- [x] Implement valid-slot hiding, no-op suppression, cards, badges, and plain DPS.
- [x] Implement the rune inspect pane and two-step Esc handling.
- [x] Import and apply Monogram through `hud_theme.tres` and project defaults.
- [x] Preserve existing tested Hud method names and signatures.

### P5d — Charge and Vũ readability

- [x] Add charge setter/signal and route Khắc partial reduction through it.
- [x] Render one to three Charge pips in `ElementIndicator`.
- [x] Add the reversed-hit signal and “Reversed!” popup.
- [x] Complete the Charge 3 playtest checkpoint and record any resulting decision.

## Progress and verification

- P4 baseline: 191/191 tests passed, 359 assertions, no IDE errors reported.
- P5a–P5d gates are closed; P6–P9 implementation is complete in the current worktree.
- P10a full-suite verification: 215/215 tests passed, 460 assertions, 0 failures, 2 expected warnings.
- Static diagnostics report no errors in the changed upgrade/run/player files.
- A reset-state regression was fixed and covered for favored Sinh elements.

## Deferred phases

P10b+ and final closeout remain deferred. P9 and P10a are verified; loadout
selection, run summary, main menu, and procedural room generation are implemented.

## Open decisions

- [ ] D15 — Confirm F direct-equips only into an empty slot and Tab opens the chooser.
- [ ] D16 — Confirm rune travel with a weapon on swap and drop.
- [ ] D17 — Confirm one target-aware `RunePickup` script remains the chosen shape.
- [ ] D18 — Tune the two-modifier chance after the first playable rune pass.
- [ ] D19 — Define the initial modifier catalogue and pool scope.
- [ ] D20 — Reconcile the stray enemy-stats fragment and duplicate training-staff resource.

## Exact next item

Start P10b: implement the room-cleared upgrade menu/input flow and connect
the P10a purchase APIs to the remaining player and reaction effect hooks.
