# Elemental Roguelike — Session Context File
*Generated: 2026-09-25 · Load this at the start of any new session to restore full project context.*

---

## Project Identity

| Field | Value |
|-------|-------|
| **Name** | Elemental Roguelike (Working Title) |
| **Engine** | Godot 4.7.1 stable (GDScript) |
| **Workspace** | `E:\FYP\elemental_roguelike\elemental_roguelike` |
| **Godot executable** | `E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe` |
| **GUT test command** | `& "E:\game-engine\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s "res://addons/gut/gut_cmdln.gd" -gdir=res://test -ginclude_subdirs -gexit` |
| **Source of truth** | `Design.md` (93 KB) |
| **Working checklist** | `AGENT_PLAN.md` |
| **Execution roadmap** | `.github/prompts/plan-elementalRoguelike.prompt.md` |
| **Sync prompt** | `.github/prompts/plan.prompt.md` |

---

## Autoloads (project.godot)

| Autoload | File | Role |
|----------|------|------|
| `InputSetup` | `autoloads/input_setup.gd` | Key binding registration |
| `HitStop` | `autoloads/hit_stop.gd` | Engine time scale for hit feel |
| `ScreenShake` | `autoloads/screen_shake.gd` | Camera shake |
| `VisionBlocker` | `autoloads/vision_blocker.gd` | Douse steam cloud vision |
| `SaveManager` | `autoloads/save_manager.gd` | JSON save (meta-progression, run history, in-progress run, tutorial_completed) |
| `RunManager` | `autoloads/run_manager.gd` | Room sequencing for a single run |
| `Hud` | `autoloads/hud.gd` | Always-on combat HUD + pickup overlay; owns all pickup chooser input |

---

## Critical Rules (never break these)

- Never edit `scripts/reactions/reaction_resolver.gd`
- Never hand-write `.uid` files
- One phase = one commit
- Run GUT after every phase before advancing
- Keep `.tscn` files path-only; use `find_child` fallbacks
- Use `test/helpers/save_test_isolation.gd` for SaveManager tests (redirects to throwaway file)
- Use deferred `add_child` (`call_deferred`) for Area2D-spawned nodes from physics callbacks
- Treat unresolved design gaps as the explicit defaults listed in AGENT_PLAN.md

---

## Phase Status

| Phase | Status | Test result |
|-------|--------|-------------|
| P0 — Repo hygiene | Complete | Verified |
| P1 — Armor mitigation + ArmorBuffEffect | Complete | Verified |
| P2 — Player death delay (0.6 s fade before `died.emit()`) | Complete | Verified |
| P3 — CCResistance + CC handling | Complete | Verified |
| P4 — Tutorial room + SaveManager.tutorial_completed | Complete | Verified |
| **P5a — RuneData, RuneRoller, RunePickup, drop wiring** | Complete | **198/198 tests, 374 assertions** |
| **P5b — Player slot runes + persistence** | Complete | **201/201 tests, 390 assertions** |
| P5c — Pickup swap HUD, Tab/I inputs, Monogram font | **NEXT** | — |
| P5d — Charge pips, Vu readability, playtest checkpoint | Blocked by P5c | — |
| P6 — Loadout selection | Deferred | — |
| P7 — Run summary + finish-run transitions | Deferred | — |
| P8 — Main menu + startup scene | Deferred | — |
| P9 — Room pool expansion (6 rooms; currently 4) | Deferred | — |
| P10a-f — Qi + UpgradeManager + specializations | Deferred | — |
| P11 — Final verification + closeout docs | Deferred | — |

---

## Key Architecture Patterns

### ElementalCombatant (composition, not inheritance)
- **File**: `scripts/reactions/ElementalCombatant.gd`
- Player is `CharacterBody2D`, dummies are `StaticBody2D`/`CharacterBody2D` — no common ancestor
- This is a **composed Node2D** added as a child
- Usage: `var elemental := ElementalCombatant.new()` then set `indicator_offset` and `armor` then `add_child(elemental)`
- Each physics frame: `elemental.tick(delta)` — apply returned DoT damage to owner's health
- Signals: `bonus_damage_dealt(amount)` (Wildfire chain), `disabled_expired`
- Has: `armor`, `armor_buff: ArmorBuffEffect`, `cc_resistance: CCResistance`, `innate_element`, `status: ElementalStatus`, `dot_effect`, `slow_effect`, `disable_effect`
- Public API: `handle_hit(hit_data)`, `mitigate_damage(amount) -> float`, `is_disabled() -> bool`, `is_slowed() -> bool`

### RuneRoller (instance-based singleton)
- **File**: `scripts/resources/runes/rune_roller.gd`
- Refactored from static methods to instance-based (2026-09-25) to fix GUT headless `class_name` resolution issue
- **Production use**: `RuneRoller.default().roll(element, target, rng)` — shared singleton, empty catalogue by default
- **Test use**: `RuneRollerScript.new()` via `preload(...)` then `roller.set_catalogue([...])` then `roller.roll(...)`
- `set_catalogue(defs: Array[RuneModifierDef])` — must be called before `roll()` returns anything useful
- `roll(element: StringName, target: RuneData.Target, rng = null) -> RuneData`

### SaveManager (save isolation in tests)
- **File**: `autoloads/save_manager.gd`
- Save path: `user://save_data.json` (redirected in tests via `test/helpers/save_test_isolation.gd`)
- Default data keys: `version`, `unlocked_weapons`, `unlocked_skills`, `run_history`, `in_progress_run`, `tutorial_completed`
- Additive migration: missing keys from older saves are filled with defaults, not rejected
- API: `is_tutorial_completed() -> bool`, `mark_tutorial_completed()`, `record_run_result(...)`, `save_in_progress_run(data)`, `clear_in_progress_run()`

### Player (CharacterBody2D)
- **File**: `scenes/player/player.gd`
- Has `weapon: WeaponStats`, `secondary_weapon: WeaponStats`, `skill_1: SkillData`, `skill_2: SkillData`
- **Does NOT yet have** `weapon_rune` or `secondary_weapon_rune` — that is P5b
- Signals: `weapon_changed(is_primary, new_weapon)`, `skill_changed(is_primary, new_skill)`, `died`
- Death: `_die()` grays visuals, `await get_tree().create_timer(0.6).timeout`, emits `died`
- Save API: `to_save_state() -> Dictionary`, `apply_save_state(data: Dictionary)`

### Hud (autoload CanvasLayer)
- **File**: `autoloads/hud.gd`
- Owns ALL pickup chooser input — WeaponPickup/SkillPickup scripts only track proximity
- Player checks `Hud.is_overlay_active()` to freeze voluntary input during chooser
- Drawn entirely in code (no .tscn) to avoid NodePath fragility
- UI scale: `const UI_SCALE: float = 0.5` (window is 2x the viewport)

---

## P5b — Next Phase Checklist

> Gate: P5a verified. Start P5b.

### Files to create/modify
- `scenes/player/player.gd` — add rune slots + API
- `scripts/items/weapon_pickup.gd` — carry rune through pickup swap
- `test/unit/test_player_save_state.gd` — extend for rune round-trip cases
- New: `test/unit/test_player_rune_slots.gd` (or extend existing weapon swap tests)

### Required Player API (from Design.md + plan.md)

```gdscript
# New vars on Player:
var weapon_rune: RuneData = null
var secondary_weapon_rune: RuneData = null

# New methods:
func get_weapon_rune(is_primary: bool) -> RuneData
func can_apply_rune(rune: RuneData, is_primary: bool) -> bool
func apply_rune(rune: RuneData, is_primary: bool) -> RuneData  # returns old rune if any

# Modified:
func swap_weapon(new_weapon: WeaponStats, is_primary: bool, new_rune: RuneData = null) -> WeaponStats
```

### Key constraints for P5b
- Weapon `Resource` objects are **never duplicated** — preserve `resource_path`
- A rune **travels with its weapon** on `swap_weapon()` and dropped `WeaponPickup` instances
- Resolve effective rune element: slot rune first, then authored `weapon.rune_element` as fallback
- Same-element Charge bonus only — modifiers act at the effect layer, never mutate raw Charge in resolver
- Save rune as dict via `rune.to_dict()` in `to_save_state()`; restore via `RuneData.from_dict()` in `apply_save_state()`
- **Missing rune keys in older saves** → `null` rune (no crash)
- **Unknown modifier ids** → `push_warning` and skip (no crash)
- Overwrite (chooser-only): drop old rune as a new `RunePickup` near player position

### Verification gate for P5b
- Pass: rune apply, weapon swap carry, skill-charge, and Player save/load tests
- Pass: existing `test_player_weapon_swap.gd`, `test_player_save_state.gd` (must not regress)
- Confirm: old saves load with `null` rune when rune keys are absent
- Confirm: unknown modifier ids warn and skip rather than crash

---

## Rune System Overview (P5a complete)

### RuneData (`scripts/resources/runes/rune_data.gd`)
- `element: StringName`, `target: Target (WEAPON|SKILL)`, `modifiers: Array[Dictionary]`
- Each modifier: `{"id": StringName, "value": float}`
- `to_dict() -> Dictionary`, `static from_dict(data) -> RuneData` (returns null on invalid)
- `describe_lines() -> Array[String]`

### RuneModifierDef (`scripts/resources/runes/rune_modifier_def.gd`)
- `@export id: StringName`, `applies_to: AppliesTo (WEAPON|SKILL|BOTH)`, `elements: Array[StringName]` (empty = any)
- `value_min`, `value_max`, `value_step` (0 = continuous)
- `applies_to_rune(target, element) -> bool`

### RuneRoller (`scripts/resources/runes/rune_roller.gd`)
- Instance-based; `TWO_MODIFIER_CHANCE = 0.25` placeholder
- `set_catalogue(defs)`, `roll(element, target, rng=null) -> RuneData`
- Empty pool → warning + empty RuneData returned (no crash)
- Production: `RuneRoller.default().roll(...)` | Tests: own instance via `preload`

### RunePickup (`scripts/items/rune_pickup.gd`)
- `class_name RunePickup extends Area2D`
- `var rune: RuneData` (runtime, no export)
- Weapon rune: square frame (gold). Skill rune: circle frame (teal)
- `add_to_group("rune_pickups")`, tracks `_player_in_range`
- Hud owns chooser input; pickup only exposes proximity state
- `static roll_spirit_element(own_element) -> StringName` — 60% same, 40% random other
- Drop wiring: `boss.gd`, `patrol_dummy.gd`, `test_dummy.gd` call `RuneRoller.default().roll(...)` in `_die()`
- Room clear: `room_controller.gd` drops a baseline weapon rune near the exit

---

## Open Design Decisions

| ID | Decision | Default |
|----|----------|---------|
| D1 | Weapon Might + Vitality upgrades (skip or implement?) | Skip until clarified |
| D2 | Missing getter API naming | Read-site-derived names |
| D3 | Upgrade menu input + room-state gating | Tab-based while room is cleared |
| D4 | Upgrade effects apply to player only or all combatants? | Player only |
| D5 | Tutorial to Loadout routing | Tutorial routes to loadout |
| D6 | Main menu + summary navigation | Add Main Menu path, keep quit explicit |
| D7 | TestDummy/PatrolDummy DoT wiring change | Adopt it |
| D8 | Upgrade persistence | Document as tech debt |
| D15 | F = direct-equip empty only; Tab = chooser | Confirmed in plan, not yet implemented |
| D16 | Rune travels with weapon on swap/drop | Confirmed in plan, not yet implemented |
| D17 | One RunePickup script with `target` field | Confirmed in code |
| D18 | Tune 25% two-modifier chance | Post first-pass playtest |
| D19 | Define modifier catalogue; global vs per-element pools | Undefined |
| D20 | Fix stray enemy_stats fragment + training_staff (1).tres duplicate | Not yet cleaned up |

---

## Directory Map

```
elemental_roguelike/
├── AGENT_PLAN.md                    <- working checklist
├── Design.md                        <- source of truth (93 KB)
├── plan.md                          <- per-sub-phase detailed plan
├── plan-elemental_roguelike.md      <- broader phase plan
├── project.godot                    <- main scene = scenes/world/test_arena.tscn
├── .github/prompts/
│   ├── plan-elementalRoguelike.prompt.md
│   └── plan.prompt.md
├── autoloads/
│   ├── hud.gd                       <- HUD + pickup chooser
│   ├── input_setup.gd
│   ├── run_manager.gd
│   └── save_manager.gd
├── scenes/
│   ├── enemies/                     <- boss.gd, patrol_dummy.gd, test_dummy.gd
│   ├── player/player.gd             <- Player (CharacterBody2D)
│   └── world/
│       ├── rooms/                   <- room_a, room_b, room_c, room_boss
│       ├── tutorial_room.tscn
│       └── procedural_run.tscn
├── scripts/
│   ├── combat/                      <- projectiles, hitbox, hurtbox, VFX
│   ├── items/
│   │   ├── rune_pickup.gd           <- RunePickup (Area2D)
│   │   ├── weapon_pickup.gd
│   │   └── skill_pickup.gd
│   ├── reactions/
│   │   ├── ElementalCombatant.gd    <- composed component (not base class)
│   │   ├── reaction_resolver.gd     <- NEVER EDIT THIS FILE
│   │   ├── armor_buff_effect.gd
│   │   ├── cc_resistance.gd
│   │   ├── dot_effect.gd
│   │   ├── slow_effect.gd
│   │   └── disable_effect.gd
│   ├── resources/
│   │   ├── enemies/
│   │   ├── runes/
│   │   │   ├── rune_data.gd
│   │   │   ├── rune_modifier_def.gd
│   │   │   └── rune_roller.gd
│   │   ├── skills/
│   │   └── weapons/
│   ├── ui/                          <- element_indicator.gd, dot_indicator.gd
│   ├── visuals/
│   └── world/
│       ├── room_controller.gd       <- room-clear drop logic
│       └── tutorial_room.gd
└── test/
    ├── helpers/                     <- save_test_isolation.gd
    ├── unit/                        <- 20 unit test files
    └── integration/                 <- 12 integration test files
```

---

## Verification Baseline

| Milestone | Tests | Assertions | Failures |
|-----------|-------|------------|---------|
| P4 complete | 191 | 359 | 0 |
| P5a complete | 198 | 374 | 0 |

1 persistent expected warning: `SpriteVisual has no fallback_polygon` in `test_sprite_visual.gd` — this is an `[ExpectedError]` block and is correct.

---

## GUT Headless Notes

- `class_name` resolution can fail in GUT's headless runner for **static method calls on class-name classes**
- Fix: use `preload("res://path/to/script.gd")` and call `.new()` or methods on the preloaded reference
- `RuneRoller` was the first case of this; fix is now in `test_rune_roller.gd`
- Boss integration test: `_die()` spawns a `RunePickup` via `RuneRoller.default().roll()` — in tests, null `boss_stats` just before the lethal hit to skip the rune drop guard branch

---

## Commit Convention

```
feat(P5X): short description

Longer body if needed.
Verification: N/N tests, M assertions.
```

One phase per commit. Do not commit until GUT passes.
