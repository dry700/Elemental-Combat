# 4+1 Architecture View Model Drawing Plan

## Purpose

Produce a report-ready 4+1 architecture model for the Elemental Roguelike.
The diagrams must describe the implemented Godot architecture, not only the
original proposal. `Design.md` is the primary source of truth; unresolved or
planned systems must be shown as planned rather than as implemented.

## Deliverables

Create six diagrams and one short explanatory page:

1. **Scenario view** — the `+1` view showing the important player workflows.
2. **Logical view** — the major runtime responsibilities and their relations.
3. **Process view** — runtime message flow for combat and room transitions.
4. **Development view** — code, scene, resource, autoload, and test organisation.
5. **Physical view** — Godot runtime/deployment nodes and persisted data.
6. **Overview diagram** — a small index showing how the five views fit together.
7. **Architecture notes** — assumptions, scope, notation, and traceability.

Recommended output formats are editable diagrams (draw.io, diagrams.net, or
equivalent) plus exported PNG/PDF images. Keep diagram source files beside the
exports so they can be updated when the implementation changes.

## UML Diagram Plan

The existing `ARCHITECTURE_4_PLUS_1.drawio` file is the architecture-view
model. Add four UML-focused pages to that file, or create a separate UML file
if the report needs less crowded pages:

1. **Use Case Diagram** — user goals and system boundaries.
2. **Class Diagram** — static code structure and composition relationships.
3. **Sequence Diagram** — ordered messages for the main runtime interactions.
4. **Activity Diagram** — decisions and control flow from input to outcome.

Keep one diagram focused on one question. Do not place every script or every
reaction in one page; use package boundaries and linked detail pages instead.

### 1. Use Case Diagram

#### System boundary

Draw one boundary named **Elemental Roguelike Game System**. Place actors
outside it and use cases inside it.

#### Actors

- **Player** — human actor controlling movement, combat, pickups, and run flow.
- **Godot Runtime** — starts scenes, processes physics, and manages scene tree
  execution.
- **Local Save File** — external persistence target represented by
  `user://save_data.json`.
- **Developer / Tester** — runs the project and GUT tests.

#### Use cases

- `Start Game`
- `Resume Run`
- `Move, Jump, and Dodge`
- `Attack Enemy`
- `Cast Skill`
- `Trigger Elemental Reaction`
- `Clear Room`
- `Collect Weapon, Skill, or Rune`
- `Select Pickup`
- `Save Run State`
- `Complete or Lose Run`
- `View Run Result`
- `Run Automated Tests`

#### Relationships to draw

- `Start Game` includes `Load Save Data` when a resume record exists.
- `Attack Enemy` includes `Resolve Hit` and may extend to `Trigger Elemental
  Reaction`.
- `Clear Room` includes `Spawn/Enable Pickup` and `Unlock Exit`.
- `Collect Weapon, Skill, or Rune` includes `Select Pickup` and `Save Run State`.
- `Complete or Lose Run` includes `Record Run Result` and `View Run Result`.
- `Developer / Tester` is associated with `Run Automated Tests`.

#### Acceptance check

Every major player-facing workflow in the Scenario (+1) page must appear as a
use case. Keep implementation names such as `ReactionResolver` and
`RunManager` out of the use-case labels; those belong in the class and sequence
diagrams.

### 2. Class Diagram

#### Packages and classes

Draw these packages with `<<scene script>>`, `<<component>>`, `<<resource>>`,
`<<autoload>>`, or `<<data>>` stereotypes:

- **Player/combat**: `Player`, `Hitbox`, `Hurtbox`, `HitData`, `WeaponStats`,
  `SkillData`.
- **Elemental domain**: `ElementalCombatant`, `Elements`, `ElementalStatus`,
  `ReactionResolver`, `DotEffect`, `SlowEffect`, `DisableEffect`,
  `CCResistance`.
- **Enemies**: `TestDummy`, `PatrolDummy`, `Boss`, `EnemyCombatAI`,
  `EnemyStats`, `BossStats`.
- **World/run**: `RoomController`, `EnemySpawnPoint`, `RoomExit`,
  `RunManager`.
- **Items/UI/persistence**: `WeaponPickup`, `SkillPickup`, `RunePickup` when
  implemented, `Hud`, and `SaveManager`.
- **Services**: `InputSetup`, `HitStop`, `ScreenShake`, `VisionBlocker`.

#### Attributes and operations to show

Only show members that explain an architectural relationship:

- `Player`: `state`, `weapon`, `secondary_weapon`, `elemental`,
  `_try_start_attack()`, `_try_cast_skill()`, `_apply_damage()`.
- `ElementalCombatant`: `status`, `dot_effect`, `slow_effect`, `disable_effect`,
  `cc_resistance`, `handle_hit()`, `tick()`, `mitigate_damage()`.
- `Hitbox`: hit configuration and overlap handling.
- `Hurtbox`: `take_hit()` and `hit_received` signal.
- `ReactionResolver`: reaction category resolution.
- `RunManager`: room sequencing, start/finish, and scene transition operations.
- `SaveManager`: load, save, resume, meta-progression, and run-history APIs.
- `Hud`: overlay state and pickup confirmation.

#### Relationships to draw

- Composition: `Player` and each enemy body contain one
  `ElementalCombatant`; enemy bodies also contain `EnemyCombatAI` where used.
- Association: `Player` and enemy bodies use `Hitbox` and `Hurtbox`.
- Dependency: `ElementalCombatant` uses `ReactionResolver` and effect classes.
- Dependency: `Player` uses `WeaponStats` and `SkillData` resources.
- Association: `RoomController` creates enemy instances and controls
  `RoomExit`.
- Dependency: `RunManager` uses `SaveManager`; `Hud` reads player/pickup state.
- Signal relation: `Hurtbox.hit_received` and body `died` signals notify their
  owning controller.

#### Important modelling rules

- Do not create a shared `Enemy` or `Combatant` superclass. The implementation
  uses composition and duck-typed attacker/owner boundaries.
- Do not draw autoloads as ordinary instantiated scene nodes; mark them
  `<<autoload>>` and note that they are script-only singletons.
- Mark `UpgradeManager` as `<<planned>>` or omit it because it is not yet
  implemented.

### 3. Sequence Diagram

Create separate sequence pages for the following interactions. Use lifelines
for the named classes and label calls with the real method or signal where the
source documents provide one.

#### Sequence A: Elemental attack

Lifelines: `Player`, `WeaponStats`, `Hitbox`, `Hurtbox`, target body,
`ElementalCombatant`, `ReactionResolver`, `HitStop`, `ScreenShake`.

1. `Player` receives attack input from `InputSetup`.
2. `Player._try_start_attack()` starts or chains the attack.
3. `Player._process_attack()` activates the hitbox window.
4. `Player` asks `WeaponStats.resolve_swing()` for swing element and Charge.
5. `Hitbox` overlaps target `Hurtbox` and creates `HitData`.
6. `Hurtbox.take_hit()` emits `hit_received` to the target body.
7. Target body applies mitigated damage and knockback.
8. Target `ElementalCombatant.handle_hit(hit_data)` resolves the reaction.
9. `HitStop` and `ScreenShake` provide feedback; timed effects tick later.

Add an `alt` fragment for no collision/no hit and an `opt` fragment for a
reaction effect that creates a projectile or terrain object.

#### Sequence B: Pickup selection and room transition

Lifelines: `Player`, `Hud`, pickup, `RoomController`, `RunManager`,
`SaveManager`, next room scene.

1. Pickup proximity becomes available to `Hud`.
2. `Hud` opens the overlay and blocks voluntary player input.
3. Player confirms a weapon, skill, or rune selection.
4. `Hud` applies the selection to `Player` and closes the overlay.
5. `RoomController` detects all enemies defeated and enables the exit.
6. Player enters `RoomExit`; `RunManager` advances the run.
7. `RunManager` asks `SaveManager` to persist the room-boundary state.
8. The next room scene is loaded.

Add an `alt` fragment for cancellation and an `alt` fragment for an invalid or
duplicate selection.

#### Sequence C: Death or boss completion

Lifelines: player/boss, `RunManager`, `SaveManager`, result scene.

Show the player death delay before `died` is emitted, the single-run finish
guard, result recording, and the scene transition. This prevents the diagram
from incorrectly implying that death transitions happen synchronously.

### 4. Activity Diagram

Create one activity diagram for the complete run and use swimlanes for
`Player`, `RoomController`, `RunManager`, `SaveManager`, and `Hud`.

#### Main flow

1. Start project.
2. Load save data.
3. Decision: resume existing run?
4. Create/select room.
5. Spawn player and enemies.
6. Process player input and enemy AI.
7. Decision: pickup nearby?
8. Open `Hud` overlay, select or cancel pickup, then resume input.
9. Decision: enemy defeated?
10. Decision: all enemies defeated?
11. Unlock room exit and autosave at the room boundary.
12. Decision: more rooms remain?
13. Load next room or enter boss/final result flow.
14. Decision: player dead or boss defeated?
15. Record result and display the next scene.

#### Branches and annotations

- A player death sets the dead state immediately but emits `died` after the
  configured visual delay.
- An active `Hud` overlay blocks voluntary input; gravity and elemental ticking
  continue.
- A failed pickup confirmation returns to the overlay rather than changing the
  loadout.
- Timed elemental effects refresh existing effects instead of stacking.
- Normal rooms are assembled from pre-built tilemap-backed chunks by a
  room-building algorithm; tutorial and boss scenes remain authored scenes.

#### Acceptance check

Every decision diamond must have labelled outcomes, and every terminal path must
end in either the next room, a completed run, or a recorded loss.

### UML Notation and Layout

- Use a consistent colour per diagram type: blue for actors/input, green for
  gameplay, amber for elemental/reaction logic, red for enemies/failure paths,
  purple for persistence/services.
- Use solid arrows for calls/dependencies and dashed arrows for signals,
  notifications, or test relationships.
- Use `alt`, `opt`, and `loop` UML fragments in sequence diagrams.
- Use composition diamonds only where ownership is real, especially the
  `ElementalCombatant` child component.
- Keep each exported page readable at A4 landscape size. Split detail rather
  than shrinking text below report readability.

### UML Validation Checklist

- [ ] Use-case actors are outside the system boundary.
- [ ] Use-case labels describe goals, not implementation classes.
- [ ] Class relationships match composition, dependency, association, and
      signal semantics in the code.
- [ ] No shared enemy superclass is invented.
- [ ] Sequence messages follow the documented combat and save order.
- [ ] Death delay and pickup-overlay behaviour are represented accurately.
- [ ] Activity diagram decisions have labelled true/false or named branches.
- [ ] Every class name maps to a current file or is clearly marked planned.
- [ ] Diagram page titles and IDs are consistent with the 4+1 overview.
- [ ] The draw.io XML opens successfully after each diagram page is added.

## View 1: Scenario View (+1)

### Goal

Use scenarios to prove that the other views explain the behaviour that matters
to a player and to the system.

### Primary scenarios to draw

1. **Start and resume a run**
   - Player launches the project.
   - `RunManager` selects the current run/room state.
   - `SaveManager` supplies persisted data from local JSON.
   - The player enters a room and the room controller creates its enemies.
2. **Execute an elemental attack**
   - Player input reaches `Player`.
   - Weapon data determines the swing and elemental Charge.
   - `Hitbox` overlaps a `Hurtbox`.
   - `HitData` reaches `ElementalCombatant` and `ReactionResolver`.
   - Damage, status/effect components, hit-stop, and visual feedback occur.
3. **Clear a room and choose a pickup**
   - Enemy deaths are observed by `RoomController`.
   - A pickup becomes available and `Hud` opens its overlay.
   - The selected weapon, skill, or rune is applied to `Player`.
   - The room transition triggers the run autosave path.
4. **Die or defeat the boss**
   - The player death delay or boss completion finishes the run.
   - `RunManager` records the result through `SaveManager`.
   - The next UI/scene is displayed.

### Drawing style

Use a use-case diagram for the actors and a small sequence diagram for each
scenario. Label each message with the owning class or autoload so the scenarios
can be traced into the process view.

## View 2: Logical View

### Goal

Show the stable runtime concepts and the responsibilities assigned to them.

### Main packages/components

- **Input and presentation**: `InputSetup`, `Hud`, visual scripts, VFX.
- **Player and combat**: `Player`, `Hitbox`, `Hurtbox`, `HitData`, weapon data.
- **Elemental domain**: `Elements`, `ElementalStatus`, `ReactionResolver`,
  `ElementalCombatant`, `DotEffect`, `SlowEffect`, `DisableEffect`, and
  `CCResistance`.
- **Enemies**: enemy bodies, `EnemyCombatAI`, `EnemyStats`, boss stats.
- **World and run control**: `RoomController`, spawn points, room exits,
  `RunManager`, and procedural run scenes.
- **Persistence**: `SaveManager` and local JSON save data.
- **Items and skills**: weapon/skill resources, pickups, rune application.
- **Cross-cutting services**: `HitStop`, `ScreenShake`, `VisionBlocker`.

### Relationships to show

- `Player` and each enemy body compose an `ElementalCombatant`; do not draw a
  shared combatant base class.
- `Player` and enemy bodies use `Hitbox`/`Hurtbox` and pass `HitData` into the
  elemental domain.
- `ElementalCombatant` delegates reaction category decisions to
  `ReactionResolver` and owns the named reaction effects.
- `RunManager` coordinates rooms, scene transitions, and run lifecycle;
  `SaveManager` owns persistence rather than gameplay state.
- `Hud` reads gameplay state and handles pickup selection, but is an autoload
  with no `.tscn` scene.

### Drawing style

Use a layered component/package diagram. Mark autoloads with a stereotype such
as `<<autoload>>`, resources with `<<resource>>`, scenes with `<<scene>>`, and
tests with `<<test>>`. Use solid arrows for calls and dashed arrows for signals.

## View 3: Process View

### Goal

Explain concurrency, event order, and the most important runtime sequences.

### Process diagrams to draw

1. **Combat process**
   - Input → player state machine → attack window → hitbox overlap.
   - Hurtbox builds `HitData` → owner applies damage → elemental handling.
   - Reaction effects tick over time and may create projectiles, zones, or VFX.
   - `HitStop` and `ScreenShake` provide feedback without owning combat rules.
2. **Pickup overlay process**
   - `Hud` detects nearby pickup → freezes voluntary input → selection →
     item/rune application → overlay closes and gameplay resumes.
3. **Room transition process**
   - Enemy deaths → room cleared → pickup/exit state → autosave → next room.
4. **Run completion process**
   - Player death or boss victory → delayed/guarded finish → result persisted →
     summary or next scene.

### Runtime rules to annotate

- Timed effects are refreshed rather than stacked.
- `Hud.is_overlay_active()` blocks voluntary input while gravity and elemental
  ticking continue.
- Physics-created `Area2D`/`CollisionShape2D` objects are added deferred.
- Nearby AoE checks use distance queries, not a separate physics AoE layer.

### Drawing style

Use UML sequence diagrams for the combat and transition flows. Use an activity
or state diagram for the player state machine and the room/run lifecycle.
Number the critical messages so they can be referenced in the report text.

## View 4: Development View

### Goal

Show how the implementation is divided for development, testing, and change
impact analysis.

### Repository areas to draw

- `scenes/player/` — player scene and controller.
- `scenes/enemies/` — enemy scenes, bodies, AI, and stats.
- `scenes/world/` — rooms, run entry, spawn points, and exits.
- `scripts/combat/` — hit resolution and projectiles.
- `scripts/reactions/` — elemental rules and reusable effects.
- `scripts/resources/` — weapon, skill, and enemy resource definitions.
- `scripts/items/` and `scripts/ui/` — pickups and scene-based UI.
- `autoloads/` — script-only global services.
- `test/unit/` and `test/integration/` — GUT tests.

### Boundaries to emphasise

- Scene scripts own node lifecycle and scene-specific state.
- Resources own reusable data and balance values.
- Reaction logic is separated from body scripts through composition.
- Autoloads provide global coordination, not a replacement for domain ownership.
- Tests isolate persistent autoload state with the existing test helpers.

### Drawing style

Use a package diagram with dependency arrows. Add a small dependency legend and
identify the packages most likely to change in P5 through P10. Do not include
`.godot/` cache files or the third-party `addons/gut/` internals in the main
architecture boundary; show GUT only as an external test tool.

## View 5: Physical View

### Goal

Show where the software executes and where its data lives.

### Nodes and artefacts to draw

- **Player device**
  - Godot 4.7 runtime.
  - Main scene currently configured as `scenes/world/test_arena.tscn`.
  - Active scene tree containing player, enemies, room objects, and HUD.
- **Autoload layer inside the runtime**
  - `InputSetup`, `HitStop`, `ScreenShake`, `VisionBlocker`, `SaveManager`,
    `RunManager`, and `Hud`.
- **Project package**
  - scenes, scripts, resources, assets, shaders, and tests shipped with the
    project.
- **Local user data**
  - `user://save_data.json`, containing resume state, meta-progression, and run
    history.
- **Development/test environment**
  - Godot editor and GUT headless/editor test runner.

### Drawing style

Use a UML deployment diagram. Distinguish shipped project files from generated
editor/cache files and from user data. Add a note that normal rooms use a
tilemap-backed chunk builder, while tutorial and boss scenes remain authored
scenes; there is no world-state server layer. The tileset is supplied
separately.

## Overview Diagram

Place the five views around a central `Elemental Roguelike` system boundary:

- Scenarios explain required behaviour.
- Logical view explains responsibilities.
- Process view explains runtime collaboration.
- Development view explains code organisation.
- Physical view explains execution and persistence.

Each view should include IDs (`S1`, `L1`, `P1`, `D1`, `PH1`) so report text can
refer to individual elements without repeating large diagrams.

## Execution Order

1. Freeze the implementation snapshot and record the Godot version and current
   main scene.
2. Extract names and relationships from `Design.md`, `project.godot`, and the
   relevant scene/script folders.
3. Draw the four scenarios first and validate that every major user-visible
   workflow has an owner.
4. Draw the logical view from the scenario participants.
5. Draw the process view from the combat and room-transition message order.
6. Draw the development view from repository boundaries and test locations.
7. Draw the physical view from Godot runtime, project files, and `user://` data.
8. Create the overview diagram and architecture notes.
9. Cross-check every diagram against the source files and remove any planned
   or obsolete component presented as implemented.
10. Export readable PNG/PDF versions and review them at report-page scale.

## Traceability and Acceptance Checklist

- [ ] Every scenario participant appears in the logical view.
- [ ] Every critical logical relationship appears in at least one process flow.
- [ ] Every logical component maps to a repository package, autoload, scene, or
      explicitly documented external tool.
- [ ] The physical view identifies both runtime location and persistent storage.
- [ ] `SaveManager`, `RunManager`, and `Hud` are clearly distinguished.
- [ ] Composition-based `ElementalCombatant` ownership is shown correctly.
- [ ] The diagrams represent the planned tilemap-backed chunk builder, but do
  not invent a server, database, or shared enemy base class.
- [ ] Planned systems, such as the upgrade system before implementation, are
      marked `planned` or omitted from the implemented view.
- [ ] Names and arrows are legible in the final exported files.
- [ ] The diagrams are reviewed against the latest automated test result and
      the current `Design.md` revision.

## Source Anchors

- `Design.md` — system map, combat loop, architectural principles, and runtime
  rules.
- `project.godot` — main scene, autoload registration, viewport, and engine
  configuration.
- `AGENT_PLAN.md` — implementation boundaries, phase order, and deferred-node
  constraints.
- `scenes/`, `scripts/`, `autoloads/` — implementation ownership.
- `test/unit/`, `test/integration/` — verification boundaries.
