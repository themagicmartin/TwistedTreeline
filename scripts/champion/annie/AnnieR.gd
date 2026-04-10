extends AbilitySystem
# Annie R — Summon: Tibbers
# Summons a giant bear at target location dealing AOE magic damage.
# Tibbers persists for 45 seconds and deals damage to nearby enemies each second.

const BASE_DMG   := [0.0, 200.0, 325.0, 450.0]
const AP_RATIO   := 0.70
const TIBBERS_DURATION := 45.0
const TIBBERS_AOE      := 290.0
const TIBBERS_TICK_DMG := [0.0, 35.0, 50.0, 65.0]
const TIBBERS_TICK_AP  := 0.20

func _ready() -> void:
	ability_name   = "Summon: Tibbers"
	cast_type      = CastType.POINT_CLICK
	cooldown_base  = 130.0
	mana_cost_base = 100.0
	range          = 600.0
	max_rank       = 3
	super()._ready()


func _is_non_interruptible() -> bool:
	return true


func get_cooldown() -> float:
	return [130.0, 115.0, 100.0][rank - 1] if rank > 0 else cooldown_base


func cast(target = null) -> void:
	if owner_champion.has_method("increment_stun_counter"):
		owner_champion.increment_stun_counter()

	var spawn_pos: Vector2
	if target is Vector2:
		spawn_pos = target
	else:
		spawn_pos = owner_champion.global_position

	# Initial AOE burst at cast location
	var dmg := BASE_DMG[rank] + owner_champion.ability_power * AP_RATIO
	for unit in owner_champion.get_tree().get_nodes_in_group("all_units"):
		if not CombatSystem.is_enemy(owner_champion, unit):
			continue
		if spawn_pos.distance_to(unit.global_position) <= TIBBERS_AOE:
			CombatSystem.deal_damage(owner_champion, unit, dmg, CombatSystem.DamageType.MAGIC, true)
			# Stun if passive proc active
			if owner_champion.has_method("increment_stun_counter") and owner_champion.stun_counter == 0:
				StatusEffect.make_stun(unit, 1.75)

	# Spawn Tibbers
	var tibbers := _Tibbers.new()
	tibbers.position = spawn_pos
	tibbers.source = owner_champion
	tibbers.tick_damage = TIBBERS_TICK_DMG[rank] + owner_champion.ability_power * TIBBERS_TICK_AP
	tibbers.aoe_radius = TIBBERS_AOE
	owner_champion.get_parent().add_child(tibbers)


class _Tibbers extends Node2D:
	var source: Node = null
	var tick_damage: float = 35.0
	var aoe_radius: float = 290.0
	var _elapsed: float = 0.0
	var _tick_timer: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		_tick_timer += delta
		if _tick_timer >= 1.0:
			_tick_timer = 0.0
			_deal_aura_damage()
		if _elapsed >= AnnieR.TIBBERS_DURATION:
			queue_free()

	func _deal_aura_damage() -> void:
		if source == null:
			return
		for unit in get_tree().get_nodes_in_group("all_units"):
			if not CombatSystem.is_enemy(source, unit):
				continue
			if global_position.distance_to(unit.global_position) <= aoe_radius:
				CombatSystem.deal_damage(source, unit, tick_damage, CombatSystem.DamageType.MAGIC, true)
