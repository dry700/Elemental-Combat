class_name SkillPool
extends RefCounted
## Shared resource pool for skills that can be found during a run.

const SKILL_PATHS: Array[String] = [
	"res://scripts/resources/skills/ignite_dart.tres",
	"res://scripts/resources/skills/overgrowth_snare.tres",
	"res://scripts/resources/skills/cleansing_tide.tres",
	"res://scripts/resources/skills/rending_edge.tres",
	"res://scripts/resources/skills/stoneguard.tres",
	"res://scripts/resources/skills/ember_burst.tres",
	"res://scripts/resources/skills/flame_dash.tres",
	"res://scripts/resources/skills/undertow.tres",
	"res://scripts/resources/skills/tide_step.tres",
	"res://scripts/resources/skills/thorn_volley.tres",
	"res://scripts/resources/skills/barkskin.tres",
	"res://scripts/resources/skills/throwing_blades.tres",
	"res://scripts/resources/skills/shard_field.tres",
	"res://scripts/resources/skills/seismic_slam.tres",
	"res://scripts/resources/skills/earthen_bulwark.tres",
]

static func by_element(element: StringName) -> Array[String]:
	var paths: Array[String] = []
	for path in SKILL_PATHS:
		var skill := load(path) as SkillData
		if skill != null and skill.element == element:
			paths.append(path)
	return paths

static func roll(exclude_paths: Array, element: StringName = Elements.NONE) -> SkillData:
	var candidates: Array[SkillData] = []
	for path in SKILL_PATHS:
		if exclude_paths.has(path):
			continue
		var skill := load(path) as SkillData
		if skill != null and (element == Elements.NONE or skill.element == element):
			candidates.append(skill)
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]
