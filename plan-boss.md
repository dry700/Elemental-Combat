# Plan: Boss "Thổ Ngưu" (placeholder name)

Status: **implementation in progress.** Build-order steps 1–6, passive-window center flight and intangibility, target-piercing shockwave with intensified travelling sparks, and heavy-weight impact feedback for all boss attacks are implemented; focused boss tests and the full GUT suite pass (419 tests, 2,596 assertions). The interactive playtest is pending. All numbers remain placeholders to tune in playtesting.
This replaces the current Ember Tide boss. Fold it into Design.md (§A.6 bosses) when implemented.

---

## 0. Decisions at a glance

| Area | Decision |
|---|---|
| Fight goal | **Crowd management.** The boss fights alongside adds and supports. |
| Elements | **Thổ** in phase 1, **Hỏa** in phase 2. |
| Attacks | Mostly melee, an occasional ranged attack, a bull charge, and a ground shockwave; all hits use heavy hit-stop and camera shake feedback. |
| Ranged | A single rock projectile aimed in any direction, with a clear trajectory tell, thrown now and then. |
| Charge | ~0.8s telegraph, straight line across most of the arena, can be jumped. Wall hit = brief stun and bonus damage taken. A miss skids to a stop. |
| Shockwave | A wave that travels along the ground, pierces each target once, and must be jumped. Emits upward diamond sparks along its path. |
| Waves | 3 waves at **75% / 50% / 25%** health. Each has at least one brawler, one flyer, one shooter, one support. |
| Passive window | ~12s per wave. Boss moves to the room center, flies to a hover position, and is **invulnerable and intangible**, then returns **regardless of the wave**. Leftover adds keep pressuring the player. |
| Early clear | Clearing the wave early brings the boss back **staggered** with a bonus-damage window. |
| Element swap | During wave 2's window, at 50%. |
| Arena | Wider than today, with platforms so flyers and ranged adds are reachable. |
| Stats | Same as Ember Tide: 700 HP, armor 15, damage 10. Tune after playtests. |
| Rewards | Unchanged: Qi burst, a rune of its element, a guaranteed skill drop. |

---

## 1. Fight flow

1. **Phase 1 (Thổ), 100% to 75%:** boss fights alone. Teaches its moves.
2. **75%: wave 1.** Boss retreats, invulnerable ~12s. Adds spawn. Clear them for an early, staggered return.
3. **75% to 50%:** boss fights normally, adds that survived are still around.
4. **50%: wave 2 + element swap to Hỏa.** Same window; the boss comes back as Hỏa with faster attacks (existing phase-2 cooldown multiplier).
5. **50% to 25%:** phase 2 fighting.
6. **25%: wave 3.** Last window, then the boss finishes the fight.
7. Death: normal boss rewards, then the boss shop.

### Counter loop (reactions)

| Phase | Boss status | Best counter |
|---|---|---|
| 1 | Thổ | **Mộc** hit: Root Break (Khắc, stagger) |
| 2 | Hỏa | **Thủy** hit: Douse (Khắc, steam cloud) |

- The correct counter flips at the swap, so players have to adapt.
- Root Break is a Thổ reaction, so it also fills Maid's Sweep's energy.
- Hỏa hitting a Thổ-carrying target is Cinder Bloom (Sinh). Fire weapons give different results than Mộc in phase 1; playtest it.
- The boss's innate Charge is 2, so a Charge-1 counter is only partial. Heavy weapons (base Charge 2) clear it fully.

---

## 2. Boss moves

| Move | Use | Behavior |
|---|---|---|
| **Melee** | Default when close | Existing telegraphed hit through `EnemyCombatAI`, with a special every Nth attack (Charge 2). |
| **Rock throw** | Player far away or elevated | A single projectile every ~5s, aimed in 2D at the player's position when its telegraph begins. Show a bright trajectory line and arrowhead for ~0.65s so the player can read and dodge the path. Placeholder damage 6. |
| **Bull charge** | Player at mid or long range | 0.8s telegraph (tint, plus a visible lane or arrow), then a fast straight run across most of the arena. Placeholder speed 220 px/s, damage 14, Charge 2. |
| **Shockwave** | Player close or on the ground | Short stomp telegraph (~0.6s), then a ground wave travels outward both ways. Placeholder speed 130 px/s, damage 8, Charge 1. |

- Move choice: a simple picker based on distance and per-move cooldowns, never the same special twice in a row.
- Phase 2: all attacks use Hỏa, cooldowns shortened by the existing `attack_cooldown_multiplier`.
- **Charge end states:**
  - Hits a wall: boss is stunned ~1.5s and takes **x1.5 damage** for the stun.
  - Misses (no wall in reach): skids to a stop, short recovery, no bonus.
- **Jumpability:** the player's jump apex is only ~22px (~44px with the double jump), but the boss body is 24px tall. The charge and shockwave hitboxes must be **low** (about 12 to 14px tall at floor level) or they cannot be jumped. Check this first when prototyping.
- Charge and shockwave use `Hitbox` / `HitData` through `Hurtbox.take_hit()`, like `ArrowProjectile`, so damage, knockback, hit-stop, shake, ICD and reactions behave like any other hit.

---

## 3. Waves and passive window

### 3.1 Trigger

- Thresholds are a list on `BossStats`: `[0.75, 0.5, 0.25]`.
- A damage hit can skip a threshold (the existing test hits for 60% of max health at once). **Recommended:** when a hit would cross a threshold, clamp health to that threshold so every wave always triggers, and handle one threshold per hit.
- Order at 50%: start wave 2, then run the phase swap (existing `_enter_phase_2`) in the same handler.

### 3.2 Passive window

- Boss moves to the center retreat anchor, then flies to a configurable hover height, stops attacking, and tints.
- **Invulnerable for ~12s.** Use a boss-level flag, not just `hurtbox.invulnerable`, because DoT and `bonus_damage_dealt` go through `_apply_damage` and bypass the hurtbox. Gate `_apply_damage` on the flag too.
- Status can still land through direct paths such as `ReactionZone`; accept this, since it only applies status and no damage.
- Ends when the timer runs out (boss returns normally; surviving adds stay), or early when every wave add is dead (boss returns **staggered**, taking x1.5 damage for ~2s).
- HUD: show the threshold ticks on the boss bar, grey the bar while invulnerable, and show the window countdown.

### 3.3 Wave contents

- Each wave: **at least** one brawler (`patrol_dummy`), one flyer (`flying_enemy`), one shooter (`shooter_enemy`), one support (`shielder`). Later waves can add extras or the planned supports (armor buffer, cleanser, summoner; no healer).
- Adds spawn from markers placed in the arena, per wave: `Wave1Spawns`, `Wave2Spawns`, `Wave3Spawns` (flyers in the air, shooters on platforms).
- Existing loop scaling (`1.0 + 0.25 * (loop - 1)`) applies through `EnemySpawnPoint.spawn()`.
- The shielder shields the nearest unshielded ally in range, and the boss is in the `"enemies"` group, so it can shield the boss. That is a good puzzle (kill the support first or break the shield), but confirm you want it (see section 8).

---

## 4. Arena

- Wider than the current 450px boss room. Placeholder: ~640px wide, boundaries at about +/-320.
- Several `OneWayPlatform` instances (layer 4) at different heights so flyers and shooters are reachable and the player can dodge the shockwave by jumping. In the boss room, standing on one starts a 3s crumble timer; the last 1.2s flashes as a warning, then it drops for 2s before returning. Other rooms keep permanent platforms.
- Keep tall solid side walls (`unclimbable_walls` group) so the charge has a wall to hit.
- Update camera horizontal limits to the new width.
- `test_shop_room.gd` asserts the boss room boundaries sit at x = 225 and that the exit stays inside; those assertions need updating.

---

## 5. Technical plan

Follow the project's composition convention (no common enemy base class).

- **`BossStats`:** add fields for wave thresholds, passive duration, early-clear stagger and damage multiplier, charge (telegraph, speed, distance, damage, wall stun, stun damage multiplier), shockwave (telegraph, speed, damage), rock (damage, speed, cooldown).
- **`Boss`:** keeps phase and element logic. Add an invulnerable flag, passive and stunned states, signals for wave thresholds.
- During the passive window, move to the center anchor before ascending to a configurable hover height; return to ground movement when the window ends.
- **Move controller:** a new component (e.g. `BossAttackController`) that owns move selection and the charge, shockwave and rock behaviors. `EnemyCombatAI` stays as the melee component it already is.
- **Projectiles:** a `ShockwaveProjectile` (low hitbox, travels along the ground) and a `RockProjectile`, both extending `BaseProjectile` and using the `ArrowProjectile` hit pattern.
- **Room script:** a `boss_room.gd` extending `RoomController` that listens to the boss's wave signals, spawns from the wave markers, tracks wave adds, and signals an early clear.
  - Wave markers must live under their own container nodes, not as direct children of the room. `RoomController` spawns every direct `EnemySpawnPoint` child on load, which would spawn all waves immediately.
  - `EnemySpawnPoint.spawn()` frees its marker, so each wave needs its own set of markers.
- **On boss death:** despawn any remaining adds so the room can clear (assumption, see section 8).
- **Charge wall detection:** `CharacterBody2D.is_on_wall()` against the arena boundaries.
- **Rewards:** unchanged `Boss._die()` path.

---

## 6. Tests

- Wave thresholds trigger once each, in order; a large hit clamps at the threshold instead of skipping waves.
- Invulnerable during the passive window, including DoT and bonus damage; vulnerable again afterwards.
- Window ends on timer with adds alive; ends early on a full clear with stagger and the damage multiplier.
- Element swap happens at 50% during wave 2.
- Wave composition: at least one brawler, flyer, shooter, support per wave.
- Charge: wall hit stuns and applies the damage multiplier; a miss skids; hitbox height allows a jump.
- Shockwave and rock deal damage through the normal hit pipeline.
- Boss death despawns remaining adds.
- Update `test_boss_phase_transition.gd` (its 60%-hit test now crosses two thresholds) and the boss-room boundary assertions in `test_shop_room.gd`.

---

## 7. Build order

1. `BossStats` fields and the new `.tres` (keep Ember Tide until the replacement works). **[Done — `BossStats` fields added, `tho_nguu_boss_stats.tres` authored, verified by `test_tho_nguu_stats.gd` (385/385 tests passing)]**
2. Wider arena scene with platforms, boundaries and wave marker groups. **[Done — arena widened to 640px, boundaries +/-320, 3 OneWayPlatforms added with warning/crumble/recovery on player entry, Wave1/2/3Spawns segregated containers populated with adds, boss configured with Tho Nguu stats, verified by `test_boss_arena.gd` and `test_boss_timed_platform.gd`]**
3. Invulnerable flag, passive state, and stun state on `Boss`. **[Done — `invulnerable`, `is_passive`, `is_stunned`, wave threshold signals & health clamping, early-clear stagger & wall stun with damage multipliers implemented in `scenes/enemies/boss.gd`, verified by `test_boss_tho_nguu.gd` (397/397 tests passing)]**
4. Wave director in `boss_room.gd` (thresholds, spawning, early clear, despawn on death). **[Done — `boss_room.gd` handles wave signals and per-wave spawn containers, tracks adds for early-clear stagger, despawns room adds/projectiles on boss death; verified by `test_boss_room_director.gd` (3 tests passing)]**
5. Move controller: shockwave first (simplest), then rock, then bull charge with wall stun. **[Done — `BossAttackController` handles distance-based specials and alternating choices; rock tracks targets in 2D with a trajectory line/arrow telegraph, rock and shockwave use `BaseProjectile`/`HitData`, charge uses a low `Hitbox`, wall collisions stagger the boss; verified by `test_boss_attacks.gd`]**
6. HUD: wave ticks, invulnerable bar, countdown. **[Done — boss HUD displays wave-threshold ticks, dims during passive windows, and shows remaining time; verified by `test_boss_attacks.gd`]**
7. Run the full suite, then do an interactive playtest to tune numbers and verify charge/shockwave jumpability. **[Automated verification complete — full GUT suite passes (419 tests, 2,596 assertions); interactive tuning and jumpability check remain]**

8. Add the short boss-entry cutscene described in section 9. **[Implemented — skippable intro locks player input and boss processing, frames the arena, plays an earth stomp and title card, then restores the camera and combat state.]**

---

## 8. Assumptions to confirm

1. The boss may be shielded by the wave's shielder.
2. Remaining adds despawn when the boss dies.
3. Hit overshoot clamps health to the threshold (so a wave never gets skipped).
4. Boss-wide invulnerability blocks DoT and bonus damage as well as direct hits.

---

## 9. Simple boss-entry cutscene

**Goal:** introduce Thổ Ngưu and give the player a clear moment before combat. Target length: about 4 seconds, with no dialogue or new animation assets.

### Sequence

1. As the boss room loads, temporarily lock player and boss combat actions.
2. Ease the camera out slightly and frame the player at the left with the boss at the arena center.
3. Have the boss lower its head and stomp once. Reuse the earth-colored burst and screen shake; add a few small gold/earth particles at floor level.
4. Show a brief title card: **THỔ NGƯU** with a smaller **EARTHBOUND BULL** subtitle and the phase-one earth icon.
5. Ease the camera back to its normal player framing, hide the title, and restore the player and boss. The boss begins its normal phase-one AI at full health.

### Implementation shape

- Add a small intro coroutine to `BossRoomController`; start it after the room has spawned the boss and connected its signals.
- Add a narrow player cutscene-input lock while leaving its physics and camera active; store and restore the boss's prior process mode so its combat components pause together.
- Tween the player's `Camera2D` zoom and offset for the shared framing, then tween both back before unlocking combat.
- Build the title card as a temporary `Control` under a `CanvasLayer`; use a short fade in/out and no persistent HUD changes.
- Spawn the existing earth skill-cast burst at the boss's feet for the stomp. Use a short camera shake; keep particles minimal and code-drawn.
- Let the `skill_1`/confirm input skip the remaining presentation and run the same camera restore/unlock path. Guard cleanup so skip and normal completion cannot restore twice.
- Do not start wave timers, change health, or trigger attacks from the cutscene. Existing phase and wave logic begins unchanged after the intro.

### Acceptance

- The intro plays once on entering the boss encounter; retries start a fresh intro.
- Player input and all boss attacks are inactive during the intro.
- Skip and normal completion both restore camera values and combat processing.
- The boss returns to full health in phase one, and the fight begins immediately after the title clears.
