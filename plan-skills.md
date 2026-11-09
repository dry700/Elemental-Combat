# Plan: Skills Rework (passive slot, Flame Dash ram, no duplicate skills)

Status: **design only, no code written.** All numbers are placeholders to tune in playtesting.
Maid's Guard and Maid's Sweep, the energy system, and the Skill station are specified in [plan-shop-and-skills.md](plan-shop-and-skills.md) and are **not repeated here**. This plan only covers the rest of the pool.

Rule for this plan: **no two skills may be the same effect in a different element.** Every skill needs its own signature effect (see section 1).

---

## 0. Decisions at a glance

| Area | Decision |
|---|---|
| Passive skills | A passive is a `SkillData` that is never cast. It works only while equipped. |
| Passive slot | A **third, passive-only slot**. Passives never go in Q/E, and actives never go in the passive slot. |
| Converted to passive | **Barkskin** and **Throwing Blades**. |
| Flame Dash | Becomes a damage **ram**: the dash stops at the first enemy hit and knocks it back hard. |
| Tide Step | Stays the utility dash (clears your slow). |
| Zone gimmicks | **Confirmed:** Overgrowth Snare tags enemies with Link; Shard Field shreds armor per tick (section 5). |
| New actives | One new active each for **Mộc** and **Kim**, to be designed later. Each must have its own signature effect (section 1 rule). |
| Loadout passive column | Added later, after the passive slot and both passives work. |
| Passives and Charge | Passives never count toward the same-element rune-to-skill Charge bonus. |

---

## 1. Uniqueness audit (the full pool after changes)

17 skills. Each row's "signature" is what makes it different from every other skill.

| Skill | Element | Kind | Function | Signature effect |
|---|---|---|---|---|
| Ignite Dart | Hỏa | Active | `APPLY_SINGLE_TARGET` | Aimed projectile through the full reaction pipeline. |
| Ember Burst | Hỏa | Active | `AREA_BURST` | Close-range damage burst. |
| **Flame Dash** | Hỏa | Active | `DASH` | **Ram: damages and knocks back one enemy, ends the dash.** |
| Cleansing Tide | Thủy | Active | `REMOVE_APPLY_SELF` | Clears your own status, then applies Thủy. |
| Undertow | Thủy | Active | `AREA_BURST` | Slow wave in a direction. |
| Tide Step | Thủy | Active | `DASH` | Escape dash with i-frames that clears your slow. |
| Overgrowth Snare | Mộc | Active | `APPLY_AREA` | Zone that applies Mộc (gimmick pending, section 4). |
| Thorn Volley | Mộc | Active | `PROJECTILE_FAN` | Wide fan of shots (now the only fan). |
| **Barkskin** | Mộc | **Passive** | passive | **Small permanent armor bonus.** |
| Rending Edge | Kim | Active | `REMOVE_ENEMY` | Strips an enemy's status. |
| Shard Field | Kim | Active | `APPLY_AREA` | Zone that applies Kim (gimmick pending, section 4). |
| **Throwing Blades** | Kim | **Passive** | passive | **Weapon hits shred armor (capped).** |
| Stoneguard | Thổ | Active | `APPLY_SELF` | Self-apply Thổ, no reaction (Vũ-bait setup). |
| Seismic Slam | Thổ | Active | `JUMP_SLAM` | Leap, then slam for damage and stagger. |
| Earthen Bulwark | Thổ | Active | `BUFF_ARMOR` | Big temporary armor buff (now the only armor active). |
| Maid's Guard | Thổ | Active | `APPLY_SHIELD` | See plan-shop-and-skills.md. |
| Maid's Sweep | Thổ | Active | `APPLY_SWEEP_BUFF` | See plan-shop-and-skills.md. |

What this fixes from the earlier audit:
- **Armor buffs:** Barkskin is a passive, so only Earthen Bulwark remains as an active.
- **Fans:** Throwing Blades leaves the active pool, so Thorn Volley is the only fan.
- **Dashes:** Flame Dash is a ram and Tide Step is the escape, so they are no longer the same skill.
- **Still similar:** the two zones (Snare and Shard Field). Section 4 proposes gimmicks.

Actives per element after the change: Hỏa 3, Thủy 3, Mộc 2, Kim 2, Thổ 5. **One new active each for Mộc and Kim is planned** (to be designed later; it must not duplicate any row above). That brings both to 3 actives, with Mộc and Kim also holding one passive each.

---

## 2. Passive slot

### 2.1 Data and rules
- New `SkillData` flag `is_passive` and the passive effect fields (section 3). `_try_cast_skill()` skips passives.
- New `Player.passive_skill` slot, separate from `skill_1` / `skill_2`. Keep `swap_skill(is_primary: bool, ...)` as it is and add a separate swap for the passive slot, so the existing two-slot overlay and tests are untouched.
- Enforce the exclusivity with `is_passive`: passives only go to the passive slot, actives only to Q/E.
- **No duplicates anywhere:** extend `would_duplicate_skill()` so the same skill can't sit in a Q/E slot and the passive slot.
- Passives stay in `SkillPool`, so they still drop and appear in the shop. `test_skill_data_prep.gd` per-element counts stay valid.

### 2.2 Pickups, shop, HUD, saves
- A passive pickup always routes to the passive slot. The slot chooser shows a single "replace" card instead of two.
- HUD: a passive slot box with no key label and no cooldown overlay (use a "passive" marker).
- Save: add `passive_path` to `Player.to_save_state()` / `apply_save_state()`. Do not re-record the unlock on resume (same rule as the other slots).
- Loadout screen: a passive column listing unlocked passives only. Passives are not in the starting skill list, so the slot starts empty until one is found. (Decide whether to ship this column in the first pass or add it later.)
- Playtest panel: list passives and allow equipping them into the passive slot.

---

## 3. Passive effects

Both act at the effect layer and **never touch raw reaction Charge**.

### Barkskin: small permanent armor
- About **+5 armor**, always on.
- Implement as a separate term next to `armor_buff` in `ElementalCombatant.mitigate_damage()`, not by editing `armor`. Armor is saved in the player's save state, so adding to it directly would double-apply on resume.

### Throwing Blades: armor shred on weapon hits
- Each weapon hit shreds about **0.5 armor**, but the target can't go **below 50% of its base armor** from this passive. Sever and Ore Surge still shred freely.
- Needs a stored base armor on `ElementalCombatant`, captured in `_ready()` (enemies set armor before adding the combatant). Tests that set armor after adding the node need to set the base explicitly.
- Hook: the player's `Hitbox` already emits `hit_landed`. For arrows, call a duck-typed method on the attacker (same convention as `on_reaction_caused`) so the bow and crossbow benefit too. Skill projectiles do not shred.
- Light weapons hit more often, so they shred faster; keep the amount small and watch this in playtests.

---

## 4. Flame Dash ram

- `_start_skill_dash()` already sets the dodge state, speed, duration and i-frames, so only the damage and the stop are new.
- Enable the player's `Hitbox` with a body-sized shape in front of the player. `Hitbox` already emits `hit_landed` and only hits each enemy once per enable.
- **On the first hit:** end the dash immediately (zero velocity), deal damage, apply hard knockback, and resolve the Hỏa reaction through the normal pipeline. If nothing is hit, the dash runs its full distance.
- Placeholders: damage ~14, knockback ~300, reaction Charge from the existing `_resolve_skill_charge()`, cooldown 8s, shorter i-frames than Tide Step.
- New optional `SkillData` fields (for example `dash_damage`, `dash_knockback`, `dash_stops_on_hit`) so other dash skills are unchanged.
- **Early-exit cleanup:** `_process_dodge` only cleans up when its timer ends. A hit-triggered stop must also stop the dash shadows, set `_last_dodge_end_time`, return to idle or fall, and disable the hitbox. Otherwise the Dodge Perfect Hit timing and the hitbox state break.
- Enemies use `collision_layer = 0`, so the player never body-collides with them. The stop has to be scripted by the hit, not by collision. The existing enemy collision-exception code is probably a no-op.
- Feedback: a heavy hit-stop and screen shake preset at impact. A shielded enemy absorbs the hit, and the dash still stops.
- Synergy: ending the dash sets the Dodge Perfect Hit window for the next swing.

---

## 5. Zone gimmicks (confirmed)

The zones are the only remaining same-effect pair. Each gimmick reuses the element's existing identity.

| Skill | Gimmick |
|---|---|
| **Overgrowth Snare** (Mộc) | Enemies inside get the Overgrowth Link tag (`OVERGROWTH_GROUP`), so a later Wildfire chains through them. Ties into the Overgrowth/Wildfire setup. |
| **Shard Field** (Kim) | Each zone tick shreds a little armor. Check it against the Throwing Blades passive so Kim doesn't over-stack shred; reuse the same 50% base-armor floor. |

Optional twists, only if the pool feels flat later:
- **Earthen Bulwark:** short stagger/knockback immunity while active. Cap it so it doesn't trivialise the boss's charge stun or Break-Free.
- **Thorn Volley:** a thorn that lands briefly roots the target (CC resistance already caps this).

---

## 6. Tests

- Passive slot: passive only equips to the passive slot, active only to Q/E, no duplicate across slots, saved and restored without re-recording the unlock.
- `_try_cast_skill()` ignores passives.
- Barkskin raises mitigation only while equipped, and is not double-applied on resume.
- Throwing Blades: shreds per hit, stops at 50% of base armor, melee and arrows both shred, skill projectiles don't, Sever can still go below the floor.
- Flame Dash: stops on the first hit, applies damage and knockback and the reaction, runs full distance on a miss, cleans up state on early stop, sets the Dodge Perfect Hit window.
- Zone gimmicks: Snare tags enemies with Link, Shard Field shreds per tick and respects the floor.
- Update `test_skill_data_prep.gd` only if the pool or element counts change.

---

## 7. Build order

1. `SkillData` fields and the passive flag; `_try_cast_skill()` skips passives.
2. Passive slot on `Player`: swap rules, duplicate checks, save/restore.
3. HUD passive slot, single-card pickup path, playtest panel entry.
4. Barkskin passive and Throwing Blades passive (including base armor and the arrow hook).
5. Flame Dash ram.
6. Zone gimmicks (Snare Link tag, Shard Field armor shred per tick).
7. Tests, then a playtest pass to tune numbers.
8. Later: design and add the new Mộc and Kim actives, then the loadout passive column.

---

## 8. Resolved decisions

| Question | Answer |
|---|---|
| Zone gimmicks | Accepted: Snare tags enemies with Link, Shard Field shreds armor per tick. |
| Loadout passive column | Add later, after the passive slot and both passives work. |
| Mộc and Kim actives | Add one new active each (design later, must be unique). |
| Passives and the same-element Charge bonus | No, they never count. |

No open questions remain. Still to design: the new Mộc and Kim actives. Update `test_skill_data_prep.gd` (it asserts 17 skills and per-element counts) when they are added.
