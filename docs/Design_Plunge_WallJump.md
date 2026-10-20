# Design: Plunge Attack and Wall Jump

## Overview
This document outlines the design and implementation logic for adding a **Wall Slide/Jump** and a **Scaling Plunge Attack** to the Player character in `elemental_roguelike`.

## 1. State Machine Additions
The `Player.State` enum will be expanded to include:
- `WALL_SLIDE`: The player is pressed against a wall while falling. Gravity is reduced, and normal horizontal movement is disabled.
- `PLUNGE`: The player is rapidly falling straight down after triggering an aerial attack.

## 2. Wall Slide & Wall Jump Mechanics
### Triggers
- **Enter Wall Slide**: While in `JUMP` or `FALL`, if the player is pressing against a wall (`is_on_wall_only()`), they transition to `WALL_SLIDE`.
- **Wall Jump**: While in `WALL_SLIDE`, pressing the jump button applies a velocity impulse away from the wall and upward, transitioning back to `JUMP` state.

### Tuning Variables
- `wall_slide_speed = 80.0`: Terminal downward velocity while sliding.
- `wall_jump_push_force = 150.0`: Horizontal impulse when jumping off the wall.
- `wall_jump_up_force = 250.0`: Vertical impulse when jumping off the wall.

## 3. Scaling Plunge Attack Mechanics
### Triggers
- **Enter Plunge**: Triggered by pressing `attack` (with the `drop_down` key to differentiate from regular aerial attacks if desired, but default to standard aerial attack) while airborne (`JUMP`, `FALL`, or `WALL_SLIDE`).
- **Plunge Physics**: Horizontal velocity is zeroed out. Downward gravity is multiplied (`plunge_gravity_multiplier`) to make the fall feel heavy and fast.

### The Scaling System
As the player falls in the `PLUNGE` state, we track their `velocity.y`. When `is_on_floor()` becomes true, we calculate an `impact_intensity` from `0.0` to `1.0`.
- `min_plunge_speed = 250.0` (Short hop)
- `max_plunge_speed = 800.0` (Max fall speed)
- `impact_intensity = clamp((velocity.y - min) / (max - min), 0.0, 1.0)`

### Impact Resolution
Upon hitting the ground, we execute an AoE burst:
1. **Damage**: Scales with intensity. `damage = base_weapon_damage * (1.0 + impact_intensity)`.
2. **Elemental Charge**: If `impact_intensity >= 0.6`, the attack counts as a **Charge 2** (Heavy hit). Otherwise, it is a **Charge 1**.
3. **AoE Radius**: Scales with intensity. `radius = 40.0 + (60.0 * impact_intensity)`.
4. **Juice**: `HitStop` and `ScreenShake` trigger using the weapon's weight.

### Collision Detection
Following the existing architectural principles in `Design.md`, we will **not** use a physics `Area2D` for the AoE. Instead, we perform a distance check against `ElementalCombatant.ALL_COMBATANTS_GROUP` and dispatch a constructed `HitData` to their respective `Hurtbox` components.

