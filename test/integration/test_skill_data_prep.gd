extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const CARD_SCENE_PATH := "res://scenes/ui/swap_card.tscn"
const SKILL_PATH := "res://scripts/resources/skills/ignite_dart.tres"
const SkillPoolResource = preload("res://scripts/resources/skills/skill_pool.gd")

func test_skill_card_displays_description_and_icon():
	var card := load(CARD_SCENE_PATH).instantiate() as PickupCard
	add_child_autofree(card)
	var skill := SkillData.new()
	skill.skill_name = "Test Skill"
	skill.description = "Test description"
	var icon := GradientTexture2D.new()
	skill.icon = icon
	card.set_skill(skill)
	assert_eq(card.get_node("MarginContainer/HBox/VBox/Description").text, "Test description")
	assert_eq(card.get_node("MarginContainer/HBox/IconBackground/Icon").texture, icon)

func test_duplicate_skill_check_compares_non_empty_resource_paths():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var skill := load(SKILL_PATH) as SkillData
	player.skill_2 = skill
	assert_true(player.would_duplicate_skill(true, skill))
	assert_false(player.would_duplicate_skill(false, skill))
	assert_false(player.would_duplicate_skill(true, SkillData.new()))

func test_skill_cooldown_ratio_is_zero_when_ready_and_one_when_just_cast():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.cooldown = 8.0
	assert_eq(player.get_skill_cooldown_ratio(skill), 0.0)
	player._skill_cooldowns[skill] = 8.0
	assert_eq(player.get_skill_cooldown_ratio(skill), 1.0)
	player._skill_cooldowns[skill] = 2.0
	assert_almost_eq(player.get_skill_cooldown_ratio(skill), 0.25, 0.001)

func test_skill_pool_contains_fifteen_described_resources_across_all_elements():
	assert_eq(SkillPoolResource.SKILL_PATHS.size(), 15)
	var elements := [Elements.HOA, Elements.THUY, Elements.MOC, Elements.KIM, Elements.THO]
	for element in elements:
		assert_eq(SkillPoolResource.by_element(element).size(), 3, "each element should have three skills")
	for path in SkillPoolResource.SKILL_PATHS:
		var skill := load(path) as SkillData
		assert_not_null(skill, "skill resource should load: " + path)
		assert_false(skill.description.is_empty(), "skill needs a card description: " + path)

func test_skill_pool_roll_respects_excluded_paths():
	var allowed_path: String = SkillPoolResource.SKILL_PATHS.back()
	var excluded := SkillPoolResource.SKILL_PATHS.duplicate()
	excluded.erase(allowed_path)
	var rolled: SkillData = SkillPoolResource.roll(excluded)
	assert_eq(rolled.resource_path, allowed_path)
	excluded.append(allowed_path)
	assert_null(SkillPoolResource.roll(excluded))

func test_test_arena_has_a_priced_shop_skill_stall():
	var arena: Node = (load("res://scenes/world/test_arena.tscn") as PackedScene).instantiate()
	add_child_autofree(arena)
	var stall := arena.get_node("ShopSkillStall") as ShopSkillPickup
	assert_not_null(stall)
	assert_eq(stall.price, 60)
	assert_eq(stall.skill.resource_path, "res://scripts/resources/skills/earthen_bulwark.tres")

func test_skill_drop_helper_spawns_matching_element_pickup():
	var parent := Node2D.new()
	add_child_autofree(parent)
	var pickup := SkillPickup.spawn_drop(parent, Vector2(12, 34), Elements.THUY)
	await get_tree().process_frame
	assert_not_null(parent.get_node_or_null(NodePath(str(pickup.name))))
	assert_eq(pickup.skill.element, Elements.THUY)
