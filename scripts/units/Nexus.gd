extends StaticBody2D
# Nexus — the win condition structure. Destroy the enemy nexus to win.

@export var team: int = GameManager.Team.BLUE

var max_hp: float = 5000.0
var current_hp: float = 5000.0
var armor: float = 100.0
var magic_resist: float = 100.0

signal hp_changed(current: float, maximum: float)


func _ready() -> void:
	add_to_group("all_units")
	add_to_group("nexus_team_" + str(team))
	if team == GameManager.Team.BLUE:
		add_to_group("enemy_units_" + str(GameManager.Team.RED))
	else:
		add_to_group("enemy_units_" + str(GameManager.Team.BLUE))

	# Regenerate 15 HP/sec
	var regen: SceneTreeTimer = get_tree().create_timer(1.0)
	regen.timeout.connect(_regen_hp)


func _regen_hp() -> void:
	current_hp = minf(current_hp + 15.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if GameManager.state == GameManager.GameState.IN_GAME:
		get_tree().create_timer(1.0).timeout.connect(_regen_hp)


func take_damage(amount: float, source: Node, _dtype: int) -> void:
	current_hp -= amount
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_destroyed(source)


func _destroyed(_source: Node) -> void:
	GameManager.notify_nexus_destroyed(team)
	queue_free()
