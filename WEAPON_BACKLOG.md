# Weapon & Perfect Hit Backlog

Post-P12 work. Nothing here belongs in the P12 closeout plan. Build in the order given under "Will do".

## Perfect Hit (the shared mechanic)

A Perfect Hit is a hit that lands inside the equipped weapon's ideal window. It multiplies damage by `perfect_multiplier` (1.5-2.0, set per weapon; see the multiplier guide in section 6) and never touches Charge, the resolver, or reactions.

- **One window per weapon.** The window is the main difference between weapons; the multiplier only varies inside the 1.5-2.0 band, set by how hard the window is to open.
- **Execution windows:** the player's own timing or position opens them (dodge, airborne, finisher, plunge, distance, streak).
- **Setup windows:** the player's earlier play opens them (a reaction left the target slowed, rooted, or disabled).
- UI: the weapon card states the window in one line ("Perfect: target slowed"). The damage popup says "Perfect!". Do not use "miss" or "imperfect" language anywhere.
- Name is chosen: **Perfect Hit**. Code names: `WeaponStats.perfect_condition` (enum), `perfect_multiplier`, `HitData.perfect`.
- Do not name anything "combo" for this. `combo_steps` / `_combo_step` already mean the hit string. Use **Streak** for the dagger's rule.

---

## WILL DO

### 1. Core system (do first)
- [ ] `WeaponStats`: add `perfect_condition` enum and `perfect_multiplier` (default 1.5, valid range 1.5-2.0). Optional per-step override on `ComboStepData` only if a weapon needs it.
- [ ] `HitData.perfect: bool`.
- [ ] Resolve the window in one place: `Hitbox._on_area_entered` (it already has the hurtbox and `hurtbox.owner.get("elemental")`). Per-swing facts that the hitbox cannot know (combo step, last dodge time, airborne) are set on the hitbox when the swing is configured, like `weapon_weight`.
- [ ] Add `signal hit_landed(hurtbox)` on `Hitbox` (needed for streaks and any future "after a hit" window).
- [ ] Feedback: "Perfect!" popup (reuse the `ElementalCombatant._spawn_text_popup` pattern), distinct damage-number color, heavier hit-stop/shake preset, window text on `PickupCard`.
- [ ] Optional cue: small glow on the target while the equipped weapon's setup window is open.
- [ ] Update `get_display_dps()` caller text so cards note the window instead of changing the DPS number.

### 2. Windows for existing weapons

| Weapon | Element / weight | Window | Type |
|---|---|---|---|
| Dagger | Hỏa / light | **Streak:** 6th landed hit; the streak resets after a 2 s gap with no hit, or on weapon swap | Execution |
| Spear | Thủy / medium | Target is **slowed** (`elemental.is_slowed()`) | Setup |
| Staff | Mộc / medium | Target is **disabled** (`elemental.is_disabled()`, read the disable effect directly, no source tag) | Setup |
| Greatsword | Kim / heavy | **Combo finisher** (last step of `combo_steps`) | Execution |
| Hammer | Thổ / heavy | **Plunge** impact above a height threshold (reuse `intensity >= 0.6` in `_trigger_plunge_impact`) | Execution |
| Bow | Mộc / medium | Target **beyond a long-distance threshold** | Execution |

Notes:
- Do not key any window on elemental status (`status.element`). The player's own next hit overwrites it (for example Hỏa turning Mộc into Wildfire), so the window closes before it can be used. Use control effects (disable, slow) or counters instead.
- The streak counter lives on the wielder's `Hitbox`/`Player`, never on the shared `WeaponStats` resource.

### 3. New weapons (`.tres` files, shop-only unless noted)

| Weapon | Element / weight | Combo / feel | Starting stats | Window |
|---|---|---|---|---|
| **Đao** (single-edged saber) | Hỏa / medium | 3 swings: diagonal down, diagonal up, flat sweep | dmg 12, 0.32 s, reach 12, lunge 70, step x1.08 | **Within 0.5 s after a dodge** |
| **Song kiếm** (twin swords) | Thủy / light | 4 quick swings, alternating direction | dmg 7, 0.2 s, reach 6, lunge 90, step x1.04 | **Attacking while airborne** (Player state JUMP/FALL) |
| **Mâu** (lance) | Thổ / heavy | 2 long thrusts, second reaches further | dmg 17, 0.5 s, reach 20, lunge 35, step x1.1 | **Target beyond about 70% of reach** (the tip) |
| **Quan đao** (glaive, Guan Yu) | Kim / heavy | 2 wide overhead arcs, large hitbox | dmg 20, 0.62 s, reach 16, radius 10, step x1.1 | **Target is disabled** (`is_disabled()`) |
| **Liên châu nỏ** (repeating crossbow, Cao Lỗ) | Mộc / medium | Single slow volley, **scattershot cone** | 5 bolts, spread about +-15 deg, about 4-5 dmg each, volley cooldown about 0.7 s, bolt speed about 260, lifetime about 0.35-0.4 s | **Target within about 40 px** (close range) |
| **Định Nam Đao** (Mạc Đăng Dung's blade, attributed by tradition) | Thổ / heavy (decided) | Very slow, longest reach in the game, one huge hit | tune after the others; DPS in the same band as the rest | **Target below about 30% health** (finisher) |

DPS target for all weapons: roughly 33-42 by `get_display_dps()` (same band as the dagger, spear, and hammer). Specialists trade base DPS for a reward when they hit the window.

Implementation notes:
- Liên châu nỏ: loop `_fire_arrow` over the bolts with `direction.rotated(angle)`. ICD means five same-element bolts resolve at most one reaction per target. Use the light hit-stop/shake preset so a volley does not feel like five impacts. Optional small armor shred per bolt (about 0.5) as a nod to the three-edged arrowheads; skip it if it stacks too hard.
- Định Nam Đao needs a health getter on every enemy. `Boss` has `get_health_ratio()`; `TestDummy`, `PatrolDummy`, `FlyingEnemy`, `ShooterEnemy`, `SwooperEnemy` keep `_current_health` private. Add the same getter to each (same "edit shape, many call sites" pattern the project already uses).
- Weapon texture width defines real reach when `weapon_texture` is set, so each weapon needs art (or accept no sprite/VFX at first). Rough sprite lengths: mâu about 20 px, quan đao about 16 px.
- Do not add these to `STARTING_WEAPON_PATHS`. Keep a separate shop-only list so they unlock through the shop and `record_weapon_unlock`.
- Avoid any weapon with `combo_steps = null` (as in `runed_greatsword.tres`); that causes a divide-by-zero in `_current_combo_step_data`.

### 4. Build order
1. Core system (section 1) with the dagger streak as the first test case.
2. Windows for existing weapons (section 2), one at a time.
3. Small hooks: last-dodge time on `Player`, airborne check, distance checks in `Hitbox`.
4. New weapon `.tres` files with placeholder art.
5. Health getter on enemies, then Định Nam Đao.
6. Shop-only weapon list wired into the shop stock.
7. Tests for every window (see below).

### 5. Tests
- Each window: true case grants x1.5 once; false case grants nothing; the multiplier never changes `hit_data.charge`.
- Streak: 6th hit triggers, resets after the 2 s gap, resets on weapon swap, is per wielder.
- Window state is not consumed by anything else (for example a Hỏa hit overwriting Mộc status does not close a rooted-target window).
- Scattershot: 5 bolts spawn, ICD resolves one reaction per target.
- `WeaponStats` loads for every new `.tres` and none has an empty `combo_steps`.

### 6. Decisions

**Resolved**
- **Disable-based windows read `is_disabled()` directly** (the Dead Cells way). No source tag on `DisableEffect`. A root, stagger, or stun all open the window.
- **Perfect Hit multiplier is 1.5-2.0x**, set per weapon (guide below).
- **Định Nam Đao is Thổ** (heavy, base Charge 2).

**Multiplier guide** (harder or rarer window, higher multiplier)

| Multiplier | Weapons (window) |
|---|---|
| 1.5x | Dagger (streak), Đao (post-dodge), Song kiếm (airborne), Bow (long range) |
| 1.75x | Spear (slowed), Greatsword (finisher), Mâu (tip), Liên châu nỏ (close range) |
| 2.0x | Staff (disabled), Quan đao (disabled), Hammer (plunge), Định Nam Đao (below 30% health) |

Starting values only. Perfect Hit stacks multiplicatively with Weapon Might and the combo-step multiplier, so a 2.0x hit with a few Weapon Might ranks can reach 3x or more. Playtest this, and if it gets out of hand, make the Perfect Hit bonus additive with Weapon Might instead.

**Still open**
1. **Staff and Quan đao share the same window** (both read "disabled"). This is acceptable because they are different elements and weights, and a Mộc weapon can open the window itself (Overgrowth roots) while a Kim weapon needs a teammate or another weapon to do it. If it feels redundant, give Quan đao a swing-based window instead: "the swing hits two or more enemies" (crowd sweep, fits the wide crescent). That needs the hitbox to count targets hit per active window and apply the bonus to the second target onward.
2. **Mộc count.** Staff, bow, and Liên châu nỏ are all Mộc. Move the bow or the nỏ to another element if that feels crowded.

---

## COULD BE

### Thuận Thiên Kiếm (Lê Lợi's sword)
Legendary reward weapon. Not required for any other item above.

- **Mechanic:** Perfect Hit window = hits with this sword **within about 3 s of landing a hit with the other equipped weapon**. It rewards alternating the two weapons, which is already how reactions between two elements get triggered. Type: execution.
- **Theme:** the two halves of the legend (blade and hilt) map to the player's two weapons.
- **Stats:** Kim, medium weight, kiếm style, 3 steps (two cuts, then a thrust using `AttackStyle.THRUST`). Keep base Charge at 1 and let the window do the work. Never give it element `none`, because that skips reaction resolution.
- **Acquisition:** guaranteed drop when the boss dies (one `WeaponPickup` spawned in `Boss._die()` next to the rune drop). `record_weapon_unlock` makes it available in the loadout pool for later runs. It also carries into the next loop through the pending-loadout fields.
- **Keep it out of** the shop pool and `STARTING_WEAPON_PATHS`.
- **Needs:** `Hitbox.hit_landed` (from the core system), a per-slot "last hit time" on `Player`, a sword sprite and slash VFX.
- **Risks:** a guaranteed boss drop means every winning run holds it; keep its DPS in the same band as the other weapons. The 3 s window is easy to keep permanently open with two fast weapons, so tune the window after playtesting.
- **Optional later flavor:** a "return the sword" moment tied to the Hoàn Kiếm legend. Leave it out unless time is spare.
- Verify the legend's details (Lê Thận, the banyan tree, the blade and hilt fitting together) against a source before citing it in the report.

### Other items discussed, not yet scheduled
- **Paid rune slot in the shop** (player picks the element from two or three offers, about 25-30 Qi). Only worthwhile after 5-8 `RuneModifierDef` assets exist.
- **Rune reforge:** pick one modifier, pay, compare current versus new, keep either. Element is never rerolled, modifier count never changes, no duplicate ids, cost escalates per rune via a `reforge_count` stored in `RuneData`. Needs 8 or more modifiers to be worth it.
- **Heavy repeater** (hold-to-fire, slows the player while firing). Needs hold-fire input and a movement-lock state first.

### Decided against
- **Weapon tier/level system.** Overlaps Weapon Might and runes, risks touching Charge, and breaks the save format unless the tier is stored on the Player slot. Revisit only if the shop needs a Qi sink after runes exist.
- **Backstab condition.** Enemies have no facing; it would need a new facing system in every enemy script.
- **Separate plunge and thrust multipliers.** Replaced by Perfect Hit windows.
