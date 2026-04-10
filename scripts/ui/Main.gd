extends Node2D
# Main — MVP solo-only version.
# Spawns one Blue Garen (local player) vs one Red Garen (dummy).

const GAREN_SCENE := preload("res://scenes/Champions/Garen.tscn")

const BLUE_SPAWN := Vector2(300,  1000)
const RED_SPAWN  := Vector2(2900, 1000)

var local_champion: ChampionBase = null

@onready var hud: CanvasLayer            = $HUD
@onready var victory_screen: CanvasLayer = $VictoryScreen
@onready var camera: Camera2D            = $Camera2D


func _ready() -> void:
	GameManager.start_game()
	_spawn_champions()
	_setup_camera()
	_connect_hud()


func _spawn_champions() -> void:
	# Blue Garen — local player
	_spawn_champion(GameManager.Team.BLUE, BLUE_SPAWN, true)
	# Red Garen — CPU dummy (no input)
	_spawn_champion(GameManager.Team.RED,  RED_SPAWN,  false)


func _spawn_champion(team: int, pos: Vector2, is_local: bool) -> void:
	var champ := GAREN_SCENE.instantiate() as ChampionBase
	champ.team            = team
	champ.player_id       = team  # use team id as player id for MVP
	champ.is_local_player = is_local
	champ.global_position = pos
	$Map.add_child(champ)
	EconomyManager.register_player(team)
	if is_local:
		local_champion = champ


func _setup_camera() -> void:
	if local_champion:
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
