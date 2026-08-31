extends Node2D
## Minimal stand-in for the real Player/TestDummy shape: an owning Node
## exposing its ElementalCombatant via a plain `elemental` property. Both
## _bystander_attacker() and the Vũ handler (ElementalCombatant.gd) read
## an attacker's combatant this exact way — hit_data.source.get("elemental")
## — which only works against a real declared script property, not a
## bare child-node relationship. Tests needing a genuine
## attacker-owns-a-combatant link (bystander exclusion, Vũ) use this.

var elemental: ElementalCombatant
