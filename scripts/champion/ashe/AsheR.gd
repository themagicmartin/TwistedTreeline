extends AbilitySystem
# Ashe R — Enchanted Crystal Arrow
# Fires a massive arrow globally. Stuns first champion hit for 1–3.5s (scales with distance).
# Deals magic damage.

const BASE_DMG := [0.0, 250.0, 425.0, 600.0]
const AP_RATIO := 1.0
const MIN_STUN  := 1.0
const MAX_STUN  := 3.5
const MAX_RANGE := 20000.0  # effectively global
const ARROW_SPEED := 1600.0

func _ready() -> void:
	ability_name   = "Enchanted Crystal Arrow"
	cast_type      = CastType.SKILLSHOT
	cooldown_base  = 100.0
	mana_cost_base = 100.0
	max_rank       = 3
	range          = MAX_RANGE
	super()._ready()


func get_cooldown() -> float:
	return [100.0, 80.0, 60.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	var origin := owner_champion.global_position
	var aim: Vector2
	if target is Vector2:
		aim = origin.direction_to(target)
	else:
		return

	var arrow := _CrystalArrow.new()
	arrow.position = origin
	arrow.direction = aim
	arrow.damage = BASE_DMG[rank] + owner_champion.ability_power * AP_RATIO
	arrow.source = owner_champion
	owner_champion.get_parent().add_child(arrow)


class _CrystalArrow extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: float = 250.0
	var source: Node = null
	var speed: float = 1600.0
	var _traveled: float = 0.0

	func _process(delta: float) -> void:
		var move := direction * speed * delta
		position += move
		_traveled += move.length()
		if _traveled >= AsheR.MAX_RANGE:
			queue_free()
			return
		for unit in get_tree().get_nodes_in_group("all_units"):
			if not unit.has_variable("team"):
				continue
			if not CombatSystem.is_enemy(source, unit):
				continue
			if global_position.distance_to(unit.global_position) < 40.0:
				_hit_target(unit)

	func _hit_target(target: Node) -> void:
		# Stun duration scales with travel distance
		var t := lerp(AsheR.MIN_STUN, AsheR.MAX_STUN, clampf(_traveled / 3000.0, 0.0, 1.0))
		CombatSystem.deal_damage(source, target, damage, CombatSystem.DamageType.MAGIC, true)
		StatusEffect.make_stun(target, t)
		queue_free()
