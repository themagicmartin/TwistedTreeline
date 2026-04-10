extends ChampionBase
class_name Garen
# Garen — Fighter
# Q: Decisive Strike (silence + damage)
# W: Courage (passive armor boost + active damage reduction shield)
# E: Judgment (AOE spin damage)
# R: Demacian Justice (execute based on % missing HP)

func _ready() -> void:
	champion_name    = "Garen"
	base_hp          = 690.0
	base_hp_per_level = 104.0
	base_mana        = 0.0      # Garen has no mana (courage resource)
	base_mana_per_level = 0.0
	base_ad          = 66.0
	base_ad_per_level = 4.5
	base_armor       = 36.0
	base_armor_per_level = 4.0
	base_mr          = 32.0
	base_move_speed  = 340.0
	base_attack_range = 175.0
	gold_value       = 300.0
	xp_value         = 220.0
	super()._ready()


func _setup_abilities() -> void:
	ability_q = GarenQ.new()
	ability_q.name = "GarenQ"
	add_child(ability_q)

	ability_w = GarenW.new()
	ability_w.name = "GarenW"
	add_child(ability_w)

	ability_e = GarenE.new()
	ability_e.name = "GarenE"
	add_child(ability_e)

	ability_r = GarenR.new()
	ability_r.name = "GarenR"
	add_child(ability_r)

	# Garen starts with rank 1 in each (for MVP; normally levels through game)
	ability_q.rank = 1
	ability_w.rank = 1
	ability_e.rank = 1
	ability_r.rank = 1
