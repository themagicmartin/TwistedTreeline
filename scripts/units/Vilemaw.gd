extends CharacterBody2D
# Vilemaw — epic boss monster. 8000 HP.
# Spawns at 10:00, respawns after 6 minutes.
# On kill: grants Crest of Crushing Wrath to killing team.

class_name Vilemaw

const MAX_HP := 8000.0
const ATTACK_DAMAGE := 200.0
const ATTACK_SPEED := 0.5
const ATTACK_RANGE := 200.0
const MOVE_SPEED := 280.0
const AGGRO_RANGE := 700.0
const LEASH_RANGE := 1000.0
const ARMOR := 40.0
const MAGIC_RESIST := 40.0

var team: int = GameManager.Team.NONE
var current_hp: float = MAX_HP
var max_hp: float = MAX_HP
var armor: float = ARMOR
var magic_resist: float = MAGIC_RESIST
var gold_value: float = 0.0
var xp_value: float = 0.0
var is_dead: bool = false

var _attack_target: Node = null
var _attack_cooldown: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO

# Track which team dealt the most damage (for buff award)
var _damage_dealt: Dictionary = {GameManager.Team.BLUE: 0.0, GameManager.Team.RED: 0.0}

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("all_units")
	add_to_group("vilemaw")
	_spawn_position = global_position
	visible = false  # starts hidden until activated at 10:00


func activate() -> void:
	visible = true
	current_hp = MAX_HP
	is_dead = false
	_damage_dealt = {GameManager.Team.BLUE: 0.0, GameManager.Team.RED: 0.0}
	global_position = _spawn_position


func _physics_process(delta: float) -> void:
	if not visible or is_dead:
		return
	_attack_cooldown -= delta

	if global_position.distance_to(_spawn_position) > LEASH_RANGE:
		_attack_target = null
		_return_to_spawn(delta)
		return

	if _attack_target == null or not is_instance_valid(_attack_target):
		if _attack_target != null and _attack_target.has_variable("is_dead") and _attack_target.is_dead:
			_attack_target = null
		_attack_target = _find_nearest_champion(AGGRO_RANGE)

	if _attack_target:
		var dist := global_position.distance_to(_attack_target.global_position)
		if dist > ATTACK_RANGE:
			nav_agent.target_position = _attack_target.global_position
			if not nav_agent.is_navigation_finished():
				velocity = global_position.direction_to(nav_agent.get_next_path_position()) * MOVE_SPEED
		else:
			velocity = Vector2.ZERO
			if _attack_cooldown <= 0.0:
				_attack()
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _return_to_spawn(delta: float) -> void:
	nav_agent.target_position = _spawn_position
	if not nav_agent.is_navigation_finished():
		velocity = global_position.direction_to(nav_agent.get_next_path_position()) * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
		current_hp = minf(current_hp + max_hp * 0.05 * delta, max_hp)
	move_and_slide()


func _find_nearest_champion(range: float) -> Node:
	var best: Node = null
	var best_dist := range
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if not is_instance_valid(champ) or champ.is_dead:
			continue
		var d := global_position.distance_to(champ.global_position)
		if d < best_dist:
			best_dist = d
			best = champ
	return best


func _attack() -> void:
	if not is_instance_valid(_attack_target):
		return
	_attack_cooldown = 1.0 / ATTACK_SPEED
	CombatSystem.deal_damage(self, _attack_target, ATTACK_DAMAGE, CombatSystem.DamageType.PHYSICAL)


func take_damage(amount: float, source: Node, _dtype: int) -> void:
	if is_dead:
		return
	current_hp -= amount
	# Track damage per team
	if source and source.has_variable("team") and source.team in _damage_dealt:
		_damage_dealt[source.team] += amount
	if current_hp <= 0.0:
		_die(source)


func _die(source: Node) -> void:
	is_dead = true
	visible = false

	# Award buff to the team that dealt the killing blow
	var killing_team := source.team if source and source.has_variable("team") else GameManager.Team.NONE
	if killing_team != GameManager.Team.NONE:
		GameManager.notify_vilemaw_killed(killing_team)
