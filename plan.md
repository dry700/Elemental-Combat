## Phase 3 — Control resistance

Status: Complete and validated with Godot 4.7.1/GUT.

Scope: This plan reflects the completed P3 work only. P4 and later tasks are intentionally excluded from the current scope and are tracked as the next phase instead of being folded into this review.

### Objective
- [x] Add the shared diminishing-returns control resistance tracker and route disable/slow applications through it.
- [x] Configure enemy and boss defaults for free-hit windows and tier-aware CC budgets.
- [x] Keep the project stable while shipping the control-resistance change with focused regression coverage.

### Required tasks
- [x] Add `CCResistance` with shared hit counting and window reset behavior.
- [x] Wire `ElementalCombatant.tick()`, `apply_control()`, and `apply_control_slow()` to the shared tracker.
- [x] Configure enemy stats and boss stats with `cc_free_hits` and `cc_window_seconds` defaults.
- [x] Update the relevant combat call sites that apply control effects and steam-cloud disables.
- [x] Add unit coverage for the diminishing-returns contract and the window reset.
- [x] Re-run the full GUT suite after the regression fix to confirm no broader combat breakage remained.

### Verification
- [x] Ran focused P3 validation and the full project suite.
  - Result: 190/190 tests passed with 355 assertions in 3.315s.
- [x] Ran static diagnostics on the project.
  - Result: no IDE errors reported.
- [x] Confirmed that the root cause of the broad Nil cascade was a compile-time class-loading issue in the new tracker, fixed with direct preload-based instantiation.

### Blockers and notes
- [x] Root cause: the new `CCResistance` class was referenced as a global type before the project had a stable class resolution path, triggering a compile cascade that made combatants appear as `Nil` everywhere.
- [x] Fix applied: load the tracker through a direct preload and instantiate it locally, which restored the full reaction stack without changing the intended control-resistance rules.
- [x] No remaining blockers for P3; P4 begins once this phase is closed.

### Exact next item to work on
- [ ] Start P4 tutorial flow: add the tutorial room and its progression gating, wire the save manager tutorial flag, and validate the first-time experience end to end.

### Out of scope for this step
- [x] Tutorial flow and other P4+ work
- [x] All later post-P3 gameplay development
