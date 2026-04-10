extends AbilitySystem
# Garen Q — Decisive Strike
# Silences target, grants Garen a burst of movement speed, and his next
# basic attack deals bonus damage.

class_name GarenQ

const SILENCE_DURATION := [0.0, 1.5, 1.5, 1.5, 1.5, 1.5]
const BONUS_AD_RATIO   := [0.0, 1.3, 1.4, 1.5, 1.6, 1.7]  # % AD multiplier
const SPEED_BONUS      := 0.30  # 30% move speed for 1.5s

func _ready() -> void:
	ability_name = "Decisive Strike"
	cast_type    = CastType.TARGETED
	cooldown_base = 8.0
	mana_cost_base = 0.0  # Garen has no mana
	range        = 175.0  # melee range
	max_rank     = 5
	super()._ready()


func get_cooldown() -> float:
	# Cooldown reduces with rank: 8/7.5/7/6.5/6
	return [8.0, 7.5, 7.0, 6.5, 6.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var c := owner_champion
	if c == null:
		return

	# Silence the target
	StatusEffect.make_silence(target, SILENCE_DURATION[rank])

	# Queue empowered next auto-attack
	c._attack_target = target
	# Temporarily boost AD for the next hit (apply a temporary buff node)
	var bonus := _BonusAutoNode.new()
	bonus.ratio = BONUS_AD_RATIO[rank]
	c.add_child(bonus)

	# Movement speed burst
	StatusEffect.make_speed_boost(c, 1.5, SPEED_BONUS)


# Inner class: empowers next basic attack then removes itself
class _BonusAutoNode extends Node:
	var ratio: float = 1.3
	var _connected: bool = false

	func _ready() -> void:
		if get_parent().has_signal("on_basic_attack_hit"):
			get_parent().on_basic_attack_hit.connect(_on_hit)
			_connected = true

	func _on_hit(target: Node, _base_dmg: float) -> void:
		# Deal extra damage equal to (ratio - 1) * AD
		var extra := get_parent().attack_damage * (ratio - 1.0)
		CombatSystem.deal_damage(get_parent(), target, extra, CombatSystem.DamageType.PHYSICAL, false)
		queue_free()
