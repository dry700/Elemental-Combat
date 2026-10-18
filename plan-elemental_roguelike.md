# Elemental Roguelike Plan

This roadmap is synchronized with [Design.md](Design.md) and [AGENT_PLAN.md](AGENT_PLAN.md). P13 (Perfect Hit and weapon window expansion) is complete; next milestone is P14 (skill system expansion).

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
- [x] P11 — Final verification and documentation closeout
- [x] P12 — Run optimization and economy tuning (Phases 1–9 complete)
- [x] P13 — Perfect Hit and weapon window expansion
- [ ] P14 — Skill system expansion

## P12 run optimization summary

- Normal procedural room exits are open from the start (`exit.locked = false`). Boss room remains locked until victory.
- Guaranteed dead-end shop branch with no enemy spawns (`shop_cell`).
- Shop contains `ShopStation` (F interaction opens card menu), 30% max HP Restore option (`20 + 10 * uses`, free at full HP), free baseline weapon rune, and two priced weapon stalls (Light: 35, Medium: 45, Heavy: 55 Qi). Refresh Shop fee removed.
- Loop persistence and scaling: `RunManager` tracks loops (`loop`); victory carries Qi, upgrades, weapons, and runes; enemy HP and damage scale by `1.0 + 0.25 * (loop - 1)` via `EnemySpawnPoint.spawn()`; death resets to loop 1.
- Tuned Qi economy: Normal brawler 5 Qi, Elemental spirit 8 Qi, Flying/Shooter/Swooper 3 Qi, Boss 30 Qi; Might/Vitality cost `20 + 12 * rank`; Sinh/Khắc Rank 1: 25 Qi, Rank 2: 55 Qi.
- Instrumentation: `[RUNLOG]` delta metrics per completed room in debug builds.

## P13 Perfect Hit summary

- Shared hit windows multiply damage and set `HitData.perfect`; Charge and reaction inputs remain unchanged.
- Existing weapon windows and six shop-only weapons are configured. The crossbow fires a five-arrow, 30-degree volley.
- Weapon cards show their Perfect Hit condition; hit feedback uses a yellow “Perfect!” popup and the heavy feel preset.
- Full GUT verification: 269/269 tests passed, 1,760 assertions, 0 failures, 2 expected headless warnings.

## Verification and blockers

- P12 full-suite verification: 257/257 tests passed, 1,658 assertions, 0 failures, with 2 expected headless warnings.
- P13 full-suite verification: 269/269 tests passed, 1,760 assertions, 0 failures, with 2 expected headless warnings.
- Static diagnostics: clean across all workspace files.
- Blockers: none; all changes verified against [Design.md](Design.md).

## Exact next item

P13 is complete. Next milestone is P14: implement the skill roadmap in [SKILL_PLAN.md](SKILL_PLAN.md).
