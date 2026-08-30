# Elemental Roguelike (Working Title)

Sprint 1 scaffold: core combat feel only. No elemental reaction system yet —
that's Sprint 2+, per the design rationale in Appendix A.3 of the proposal
("build and tune core combat before any elemental system is added").

## Opening the project

1. Open Godot **4.7.x** (this was written against 4.7 conventions specifically).
2. Import this folder as a project (Godot will detect `project.godot`).
3. Run the project (F5) — it should open straight into `test_arena.tscn`.

**I wrote this without a running Godot instance to test it against**, since
this environment doesn't have Godot installed. It's a first-pass scaffold
built carefully against known Godot 4.x conventions, not something I've
personally confirmed runs frame-perfect. Please treat the first run as a
verification step, not an assumption — see "If something doesn't work"
below for the most likely failure points and how to fix them fast.

## Controls

| Action | Key |
|---|---|
| Move | A/D or Left/Right arrows |
| Jump | Space |
| Dodge | Left Shift |
| Attack | left and right click |

Input actions are defined in code (`autoloads/input_setup.gd`), not in
Project Settings → Input Map. To rebind, edit the `*_KEYS` constants at the
top of that file. See the comment there for why it's done this way instead
of hand-editing `project.godot`.

## What's actually implemented (Sprint 1 scope)

- Movement: acceleration/friction-based horizontal movement, not instant
  velocity snapping — this is the "response curve" half of Swink's (2009)
  feel model.
- Jump with coyote time and jump buffering (standard feel techniques,
  nothing element-related).
- Dodge roll with a partial i-frame window (not the whole dodge duration —
  see the comment in `player.gd` for why a full-duration invuln window
  would make dodge spam degenerate).
- A single test attack (Hitbox/Hurtbox components) with hit-stop on
  connect — the "juice" half of Swink's model.
- A `TestDummy` that flashes and tracks damage taken, so hit feedback can
  be judged against something static before any real enemy AI exists.

## What's deliberately NOT implemented yet

- Elements, Charge, Sinh/Khắc/Cheng/Wu resolution — `HitData` carries
  placeholder `element`/`charge` fields (all `"none"`/`0`) so the
  Hitbox/Hurtbox shape won't need to change later, but nothing reads them
  yet.
- The rune system, skills, Break-Free, and the internal cooldown on
  element application (Appendix A.3) — all downstream of the reaction
  system landing first.
- Real art — `PlaceholderVisual` nodes are flat-colour `Polygon2D`s, swapped
  for actual 16×16 Aseprite sprites later (Appendix A.1).
- Enemy AI (`TestDummy` never attacks back or dies) — that's Appendix A.6,
  after combat feel is validated.

## If something doesn't work

Most likely failure points, roughly in order of likelihood:

1. **Player falls through the floor / doesn't collide.** Check
   `Ground`'s `CollisionShape2D` has a valid shape assigned in the
   inspector — if the `.tscn` sub-resource reference didn't parse cleanly,
   Godot usually still opens the scene but with an empty shape.
2. **Nothing happens on input.** Confirm `InputSetup` and `HitStop` show
   up under Project Settings → Autoload — they're registered in
   `project.godot`, but worth a quick visual check on first open.
3. **Attack doesn't damage the dummy.** Check the `Hitbox` and `Hurtbox`
   collision layer/mask numbers in each scene's inspector — the intended
   pairing is Hitbox `mask=2` matching Hurtbox `layer=2`. If either got
   mis-set, `area_entered` won't fire.
4. **`training_dagger.tres` shows as broken/missing** in the `Player`
   node's `weapon` slot. `player.gd`'s `_ready()` falls back to a default
   `WeaponStats.new()` if this happens, so combat should still work with
   generic numbers — but re-saving the `.tres` from the editor (open it,
   Ctrl+S) will regenerate it cleanly if needed.

None of these would be silent failures — Godot's editor and output panel
will flag missing shapes/scripts on scene open, so the first F5 run should
surface anything wrong quickly.

## Next steps (Sprint 2)

Wire up `HitData.element` / `HitData.charge`, add the Sinh/Khắc resolver
(Appendix A.3) as a new autoload, and give `TestDummy` an element so
reactions have something to fire against.
