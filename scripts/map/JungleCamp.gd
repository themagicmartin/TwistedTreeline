extends Node2D
# JungleCamp — manages a group of jungle monsters (Golems or Wraiths).
# Spawns monsters on game start and after 75s respawn timer.

const RESPAWN_TIME := 75.0

@export var camp_type: String = "golems"  # "golems" or "wraiths"
@export var monster_scene: PackedScene = null

var _monsters: Array = []
var _respawn_timer: float = 0.0
var _is_alive: bool = false


func _ready() -> void:
	add_to_group("jungle_camps")
	call_deferred("_spawn_camp")


func _spawn_camp() -> void:
	if monster_scene == null:
		return
	_clear_monsters()
	match camp_type:
		"golems":
			_spawn_monster(Vector2(-40, 0))   # large golem
			_spawn_monster(Vector2(40, 20))   # small golem
		"wraiths":
			_spawn_monster(Vector2(0, -30))   # main wraith
			_spawn_monster(Vector2(-40, 30))  # lesser wraith
			_spawn_monster(Vector2(40, 30))   # lesser wraith
	_is_alive = true


func _spawn_monster(offset: Vector2) -> void:
	var m := monster_scene.instantiate()
	m.position = global_position + offset
	m.camp = self
	get_parent().add_child(m)
	_monsters.append(m)


func _clear_monsters() -> void:
	for m in _monsters:
		if is_instance_valid(m):
			m.queue_free()
	_monsters.clear()


func notify_monster_died(monster: Node) -> void:
	_monsters.erase(monster)
	if _monsters.is_empty():
		_is_alive = false
		_respawn_timer = RESPAWN_TIME


func _process(delta: float) -> void:
	if not _is_alive and GameManager.state == GameManager.GameState.IN_GAME:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_spawn_camp()
