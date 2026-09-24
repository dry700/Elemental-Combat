extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player
var pickup: RunePickup

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)
	pickup = RunePickup.new()
	pickup.set_rune(RuneData.new(Elements.KIM, RuneData.Target.WEAPON))
	add_child_autofree(pickup)

func test_pickup_joins_rune_group_after_ready():
	assert_true(pickup.is_in_group("rune_pickups"))

func test_pickup_tracks_player_proximity_without_equipping():
	pickup._on_body_entered(player)
	assert_eq(pickup._player_in_range, player)
	assert_not_null(player.weapon)

func test_leaving_range_clears_player_proximity():
	pickup._on_body_entered(player)
	pickup._on_body_exited(player)
	assert_null(pickup._player_in_range)

func test_spirit_roll_can_return_own_element():
	seed(1)
	var rolled := RunePickup.roll_spirit_element(Elements.HOA)
	assert_true(Elements.ALL.has(rolled))
