extends Control
# ChampionSelect — handles networking setup + champion/team selection.
# Supports: Host (local), Join (by IP), or solo local play.

const CHAMPION_SCENES := {
	"Garen": "res://scenes/Champions/Garen.tscn",
	"Ashe":  "res://scenes/Champions/Ashe.tscn",
	"Annie": "res://scenes/Champions/Annie.tscn",
}

var selected_champion: String = ""
var selected_team: int = GameManager.Team.BLUE
var is_ready: bool = false


func _ready() -> void:
	%GarenCard.pressed.connect(func(): _select_champion("Garen"))
	%AsheCard.pressed.connect(func():  _select_champion("Ashe"))
	%AnnieCard.pressed.connect(func(): _select_champion("Annie"))

	%TeamBlueBtn.pressed.connect(func(): _select_team(GameManager.Team.BLUE))
	%TeamRedBtn.pressed.connect(func():  _select_team(GameManager.Team.RED))

	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%ReadyButton.pressed.connect(_on_ready_pressed)

	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)


func _select_champion(name: String) -> void:
	selected_champion = name
	%SelectionLabel.text = "Selected: " + name
	_check_ready()


func _select_team(team: int) -> void:
	selected_team = team
	var label := "Blue" if team == GameManager.Team.BLUE else "Red"
	%TeamLabel.text = "Your team: " + label


func _check_ready() -> void:
	%ReadyButton.disabled = selected_champion.is_empty()


func _on_host_pressed() -> void:
	var port := int(%PortField.text) if %PortField.text.is_valid_int() else 7777
	var err := NetworkManager.start_server(port)
	if err == OK:
		%StatusLabel.text = "Hosting on :%d" % port
		# Also connect as local client
		NetworkManager.connect_to_server("127.0.0.1", port)
	else:
		%StatusLabel.text = "Host failed!"


func _on_join_pressed() -> void:
	var ip := %IPField.text.strip_edges()
	var port := int(%PortField.text) if %PortField.text.is_valid_int() else 7777
	%StatusLabel.text = "Connecting to %s:%d..." % [ip, port]
	NetworkManager.connect_to_server(ip, port)


func _on_connected() -> void:
	%StatusLabel.text = "Connected! (ID: %d)" % NetworkManager.local_peer_id


func _on_connection_failed() -> void:
	%StatusLabel.text = "Connection failed."


func _on_server_started() -> void:
	%StatusLabel.text = "Server running."


func _on_ready_pressed() -> void:
	if selected_champion.is_empty():
		return

	var info := {
		"champion": selected_champion,
		"team": selected_team,
		"peer_id": NetworkManager.local_peer_id,
	}
	NetworkManager.register_player.rpc(info)

	# For solo local play: just start immediately
	if not multiplayer.has_multiplayer_peer() or NetworkManager.is_host():
		_start_game_local()


func _start_game_local() -> void:
	# Store selection in a global so Main.tscn can read it
	GameManager.state = GameManager.GameState.IN_GAME
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
