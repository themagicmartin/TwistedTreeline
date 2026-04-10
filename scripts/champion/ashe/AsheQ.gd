extends AbilitySystem
# Ashe Q — Ranger's Focus
# Passive: stacks Focus on basic attacks. At 4 stacks, next basic attack
# fires a cone of 4 arrows, each dealing 100% AD physical damage.
# Active: immediately fire the volley if stacks are available.

const MAX_STACKS := 4
const CONE_ARROWS := 4
const CONE_ANGLE_DEG := 40.0

var focus_stacks: int = 0

func _ready() -> void:
	ability_name   = "Ranger's Focus"
	cast_type      = CastType.INSTANT
	cooldown_base  = 0.0  # no cooldown, passive-based
	mana_cost_base = 50.0
	max_rank       = 5
	super()._ready()
	if owner_champion:
		owner_champion.on_basic_attack_hit.connect(_on_basic_attack)


func _on_basic_attack(_target: Node, _dmg: float) -> void:
	focus_stacks = mini(focus_stacks + 1, MAX_STACKS)


func cast(target = null) -> void:
	if focus_stacks < MAX_STACKS:
		return
	focus_stacks = 0
	# Fire cone of arrows toward cursor/target
	var origin := owner_champion.global_position
	var direction: Vector2
	if target is Vector2:
		direction = origin.direction_to(target)
	elif target is Node:
		direction = origin.direction_to(target.global_position)
	else:
		return
	_fire_cone(origin, direction)


func _fire_cone(origin: Vector2, direction: Vector2) -> void:
	var angle_step := CONE_ANGLE_DEG / (CONE_ARROWS - 1)
	var start_angle := -CONE_ANGLE_DEG / 2.0
	for i in range(CONE_ARROWS):
		var angle := deg_to_rad(start_angle + angle_step * i)
		var dir := direction.rotated(angle)
		_spawn_arrow(origin, dir)


func _spawn_arrow(origin: Vector2, direction: Vector2) -> void:
	var arrow := _Arrow.new()
	arrow.position = origin
	arrow.direction = direction
	arrow.damage = owner_champion.attack_damage
	arrow.source = owner_champion
	arrow.speed = 1200.0
	arrow.max_range = 600.0
	owner_champion.get_parent().add_child(arrow)


class _Arrow extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: float = 60.0
	var source: Node = null
	var speed: float = 1200.0
	var max_range: float = 600.0
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
