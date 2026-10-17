# Elemental Roguelike

A Godot 4.7 action-combat roguelike built around elemental reactions, charge resolution, procedural room generation, and a per-run Qi upgrade economy.

## Current implementation status

The project is beyond the initial prototype stage. The verified codebase includes:

- Armor mitigation and `ArmorBuffEffect`
- Delayed player death and run-loss tracking
- Shared `CCResistance` handling for control effects
- Rune data, pickups, and slot-based rune persistence
- HUD pickup flow, loadout selection, run summary, and main menu
- Procedural room generation with open exits and guaranteed dead-end shop branches
- In-world shop containing `ShopStation` upgrade menu, paid Restore card, free baseline rune, and priced weapon stalls
- Run loop persistence and enemy/boss scaling across loops (`1.0 + 0.25 * (loop - 1)`)
- `UpgradeManager` with tuned Qi economy numbers and spend tracking
- Runtime debug instrumentation (`[RUNLOG]`) logging room performance metrics

The active phase is P12 closeout complete. The implementation matches the design contract in [Design.md](Design.md).

## Opening the project

1. Open Godot 4.7.x.
2. Import this folder as a project.
3. Run the project from the editor or from the root startup scene.

## Controls

- Move: A/D or Left/Right
- Jump: Space
- Dodge: Left Shift
- Attack: left click / right click
- Skills: Q / E
- Pickup / Shop interaction: F (proximity-driven; pickups prioritize over shop station)
- Choose slot / Swap: Tab
- Inspect rune: I

## Testing

Run the full suite in headless mode with:

`& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`

Current verification status: 257/257 tests passed, 1,658 assertions, 0 failures, 2 expected warnings.

## Save data

Save data is handled by `SaveManager` and includes meta-progression, run history, and in-progress run state (including the procedural map layout, loop count, and active upgrade state). Qi and purchased ranks remain per-run state and are intentionally excluded from persistent meta-progression.

## Design and planning docs

- [Design.md](Design.md) — the implementation source of truth
- [AGENT_PLAN.md](AGENT_PLAN.md) — active checklist for phase work
- [plan.md](plan.md) — current execution log and verified status
- [plan-elemental_roguelike.md](plan-elemental_roguelike.md) — roadmap summary aligned with the current design contract
- [P12_RUN_OPTIMIZATION_PLAN.md](P12_RUN_OPTIMIZATION_PLAN.md) — run optimization and economy tuning specification
