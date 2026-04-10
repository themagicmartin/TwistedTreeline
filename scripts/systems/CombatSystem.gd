extends Node
# CombatSystem — static helpers for damage calculation and combat events.
# Not a scene node; call its static methods from anywhere.

class_name CombatSystem

enum DamageType { PHYSICAL, MAGIC, TRUE_DAMAGE }

# Physical damage: reduced by armor
# Formula matches LoL: effective_dmg = raw * (100 / (100 + armor))
static func calc_physical(raw: float, target_armor: float) -> float:
	var armor := maxf(target_armor, 0.0)
	return raw * (100.0 / (100.0 + armor))


# Magic damage: reduced by magic resistance
static func calc_magic(raw: float, target_mr: float) -> float:
	var mr := maxf(target_mr, 0.0)
	return raw * (100.0 / (100.0 + mr))


# Apply damage to a unit (must have take_damage method)
static func deal_damage(
	source: Node,
	target: Node,
	amount: float,
	dtype: DamageType,
	is_ability: bool = false
) -> float:
	if not target.has_method("take_damage"):
		return 0.0
	if not is_instance_valid(target):
		return 0.0

	var final_amount: float
	match dtype:
		DamageType.PHYSICAL:
			final_amount = calc_physical(amount, target.armor)
		DamageType.MAGIC:
			final_amount = calc_magic(amount, target.magic_resist)
		DamageType.TRUE_DAMAGE:
			final_amount = amount

	target.take_damage(final_amount, source, dtype)
	return final_amount


# Basic attack from source to target
static func basic_attack(source: Node, target: Node) -> float:
	if not is_instance_valid(target):
		return 0.0
	var raw := source.attack_damage
	var dmg := deal_damage(source, target, raw, DamageType.PHYSICAL, false)
	# Trigger on-hit effects
	if source.has_signal("on_basic_attack_hit"):
		source.emit_signal("on_basic_attack_hit", target, dmg)
	return dmg


# Check if source and target are on opposing teams
static func is_enemy(source: Node, target: Node) -> bool:
	if not "team" in source or not "team" in target:
		return false
	return source.team != target.team and target.team != GameManager.Team.NONE


# Check if source and target are on the same team
static func is_ally(source: Node, target: Node) -> bool:
	if not "team" in source or not "team" in target:
		return false
	return source.team == target.team


# Compute XP award value for a unit kill (rough scale)
static func kill_xp(killed: Node) -> float:
	if "xp_value" in killed:
		return killed.xp_value
	return 0.0


# Compute gold award for a unit kill
static func kill_gold(killed: Node) -> float:
	if "gold_value" in killed:
		return killed.gold_value
	return 0.0
