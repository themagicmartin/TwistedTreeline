extends ChampionBase
# Annie — Mage
# Passive: Every 4th ability cast stuns the next target hit.
# Q: Disintegrate (refund mana on kill)
# W: Incinerate (cone AOE)
# E: Molten Shield (self shield + return dmg)
# R: Summon: Tibbers (AOE summon + damage)

var stun_counter: int = 0
const STUN_THRESHOLD := 4

func _ready() -> void:
	champion_name     = "Annie"
	base_hp           = 523.0
	base_hp_per_level = 88.0
	base_mana         = 418.0
	base_mana_per_level = 25.0
	base_ad           = 50.5
	base_ad_per_level = 3.0
	base_ap           = 0.0
	base_armor        = 21.0
	base_armor_per_level = 4.0
	base_mr           = 30.0
	base_move_speed   = 335.0
	base_attack_range = 625.0
	gold_value        = 300.0
	xp_value          = 200.0
	super()._ready()


func _setup_abilities() -> void:
	ability_q = load("res://scripts/champion/annie/AnnieQ.gd").new()
	ability_q.name = "AnnieQ"
	add_child(ability_q)

	ability_w = load("res://scripts/champion/annie/AnnieW.gd").new()
	ability_w.name = "AnnieW"
	add_child(ability_w)

	ability_e = load("res://scripts/champion/annie/AnnieE.gd").new()
	ability_e.name = "AnnieE"
	add_child(ability_e)

	ability_r = load("res://scripts/champion/annie/AnnieR.gd").new()
	ability_r.name = "AnnieR"
	add_child(ability_r)

	ability_q.rank = 1
	ability_w.rank = 1
	ability_e.rank = 1
	ability_r.rank = 1


func increment_stun_counter() -> bool:
	# Returns true if this cast should stun the target
	stun_counter += 1
	if stun_counter >= STUN_THRESHOLD:
		stun_counter = 0
		return true
	return false
