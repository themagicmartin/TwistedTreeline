extends CharacterBody2D
# JungleMonster — base class for Golems and Wraiths.
# Idle at spawn point, aggro on nearby champions, leash back if too far.

class_name JungleMonster

@export var monster_type: String = "golem"  # golem, lesser_golem, wraith, lesser_wraith
@export var team: int = GameManager.Team.NONE

const STATS := {
	"golem":         {"hp": 1200.0, "ad": 60.0, "as": 0.67, "range": 150.0, "xp": 120.0, "gold": 50.0},
	"lesser_golem":  {"hp": 600.0,  "ad": 30.0, "as": 0.85, "range": 120.0, "xp": 50.0,  "gold": 20.0},
	"wraith":        {"hp": 700.0,  "ad": 45.0, "as": 0.75, "range": 500.0, "xp": 80.0,  "gold": 35.0},
	"lesser_wraith": {"hp": 250.0,  "ad": 15.0, "as": 1.0,  "range": 500.0, "xp": 25.0,  "gold": 8.0},
}

const AGGRO_RANGE := 400.0
const LEASH_RANGE := 800.0

var max_hp: float = 1200.0
var current_hp: float = 1200.0
var attack_damage: float = 60.0
var attack_speed: float = 0.67
var attack_range: float = 150.0
var move_speed: float = 300.0
var gold_value: float = 50.0
var xp_value: float = 120.0
var armor: float = 15.0
var magic_resist: float = 0.0

var is_dead: bool = false
var camp: Node = null
var spawn_position: Vector2 = Vector2.ZERO
var _attack_target: Node = null
var _attack_cooldown: float = 0.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("all_units")
	add_to_group("jungle_monsters")
	spawn_position = global_position

	var stats := STATS.get(monster_type, STATS["golem"])
	max_hp       = stats["hp"]
	current_hp   = max_hp
	attack_damage = stats["ad"]
	attack_speed  = stats["as"]
	attack_range  = stats["range"]
	gold_value    = stats["gold"]
	xp_value      = stats["xp"]

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown -= delta

	# Leash: if too far from spawn, return
	if global_position.distance_to(spawn_position) > LEASH_RANGE:
		_attack_target = null
		_return_to_spawn(delta)
		return

	# Aggro
	if _attack_target == null or not is_instance_valid(_attack_target) or ("is_dead" in _attack_target and _attack_target.is_dead):
		_attack_target = _find_nearest_champion(AGGRO_RANGE)

	if _attack_target and is_instance_valid(_attack_target):
		var dist := global_position.distance_to(_attack_target.global_position)
		if dist > attack_range:
			# Chase target
			nav_agent.target_position = _attack_target.global_position
			if not nav_agent.is_navigation_finished():
				var next := nav_agent.get_next_path_position()
				velocity = global_position.direction_to(next) * move_speed
		else:
			velocity = Vector2.ZERO
			if _attack_cooldown <= 0.0:
				_attack()
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _return_to_spawn(delta: float) -> void:
	nav_agent.target_position = spawn_position
	if not nav_agent.is_navigation_finished():
		var next := nav_agent.get_next_path_position()
		velocity = global_position.direction_to(next) * move_speed
	else:
		velocity = Vector2.ZERO
		# Regenerate HP when leashed
		current_hp = minf(current_hp + max_hp * 0.10 * delta, max_hp)
	move_and_slide()


func _find_nearest_champion(range: float) -> Node:
	var best: Node = null
	var best_dist := range
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if not is_instance_valid(champ):
			continue
		if "is_dead" in champ and champ.is_dead:
			continue
		var d := global_position.distance_to(champ.global_position)
		if d < best_dist:
			best_dist = d
			best = champ
	return best


func _attack() -> void:
	if not is_instance_valid(_attack_target):
		return
	_attack_cooldown = 1.0 / attack_speed
	CombatSystem.deal_damage(self, _attack_target, attack_damage, CombatSystem.DamageType.PHYSICAL)


func take_damage(amount: float, source: Node, _dtype: int) -> void:
	if is_dead:
		return
	current_hp -= amount
	if _attack_target == null:
		_attack_target = source
	if current_hp <= 0.0:
		_die(source)


func _die(killer: Node) -> void:
	is_dead = true
	if killer and "player_id" in killer:
		EconomyManager.add_gold(killer.player_id, gold_value)
		EconomyManager.add_xp(killer.player_id, xp_value)
	if camp and camp.has_method("notify_monster_died"):
		camp.notify_monster_died(self)
	queue_free()
