# Elemental Roguelike

A Godot 4.7 action-combat roguelike built around elemental reactions, charge resolution, procedural room generation, and a per-run Qi upgrade economy.

## Current implementation status

The project is beyond the initial prototype stage. The verified codebase includes:

- Armor mitigation and `ArmorBuffEffect`
- Delayed player death and run-loss tracking
- Shared `CCResistance` handling for control effects
- Rune data, pickups, and slot-based rune persistence
- HUD pickup flow, loadout selection, run summary, and main menu
- Procedural room generation with resume-safe map snapshot persistence
- `UpgradeManager` and Qi reward + stat/rank purchase logic

The active phase is P11 closeout: final documentation and repo polish after the T10b room-cleared upgrade menu implementation. The implementation boundary matches the design contract in [Design.md](Design.md).

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
- Pickup interaction: proximity and prompt-driven UI flow in the runtime HUD

## Testing

Run the full suite in headless mode with:

`& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`

Current verification status: 225/225 tests passed, 501 assertions, 0 failures, 2 expected warnings.

## Save data

Save data is handled by `SaveManager` and includes meta-progression, run history, and in-progress run state, including the procedural map layout when relevant. Qi and purchased ranks remain per-run state and are intentionally excluded from persistent save snapshots.

## Design and planning docs

- [Design.md](Design.md) — the implementation source of truth
- [AGENT_PLAN.md](AGENT_PLAN.md) — active checklist for phase work
- [plan.md](plan.md) — current execution log and verified status
- [plan-elemental_roguelike.md](plan-elemental_roguelike.md) — roadmap summary aligned with the current design contract
