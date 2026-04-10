extends Node
class_name StatusEffect
# StatusEffect — attach to a unit to apply a timed CC or buff.
# Instantiate, configure, then add as child of the target unit.

enum Type {
	SLOW,
	SILENCE,
	STUN,
	KNOCKUP,
	KNOCKBACK,
	SPEED_BOOST,
	SHIELD,
	GHOSTED,        # ignore unit collision
	VILEMAW_BUFF,
}

@export var effect_type: Type = Type.SLOW
@export var duration: float = 1.0
@export var magnitude: float = 0.3   # e.g. 0.3 = 30% slow
@export var knockback_direction: Vector2 = Vector2.ZERO

var _elapsed: float = 0.0
var _target: Node = null  # set by owner on _ready


signal expired(effect: Node)


func _ready() -> void:
	_target = get_parent()
	if _target.has_method("on_status_effect_applied"):
		_target.on_status_effect_applied(self)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		_remove()


func _remove() -> void:
	if _target and _target.has_method("on_status_effect_removed"):
		_target.on_status_effect_removed(self)
	expired.emit(self)
	queue_free()


func is_type(t: Type) -> bool:
	return effect_type == t


# --- Static helpers to create common effects ---

static func make_slow(target: Node, dur: float, amount: float) -> "StatusEffect":
	return _make(target, Type.SLOW, dur, amount)

static func make_silence(target: Node, dur: float) -> "StatusEffect":
	return _make(target, Type.SILENCE, dur, 0.0)

static func make_stun(target: Node, dur: float) -> "StatusEffect":
	return _make(target, Type.STUN, dur, 0.0)

static func make_knockup(target: Node, dur: float) -> "StatusEffect":
	return _make(target, Type.KNOCKUP, dur, 0.0)

static func make_knockback(target: Node, dur: float, direction: Vector2, force: float) -> "StatusEffect":
	var fx := _make(target, Type.KNOCKBACK, dur, force)
	fx.knockback_direction = direction
	return fx

static func make_ghosted(target: Node, dur: float) -> "StatusEffect":
	return _make(target, Type.GHOSTED, dur, 0.0)

static func make_speed_boost(target: Node, dur: float, amount: float) -> "StatusEffect":
	return _make(target, Type.SPEED_BOOST, dur, amount)

static func make_vilemaw_buff(target: Node) -> "StatusEffect":
	return _make(target, Type.VILEMAW_BUFF, 180.0, 0.0)

static func _make(target: Node, t: Type, dur: float, mag: float) -> "StatusEffect":
	var fx := load("res://scripts/systems/StatusEffect.gd").new()
	fx.effect_type = t
	fx.duration = dur
	fx.magnitude = mag
	target.add_child(fx)
	return fx
