extends GutTest

## Unit + integration tests for the plague relics (carrion / parasite / pustule).
## These exercise the relic effect objects directly and the EffectManager fly-bite
## dispatch; they do not require the fly scene or any generated art.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const PlagueFlyScene: PackedScene = preload("res://Combat/effects/plague_fly/plague_fly.tscn")
const InfectionVisualScene: PackedScene = preload("res://Combat/effects/infection_status_visual/infection_status_visual.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		var empty_loadout: RefCounted = LoadoutScript.new()
		var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
		_effect_manager.configure(empty_loadout, empty_progression)
	_effect_manager = null
	_loadout = null
	_progression = null


# --- carrion ---

func test_carrion_duration_bonus_scales_by_level() -> void:
	var carrion: CarrionEffect = CarrionEffect.new()
	carrion.set_level(1)
	assert_eq(carrion.get_fly_duration_bonus(), 2.0)
	carrion.set_level(2)
	assert_eq(carrion.get_fly_duration_bonus(), 4.0)
	carrion.set_level(3)
	assert_eq(carrion.get_fly_duration_bonus(), 6.0)


func test_carrion_awakened_adds_bite_damage() -> void:
	var carrion: CarrionEffect = CarrionEffect.new()
	assert_eq(carrion.get_fly_damage_bonus(), 0, "no bonus before awakening")
	carrion.set_awakened(true)
	assert_eq(carrion.get_fly_damage_bonus(), 1)


# --- pustule ---

func test_pustule_extra_fly_count() -> void:
	var pustule: PustuleEffect = PustuleEffect.new()
	pustule.set_level(1)
	assert_eq(pustule.get_extra_fly_count(), 1)
	pustule.set_level(3)
	assert_eq(pustule.get_extra_fly_count(), 1, "levels add duration, not count")
	pustule.set_awakened(true)
	assert_eq(pustule.get_extra_fly_count(), 2)


func test_pustule_extra_fly_duration_penalty_by_level() -> void:
	var pustule: PustuleEffect = PustuleEffect.new()
	pustule.set_level(1)
	assert_eq(pustule.get_extra_fly_duration_penalty(), 2.0)
	pustule.set_level(2)
	assert_eq(pustule.get_extra_fly_duration_penalty(), 1.0)
	pustule.set_level(3)
	assert_eq(pustule.get_extra_fly_duration_penalty(), 0.0)
	pustule.set_awakened(true)
	assert_eq(pustule.get_extra_fly_duration_penalty(), 0.0, "awakened: no penalty")


# --- parasite ---

func test_parasite_stacks_per_bite() -> void:
	var parasite: ParasiteEffect = ParasiteEffect.new()
	parasite.set_level(1)
	assert_eq(parasite.get_stacks_per_bite(), 1)
	parasite.set_level(2)
	assert_eq(parasite.get_stacks_per_bite(), 2)
	parasite.set_level(3)
	assert_eq(parasite.get_stacks_per_bite(), 3)
	parasite.set_awakened(true)
	assert_eq(parasite.get_stacks_per_bite(), 4)


func test_parasite_fly_bite_layers_poison() -> void:
	var enemy: Enemy = _enemy()
	var parasite: ParasiteEffect = ParasiteEffect.new()
	parasite.set_level(1)
	assert_false(enemy.has_buff("poison_debuff"))
	parasite.on_fly_bite(enemy)
	assert_true(enemy.has_buff("poison_debuff"))
	assert_eq(enemy.get_buff_stacks("poison_debuff"), 1)


func test_parasite_bite_can_infect() -> void:
	var enemy: Enemy = _enemy()
	var parasite: ParasiteEffect = ParasiteEffect.new()
	parasite.set_level(1)
	for i: int in range(4):
		parasite.on_fly_bite(enemy)
	assert_true(enemy.has_buff("infection_debuff"), "four parasite bites reach infection")


func test_plague_fly_visuals_reuse_the_looping_two_frame_animation() -> void:
	var fly: Node2D = PlagueFlyScene.instantiate() as Node2D
	add_child_autofree(fly)
	var fly_sprite: AnimatedSprite2D = fly.get_node_or_null("Sprite") as AnimatedSprite2D
	assert_not_null(fly_sprite)
	assert_eq(fly_sprite.sprite_frames.get_frame_count(&"fly"), 2)
	assert_eq(fly_sprite.sprite_frames.get_animation_speed(&"fly"), 8.0)
	assert_eq(fly_sprite.autoplay, "fly")
	assert_true(fly_sprite.is_playing())
	var infection: Node2D = InfectionVisualScene.instantiate() as Node2D
	add_child_autofree(infection)
	for path: NodePath in [NodePath("Orbit/FlyA"), NodePath("Orbit/FlyB")]:
		var orbit_fly: AnimatedSprite2D = infection.get_node_or_null(path) as AnimatedSprite2D
		assert_not_null(orbit_fly)
		assert_eq(orbit_fly.sprite_frames.get_frame_count(&"fly"), 2)
		assert_eq(orbit_fly.sprite_frames.get_animation_speed(&"fly"), 8.0)
		assert_eq(orbit_fly.autoplay, "fly")
		assert_true(orbit_fly.is_playing())


# --- effect manager dispatch ---

func test_effect_manager_dispatches_fly_bite_to_parasite() -> void:
	_configure(["parasite"])
	var enemy: Enemy = _enemy()
	assert_false(enemy.has_buff("poison_debuff"))
	_effect_manager.on_fly_bite(enemy, null)
	assert_true(enemy.has_buff("poison_debuff"), "on_fly_bite reaches the parasite relic")


func _configure(relic_ids: Array) -> void:
	_loadout = LoadoutScript.new()
	for relic_id: String in relic_ids:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(_loadout.call("add", relic))
	_progression = ProgressionScript.new(_loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(_loadout, _progression))


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
