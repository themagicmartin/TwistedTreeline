extends AbilitySystem
# Ashe E — Hawkshot
# Fires a hawk toward target location that reveals terrain along its path and at destination.

const HAWK_SPEED := 1600.0
const REVEAL_RADIUS := 500.0
const REVEAL_DURATION := 5.0

func _ready() -> void:
	ability_name   = "Hawkshot"
	cast_type      = CastType.POINT_CLICK
	cooldown_base  = 20.0
	mana_cost_base = 0.0
	max_rank       = 5
	range          = 3500.0
	super()._ready()


func get_cooldown() -> float:
	return [20.0, 18.0, 16.0, 14.0, 12.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	var origin := owner_champion.global_position
	var dest: Vector2
	if target is Vector2:
		dest = target
	else:
		return

	var hawk := _Hawk.new()
	hawk.position = origin
	hawk.destination = dest
	hawk.reveal_radius = REVEAL_RADIUS
	hawk.reveal_duration = REVEAL_DURATION
	hawk.source_team = owner_champion.team
	owner_champion.get_parent().add_child(hawk)


class _Hawk extends Node2D:
	var destination: Vector2 = Vector2.ZERO
	var reveal_radius: float = 500.0
	var reveal_duration: float = 5.0
	var source_team: int = 1
	var speed: float = 1600.0

	func _process(delta: float) -> void:
		var dir := global_position.direction_to(destination)
		var dist := global_position.distance_to(destination)
		if dist < speed * delta:
			global_position = destination
			_reveal_area()
			queue_free()
			return
		global_position += dir * speed * delta

	func _reveal_area() -> void:
		# Place a vision ward at destination for reveal_duration
		var ward := _VisionWard.new()
		ward.position = destination
		ward.radius = reveal_radius
		ward.duration = reveal_duration
		ward.team = source_team
		get_parent().add_child(ward)
		queue_free()

	class _VisionWard extends Node2D:
		var radius: float = 500.0
		var duration: float = 5.0
		var team: int = 1
		var _elapsed: float = 0.0

		func _ready() -> void:
			add_to_group("vision_sources_team_" + str(team))

		func _process(delta: float) -> void:
			_elapsed += delta
			if _elapsed >= duration:
				remove_from_group("vision_sources_team_" + str(team))
				queue_free()
