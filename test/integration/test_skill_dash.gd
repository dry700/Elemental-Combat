extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

func test_skill_dash_uses_iframes_without_normal_dodge_cooldown():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.dash_distance = 70.0
	skill.dash_iframes = 0.2
	player._start_skill_dash(skill)
	assert_eq(player._dodge_cooldown_timer, 0.0)
	player._process_dodge(0.01)
	assert_true(player.hurtbox.invulnerable)
	player._process_dodge(0.25)
	assert_false(player.hurtbox.invulnerable)
