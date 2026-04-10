extends Area2D
# Altar — Twisted Treeline capture point.
# Stand on it for 9 seconds (faster with more allies) to capture.
# Seals for 90 seconds after capture. Awards 80g to each captor.

const CAPTURE_TIME := 9.0
const SEAL_DURATION := 90.0
const CAPTURE_RADIUS := 120.0

@export var altar_id: int = 0  # 0 = left altar, 1 = right altar

var owner_team: int = GameManager.Team.NONE
var capture_progress: float = 0.0  # 0.0 to 1.0
var capturing_team: int = GameManager.Team.NONE
var is_sealed: bool = false
var _seal_timer: float = 0.0

# Units currently standing on this altar
var _units_on_altar: Dictionary = {GameManager.Team.BLUE: [], GameManager.Team.RED: []}

signal capture_started(altar_id: int, team: int)
signal capture_completed(altar_id: int, team: int)
signal capture_contested(altar_id: int)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return

	if is_sealed:
		_seal_timer -= delta
		if _seal_timer <= 0.0:
			is_sealed = false
		return

	var blue_count := _units_on_altar[GameManager.Team.BLUE].size()
	var red_count  := _units_on_altar[GameManager.Team.RED].size()

	if blue_count > 0 and red_count > 0:
		# Contested — no progress
		capture_contested.emit(altar_id)
		return

	if blue_count == 0 and red_count == 0:
		return

	var active_team := GameManager.Team.BLUE if blue_count > 0 else GameManager.Team.RED
	var unit_count  := blue_count if blue_count > 0 else red_count

	if active_team == owner_team:
		return  # Already owned

	if capturing_team != active_team:
		capture_progress = 0.0
		capturing_team = active_team
		capture_started.emit(altar_id, active_team)

	# Multiple allies speed up capture proportionally
	var rate := unit_count / CAPTURE_TIME
	capture_progress += rate * delta
	capture_progress = minf(capture_progress, 1.0)

	if capture_progress >= 1.0:
		_complete_capture(active_team)


func _complete_capture(team: int) -> void:
	owner_team = team
	capturing_team = GameManager.Team.NONE
	capture_progress = 0.0
	is_sealed = true
	_seal_timer = SEAL_DURATION
	capture_completed.emit(altar_id, team)
	GameManager.notify_altar_captured(altar_id, team)


func _on_body_entered(body: Node) -> void:
	if body.has_variable("team"):
		var t: int = body.team
		if t in _units_on_altar and body not in _units_on_altar[t]:
			_units_on_altar[t].append(body)


func _on_body_exited(body: Node) -> void:
	for t in _units_on_altar.keys():
		_units_on_altar[t].erase(body)


func get_capture_progress_for_team(team: int) -> float:
	if capturing_team == team:
		return capture_progress
	return 0.0
