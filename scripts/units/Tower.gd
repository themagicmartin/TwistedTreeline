extends StaticBody2D
# Tower — turret that attacks nearest enemy champion first, then minions.
# Deals true damage on the first shot against a champion (turret aggro).
# Damage is applied when the projectile arrives, not instantly.

class_name Tower

signal destroyed(tower: Tower)

@export var team: int = GameManager.Team.BLUE
@export var tower_type: String = "outer"  # outer, inner, inhibitor, nexus
@export var lane: String = "top"

const TOWER_STATS := {
	"outer":     {"hp": 1800.0, "dmg": 175.0, "range": 375.0, "as": 1.0},
	"inner":     {"hp": 2000.0, "dmg": 200.0, "range": 375.0, "as": 1.0},
	"inhibitor": {"hp": 2250.0, "dmg": 230.0, "range": 375.0, "as": 1.0},
	"nexus":     {"hp": 2500.0, "dmg": 250.0, "range": 375.0, "as": 0.83},
}

var max_hp:       float = 1800.0
var current_hp:   float = 1800.0
var attack_damage: float = 175.0
var attack_range:  float = 375.0
var attack_speed:  float = 1.0
var armor:         float = 100.0
var magic_resist:  float = 100.0

var _attack_target: Node = null
var _attack_cooldown: float = 0.0
var _first_shot_on_champion: bool = true

var gold_value: float = 150.0
var xp_value:   float = 0.0


func _ready() -> void:
	add_to_group("all_units")
	add_to_group("towers")
	add_to_group("tower_team_" + str(team))
	if team == GameManager.Team.BLUE:
		add_to_group("enemy_units_" + str(GameManager.Team.RED))
	else:
		add_to_group("enemy_units_" + str(GameManager.Team.BLUE))

	var stats: Dictionary = TOWER_STATS.get(tower_type, TOWER_STATS["outer"])
	max_hp        = stats["hp"]
	current_hp    = max_hp
	attack_damage = stats["dmg"]
	attack_range  = stats["range"]
	attack_speed  = stats["as"]

	_add_range_indicator()


func _add_range_indicator() -> void:
	var ri := RangeIndicator.new()
	ri.radius     = attack_range
	# Blue towers: blue-tinted ring; red towers: red-tinted ring
	ri.ring_color = Color(0.3, 0.5, 1.0, 0.4) if team == GameManager.Team.BLUE \
				 else Color(1.0, 0.3, 0.3, 0.4)
	add_child(ri)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return
	_attack_cooldown -= delta
	_find_target()
	if _attack_target and _attack_cooldown <= 0.0:
		_fire()


func _find_target() -> void:
	# Retain the current target if still alive and in range
	if _attack_target and is_instance_valid(_attack_target):
		var target_dead: bool = "is_dead" in _attack_target and _attack_target.is_dead
		if not target_dead:
			if global_position.distance_to(_attack_target.global_position) <= attack_range + 50.0:
				return

	var prev_target := _attack_target
	_attack_target = null
	var best_priority := -1
	var best_dist    := attack_range

	for unit in get_tree().get_nodes_in_group("all_units"):
		if not is_instance_valid(unit):
			continue
		if not "team" in unit:
			continue
		if unit.team == team or unit.team == GameManager.Team.NONE:
			continue
		if "is_dead" in unit and unit.is_dead:
			continue
		# Towers and nexus don't shoot each other
		if unit.is_in_group("towers"):
			continue
		if unit.is_in_group("nexus_team_1") or unit.is_in_group("nexus_team_2"):
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist > attack_range:
			continue
		var priority := _get_target_priority(unit)
		if priority > best_priority or (priority == best_priority and dist < best_dist):
			best_priority = priority
			best_dist     = dist
			_attack_target = unit

	# Reset first-shot flag when switching to a new champion
	if _attack_target != prev_target:
		if _attack_target != null and _attack_target.has_method("_setup_abilities"):
			_first_shot_on_champion = true


func _get_target_priority(unit: Node) -> int:
	if unit.has_method("_setup_abilities"):  # champion
		return 2
	if "is_minion" in unit:
		return 1
	return 0


func _fire() -> void:
	if not is_instance_valid(_attack_target):
		_attack_target = null
		return
	_attack_cooldown = 1.0 / attack_speed

	# Determine damage type; first shot on a champion is true damage
	var is_champ: bool = _attack_target.has_method("_setup_abilities")
	var dtype: int     = CombatSystem.DamageType.PHYSICAL
	if is_champ and _first_shot_on_champion:
		_first_shot_on_champion = false
		dtype = CombatSystem.DamageType.TRUE_DAMAGE

	# Spawn a projectile — it deals the damage when it arrives
	_spawn_projectile(_attack_target, attack_damage, dtype)


func _spawn_projectile(target: Node, damage: float, dtype: int) -> void:
	var proj := TowerProjectile.new()
	get_parent().add_child(proj)
	proj.setup(
		global_position, target, self, damage, dtype,
		700.0,                        # speed (px/s)
		Color(1.0, 0.9, 0.15),        # yellow bolt
		10.0                          # dot size
	)


func take_damage(amount: float, source: Node, _dtype: int) -> void:
	current_hp -= amount
	var hbar := get_node_or_null("HealthBar")
	if hbar:
		hbar.value = (current_hp / max_hp) * 100.0
	if current_hp <= 0.0:
		_destroy(source)


func _destroy(killer: Node) -> void:
	current_hp = 0.0
	if killer and "team" in killer:
		get_tree().call_group("champions_team_" + str(killer.team), "add_gold", gold_value / 3.0)

	destroyed.emit(self)

	if tower_type == "inhibitor":
		GameManager.notify_inhibitor_destroyed(team, lane)

	queue_free()
