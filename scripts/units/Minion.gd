extends CharacterBody2D
# Minion — marches down a lane, fights enemy minions, then attacks towers/nexus.
# State machine: MARCH → APPROACH_BUILDING → ATTACK_BUILDING
#                      ↘ ATTACK_ENEMY ↗

class_name Minion

enum State { MARCH, APPROACH_BUILDING, ATTACK_BUILDING, ATTACK_ENEMY }

@export var team: int = GameManager.Team.BLUE
@export var lane: String = "top"
@export var minion_type: String = "melee"  # melee, caster, cannon, super

var is_minion: bool = true   # used by tower priority check

const STATS := {
	"melee":  {"hp": 475.0,  "ad": 21.0,  "as": 1.0,  "range": 110.0, "speed": 325.0, "gold": 21.0, "xp": 58.0},
	"caster": {"hp": 280.0,  "ad": 24.0,  "as": 0.67, "range": 300.0, "speed": 325.0, "gold": 14.0, "xp": 40.0},
	"cannon": {"hp": 840.0,  "ad": 40.0,  "as": 0.67, "range": 300.0, "speed": 325.0, "gold": 45.0, "xp": 92.0},
	"super":  {"hp": 1500.0, "ad": 190.0, "as": 0.83, "range": 175.0, "speed": 300.0, "gold": 40.0, "xp": 97.0},
}

# How far away a minion will detect and lock onto an enemy building.
# Large enough to intercept towers they march toward.
const BUILDING_DETECT_RANGE := 700.0

var max_hp:       float = 475.0
var current_hp:   float = 475.0
var attack_damage: float = 21.0
var attack_speed:  float = 1.0
var attack_range:  float = 110.0
var move_speed:    float = 325.0
var gold_value:    float = 21.0
var xp_value:      float = 58.0
var armor:         float = 0.0
var magic_resist:  float = 0.0

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
	max_hp        = stats["hp"]
	current_hp    = max_hp
	attack_damage = stats["ad"]
	attack_speed  = stats["as"]
	attack_range  = stats["range"]
	move_speed    = stats["speed"]
	gold_value    = stats["gold"]
	xp_value      = stats["xp"]

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

	# Color-code by team
	var sprite := get_node_or_null("Sprite2D")
	if sprite:
		sprite.color = Color(0.2, 0.4, 0.9) if team == GameManager.Team.BLUE else Color(0.9, 0.2, 0.2)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown -= delta
	_update_state()
	_act(delta)
	move_and_slide()


func _update_state() -> void:
	# Invalidate stale target
	if _attack_target != null:
		if not is_instance_valid(_attack_target):
			_attack_target = null
		elif "is_dead" in _attack_target and _attack_target.is_dead:
			_attack_target = null

	# --- Priority 1: enemy unit (minion/champion) within attack range → fight ---
	var enemy := _find_nearest_enemy_unit(attack_range)
	if enemy:
		_attack_target = enemy
		_state = State.ATTACK_ENEMY
		return

	# --- Priority 2: enemy building within detection range → approach & attack ---
	var building := _find_nearest_enemy_building(BUILDING_DETECT_RANGE)
	if building:
		_attack_target = building
		var dist := global_position.distance_to(building.global_position)
		if dist <= attack_range:
			_state = State.ATTACK_BUILDING
		else:
			_state = State.APPROACH_BUILDING
		return

	# --- Default: march along waypoints ---
	_attack_target = null
	_state = State.MARCH


func _act(delta: float) -> void:
	match _state:
		State.MARCH:
			_march(delta)
		State.APPROACH_BUILDING:
			# Walk straight toward the building; stop when in attack range
			_move_toward(_attack_target.global_position)
		State.ATTACK_BUILDING, State.ATTACK_ENEMY:
			velocity = Vector2.ZERO
			if _attack_cooldown <= 0.0 and _attack_target and is_instance_valid(_attack_target):
				_attack()


func _march(_delta: float) -> void:
	if waypoints.is_empty():
		velocity = Vector2.ZERO
		return

	var target_wp: Vector2 = waypoints[mini(_waypoint_index, waypoints.size() - 1)]

	# Advance waypoint when close enough
	if global_position.distance_to(target_wp) < 20.0 and _waypoint_index < waypoints.size() - 1:
		_waypoint_index += 1
		target_wp = waypoints[_waypoint_index]

	# Direct movement — the map is one open rectangle so we don't need nav-mesh
	# pathfinding; this also avoids NavigationAgent2D one-frame startup delays
	# that caused minions to freeze on spawn.
	if global_position.distance_to(target_wp) < 4.0:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target_wp) * move_speed


func _move_toward(target_pos: Vector2) -> void:
	var dist := global_position.distance_to(target_pos)
	if dist <= attack_range:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target_pos) * move_speed


func _attack() -> void:
	_attack_cooldown = 1.0 / attack_speed
	if not (_attack_target and is_instance_valid(_attack_target)):
		return
	if attack_range > 150.0:
		# Ranged (caster / cannon) — fire a projectile; damage on arrival
		_fire_projectile()
	else:
		# Melee — instant damage
		CombatSystem.deal_damage(self, _attack_target, attack_damage, CombatSystem.DamageType.PHYSICAL)


func _fire_projectile() -> void:
	var proj := TowerProjectile.new()
	get_parent().add_child(proj)
	proj.setup(
		global_position, _attack_target, self, attack_damage,
		CombatSystem.DamageType.PHYSICAL,
		500.0,                        # speed — slower than tower shots
		Color(0.3, 0.9, 1.0),         # cyan bolt for caster minions
		7.0                           # slightly smaller dot
	)


# Search only for living units (minions/champions) — NOT buildings.
func _find_nearest_enemy_unit(search_range: float) -> Node:
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
		# Skip towers/nexus — those are handled by building search
		if unit.is_in_group("towers"):
			continue
		if unit.is_in_group("nexus_team_1") or unit.is_in_group("nexus_team_2"):
			continue
		var d := global_position.distance_to(unit.global_position)
		if d < best_dist:
			best_dist = d
			best = unit
	return best


# Search for the nearest enemy tower (buildings only).
func _find_nearest_enemy_building(search_range: float) -> Node:
	var best: Node = null
	var best_dist := search_range
	for building in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(building):
			continue
		if not "team" in building:
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
	# Update health bar if present
	var hbar := get_node_or_null("HealthBar")
	if hbar:
		hbar.value = (current_hp / max_hp) * 100.0
	if current_hp <= 0.0:
		_die(source)


func _die(killer: Node) -> void:
	is_dead = true
	# Award gold to killer (if champion)
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
			armor        += 20.0
			magic_resist += 20.0
			attack_speed += attack_speed * 0.20
			attack_damage += 15.0
			attack_range  += 75.0
		"caster", "cannon":
			armor        += 10.0
			magic_resist += 10.0
			attack_speed += attack_speed * 0.10
			attack_damage += 20.0
			attack_range  += 100.0
