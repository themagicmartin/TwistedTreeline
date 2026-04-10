extends AbilitySystem
# Garen E — Judgment
# Garen rapidly spins his sword, dealing physical damage to all nearby enemies.
# Lasts 3 seconds. Each spin tick happens every 0.33s.

class_name GarenE

const SPIN_DURATION     := 3.0
const TICK_INTERVAL     := 0.33
const SPIN_RADIUS       := 325.0
const BASE_DMG_PER_TICK := [0.0, 14.0, 18.0, 22.0, 26.0, 30.0]
const AD_RATIO_PER_TICK := 0.32

func _ready() -> void:
	ability_name   = "Judgment"
	cast_type      = CastType.INSTANT
	cooldown_base  = 9.0
	mana_cost_base = 0.0
	max_rank       = 5
	super()._ready()


func get_cooldown() -> float:
	return [9.0, 8.0, 7.0, 6.0, 5.0][rank - 1] if rank > 0 else cooldown_base


func cast(_target = null) -> void:
	var c := owner_champion
	if c == null:
		return
	var spinner := _SpinNode.new()
	spinner.champion = c
	spinner.damage_per_tick = BASE_DMG_PER_TICK[rank] + c.attack_damage * AD_RATIO_PER_TICK
	spinner.radius = SPIN_RADIUS
	c.add_child(spinner)


class _SpinNode extends Node:
	var champion: Node = null
	var damage_per_tick: float = 14.0
	var radius: float = 325.0
	var _elapsed: float = 0.0
	var _tick_elapsed: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		_tick_elapsed += delta

		if _tick_elapsed >= GarenE.TICK_INTERVAL:
			_tick_elapsed = 0.0
			_deal_spin_damage()

		if _elapsed >= GarenE.SPIN_DURATION:
			queue_free()

	func _deal_spin_damage() -> void:
		if champion == null:
			return
		for unit in champion.get_tree().get_nodes_in_group("all_units"):
			if not is_instance_valid(unit):
				continue
			if not CombatSystem.is_enemy(champion, unit):
				continue
			if champion.global_position.distance_to(unit.global_position) <= radius:
				CombatSystem.deal_damage(champion, unit, damage_per_tick, CombatSystem.DamageType.PHYSICAL, true)
