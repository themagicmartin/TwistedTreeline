extends CanvasLayer
# FogOfWar — renders a dark overlay with vision holes for the local player's team.
# Uses a SubViewport with a dark texture drawn on top, punching holes via Light2D.
# Attach to Main scene. Set local_team before game start.

@export var local_team: int = GameManager.Team.BLUE

# How often to redraw vision (seconds). Lower = smoother, higher = cheaper.
const UPDATE_INTERVAL := 0.05

var _timer: float = 0.0
var _vision_nodes: Array = []  # nodes that provide vision (champions + structures)

# We use a simple approach: a CanvasLayer with a dark ColorRect,
# and we hide enemy units that are outside vision circles.


func _ready() -> void:
	layer = 10  # draw on top of game world, below UI


func register_vision_source(node: Node) -> void:
	if node not in _vision_nodes:
		_vision_nodes.append(node)


func unregister_vision_source(node: Node) -> void:
	_vision_nodes.erase(node)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_update_visibility()


func _update_visibility() -> void:
	# Build set of vision circles for local team
	var vision_circles: Array = []  # Array of {pos: Vector2, radius: float}
	for node in _vision_nodes:
		if not is_instance_valid(node):
			continue
		if not node.has_variable("team") or node.team != local_team:
			continue
		var radius: float = node.vision_radius if node.has_variable("vision_radius") else 900.0
		vision_circles.append({"pos": node.global_position, "radius": radius})

	# Show/hide enemy units based on vision
	for unit in get_tree().get_nodes_in_group("enemy_units_" + str(local_team)):
		if not is_instance_valid(unit):
			continue
		var visible_to_team := _is_in_vision(unit.global_position, vision_circles)
		unit.visible = visible_to_team


func _is_in_vision(pos: Vector2, circles: Array) -> bool:
	for c in circles:
		if pos.distance_to(c["pos"]) <= c["radius"]:
			return true
	return false
