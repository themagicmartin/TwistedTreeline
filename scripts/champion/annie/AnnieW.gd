extends AbilitySystem
# Annie W — Incinerate
# AOE cone of fire in front of Annie, deals magic damage.

const BASE_DMG := [0.0, 70.0, 115.0, 160.0, 205.0, 250.0]
const AP_RATIO := 0.75
const CONE_ANGLE_DEG := 50.0
const CONE_RANGE := 625.0

func _ready() -> void:
	ability_name   = "Incinerate"
	cast_type      = CastType.AOE
	cooldown_base  = 8.0
	mana_cost_base = 70.0
	cast_range     = CONE_RANGE
	max_rank       = 5
	super()


func cast(target = null) -> void:
	var c := owner_champion
	if c == null:
		return
	var will_stun := false
	if c.has_method("increment_stun_counter"):
		will_stun = c.increment_stun_counter()

	var dmg: float = (BASE_DMG[rank] as float) + (c.ability_power as float) * AP_RATIO
	var aim: Vector2
	if target is Vector2:
		aim = c.global_position.direction_to(target)
	else:
		aim = Vector2.RIGHT

	for unit in c.get_tree().get_nodes_in_group("all_units"):
		if not CombatSystem.is_enemy(c, unit):
			continue
		var to_unit := c.global_position.direction_to(unit.global_position)
		var dist := c.global_position.distance_to(unit.global_position)
		if dist > CONE_RANGE:
			continue
		var angle := rad_to_deg(aim.angle_to(to_unit))
		if absf(angle) <= CONE_ANGLE_DEG / 2.0:
			CombatSystem.deal_damage(c, unit, dmg, CombatSystem.DamageType.MAGIC, true)
			if will_stun and is_instance_valid(unit):
				StatusEffect.make_stun(unit, 1.75)
