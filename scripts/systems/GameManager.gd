extends Node
# GameManager — singleton (autoload as "GameManager")
# Tracks game state, win condition, timers, team buffs.

signal game_ended(winning_team: int)
signal altar_captured(altar_id: int, team: int)
signal vilemaw_killed(team: int)
signal inhibitor_destroyed(team: int, lane: String)

enum Team { NONE = 0, BLUE = 1, RED = 2 }
enum GameState { LOBBY, CHAMPION_SELECT, IN_GAME, ENDED }

const VILEMAW_SPAWN_TIME   := 600.0  # 10 minutes
const VILEMAW_RESPAWN_TIME := 360.0  # 6 minutes
const MINION_FIRST_SPAWN   := 45.0
const MINION_WAVE_INTERVAL := 30.0
const INHIBITOR_RESPAWN    := 300.0  # 5 minutes

var state: GameState = GameState.LOBBY
var game_time: float = 0.0
var winning_team: int = Team.NONE

# Per-team altar ownership [altar_id] -> Team
var altar_owners: Dictionary = {0: Team.NONE, 1: Team.NONE}

# Team buffs (computed from altar_owners)
var team_move_speed_bonus: Dictionary = {Team.BLUE: 0.0, Team.RED: 0.0}
var team_lifesteal_on_kill: Dictionary = {Team.BLUE: false, Team.RED: false}

# Vilemaw state
var vilemaw_alive: bool = false
var vilemaw_spawn_timer: float = VILEMAW_SPAWN_TIME

# Inhibitor state: true = alive
var inhibitors: Dictionary = {
	Team.BLUE: {"top": true, "bot": true},
	Team.RED:  {"top": true, "bot": true},
}

# Minion spawn timers
var minion_spawn_timer: float = MINION_FIRST_SPAWN
var wave_number: int = 0


func _ready() -> void:
	pass


func start_game() -> void:
	state = GameState.IN_GAME
	game_time = 0.0
	wave_number = 0
	minion_spawn_timer = MINION_FIRST_SPAWN
	vilemaw_spawn_timer = VILEMAW_SPAWN_TIME
	altar_owners = {0: Team.NONE, 1: Team.NONE}
	_update_team_buffs()


func _process(delta: float) -> void:
	if state != GameState.IN_GAME:
		return
	game_time += delta
	_tick_minion_spawner(delta)
	_tick_vilemaw(delta)


func _tick_minion_spawner(delta: float) -> void:
	minion_spawn_timer -= delta
	if minion_spawn_timer <= 0.0:
		minion_spawn_timer = MINION_WAVE_INTERVAL
		wave_number += 1
		_spawn_minion_waves()


func _spawn_minion_waves() -> void:
	# Signal to WaveManager (connected in scene)
	var is_cannon_wave: bool = (wave_number % 3 == 0)
	get_tree().call_group("wave_manager", "spawn_wave", wave_number, is_cannon_wave)


func _tick_vilemaw(delta: float) -> void:
	if not vilemaw_alive:
		vilemaw_spawn_timer -= delta
		if vilemaw_spawn_timer <= 0.0:
			_spawn_vilemaw()


func _spawn_vilemaw() -> void:
	vilemaw_alive = true
	get_tree().call_group("vilemaw", "activate")


func notify_vilemaw_killed(killing_team: int) -> void:
	vilemaw_alive = false
	vilemaw_spawn_timer = VILEMAW_RESPAWN_TIME
	vilemaw_killed.emit(killing_team)
	# Apply Crest of Crushing Wrath buff to the killing team's champions
	get_tree().call_group("champions_team_" + str(killing_team), "apply_vilemaw_buff")


func notify_altar_captured(altar_id: int, capturing_team: int) -> void:
	altar_owners[altar_id] = capturing_team
	_update_team_buffs()
	altar_captured.emit(altar_id, capturing_team)
	# Grant gold to capturing team
	get_tree().call_group("champions_team_" + str(capturing_team), "add_gold", 80)


func _update_team_buffs() -> void:
	for team in [Team.BLUE, Team.RED]:
		var owned := altar_owners.values().count(team)
		team_move_speed_bonus[team] = 0.1 if owned >= 1 else 0.0
		team_lifesteal_on_kill[team] = owned >= 2
	# Broadcast buff changes to all champions
	get_tree().call_group("all_champions", "on_team_buffs_updated")


func notify_inhibitor_destroyed(team: int, lane: String) -> void:
	# team = the team whose inhibitor was destroyed
	inhibitors[team][lane] = false
	inhibitor_destroyed.emit(team, lane)
	# Trigger super minion spawning for the opposing team
	var opposing := Team.RED if team == Team.BLUE else Team.BLUE
	get_tree().call_group("wave_manager", "enable_super_minions", opposing, lane)
	# Schedule inhibitor respawn
	get_tree().create_timer(INHIBITOR_RESPAWN).timeout.connect(
		func(): _respawn_inhibitor(team, lane)
	)


func _respawn_inhibitor(team: int, lane: String) -> void:
	inhibitors[team][lane] = true
	get_tree().call_group("wave_manager", "disable_super_minions",
		Team.RED if team == Team.BLUE else Team.BLUE, lane)
	get_tree().call_group("inhibitor_" + str(team) + "_" + lane, "respawn")


func notify_nexus_destroyed(destroyed_team: int) -> void:
	winning_team = Team.RED if destroyed_team == Team.BLUE else Team.BLUE
	state = GameState.ENDED
	game_ended.emit(winning_team)


func get_game_time_string() -> String:
	var minutes := int(game_time) / 60
	var seconds := int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]


func get_altar_bonus_move_speed(team: int) -> float:
	return team_move_speed_bonus.get(team, 0.0)


func has_lifesteal_on_kill(team: int) -> bool:
	return team_lifesteal_on_kill.get(team, false)
