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
| **GUT test command** | `& "E:\...\Godot_v4.7.1-stable_win64_console.exe" --headless --path "E:\FYP\elemental_roguelike\elemental_roguelike" -s "res://addons/gut/gut_cmdln.gd" -gdir=res://test -ginclude_subdirs -gexit` |
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
| P5b — Player slot runes + persistence | **NEXT** | — |
| P5c — Pickup swap HUD, Tab/I inputs, Monogram font | Blocked by P5b | — |
| P5d — Charge pips, Vu readability, playtest checkpoint | Blocked by P5c | — |
| P6–P11 | Deferred until P5d verified | — |

---

## Key Architecture Patterns

### ElementalCombatant (composition, not inheritance)
- **File**: `scripts/reactions/ElementalCombatant.gd`
- Player is `CharacterBody2D`, dummies are `StaticBody2D`/`CharacterBody2D` — no common ancestor
- Composed `Node2D` added as a child
- Usage: `var elemental := ElementalCombatant.new()` → set `indicator_offset` + `armor` → `add_child(elemental)`
- Each physics frame: `elemental.tick(delta)` → apply returned DoT damage to owner health
- Signals: `bonus_damage_dealt(amount)`, `disabled_expired`
- API: `handle_hit(hit_data)`, `mitigate_damage(amount)`, `is_disabled()`, `is_slowed()`

### RuneRoller (instance-based singleton)
- **File**: `scripts/resources/runes/rune_roller.gd`
- Refactored from static to instance-based (2026-09-25) to fix GUT headless class_name resolution issue
- **Production**: `RuneRoller.default().roll(element, target, rng)` — shared singleton, empty catalogue by default
- **Tests**: `preload("...rune_roller.gd").new()` → `roller.set_catalogue([...])` → `roller.roll(...)`

### SaveManager
- **File**: `autoloads/save_manager.gd`
- Default keys: `version`, `unlocked_weapons`, `unlocked_skills`, `run_history`, `in_progress_run`, `tutorial_completed`
- Additive migration — missing keys filled from defaults, never rejects older saves
- Tests redirect save path via `test/helpers/save_test_isolation.gd`

### Player
- **File**: `scenes/player/player.gd` (`CharacterBody2D`)
- Equipment: `weapon`, `secondary_weapon` (`WeaponStats`), `skill_1`, `skill_2` (`SkillData`)
- **P5b adds**: `weapon_rune`, `secondary_weapon_rune` (`RuneData`)
- Death: `await get_tree().create_timer(0.6).timeout` then `died.emit()`
- Save: `to_save_state() -> Dictionary`, `apply_save_state(data)`

### Hud
- **File**: `autoloads/hud.gd` (`CanvasLayer`)
- Owns ALL pickup chooser input; WeaponPickup/SkillPickup scripts are proximity-only
- Player gates voluntary input with `Hud.is_overlay_active()`
- Drawn in code (no .tscn); `UI_SCALE = 0.5`

---

## P5b — Next Phase Checklist

> Gate: P5a verified. Start P5b now.

### New Player API needed

```gdscript
var weapon_rune: RuneData = null
var secondary_weapon_rune: RuneData = null

func get_weapon_rune(is_primary: bool) -> RuneData
func can_apply_rune(rune: RuneData, is_primary: bool) -> bool
func apply_rune(rune: RuneData, is_primary: bool) -> RuneData  # returns old rune

# Modified signature:
func swap_weapon(new_weapon: WeaponStats, is_primary: bool, new_rune: RuneData = null) -> WeaponStats
```

### Key constraints
- Weapon Resources never duplicated — preserve `resource_path`
- Rune travels with its weapon on swap and dropped WeaponPickup
- Effective rune element: slot rune first, authored `weapon.rune_element` as fallback
- Charge bonus only from same-element rune — never mutate raw Charge in resolver
- Missing rune keys in older saves → `null` rune (no crash)
- Unknown modifier ids → `push_warning` and skip (no crash)
- Chooser-only overwrite → drop old rune as a new `RunePickup` near player

### Verification gate
- Pass: rune apply, weapon swap carry, skill-charge, and Player save/load tests
- Confirm: old saves load with null rune; unknown modifier ids warn+skip

---

## Rune System (P5a complete)

| Class | File | Role |
|-------|------|------|
| `RuneData` | `scripts/resources/runes/rune_data.gd` | Rolled rune state; `to_dict()`/`from_dict()` |
| `RuneModifierDef` | `scripts/resources/runes/rune_modifier_def.gd` | Catalogue entry; `applies_to_rune(target, element)` |
| `RuneRoller` | `scripts/resources/runes/rune_roller.gd` | Roll logic; instance-based; `default()` singleton |
| `RunePickup` | `scripts/items/rune_pickup.gd` | World pickup (Area2D); square=weapon, circle=skill |

Drop callers use `RuneRoller.default().roll(...)`: `boss.gd`, `patrol_dummy.gd`, `test_dummy.gd`, `room_controller.gd`

---

## Open Design Decisions

| ID | Default |
|----|---------|
| D1 — Weapon Might + Vitality | Skip until clarified |
| D2 — Missing getter API naming | Read-site-derived names |
| D3 — Upgrade menu gating | Tab while room is cleared |
| D4 — Upgrade effect scope | Player only |
| D5 — Tutorial routing | Tutorial → Loadout |
| D6 — Main menu navigation | Add Main Menu path |
| D7 — DoT wiring change | Adopt it |
| D8 — Upgrade persistence | Tech debt note |
| D15 — F/Tab key flow | F = empty only; Tab = chooser |
| D16 — Rune travel on swap | Travels with weapon |
| D17 — RunePickup shape | One script with `target` field |
| D18 — Two-modifier chance | Post playtest tune |
| D19 — Modifier catalogue | Not yet defined |
| D20 — Stray file cleanup | Not yet done |

---

## Directory Map (key files)

```
elemental_roguelike/
├── AGENT_PLAN.md                    <- working checklist
├── Design.md                        <- source of truth (93 KB)
├── plan.md / plan-elemental_roguelike.md
├── project.godot                    <- main scene = test_arena.tscn
├── autoloads/
│   ├── hud.gd, input_setup.gd, run_manager.gd, save_manager.gd
├── scenes/
│   ├── enemies/ (boss.gd, patrol_dummy.gd, test_dummy.gd)
│   ├── player/player.gd
│   └── world/rooms/ (room_a/b/c/boss.tscn)
├── scripts/
│   ├── items/ (rune_pickup.gd, weapon_pickup.gd, skill_pickup.gd)
│   ├── reactions/
│   │   ├── ElementalCombatant.gd   <- composed component
│   │   ├── reaction_resolver.gd    <- NEVER EDIT
│   │   └── armor_buff, cc_resistance, dot, slow, disable effects
│   └── resources/runes/
│       ├── rune_data.gd
│       ├── rune_modifier_def.gd
│       └── rune_roller.gd
└── test/ (unit/ + integration/ + helpers/)
```

---

## Verification Baseline

| Milestone | Tests | Assertions |
|-----------|-------|------------|
| P4 complete | 191 | 359 |
| P5a complete | **198** | **374** |

Expected warning: `SpriteVisual has no fallback_polygon` in `test_sprite_visual.gd` — is an `[ExpectedError]` block, correct.

---

## GUT Headless Gotchas

- `class_name` static method calls can silently fail in GUT headless runner
- Fix: `preload("res://path/script.gd")` and call `.new()` on the result
- `RuneRoller` was the first case — `test_rune_roller.gd` now uses preload instantiation
- Boss `_die()` spawns a `RunePickup` during tests — null `boss_stats` just before lethal hit to skip the rune drop guard

---

## Commit Convention

```
feat(P5X): short description

Body if needed.
Verification: N/N tests, M assertions.
```
