extends AbilitySystem
# Ashe W — Volley
# Fires 7 arrows in a cone, each slowing enemies hit.

const ARROW_COUNT := 7
const CONE_ANGLE_DEG := 57.5
const SLOW_AMOUNT := [0.0, 0.20, 0.25, 0.30, 0.35, 0.40]
const SLOW_DURATION := 2.0
const BASE_DMG := [0.0, 40.0, 50.0, 60.0, 70.0, 80.0]

func _ready() -> void:
	ability_name   = "Volley"
	cast_type      = CastType.SKILLSHOT
	cooldown_base  = 14.0
	mana_cost_base = 50.0
	max_rank       = 5
	range          = 1200.0
	super()._ready()


func get_cooldown() -> float:
	return [14.0, 12.0, 10.0, 8.0, 6.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	var origin := owner_champion.global_position
	var aim: Vector2
	if target is Vector2:
		aim = origin.direction_to(target)
	else:
		return

	var angle_step := CONE_ANGLE_DEG / (ARROW_COUNT - 1)
	var start_angle := -CONE_ANGLE_DEG / 2.0
	for i in range(ARROW_COUNT):
		var angle := deg_to_rad(start_angle + angle_step * i)
		var dir := aim.rotated(angle)
		_spawn_slowing_arrow(origin, dir)


func _spawn_slowing_arrow(origin: Vector2, direction: Vector2) -> void:
	var arrow := _SlowArrow.new()
	arrow.position = origin
	arrow.direction = direction
	arrow.damage = BASE_DMG[rank] + owner_champion.attack_damage * 1.0
	arrow.slow = SLOW_AMOUNT[rank]
	arrow.slow_dur = SLOW_DURATION
	arrow.source = owner_champion
	arrow.max_range = range
	owner_champion.get_parent().add_child(arrow)


class _SlowArrow extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: float = 40.0
	var slow: float = 0.20
	var slow_dur: float = 2.0
	var source: Node = null
	var speed: float = 1500.0
	var max_range: float = 1200.0
	var _traveled: float = 0.0
	var _hit: Array = []

	func _process(delta: float) -> void:
		var move := direction * speed * delta
		position += move
		_traveled += move.length()
		if _traveled >= max_range:
			queue_free()
			return
		for unit in get_tree().get_nodes_in_group("all_units"):
			if unit in _hit:
				continue
			if not CombatSystem.is_enemy(source, unit):
				continue
			if global_position.distance_to(unit.global_position) < 30.0:
				_hit.append(unit)
				CombatSystem.deal_damage(source, unit, damage, CombatSystem.DamageType.PHYSICAL, false)
				StatusEffect.make_slow(unit, slow_dur, slow)
