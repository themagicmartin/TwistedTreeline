extends CharacterBody2D
# Minion — marches down a lane, attacks towers then enemies, pushes to Nexus.
# State machine: MARCH → ATTACK_BUILDING → ATTACK_ENEMY → MARCH

class_name Minion

enum State { MARCH, ATTACK_BUILDING, ATTACK_ENEMY }

@export var team: int = GameManager.Team.BLUE
@export var lane: String = "top"
@export var minion_type: String = "melee"  # melee, caster, cannon, super

var is_minion: bool = true   # used by tower priority check

const STATS := {
	"melee":  {"hp": 475.0, "ad": 21.0, "as": 1.0,  "range": 110.0, "speed": 325.0, "gold": 21.0, "xp": 58.0},
	"caster": {"hp": 280.0, "ad": 24.0, "as": 0.67, "range": 600.0, "speed": 325.0, "gold": 14.0, "xp": 40.0},
	"cannon": {"hp": 840.0, "ad": 40.0, "as": 0.67, "range": 600.0, "speed": 325.0, "gold": 45.0, "xp": 92.0},
	"super":  {"hp": 1500.0, "ad": 190.0, "as": 0.83, "range": 175.0, "speed": 300.0, "gold": 40.0, "xp": 97.0},
}

var max_hp: float = 475.0
var current_hp: float = 475.0
var attack_damage: float = 21.0
var attack_speed: float = 1.0
var attack_range: float = 110.0
var move_speed: float = 325.0
var gold_value: float = 21.0
var xp_value: float = 58.0
var armor: float = 0.0
var magic_resist: float = 0.0

var is_dead: bool = false
var _state: State = State.MARCH
var _attack_target: Node = null
var _attack_cooldown: float = 0.0

# Vilemaw buff bonuses
var has_vilemaw_buff: bool = false

# Waypoints defining the lane path (set by WaveManager)
var waypoints: Array = []
var _waypoint_index: int = 0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("all_units")
	add_to_group("minions")
	add_to_group("minions_team_" + str(team))
	if team == GameManager.Team.BLUE:
		add_to_group("enemy_units_" + str(GameManager.Team.RED))
	else:
		add_to_group("enemy_units_" + str(GameManager.Team.BLUE))

	var stats: Dictionary = STATS.get(minion_type, STATS["melee"])
	max_hp       = stats["hp"]
	current_hp   = max_hp
	attack_damage = stats["ad"]
	attack_speed  = stats["as"]
	attack_range  = stats["range"]
	move_speed    = stats["speed"]
	gold_value    = stats["gold"]
	xp_value      = stats["xp"]

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown -= delta
	_update_state()
	_act(delta)


func _update_state() -> void:
	# Check for nearby enemies first
	var enemy := _find_nearest_enemy(attack_range)
	if enemy:
		_attack_target = enemy
		_state = State.ATTACK_ENEMY
		return

	# Check for enemy building in range
	var building := _find_nearest_enemy_building(attack_range)
	if building:
		_attack_target = building
		_state = State.ATTACK_BUILDING
		return

	_attack_target = null
	_state = State.MARCH


func _act(delta: float) -> void:
	match _state:
		State.MARCH:
			_march(delta)
		State.ATTACK_BUILDING, State.ATTACK_ENEMY:
			velocity = Vector2.ZERO
			if _attack_cooldown <= 0.0 and _attack_target and is_instance_valid(_attack_target):
				_attack()


func _march(_delta: float) -> void:
	if waypoints.is_empty():
		velocity = Vector2.ZERO
		return
	var target_wp: Vector2 = waypoints[mini(_waypoint_index, waypoints.size() - 1)]
	nav_agent.target_position = target_wp
	if global_position.distance_to(target_wp) < 20.0:
		_waypoint_index = mini(_waypoint_index + 1, waypoints.size() - 1)

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next := nav_agent.get_next_path_position()
		velocity = global_position.direction_to(next) * move_speed

	move_and_slide()


func _attack() -> void:
	_attack_cooldown = 1.0 / attack_speed
	CombatSystem.deal_damage(self, _attack_target, attack_damage, CombatSystem.DamageType.PHYSICAL)


func _find_nearest_enemy(search_range: float) -> Node:
	var best: Node = null
	var best_dist := search_range
	for unit in get_tree().get_nodes_in_group("all_units"):
		if not is_instance_valid(unit):
			continue
		if not "team" in unit:
			continue
		if unit.team == team or unit.team == GameManager.Team.NONE:
			continue
		if "is_dead" in unit and unit.is_dead:
			continue
		var d := global_position.distance_to(unit.global_position)
		if d < best_dist:
			best_dist = d
			best = unit
	return best


func _find_nearest_enemy_building(search_range: float) -> Node:
	var best: Node = null
	var best_dist := search_range
	for building in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(building):
			continue
		if building.team == team:
			continue
		var d := global_position.distance_to(building.global_position)
		if d < best_dist:
			best_dist = d
			best = building
	return best


func take_damage(amount: float, source: Node, _dtype: int) -> void:
	if is_dead:
		return
	current_hp -= amount
	if current_hp <= 0.0:
		_die(source)


func _die(killer: Node) -> void:
	is_dead = true
	# Award gold to killer (nearby champions)
	if killer and "player_id" in killer:
		EconomyManager.add_gold(killer.player_id, gold_value)
		EconomyManager.add_xp(killer.player_id, xp_value)
	# Award XP to nearby allied champions
	var killer_team: int = killer.team if (killer and "team" in killer) else 0
	for champ in get_tree().get_nodes_in_group("champions_team_" + str(killer_team)):
		if champ == killer:
			continue
		if champ.global_position.distance_to(global_position) < 1200.0:
			EconomyManager.add_xp(champ.player_id, xp_value * 0.5)

	queue_free()


func apply_vilemaw_buff() -> void:
	has_vilemaw_buff = true
	match minion_type:
		"melee", "super":
			armor += 20.0
			magic_resist += 20.0
			attack_speed += attack_speed * 0.20
			attack_damage += 15.0
			attack_range += 75.0
		"caster", "cannon":
			armor += 10.0
			magic_resist += 10.0
			attack_speed += attack_speed * 0.10
			attack_damage += 20.0
			attack_range += 100.0
