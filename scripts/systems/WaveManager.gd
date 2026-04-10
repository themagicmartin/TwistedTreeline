extends Node
# WaveManager — spawns minion waves for both teams in both lanes.
# Called by GameManager via group "wave_manager".

class_name WaveManager

@export var minion_scene: PackedScene = null

# Lane waypoints: each Array is a list of Vector2 positions for minions to follow.
# These are set up to match the TwistedTreeline map layout.
# Blue team marches right; Red team marches left.
@export var blue_top_waypoints: Array = []
@export var blue_bot_waypoints: Array = []
@export var red_top_waypoints: Array = []
@export var red_bot_waypoints: Array = []

# Super minion state per lane per team
var _super_minion_lanes: Dictionary = {
	GameManager.Team.BLUE: {"top": false, "bot": false},
	GameManager.Team.RED:  {"top": false, "bot": false},
}


func _ready() -> void:
	add_to_group("wave_manager")


func spawn_wave(wave_number: int, is_cannon: bool) -> void:
	if minion_scene == null:
		push_error("WaveManager: minion_scene not set!")
		return
	for lane in ["top", "bot"]:
		_spawn_lane_wave(GameManager.Team.BLUE, lane, wave_number, is_cannon)
		_spawn_lane_wave(GameManager.Team.RED,  lane, wave_number, is_cannon)


func _spawn_lane_wave(team: int, lane: String, _wave_number: int, is_cannon: bool) -> void:
	var waypoints: Array = _get_waypoints(team, lane)
	if waypoints.is_empty():
		return

	var spawn_pos: Vector2 = waypoints[0]
	var super_active: bool = _super_minion_lanes.get(team, {}).get(lane, false)

	if super_active:
		_spawn_minion(team, lane, "super", spawn_pos, waypoints)
		_spawn_minion(team, lane, "melee", spawn_pos + Vector2(30, 0), waypoints)
	else:
		# Standard wave: 3 melee + 3 caster (+ cannon every 3rd wave)
		for i in range(3):
			_spawn_minion(team, lane, "melee", spawn_pos + Vector2(i * 40, 0), waypoints)
		for i in range(3):
			_spawn_minion(team, lane, "caster", spawn_pos + Vector2(i * 40, 50), waypoints)
		if is_cannon:
			_spawn_minion(team, lane, "cannon", spawn_pos + Vector2(-40, 25), waypoints)


func _spawn_minion(team: int, lane: String, type: String, pos: Vector2, waypoints: Array) -> void:
	var minion := minion_scene.instantiate() as Minion
	if minion == null:
		return
	minion.team = team
	minion.lane = lane
	minion.minion_type = type
	minion.waypoints = waypoints.duplicate()
	minion.global_position = pos
	get_parent().add_child(minion)


func _get_waypoints(team: int, lane: String) -> Array:
	match [team, lane]:
		[GameManager.Team.BLUE, "top"]: return blue_top_waypoints
		[GameManager.Team.BLUE, "bot"]: return blue_bot_waypoints
		[GameManager.Team.RED,  "top"]: return red_top_waypoints
		[GameManager.Team.RED,  "bot"]: return red_bot_waypoints
	return []


func enable_super_minions(team: int, lane: String) -> void:
	_super_minion_lanes[team][lane] = true


func disable_super_minions(team: int, lane: String) -> void:
	_super_minion_lanes[team][lane] = false
