extends Node2D
# TowerProjectile — a visual bolt fired by a tower or a ranged minion.
# Damage is intentionally NOT applied until the projectile arrives at the target,
# matching League of Legends behaviour.

class_name TowerProjectile

var _speed: float = 700.0

var _target: Node = null
var _target_pos: Vector2 = Vector2.ZERO

# Combat payload (applied on arrival)
var _source: Node = null
var _damage: float = 0.0
var _damage_type: int = CombatSystem.DamageType.PHYSICAL


# Call immediately after add_child().
# color / dot_size / speed let towers and minions look different.
func setup(
		from_pos: Vector2,
		target: Node,
		source: Node,
		damage: float,
		dtype: int,
		speed: float = 700.0,
		color: Color = Color(1.0, 0.9, 0.15),
		dot_size: float = 10.0
) -> void:
	global_position = from_pos
	_target     = target
	_source     = source
	_damage     = damage
	_damage_type = dtype
	_speed      = speed

	if is_instance_valid(target):
		_target_pos = target.global_position

	# Build the visual (ColorRect so no texture asset required)
	var dot := ColorRect.new()
	dot.size     = Vector2(dot_size, dot_size)
	dot.position = Vector2(-dot_size * 0.5, -dot_size * 0.5)
	dot.color    = color
	add_child(dot)


func _process(delta: float) -> void:
	# Track a moving target
	if _target and is_instance_valid(_target):
		_target_pos = _target.global_position

	var dist := global_position.distance_to(_target_pos)
	var step := _speed * delta

	if dist <= step:
		_on_arrive()
		return

	global_position += global_position.direction_to(_target_pos) * step


func _on_arrive() -> void:
	# Deal damage only if the target is still alive
	if _source and is_instance_valid(_source) \
	and _target and is_instance_valid(_target):
		var already_dead: bool = "is_dead" in _target and _target.is_dead
		if not already_dead:
			CombatSystem.deal_damage(_source, _target, _damage, _damage_type)
	queue_free()
