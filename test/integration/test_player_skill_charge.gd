extends GutTest
## Integration test for A.3's rune-to-skill bonus: "a same-element rune's
## +1 Charge applies both to the weapon's own hits and to any equipped
## skill sharing that element." Lives on Player, not a standalone
## component, so this loads the real scene.
##
## NOTE: adjust WEAPON_*_PATH below if resources/weapons differs in your
## project. Uses load() rather than preload() so a wrong path fails one
## test, not the whole file.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const WEAPON_RUNED_GREATSWORD_PATH := "res://scripts/resources/weapons/runed_greatsword.tres"  # Kim, same-element Kim rune
const WEAPON_TRAINING_DAGGER_PATH := "res://scripts/resources/weapons/training_dagger.tres"     # Hỏa, no rune

var player: Player

func after_each():
	if is_instance_valid(player):
		player.queue_free()

func test_matching_same_element_rune_reaches_charge_3():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	player.weapon = load(WEAPON_RUNED_GREATSWORD_PATH)
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.element = Elements.KIM
	assert_eq(player._resolve_skill_charge(skill), 3)

func test_no_matching_rune_stays_at_base_charge_2():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	player.weapon = load(WEAPON_TRAINING_DAGGER_PATH)
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.element = Elements.HOA
	assert_eq(player._resolve_skill_charge(skill), 2)

func test_rune_element_matching_a_different_skill_element_gives_no_bonus():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	player.weapon = load(WEAPON_RUNED_GREATSWORD_PATH)
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.element = Elements.THUY
	assert_eq(player._resolve_skill_charge(skill), 2)
