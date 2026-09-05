# Art Direction (Appendix A.1, extended)

Companion to this folder's README.md — that file covers the technical
pipeline (naming, canvas, upscaling); this one covers the creative
decisions those files should actually look like. Resolved through
Q&A on 2026-09-04; revisit if any of these stop fitting mid-production.

## Tone
Vibrant, saturated, arcade-readable — closer to Dead Cells than a
muted/gritty palette. Full color range, **black outlines** on every
sprite for silhouette clarity at 16×16 and to hold up against busy
VFX (Zones, steam clouds, glyph accents).

## Player: the Exorcist
Taoist/East-Asian exorcist archetype — robes, talismans, a straight
jian sword as the **default/base appearance** (matches the
`WeaponStats.new()` fallback already in `player.gd` when no weapon
resource is assigned). The jian is not the only weapon in-game — see
Weapons below — it's what the exorcist looks like unarmed/bare-default.

Stays visually plain otherwise. The one exception is a **talisman
accessory**, which dynamically recolors and (where practical at 16×16)
reshapes to match `ElementalStatus.element` currently active on the
player — i.e. it mirrors what `ElementIndicator` already shows above
the player's head, just worn on the character instead of floating.
No active status (`Elements.NONE`, the common case) = a **dormant/neutral**
look for the talisman — plain paper/wood, no glyph, no tint. This
dormant state still needs its own sketch pass, not just "absence of
color."

## Weapons (Appendix A.4)
**Full swap** — each weight/element archetype gets its own weapon
sprite, not a reskin of one silhouette:

| Element | Weight | Weapon sprite |
|---|---|---|
| Hỏa | Light | Dagger / dual blade |
| Thủy | Medium | Spear (flail/thrown as alt skins, lower priority) |
| Mộc | Medium | Staff (bow as alt skin, lower priority) |
| Kim | Heavy | Greatsword |
| Thổ | Heavy | Hammer |

Jian = unequipped/default state only, per the Player section above —
not one of the five archetype weapons itself.

## Element Palette (already load-bearing in code — reuse exactly)
Pulled from `ElementIndicator.ELEMENT_COLOR` / `ReactionZone.ZONE_TINT`,
so sprite/VFX/UI colors stay consistent instead of three separate
palettes drifting apart. Treat these as the source of truth; the hex
below is a derived reference, not a separate authority:

| Element | Glyph | Color (code) | Approx. hex |
|---|---|---|---|
| Kim (Metal) | Diamond | `Color(0.82, 0.82, 0.88)` | `#D1D1E0` |
| Mộc (Wood) | Spiral | `Color(0.45, 0.75, 0.45)` | `#73BF73` |
| Thủy (Water) | Wave | `Color(0.30, 0.55, 0.95)` | `#4D8CF2` |
| Hỏa (Fire) | Zigzag | `Color(0.95, 0.35, 0.25)` | `#F25940` |
| Thổ (Earth) | Dot-grid | `Color(0.65, 0.50, 0.30)` | `#A6804D` |

## Where the glyphs live
- **Elemental enemies/bosses**: glyph markings woven directly into the
  design (e.g. a Kim spirit's diamond etched into its body/armor, not
  just floating above it) — reinforces A.1's WCAG 1.4.1 pattern
  language at the creature level, not only in the status UI.
- **Player**: glyph appears ONLY on the one talisman accessory, per
  its current status element (see above). Nowhere else on the exorcist.
- **Normal enemies** (no innate element): no glyph markings at all —
  visually distinct from spirits/bosses by having none.

## Enemy tiers (Appendix A.6) — silhouette scaling
- **Normal**: small, 16×16, no glyph.
- **Elemental spirit**: medium, 16×16 canvas (per existing README.md
  convention) unless a specific design needs more — glyph marking present.
- **Boss**: large. Canvas size **decided per-boss**, no fixed rule —
  `boss.tscn`'s existing 32×48 collision shape is a reasonable floor,
  not a ceiling; a boss can go bigger if the silhouette needs it.

## Open / deferred (not blocking, revisit per-sprite)
- Talisman's exact dormant-state art (flagged above).
- Rune-slot visual representation on weapons — out of scope until a
  rune actually needs to read on-screen.
- Animation frame budget per state (idle/run/attack/hurt/death) —
  production question, not art-direction; tackle once the first
  character sheet is under way.
