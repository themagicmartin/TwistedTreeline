extends AbilitySystem
# Garen R — Demacian Justice
# Calls down a magical sword on a targeted enemy champion.
# Deals true damage equal to: base + (target's missing HP * scaling).
# Iconic execute ability.

class_name GarenR

const BASE_DMG    := [0.0, 175.0, 350.0, 525.0]
const MISSING_HP_RATIO := 0.20  # 20% of target's missing HP as bonus true damage

func _ready() -> void:
	ability_name   = "Demacian Justice"
	cast_type      = CastType.TARGETED
	cooldown_base  = 120.0
	mana_cost_base = 0.0
	cast_range     = 400.0
	max_rank       = 3
	super()


func _is_non_interruptible() -> bool:
	return true  # R is not interrupted by silence


func get_cooldown() -> float:
	return [120.0, 100.0, 80.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var c := owner_champion
	if c == null:
		return

	# Calculate damage
	var missing_hp: float = (target.max_hp as float) - (target.current_hp as float)
	var total_dmg: float = (BASE_DMG[rank] as float) + missing_hp * MISSING_HP_RATIO

	# Small delay for dramatic effect, then deal damage
	await get_tree().create_timer(0.5).timeout

	if is_instance_valid(target):
		CombatSystem.deal_damage(c, target, total_dmg, CombatSystem.DamageType.TRUE_DAMAGE, true)
