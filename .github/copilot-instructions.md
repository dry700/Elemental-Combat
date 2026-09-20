# Development Workflow Rules

## Plan File Enforcement
- When working on multi-step features, always check if `plan.md` exists in the workspace root.
- Never write code for multiple phases simultaneously. Only address the single active checkbox or task at hand.
- Do not mark an item as completed `[x]` in `plan.md` until you have verified the solution or tests pass.
- When an unforeseen architectural change, new dependency, or error occurs, update the "Decisions & Discoveries" or "Current Blocker" section in `plan.md`.