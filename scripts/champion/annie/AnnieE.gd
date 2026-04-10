extends AbilitySystem
# Annie E — Molten Shield
# Shields Annie for a duration, reflecting a portion of damage taken back at attackers.

const SHIELD_AMOUNT := [0.0, 60.0, 100.0, 140.0, 180.0, 220.0]
const AP_RATIO      := 0.30
const REFLECT_DMG   := [0.0, 20.0, 30.0, 40.0, 50.0, 60.0]
const DURATION       := [0.0, 4.0, 5.0, 6.0, 7.0, 8.0]

func _ready() -> void:
	ability_name   = "Molten Shield"
	cast_type      = CastType.INSTANT
	cooldown_base  = 10.0
	mana_cost_base = 20.0
	max_rank       = 5
	super()._ready()


func cast(_target = null) -> void:
	var c := owner_champion
	if c == null:
		return
	if c.has_method("increment_stun_counter"):
		c.increment_stun_counter()

	var shield_hp := SHIELD_AMOUNT[rank] + c.ability_power * AP_RATIO
	var reflect   := REFLECT_DMG[rank]
	var dur       := DURATION[rank]

	var shield := _MoltenShield.new()
	shield.shield_remaining = shield_hp
	shield.reflect_damage = reflect
	shield.duration = dur
	c.add_child(shield)


class _MoltenShield extends Node:
	var shield_remaining: float = 60.0
	var reflect_damage: float = 20.0
	var duration: float = 4.0
	var _elapsed: float = 0.0
	# Intercept damage via take_damage override not possible in GDScript directly;
	# Instead, register with champion so it can absorb before HP loss.

	func _ready() -> void:
		if get_parent().has_method("register_shield"):
			get_parent().register_shield(self)

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration or shield_remaining <= 0.0:
			if get_parent().has_method("unregister_shield"):
				get_parent().unregister_shield(self)
			queue_free()

	func absorb(amount: float, source: Node) -> float:
		# Returns remaining damage after shield absorbs
		var absorbed := minf(amount, shield_remaining)
		shield_remaining -= absorbed
		if source and is_instance_valid(source) and source.has_method("take_damage"):
			CombatSystem.deal_damage(get_parent(), source, reflect_damage, CombatSystem.DamageType.MAGIC, true)
		return amount - absorbed
