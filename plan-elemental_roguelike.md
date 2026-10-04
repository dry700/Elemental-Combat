# Elemental Roguelike Plan

This roadmap is synchronized with [Design.md](Design.md) and [AGENT_PLAN.md](AGENT_PLAN.md). The verified implementation boundary is P10b complete; final project closeout now sits in P11.

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
- [x] P9 — Procedural room generation and room-system overhaul
- [x] P10a — Qi economy and upgrade-manager foundations
- [x] P10b — Room-cleared upgrade menu, input flow, and HUD purchase path
- [ ] P11 — Final verification and documentation closeout

## P10a design contract

- `UpgradeManager` is a script-only autoload and owns per-run Qi/rank state.
- Reaction specializations are one-time Rank 1/Rank 2 purchases.
- Weapon Might and Vitality are repeatable purchases with category-local escalating prices.
- Qi and upgrade ranks remain out of `SaveManager` and persistent save data.
- The remaining P10b work is the normal room-cleared UI and the effect hookups, not a second pass on P10a itself.

## P10b active scope

- [x] Resolve D3 and D4: the active room-cleared upgrade flow uses the Tab-based HUD menu, and upgrades remain scoped to the player-owned run state.
- [x] Implement the normal room-cleared upgrade screen and input gating.
- [x] Connect the verified purchase APIs to the HUD purchase path.
- [x] Add focused tests for the room-cleared menu flow and purchase behavior.

## Verification and blockers

- Full-suite verification: 225/225 tests passed, 501 assertions, 0 failures, 2 expected warnings.
- Static diagnostics: no errors found in the workspace.
- Blockers: none in the active P10b scope; P11 is now the final verification/documentation closeout pass.

## Procedural map save contract

- The in-progress snapshot contains the current procedural grid, door masks, start/finish cells, and chosen chunk scene paths.
- Resume restores the structure before room entry so the room topology is not rerolled.
- Enemy state remains intentionally fresh on resume; legacy snapshots without `map_structure` still load properly.

## Exact next item

Advance to P11 closeout: finish the final documentation pass and any repo polish after the verified room-cleared upgrade-menu implementation.
