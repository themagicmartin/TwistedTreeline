extends AbilitySystem
# Annie Q — Disintegrate
# Hurls a fireball at target. If it kills the target, mana is refunded.

const BASE_DMG := [0.0, 80.0, 115.0, 150.0, 185.0, 220.0]
const AP_RATIO := 0.75

func _ready() -> void:
	ability_name   = "Disintegrate"
	cast_type      = CastType.TARGETED
	cooldown_base  = 4.0
	mana_cost_base = 60.0
	range          = 625.0
	max_rank       = 5
	super()._ready()


func cast(target = null) -> void:
	if not is_instance_valid(target):
		return
	var annie := owner_champion as Annie if owner_champion is Annie else null
	var will_stun := annie.increment_stun_counter() if annie else false

	var dmg := BASE_DMG[rank] + owner_champion.ability_power * AP_RATIO
	var pre_hp := target.current_hp if target.has_variable("current_hp") else 1.0

	CombatSystem.deal_damage(owner_champion, target, dmg, CombatSystem.DamageType.MAGIC, true)

	# Stun on passive proc
	if will_stun and is_instance_valid(target):
		StatusEffect.make_stun(target, 1.75)

	# Refund mana if target died
	if is_instance_valid(target) and target.has_variable("current_hp") and target.current_hp <= 0.0:
		owner_champion.current_mana = minf(
			owner_champion.current_mana + get_mana_cost(),
			owner_champion.max_mana
		)
