extends Node2D
# Main — root of the game scene.
# Spawns champions based on NetworkManager.player_info (or default solo setup),
# sets up camera, connects HUD to local champion.

const CHAMPION_SCENES := {
	"Garen": preload("res://scenes/Champions/Garen.tscn"),
	"Ashe":  preload("res://scenes/Champions/Ashe.tscn"),
	"Annie": preload("res://scenes/Champions/Annie.tscn"),
}

# Default solo spawn: one Garen (Blue) vs one Garen (Red) for testing
const BLUE_SPAWN := Vector2(300, 1000)
const RED_SPAWN  := Vector2(2900, 1000)

# Spawn positions offset per player slot
const BLUE_SLOTS := [Vector2(300, 900), Vector2(300, 1000), Vector2(300, 1100)]
const RED_SLOTS  := [Vector2(2900, 900), Vector2(2900, 1000), Vector2(2900, 1100)]

var local_champion: ChampionBase = null

@onready var hud: CanvasLayer          = $HUD
@onready var victory_screen: CanvasLayer = $VictoryScreen
@onready var camera: Camera2D          = $Camera2D


func _ready() -> void:
	GameManager.start_game()

	_spawn_champions()
	_setup_camera()
	_connect_hud()


func _spawn_champions() -> void:
	var player_info := NetworkManager.player_info

	if player_info.is_empty():
		# Solo / debug mode: spawn one Blue Garen for the local player
		_spawn_champion("Garen", GameManager.Team.BLUE, 1, BLUE_SLOTS[0], true)
		# Spawn a Red Annie as a dummy opponent
		_spawn_champion("Annie", GameManager.Team.RED, 2, RED_SLOTS[0], false)
		return

	var blue_slot := 0
	var red_slot  := 0
	for pid in player_info:
		var info: Dictionary = player_info[pid]
		var champ_name: String = info.get("champion", "Garen")
		var team: int          = info.get("team", GameManager.Team.BLUE)
		var is_local: bool     = (pid == NetworkManager.local_peer_id)

		var spawn_pos: Vector2
		if team == GameManager.Team.BLUE:
			spawn_pos = BLUE_SLOTS[blue_slot % 3]
			blue_slot += 1
		else:
			spawn_pos = RED_SLOTS[red_slot % 3]
			red_slot += 1

		_spawn_champion(champ_name, team, pid, spawn_pos, is_local)


func _spawn_champion(champ_name: String, team: int, pid: int, pos: Vector2, is_local: bool) -> void:
	var scene := CHAMPION_SCENES.get(champ_name)
	if scene == null:
		push_error("Main: unknown champion '%s'" % champ_name)
		return

	var champ := scene.instantiate() as ChampionBase
	champ.team      = team
	champ.player_id = pid
	champ.is_local_player = is_local
	champ.global_position = pos

	# Set sprite color based on team
	$Map.add_child(champ)
	EconomyManager.register_player(pid)

	if is_local:
		local_champion = champ


func _setup_camera() -> void:
	if local_champion:
		# Camera follows local champion
		camera.reparent(local_champion)
		camera.position = Vector2.ZERO
	else:
		camera.position = Vector2(1600, 1000)

	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = 3200
	camera.limit_bottom = 2000
	camera.zoom         = Vector2(0.6, 0.6)


func _connect_hud() -> void:
	if local_champion and hud.has_method("set_local_champion"):
		hud.set_local_champion(local_champion)
