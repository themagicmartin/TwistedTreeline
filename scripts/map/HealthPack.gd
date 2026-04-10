extends Area2D
# HealthPack — small health/mana restore + speed boost in jungle center.
# Respawns every 30 seconds.

const RESPAWN_TIME := 30.0
const HEAL_PERCENT := 0.12   # 12% max HP
const MANA_PERCENT := 0.12   # 12% max mana
const SPEED_BOOST  := 0.30   # 30% for 2 seconds

var is_available: bool = true
var _respawn_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not is_available:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			is_available = true
			visible = true


func _on_body_entered(body: Node) -> void:
	if not is_available:
		return
	if not body.has_method("heal"):
		return
	# Only champions can pick up health packs
	if not body.has_variable("team"):
		return

	body.heal(body.max_hp * HEAL_PERCENT)
	if body.has_variable("current_mana"):
		body.current_mana = minf(body.current_mana + body.max_mana * MANA_PERCENT, body.max_mana)
	StatusEffect.make_speed_boost(body, 2.0, SPEED_BOOST)

	is_available = false
	visible = false
	_respawn_timer = RESPAWN_TIME
