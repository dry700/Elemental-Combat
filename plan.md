## Phase 2 — Player death delay

Status: Complete and validated with Godot 4.7.1/GUT.

Scope: This plan reflects the completed P2 work only. P3 and later tasks are intentionally excluded from the current scope and are tracked as the next phase instead of being folded into this review.

### Objective
- [x] Replace immediate player death signaling with the planned delayed fade/tint sequence.

### Required tasks
- [x] Set the player death tint and invulnerability immediately when lethal damage lands.
- [x] Wait 0.6 seconds before emitting the `died` signal.
- [x] Preserve one-shot death behavior through the existing `_is_dead` guard.
- [x] Update player death tests to await the delayed signal.
- [x] Update RunManager persistence tests to await the delayed signal.

### Verification
- [x] Ran focused P2 death and persistence validation.
  - Result: all selected tests passed.
- [x] Ran the full GUT validation for the current worktree.
  - Result: 188/188 tests passed with 347 assertions in 4.137s.
- [x] Ran static diagnostics on the project.
  - Result: no IDE errors reported.
- [x] Confirmed that no P3 or later phases are included in this scope.

### Blockers and notes
- [x] Architectural note: death remains owner-controlled; the player enters its terminal state immediately, while RunManager reacts only after the delayed `died` signal.
- [x] No new blockers or architectural changes were discovered in this review.
- [x] Follow-up note: the next work item is P3 (`CCResistance`) and should be implemented in a separate, verified phase.

### Exact next item to work on
- [ ] Start P3 control resistance: add `CCResistance`, configure enemy tiers/windows, route gameplay slow/disable applications through shared resistance, add focused tests, and rerun the full GUT suite.

### Out of scope for this step
- [x] Armor mitigation and other P1 work
- [x] Control resistance and other P3 or later work
