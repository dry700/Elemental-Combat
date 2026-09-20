## Phase 4 — First-time tutorial

Status: Complete and validated with Godot 4.7.1/GUT.

Scope: This plan reflects the completed P4 work only. P5 and later tasks are intentionally excluded from the current scope and are tracked as the next phase instead of being folded into this review.

### Objective
- [x] Add the first-time tutorial room and stage progression flow.
- [x] Gate the tutorial exit behind a completed-state save flag.
- [x] Keep the project stable while shipping the tutorial flow and persistence change.

### Required tasks
- [x] Add the tutorial room scene and script with stage progression prompts.
- [x] Mark the tutorial complete state in `SaveManager` and persist it once.
- [x] Hook the tutorial completion path into the room exit and scene transition.
- [x] Validate the tutorial save flow and ensure the full project suite still passes.

### Verification
- [x] Ran the full Godot GUT suite after the P4 work.
  - Result: 191/191 tests passed with 359 assertions in 3.417s.
- [x] Ran static diagnostics on the project.
  - Result: no IDE errors reported.
- [x] Confirmed the tutorial completion flag persists idempotently without duplicate writes.

### Blockers and notes
- [x] No active blockers for P4; the tutorial flow is complete and validated.
- [x] The scene uses the project room/exit framework and reuses the standard `SaveManager` persistence path.
- [x] P5 begins once this phase is closed.

### Exact next item to work on
- [ ] Start P5 rune pickups and run-state persistence work: add rune pickups, update the player loadout pathing, and validate the pickup flow before moving on.

### Out of scope for this step
- [x] Rune pickups and other P5+ work
- [x] All later post-P4 gameplay development
