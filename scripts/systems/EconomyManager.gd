extends Node
# EconomyManager — singleton (autoload as "EconomyManager")
# Tracks gold and XP per player, handles passive income.

const PASSIVE_GOLD_RATE   := 19.0   # gold per 5 seconds
const PASSIVE_GOLD_PERIOD := 5.0
const STARTING_GOLD       := 1375.0

# Indexed by peer_id (multiplayer) or player index (local)
var player_gold: Dictionary = {}
var player_xp: Dictionary = {}
var player_level: Dictionary = {}

# XP required to level from n to n+1
const XP_PER_LEVEL := [
	0, 280, 660, 1140, 1720, 2400, 3180, 4060, 5040, 6120,
	7300, 8580, 9960, 11440, 13020, 14700, 16480, 18360
]

var _passive_timer: float = 0.0


func _ready() -> void:
	pass


func register_player(player_id: int) -> void:
	player_gold[player_id] = STARTING_GOLD
	player_xp[player_id] = 0.0
	player_level[player_id] = 1


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return
	_passive_timer += delta
	if _passive_timer >= PASSIVE_GOLD_PERIOD:
		_passive_timer = 0.0
		_tick_passive_gold()


func _tick_passive_gold() -> void:
	for pid in player_gold.keys():
		player_gold[pid] += PASSIVE_GOLD_RATE


func add_gold(player_id: int, amount: float) -> void:
	if player_id in player_gold:
		player_gold[player_id] += amount


func spend_gold(player_id: int, amount: float) -> bool:
	if player_id not in player_gold:
		return false
	if player_gold[player_id] < amount:
		return false
	player_gold[player_id] -= amount
	return true


func get_gold(player_id: int) -> float:
	return player_gold.get(player_id, 0.0)


func add_xp(player_id: int, amount: float) -> void:
	if player_id not in player_xp:
		return
	player_xp[player_id] += amount
	_check_level_up(player_id)


func _check_level_up(player_id: int) -> void:
	var level := player_level[player_id]
	while level < 18:
		var xp_needed: float = XP_PER_LEVEL[level]
		if player_xp[player_id] >= xp_needed:
			player_level[player_id] = level + 1
			level += 1
			# Notify champion to update stats
			get_tree().call_group("player_" + str(player_id), "on_level_up", player_level[player_id])
		else:
			break


func get_level(player_id: int) -> int:
	return player_level.get(player_id, 1)


func get_xp(player_id: int) -> float:
	return player_xp.get(player_id, 0.0)


func get_xp_to_next(player_id: int) -> float:
	var level := player_level.get(player_id, 1)
	if level >= 18:
		return 0.0
	return XP_PER_LEVEL[level]
