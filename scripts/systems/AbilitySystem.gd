extends Node
class_name AbilitySystem
# AbilitySystem — base class for all champion abilities.
# Each ability (Q/W/E/R) extends this and overrides cast().

enum CastType {
	INSTANT,      # activates immediately on self or at cursor position
	TARGETED,     # requires an enemy target
	SKILLSHOT,    # fires a projectile toward cursor
	AOE,          # affects area around champion or cursor
	POINT_CLICK,  # click a point, champion moves/blinks there
}

@export var ability_name: String = "Ability"
@export var cast_type: CastType = CastType.INSTANT
@export var cooldown_base: float = 5.0
@export var mana_cost_base: float = 50.0
@export var base_damage: float = 0.0
@export var ap_ratio: float = 0.0
@export var ad_ratio: float = 0.0
@export var cast_range: float = 600.0
@export var rank: int = 0           # 0 = not learned, 1–5 (or 1–3 for R)
@export var max_rank: int = 5

var cooldown_remaining: float = 0.0
var owner_champion: Node = null  # set by champion on ready

signal cast_performed(ability: Node)


func _ready() -> void:
	owner_champion = get_parent()


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta


func get_cooldown() -> float:
	return cooldown_base  # subclasses can scale by rank


func get_mana_cost() -> float:
	return mana_cost_base


func can_cast() -> bool:
	if owner_champion == null:
		return false
	if rank == 0:
		return false
	if cooldown_remaining > 0.0:
		return false
	if owner_champion.current_mana < get_mana_cost():
		return false
	if _has_blocking_cc():
		return false
	return true


func _has_blocking_cc() -> bool:
	for child in owner_champion.get_children():
		if child is StatusEffect:
			if child.effect_type in [StatusEffect.Type.STUN, StatusEffect.Type.KNOCKUP, StatusEffect.Type.KNOCKBACK]:
				return true
			if child.effect_type == StatusEffect.Type.SILENCE and not _is_non_interruptible():
				return true
	return false


func _is_non_interruptible() -> bool:
	# R abilities that are not interrupted by silence can override this
	return false


# Call this to attempt a cast. target can be a Node or Vector2.
func try_cast(target = null) -> bool:
	if not can_cast():
		return false
	owner_champion.current_mana -= get_mana_cost()
	cooldown_remaining = get_cooldown()
	cast(target)
	cast_performed.emit(self)
	return true


# Override in subclasses
func cast(_target = null) -> void:
	pass


func level_up() -> void:
	if rank < max_rank:
		rank += 1


func get_damage() -> float:
	if owner_champion == null:
		return base_damage
	return base_damage + owner_champion.ability_power * ap_ratio + owner_champion.attack_damage * ad_ratio


func get_cooldown_percent() -> float:
	if get_cooldown() <= 0.0:
		return 0.0
	return clampf(cooldown_remaining / get_cooldown(), 0.0, 1.0)
