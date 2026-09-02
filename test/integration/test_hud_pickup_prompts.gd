extends GutTest
## Integration test for Hud._refresh_active_pickups() — the group-scan
## that lets the HUD highlight both candidate slots while a weapon/skill
## pickup's 1/2 choice is live (see hud.gd, weapon_pickup.gd,
## skill_pickup.gd). Uses the real Hud autoload singleton rather than a
## fresh instance, since Hud is registered once in project.godot and
## every scene already shares that one instance.

var pickup: WeaponPickup
var player: Player

func before_each():
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	add_child_autofree(player)
	pickup = WeaponPickup.new()
	pickup.weapon = WeaponStats.new()
	add_child_autofree(pickup)

func after_each():
	Hud._active_weapon_pickup = null  # Don't leak this test's pickup reference into later frames/tests.

func test_refresh_finds_a_pickup_the_player_is_standing_near():
	pickup._on_body_entered(player)
	Hud._refresh_active_pickups()
	assert_eq(Hud._active_weapon_pickup, pickup)

func test_refresh_clears_once_the_player_leaves_range():
	pickup._on_body_entered(player)
	Hud._refresh_active_pickups()
	pickup._on_body_exited(player)
	Hud._refresh_active_pickups()
	assert_null(Hud._active_weapon_pickup)
