extends CharacterBody2D
class_name ChampionBase
# ChampionBase — base class for all 6 champions.
# Handles: movement (click-to-move), basic attacks, stats, level scaling,
# status effect reception, death/respawn, team buff integration.

class_name ChampionBase

# --- Signals ---
signal died(champion: ChampionBase)
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal on_basic_attack_hit(target: Node, damage: float)

# --- Team & Identity ---
@export var champion_name: String = "Champion"
@export var team: int = GameManager.Team.BLUE
@export var player_id: int = 0  # multiplayer peer ID

# --- Base Stats (level 1) ---
@export var base_hp: float = 600.0
@export var base_hp_per_level: float = 85.0
@export var base_mana: float = 300.0
@export var base_mana_per_level: float = 40.0
@export var base_ad: float = 60.0
@export var base_ad_per_level: float = 3.0
@export var base_ap: float = 0.0
@export var base_armor: float = 28.0
@export var base_armor_per_level: float = 3.5
@export var base_mr: float = 32.0
@export var base_mr_per_level: float = 1.25
@export var base_move_speed: float = 345.0
@export var base_attack_speed: float = 0.625  # attacks per second
@export var base_attack_range: float = 125.0  # melee default
@export var vision_radius: float = 900.0
@export var gold_value: float = 300.0
@export var xp_value: float = 200.0

# --- Computed Stats (updated on level up) ---
var max_hp: float = 600.0
var current_hp: float = 600.0
var max_mana: float = 300.0
var current_mana: float = 300.0
var attack_damage: float = 60.0
var ability_power: float = 0.0
var armor: float = 28.0
var magic_resist: float = 32.0
var move_speed: float = 345.0
var attack_speed: float = 0.625
var attack_range: float = 125.0

# --- Level ---
var level: int = 1

# --- Respawn ---
const RESPAWN_BASE := 6.0
const RESPAWN_PER_LEVEL := 2.5
var is_dead: bool = false
var _respawn_timer: float = 0.0

# --- Basic Attack ---
var _attack_target: Node = null
var _attack_cooldown: float = 0.0
var _is_attack_moving: bool = false
var _attack_windup: float = 0.0  # seconds into current attack animation

# --- Damage reduction (Garen W, etc.) ---
var active_damage_reduction: float = 0.0  # 0.0–1.0 fraction

# --- Shields ---
var _active_shields: Array = []

# --- Movement ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var _move_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false

# --- Abilities ---
var ability_q: AbilitySystem = null
var ability_w: AbilitySystem = null
var ability_e: AbilitySystem = null
var ability_r: AbilitySystem = null

# --- Status Effects ---
var _active_effects: Array = []  # StatusEffect nodes

# --- Vilemaw buff ---
var has_vilemaw_buff: bool = false

# --- Ability points available ---
var _ability_points: int = 0

# --- Input lock (for the local player only) ---
var is_local_player: bool = false


func _ready() -> void:
	add_to_group("all_champions")
	add_to_group("champions_team_" + str(team))
	add_to_group("player_" + str(player_id))
	if team == GameManager.Team.BLUE:
		add_to_group("enemy_units_" + str(GameManager.Team.RED))
	else:
		add_to_group("enemy_units_" + str(GameManager.Team.BLUE))

	_compute_stats()
	current_hp = max_hp
	current_mana = max_mana

	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

	_setup_abilities()


func _setup_abilities() -> void:
	# Subclasses override to add ability children
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_local_player:
		# Networked movement handled by MultiplayerSynchronizer
		_apply_physics(delta)
		return

	_handle_input()
	_handle_movement(delta)
	_handle_basic_attack(delta)
	_apply_physics(delta)


func _handle_input() -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return

	# Right-click: move command
	if Input.is_action_just_pressed("ui_accept"):
		pass  # handled via InputEvent in _input()

	# Ability hotkeys
	if Input.is_action_just_pressed("ability_q") and ability_q:
		_cast_ability(ability_q)
	if Input.is_action_just_pressed("ability_w") and ability_w:
		_cast_ability(ability_w)
	if Input.is_action_just_pressed("ability_e") and ability_e:
		_cast_ability(ability_e)
	if Input.is_action_just_pressed("ability_r") and ability_r:
		_cast_ability(ability_r)


func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if is_dead:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var world_pos := get_global_mouse_position()
		set_move_target(world_pos)
		_attack_target = null
		_is_attack_moving = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.is_action_pressed("attack_move"):
			# Attack-move: find nearest enemy near click position
			var world_pos := get_global_mouse_position()
			var target := _find_nearest_enemy_near(world_pos, 200.0)
			if target:
				_attack_target = target
				_is_attack_moving = false
			else:
				set_move_target(world_pos)
				_is_attack_moving = true


func set_move_target(pos: Vector2) -> void:
	_move_target = pos
	_is_moving = true
	nav_agent.target_position = pos


func _handle_movement(delta: float) -> void:
	if not _is_moving:
		velocity = Vector2.ZERO
		return

	# If attacking a target, move toward it until in range
	if _attack_target and is_instance_valid(_attack_target):
		var dist := global_position.distance_to(_attack_target.global_position)
		if dist <= attack_range:
			velocity = Vector2.ZERO
			_is_moving = false
			return
		nav_agent.target_position = _attack_target.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_is_moving = false
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_pos)
	var spd := _effective_move_speed()
	velocity = direction * spd


func _effective_move_speed() -> float:
	var spd := move_speed
	# Altar movement speed bonus
	spd *= (1.0 + GameManager.get_altar_bonus_move_speed(team))
	# Slow effect
	for child in get_children():
		if child is StatusEffect and child.effect_type == StatusEffect.Type.SLOW:
			spd *= (1.0 - child.magnitude)
	# Speed boost
	for child in get_children():
		if child is StatusEffect and child.effect_type == StatusEffect.Type.SPEED_BOOST:
			spd *= (1.0 + child.magnitude)
	return spd


func _apply_physics(_delta: float) -> void:
	# Knockback override
	for child in get_children():
		if child is StatusEffect and child.effect_type == StatusEffect.Type.KNOCKBACK:
			velocity = child.knockback_direction * child.magnitude
	move_and_slide()


func _handle_basic_attack(delta: float) -> void:
	_attack_cooldown -= delta

	if _attack_target == null or not is_instance_valid(_attack_target):
		_attack_target = null
		return

	var dist := global_position.distance_to(_attack_target.global_position)
	if dist > attack_range + 50.0:
		# Out of range — move toward target if attack-moving
		if _is_attack_moving:
			set_move_target(_attack_target.global_position)
		return

	if _attack_cooldown <= 0.0:
		_perform_basic_attack()


func _perform_basic_attack() -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	_attack_cooldown = 1.0 / attack_speed
	CombatSystem.basic_attack(self, _attack_target)


func _cast_ability(ability: AbilitySystem) -> void:
	if _is_hard_cced():
		return
	match ability.cast_type:
		AbilitySystem.CastType.INSTANT, AbilitySystem.CastType.AOE:
			ability.try_cast(get_global_mouse_position())
		AbilitySystem.CastType.SKILLSHOT, AbilitySystem.CastType.POINT_CLICK:
			ability.try_cast(get_global_mouse_position())
		AbilitySystem.CastType.TARGETED:
			# Find enemy under cursor
			var target := _find_enemy_under_cursor()
			if target:
				ability.try_cast(target)


func _is_hard_cced() -> bool:
	for child in get_children():
		if child is StatusEffect:
			if child.effect_type in [StatusEffect.Type.STUN, StatusEffect.Type.KNOCKUP, StatusEffect.Type.KNOCKBACK]:
				return true
	return false


func _find_enemy_under_cursor() -> Node:
	var cursor_pos := get_global_mouse_position()
	return _find_nearest_enemy_near(cursor_pos, 80.0)


func _find_nearest_enemy_near(pos: Vector2, radius: float) -> Node:
	var best: Node = null
	var best_dist := radius
	for unit in get_tree().get_nodes_in_group("all_units"):
		if not is_instance_valid(unit):
			continue
		if not CombatSystem.is_enemy(self, unit):
			continue
		var d := pos.distance_to(unit.global_position)
		if d < best_dist:
			best_dist = d
			best = unit
	return best


# --- Damage & Death ---

func take_damage(amount: float, source: Node, _dtype: int) -> void:
	if is_dead:
		return
	# Apply damage reduction (e.g. Garen W)
	var mitigated := amount * (1.0 - clampf(active_damage_reduction, 0.0, 1.0))
	# Let shields absorb first
	for shield in _active_shields.duplicate():
		if not is_instance_valid(shield):
			_active_shields.erase(shield)
			continue
		mitigated = shield.absorb(mitigated, source)
		if mitigated <= 0.0:
			return
	current_hp -= mitigated
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_die(source)


func register_shield(shield: Node) -> void:
	_active_shields.append(shield)


func unregister_shield(shield: Node) -> void:
	_active_shields.erase(shield)


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func _die(killer: Node) -> void:
	is_dead = true
	current_hp = 0.0
	visible = false

	# Award gold + XP to killer
	if killer and "player_id" in killer:
		EconomyManager.add_gold(killer.player_id, gold_value)
		EconomyManager.add_xp(killer.player_id, xp_value)

	# Assists: team members who dealt damage recently (simplified: all nearby teammates)
	var killer_team := killer.team if (killer and "team" in killer) else 0
	for ally in get_tree().get_nodes_in_group("champions_team_" + str(killer_team)):
		if ally == killer:
			continue
		if ally.global_position.distance_to(global_position) < 1500.0:
			EconomyManager.add_gold(ally.player_id, 150.0)

	# Altar lifesteal on kill
	if killer and "team" in killer and GameManager.has_lifesteal_on_kill(killer.team):
		killer.heal(killer.max_hp * 0.01)

	died.emit(self)
	_start_respawn_timer()


func _start_respawn_timer() -> void:
	var respawn_time := RESPAWN_BASE + (level - 1) * RESPAWN_PER_LEVEL
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	is_dead = false
	current_hp = max_hp
	current_mana = max_mana
	visible = true
	# Teleport to fountain
	var fountain_group := "fountain_team_" + str(team)
	var fountains := get_tree().get_nodes_in_group(fountain_group)
	if fountains.size() > 0:
		global_position = fountains[0].global_position


# --- Stat Computation ---

func _compute_stats() -> void:
	var lvl := level - 1
	max_hp       = base_hp + base_hp_per_level * lvl
	max_mana     = base_mana + base_mana_per_level * lvl
	attack_damage = base_ad + base_ad_per_level * lvl
	armor        = base_armor + base_armor_per_level * lvl
	magic_resist = base_mr + base_mr_per_level * lvl
	move_speed   = base_move_speed
	attack_speed = base_attack_speed
	attack_range = base_attack_range


func on_level_up(new_level: int) -> void:
	level = new_level
	var old_max := max_hp
	_compute_stats()
	# HP scales up proportionally
	current_hp = current_hp * (max_hp / old_max)
	current_hp = minf(current_hp, max_hp)
	health_changed.emit(current_hp, max_hp)
	_ability_points += 1


# --- Status Effect Callbacks ---

func on_status_effect_applied(fx: StatusEffect) -> void:
	_active_effects.append(fx)
	if fx.effect_type == StatusEffect.Type.GHOSTED or fx.effect_type == StatusEffect.Type.VILEMAW_BUFF:
		# Disable collision for ghosted units
		$CollisionShape2D.disabled = true


func on_status_effect_removed(fx: StatusEffect) -> void:
	_active_effects.erase(fx)
	if fx.effect_type == StatusEffect.Type.GHOSTED or fx.effect_type == StatusEffect.Type.VILEMAW_BUFF:
		var still_ghosted := false
		for other in _active_effects:
			if other.effect_type in [StatusEffect.Type.GHOSTED, StatusEffect.Type.VILEMAW_BUFF]:
				still_ghosted = true
				break
		if not still_ghosted:
			$CollisionShape2D.disabled = false


# --- Team Buff Callbacks ---

func on_team_buffs_updated() -> void:
	pass  # movement speed is computed dynamically in _effective_move_speed()


func apply_vilemaw_buff() -> void:
	has_vilemaw_buff = true
	StatusEffect.make_ghosted(self, 180.0)
	StatusEffect.make_vilemaw_buff(self)


func add_gold(amount: float) -> void:
	EconomyManager.add_gold(player_id, amount)


# --- Networking helpers ---

# Called on all clients when another player issues a move command (RPC)
@rpc("any_peer", "call_local", "reliable")
func rpc_set_move_target(x: float, y: float) -> void:
	set_move_target(Vector2(x, y))


@rpc("any_peer", "call_local", "reliable")
func rpc_cast_ability(slot: int, target_x: float, target_y: float) -> void:
	var ability: AbilitySystem = _get_ability_by_slot(slot)
	if ability:
		ability.try_cast(Vector2(target_x, target_y))


func _get_ability_by_slot(slot: int) -> AbilitySystem:
	match slot:
		0: return ability_q
		1: return ability_w
		2: return ability_e
		3: return ability_r
	return null
