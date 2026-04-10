extends ChampionBase
# Ashe — Marksman
# Q: Ranger's Focus (volley of arrows in cone)
# W: Volley (cone of 7 arrows, all slow)
# E: Hawkshot (fires a hawk that reveals an area)
# R: Enchanted Crystal Arrow (global stunning arrow)

func _ready() -> void:
	champion_name     = "Ashe"
	base_hp           = 570.0
	base_hp_per_level = 90.0
	base_mana         = 280.0
	base_mana_per_level = 35.0
	base_ad           = 61.0
	base_ad_per_level = 3.0
	base_armor        = 26.0
	base_armor_per_level = 4.0
	base_mr           = 30.0
	base_move_speed   = 325.0
	base_attack_range = 600.0
	gold_value        = 300.0
	xp_value          = 200.0
	super()._ready()


func _setup_abilities() -> void:
	ability_q = load("res://scripts/champion/ashe/AsheQ.gd").new()
	ability_q.name = "AsheQ"
	add_child(ability_q)

	ability_w = load("res://scripts/champion/ashe/AsheW.gd").new()
	ability_w.name = "AsheW"
	add_child(ability_w)

	ability_e = load("res://scripts/champion/ashe/AsheE.gd").new()
	ability_e.name = "AsheE"
	add_child(ability_e)

	ability_r = load("res://scripts/champion/ashe/AsheR.gd").new()
	ability_r.name = "AsheR"
	add_child(ability_r)

	ability_q.rank = 1
	ability_w.rank = 1
	ability_e.rank = 1
	ability_r.rank = 1
