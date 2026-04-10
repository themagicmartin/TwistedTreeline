extends AbilitySystem
# Garen W — Courage
# Passive: permanently increases armor and MR as Garen kills units (up to +30 armor/MR).
# Active: Garen braces for 0.75s (damage reduction 60%), then maintains 30% reduction for duration.

class_name GarenW

const ACTIVE_DURATION := [0.0, 2.0, 3.0, 4.0, 5.0, 6.0]
const DAMAGE_REDUCTION_ACTIVE := 0.30  # 30% after brace phase
const DAMAGE_REDUCTION_BRACE  := 0.60  # 60% during 0.75s brace
const BRACE_DURATION := 0.75

var passive_stacks: int = 0
const MAX_PASSIVE_STACKS := 30
const PASSIVE_ARMOR_PER_STACK := 1.0

func _ready() -> void:
	ability_name    = "Courage"
	cast_type       = CastType.INSTANT
	cooldown_base   = 24.0
	mana_cost_base  = 0.0
	max_rank        = 5
	super()._ready()


func get_cooldown() -> float:
	return [24.0, 22.0, 20.0, 18.0, 16.0][rank - 1] if rank > 0 else cooldown_base


func cast(_target = null) -> void:
	var c := owner_champion
	if c == null:
		return
	# Apply brace phase (60% DR for 0.75s) then active phase
	var brace := _CourageShield.new()
	brace.dr = DAMAGE_REDUCTION_BRACE
	brace.duration = BRACE_DURATION
	c.add_child(brace)

	await get_tree().create_timer(BRACE_DURATION).timeout

	var active := _CourageShield.new()
	active.dr = DAMAGE_REDUCTION_ACTIVE
	active.duration = ACTIVE_DURATION[rank] - BRACE_DURATION
	c.add_child(active)


# Called by kill events to increment passive stacks
func on_unit_killed() -> void:
	if passive_stacks >= MAX_PASSIVE_STACKS:
		return
	passive_stacks += 1
	if owner_champion:
		owner_champion.armor += PASSIVE_ARMOR_PER_STACK
		owner_champion.magic_resist += PASSIVE_ARMOR_PER_STACK * 0.5


class _CourageShield extends Node:
	var dr: float = 0.3
	var duration: float = 2.0
	var _elapsed: float = 0.0

	func _ready() -> void:
		if get_parent().has_method("apply_damage_reduction"):
			get_parent().active_damage_reduction = maxf(get_parent().active_damage_reduction, dr)

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration:
			if get_parent().has_variable("active_damage_reduction"):
				get_parent().active_damage_reduction = 0.0
			queue_free()
