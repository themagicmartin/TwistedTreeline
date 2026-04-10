extends Node
# NetworkManager — singleton (autoload as "NetworkManager")
# Handles ENet multiplayer: dedicated server hosting, client connections.
# The Ubuntu server runs Godot headless and calls start_server().
# Clients call connect_to_server(ip, port).

signal server_started
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connection_succeeded
signal connection_failed

const DEFAULT_PORT := 7777
const MAX_PLAYERS  := 6  # 3v3

var is_server: bool = false
var local_peer_id: int = 1
var connected_peers: Array = []

# Player info registered before/after connection
# peer_id -> {name, team, champion}
var player_info: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# If launched with --server argument, auto-start
	if "--server" in OS.get_cmdline_args():
		var port := DEFAULT_PORT
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--port="):
				port = int(arg.split("=")[1])
		start_server(port)


func start_server(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Failed to start server on port %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	is_server = true
	local_peer_id = 1
	print("Server started on port %d" % port)
	server_started.emit()
	return OK


func connect_to_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d" % [ip, port])
		return err

	multiplayer.multiplayer_peer = peer
	is_server = false
	return OK


func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	player_info.clear()


# --- RPC: Register player info after connecting ---

@rpc("any_peer", "call_local", "reliable")
func register_player(info: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	player_info[sender] = info
	print("Player registered: peer %d, info: %s" % [sender, str(info)])

	if is_server:
		# Send all existing player info to the new player
		for pid in player_info:
			if pid != sender:
				rpc_id(sender, "register_player", player_info[pid])
		# Tell everyone about the new player
		rpc("register_player", info)


@rpc("any_peer", "call_local", "reliable")
func start_game_rpc() -> void:
	if not is_server:
		return
	GameManager.start_game()
	rpc("_client_start_game")


@rpc("call_local", "reliable")
func _client_start_game() -> void:
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# --- Input relay: clients send input to server, server applies authoritatively ---

@rpc("any_peer", "call_local", "reliable")
func send_move_command(champion_name: String, x: float, y: float) -> void:
	if not is_server:
		return
	# Find the champion belonging to the sending peer and move it
	var sender := multiplayer.get_remote_sender_id()
	_apply_move_for_peer(sender, champion_name, Vector2(x, y))


func _apply_move_for_peer(peer_id: int, champion_name: String, pos: Vector2) -> void:
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if champ.player_id == peer_id and champ.champion_name == champion_name:
			champ.set_move_target(pos)
			# Broadcast to all clients
			rpc("_broadcast_move", champion_name, peer_id, pos.x, pos.y)
			break


@rpc("call_local", "reliable")
func _broadcast_move(champion_name: String, peer_id: int, x: float, y: float) -> void:
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if champ.player_id == peer_id and champ.champion_name == champion_name:
			if not champ.is_local_player:
				champ.set_move_target(Vector2(x, y))
			break


@rpc("any_peer", "call_local", "reliable")
func send_ability_cast(champion_name: String, slot: int, target_x: float, target_y: float) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if champ.player_id == sender and champ.champion_name == champion_name:
			var ability := champ._get_ability_by_slot(slot)
			if ability:
				ability.try_cast(Vector2(target_x, target_y))
			rpc("_broadcast_ability", champion_name, sender, slot, target_x, target_y)
			break


@rpc("call_local", "reliable")
func _broadcast_ability(champion_name: String, peer_id: int, slot: int, target_x: float, target_y: float) -> void:
	for champ in get_tree().get_nodes_in_group("all_champions"):
		if champ.player_id == peer_id and champ.champion_name == champion_name and not champ.is_local_player:
			var ability := champ._get_ability_by_slot(slot)
			if ability:
				ability.try_cast(Vector2(target_x, target_y))
			break


# --- Peer connection callbacks ---

func _on_peer_connected(peer_id: int) -> void:
	connected_peers.append(peer_id)
	print("Peer connected: %d" % peer_id)
	client_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	player_info.erase(peer_id)
	print("Peer disconnected: %d" % peer_id)
	client_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("Connected to server. My peer ID: %d" % local_peer_id)
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	push_error("NetworkManager: Connection to server failed.")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("NetworkManager: Disconnected from server.")
	disconnect_from_server()


func get_player_count() -> int:
	return player_info.size()


func is_host() -> bool:
	return is_server
