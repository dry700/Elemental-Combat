# Sprint 1 Guide: First Run to First Tuning Pass

This walks through opening the project for the first time, what you should
actually feel when you run it, and how to turn that feeling into concrete
edits. The README covers technical troubleshooting; this covers *using*
the thing.

## 1. Opening it

1. Install Godot **4.7.x** if you don't already have it — get it from
   godotengine.org, no installer needed, it's a single executable.
2. Launch Godot, click **Import**, and point it at the `project.godot`
   file inside the unzipped `elemental_roguelike` folder.
3. Once it opens in the editor, press **F5** (or the Play button, top
   right). It should ask which scene to run the first time — pick
   `test_arena.tscn` if prompted, though `project.godot` already sets
   this as the default main scene.

If the editor shows any red errors in the bottom **Output** panel before
you even press play, stop and check the README's troubleshooting section
first — running with a broken script attached rarely fails cleanly.

## 2. What you should see

A grey ground strip, a lighter grey floating platform on the right, a
blue rectangle (you) on the left, and a red rectangle (the test dummy) in
the middle. No sprites, no animation — that's expected, see A.1 for the
actual art pipeline, which comes later.

Move with A/D, jump with Space, dodge with Left Shift, attack with J.
Walk up to the dummy and hit it.

## 3. What you're actually judging

Sprint 1 has exactly one job: does this feel good to move and hit things
with, independent of anything elemental. Swink's (2009) framework — the
one in your own lit review — splits "feel" into three things. Judge each
one separately rather than forming one vague "feels ok/bad" impression:

**Input latency** — does the character respond the instant you press a
key, or does it feel like there's a delay? Try tapping jump right as you
run off the platform edge, and tapping it slightly *before* you land from
a fall. Both should still jump (that's coyote time and jump buffering
doing their job) — if either feels like it "ate" your input, that's a
latency problem, not a tuning problem, and worth flagging before you move
on.

**Response curves** — does accelerating up to full speed and stopping
feel abrupt or smooth? Compare tapping A/D briefly (should give small,
controlled taps of movement) against holding it (should ramp to full
speed). If tapping briefly still launches you at full speed, the
acceleration curve is too aggressive for the numbers below.

**Juice** — does landing a hit on the dummy feel like an *event*? The
hit-stop (brief freeze-frame) and knockback are doing the work here. Too
weak and hits feel like nothing happened; too strong and it feels like
the game stuttered. This is the most subjective of the three and the one
worth spending the most playtesting time on, since it's what "combat
feel" mostly boils down to in practice.

## 4. Tuning — what to change and where

Everything tunable lives as `@export` variables at the top of
`scenes/player/player.gd`, so you can also drag them live in the Godot
Inspector while the game is running (select the `Player` node in the
scene tree during Play mode) instead of editing code and re-running each
time. That's the fastest way to iterate — find a number you like in the
Inspector, *then* copy it back into the script.

| If this feels... | Try changing | Direction |
|---|---|---|
| Sluggish to start moving | `acceleration` | increase |
| Slidey / hard to stop precisely | `friction` | increase |
| Floaty in the air | `air_acceleration`, or raise gravity in Project Settings → Physics → 2D | increase both |
| Jump feels weak/short | `jump_velocity` | more negative (e.g. -420 → -480) |
| Coyote/buffer window too generous (feels unresponsive to misses) | `coyote_time`, `jump_buffer_time` | decrease |
| Dodge i-frames feel unfair to enemies (once you have any) | `dodge_iframe_window` | shrink the window |
| Hits feel weak | `HitStop.freeze()` call in `_on_hurtbox_hit`, and `knockback_strength` on the Hitbox node | increase both |
| Hits feel like the game freezes oddly | the hit-stop duration (first argument to `freeze()`) | decrease |

Change one thing at a time. It's tempting to adjust three numbers after
one playtest — resist it, since you won't know which change actually
fixed (or broke) the feel.

## 5. A minimal way to keep track of what you tried

You don't need a formal spreadsheet for this, but it's worth writing down
even a one-line note per session — something like:

```
2026-08-24: jump_velocity -420 -> -460, feels much better on the platform jump.
            friction 2200 -> 1800, now feels too slidey, reverting.
```

This matters more than it sounds like it should: by the time you're
writing the Contextual Report's evaluation section, "I tuned it until it
felt right" isn't something you can defend, but a short log of what you
tried and why gives you actual evidence of an iterative process — which
is the whole methodology point already written into Section 6 of your
proposal.

## 6. Version control — first commit

If you haven't already:

```bash
cd elemental_roguelike
git init
git add .
git commit -m "Sprint 1: core movement, jump, dodge, attack, hit-stop"
```

The `.gitignore` already excludes Godot's generated `.godot/` cache
folder, so you won't accidentally commit it.

## 7. When Sprint 1 is "done"

Not when it's perfect — when movement, jump, dodge, and one attack all
feel intentional rather than accidental, and you could hand it to someone
else to try for 30 seconds without needing to explain the controls. That
bar is what Sprint 2 (the actual Sinh/Khắc reaction system, Appendix A.2)
gets to build on top of. If combat doesn't feel good yet, adding
elemental reactions on top won't fix that — per the design rationale
already in A.3, the two are meant to operate at different layers, and a
reaction system can't rescue combat that isn't fun on its own.
