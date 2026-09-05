class_name SkillData
extends Resource
## Describes one active skill (Appendix A.5). Resource-based, same
## reasoning as WeaponStats — authored/tuned as .tres assets rather than
## hardcoded. A.5 frames skills as shared between player and elemental
## enemies/bosses; only the player casts these for now since A.6 enemy
## AI doesn't exist yet, but nothing here is player-specific.

## What a cast actually DOES, resolved once here instead of scattered
## across Player's input handling — mirrors WeaponStats.resolve_swing()
## owning its own resolution rather than the caller.
enum Function {
	APPLY_SELF,          ## Stoneguard: status.apply() straight to self, no reaction check (A.3's Wu-bait case — building up your OWN status, not reacting to a hit).
	REMOVE_APPLY_SELF,   ## Cleansing Tide: clears own status (bypasses Charge), then applies a fresh one.
	APPLY_SINGLE_TARGET, ## Ignite Dart: fires a traveling SkillProjectile that resolves through the full Sinh/Khắc pipeline on its first hit, same as a weapon hit — no longer an instant hitscan (see SkillProjectile).
	REMOVE_ENEMY,        ## Rending Edge: strips a target enemy's status, bypasses Charge, no damage.
	APPLY_AREA,          ## Overgrowth Snare: spawns an A.7 Zone at the caster's position.
}

@export var skill_name: String = "Skill"
@export var element: StringName = &"none"
@export var function: Function = Function.APPLY_SELF
@export var cooldown: float = 10.0

## APPLY_SINGLE_TARGET / REMOVE_ENEMY only. No aim/targeting system
## exists anywhere else in this project (Hitbox is melee-proximity,
## Projectile fires in a fixed spread) — see Player._find_skill_target().
@export var cast_range: float = 110.0

## APPLY_AREA only.
@export var zone_radius: float = 60.0
@export var zone_lifetime: float = 9.0
