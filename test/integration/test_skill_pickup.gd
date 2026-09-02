extends GutTest
## Integration tests for SkillPickup — mirrors test_weapon_pickup.gd's
## structure: proximity tracking, the F quick-pickup default-slot logic,
## and the explicit 1/2 slot choice (A.4/A.5, "full swap"), targeting
## skill_1/skill_2 instead of weapon/secondary_weapon.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player
var pickup: SkillPickup

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)
	pickup = SkillPickup.new()
	pickup.skill = SkillData.new()
	pickup.skill.element = Elements.KIM
	pickup.slot = SkillPickup.Slot.PRIMARY
	add_child_autofree(pickup)

func test_entering_range_does_not_equip_by_itself():
	var original := player.skill_1
	pickup._on_body_entered(player)
	assert_eq(player.skill_1, original, "proximity alone must not equip — needs a key press")

func test_explicit_choice_of_slot_1_equips_skill_1_regardless_of_pickups_default():
	pickup.slot = SkillPickup.Slot.SECONDARY
	pickup._on_body_entered(player)
	pickup._do_pickup(player, true)
	assert_eq(player.skill_1, pickup.skill)

func test_explicit_choice_of_slot_2_equips_skill_2_regardless_of_pickups_default():
	pickup.slot = SkillPickup.Slot.PRIMARY
	var original_skill_1 := player.skill_1
	pickup._on_body_entered(player)
	pickup._do_pickup(player, false)
	assert_eq(player.skill_2, pickup.skill)
	assert_eq(player.skill_1, original_skill_1)

func test_quick_pickup_defaults_to_an_empty_slot_over_the_pickups_own_default():
	pickup.slot = SkillPickup.Slot.SECONDARY  # would normally target secondary
	assert_null(player.skill_1)  # skill_1 has no fallback assignment — starts empty
	pickup._on_body_entered(player)
	assert_true(pickup._default_target_is_primary(player), "quick pickup should prefer the empty skill_1 slot")

func test_quick_pickup_falls_back_to_the_pickups_own_slot_when_both_full():
	pickup.slot = SkillPickup.Slot.SECONDARY
	player.skill_1 = SkillData.new()
	player.skill_2 = SkillData.new()
	pickup._on_body_entered(player)
	assert_false(pickup._default_target_is_primary(player), "with both slots full, falls back to the pickup's own preferred slot (secondary)")

func test_leaving_range_clears_the_prompt_target():
	pickup._on_body_entered(player)
	pickup._on_body_exited(player)
	assert_null(pickup._player_in_range)

func test_a_second_pickup_call_after_pickup_does_nothing():
	pickup._on_body_entered(player)
	pickup._do_pickup(player, true)
	var equipped := player.skill_1
	assert_true(pickup._picked_up)
	assert_eq(player.skill_1, equipped)

func test_contact_from_a_non_player_body_is_ignored():
	var stranger := Node2D.new()
	add_child_autofree(stranger)
	var original := player.skill_1
	pickup._on_body_entered(stranger)
	assert_null(pickup._player_in_range)
	assert_eq(player.skill_1, original)
