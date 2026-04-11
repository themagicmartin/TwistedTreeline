extends Node2D
# TowerProjectile — visual-only shot fired by a tower.
# Damage is applied instantly in Tower._fire(); this node just shows the bullet
# travelling to its target so players can see what the tower is shooting at.

class_name TowerProjectile

const SPEED := 700.0  # pixels per second

var _target: Node = null
var _target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Build a small glowing square as the bullet visual
	var dot := ColorRect.new()
	dot.size = Vector2(10, 10)
	dot.position = Vector2(-5, -5)
	dot.color = Color(1.0, 0.9, 0.15, 1.0)  # bright yellow bolt
	add_child(dot)


func setup(from_pos: Vector2, target: Node) -> void:
	global_position = from_pos
	_target = target
	if is_instance_valid(target):
		_target_pos = target.global_position


func _process(delta: float) -> void:
	# Track moving targets (champion or minion)
	if _target and is_instance_valid(_target):
		_target_pos = _target.global_position

	var dist := global_position.distance_to(_target_pos)
	var step := SPEED * delta
	if dist <= step:
		queue_free()
		return
	global_position += global_position.direction_to(_target_pos) * step
