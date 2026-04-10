extends CanvasLayer
# HUD — updates all UI elements each frame from the local player's champion state.

var local_champion: ChampionBase = null

# Kill tracking
var blue_kills: int = 0
var red_kills: int = 0


func _ready() -> void:
	GameManager.altar_captured.connect(_on_altar_captured)
	GameManager.vilemaw_killed.connect(_on_vilemaw_killed)


func set_local_champion(champion: ChampionBase) -> void:
	local_champion = champion
	%ChampName.text = champion.champion_name
	champion.health_changed.connect(_on_hp_changed)
	champion.mana_changed.connect(_on_mana_changed)
	champion.died.connect(_on_champion_died)
	_refresh_all()


func _process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.IN_GAME:
		return
	%GameTimer.text = GameManager.get_game_time_string()
	_update_ability_cooldowns()
	_update_gold()
	_update_level()
	_update_vilemaw_timer()


func _refresh_all() -> void:
	if local_champion == null:
		return
	_on_hp_changed(local_champion.current_hp, local_champion.max_hp)
	_on_mana_changed(local_champion.current_mana, local_champion.max_mana)


func _on_hp_changed(current: float, maximum: float) -> void:
	var bar := %HPBar
	bar.max_value = maximum
	bar.value = current
	%HPLabel.text = "%d / %d" % [int(current), int(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
	var bar := %ManaBar
	bar.max_value = maximum
	bar.value = current
	%ManaLabel.text = "%d / %d" % [int(current), int(maximum)]


func _on_champion_died(_champ: Node) -> void:
	# Track kills for scoreboard - champion died signal
	pass


func notify_kill(killing_team: int) -> void:
	if killing_team == GameManager.Team.BLUE:
		blue_kills += 1
	else:
		red_kills += 1
	%BlueScore.text = "Blue: %d" % blue_kills
	%RedScore.text  = "Red:  %d" % red_kills


func _update_ability_cooldowns() -> void:
	if local_champion == null:
		return
	_set_ability_cd(%QCooldown, local_champion.ability_q)
	_set_ability_cd(%WCooldown, local_champion.ability_w)
	_set_ability_cd(%ECooldown, local_champion.ability_e)
	_set_ability_cd(%RCooldown, local_champion.ability_r)


func _set_ability_cd(label: Label, ability: AbilitySystem) -> void:
	if ability == null or ability.cooldown_remaining <= 0.0:
		label.text = ""
	else:
		label.text = "%.1f" % ability.cooldown_remaining


func _update_gold() -> void:
	if local_champion == null:
		return
	var gold := EconomyManager.get_gold(local_champion.player_id)
	%GoldLabel.text = "Gold: %d" % int(gold)


func _update_level() -> void:
	if local_champion == null:
		return
	var lvl := EconomyManager.get_level(local_champion.player_id)
	%LevelLabel.text = "Lv: %d" % lvl


func _on_altar_captured(altar_id: int, team: int) -> void:
	var team_name := "Blue" if team == GameManager.Team.BLUE else "Red"
	if altar_id == 0:
		%AltarALabel.text = "Altar A: " + team_name
	else:
		%AltarBLabel.text = "Altar B: " + team_name


func _on_vilemaw_killed(_team: int) -> void:
	%VilemawPanel.visible = true


func _update_vilemaw_timer() -> void:
	var t := GameManager.vilemaw_spawn_timer
	if GameManager.vilemaw_alive:
		%VilemawPanel.visible = false
		return
	%VilemawPanel.visible = true
	if GameManager.game_time < GameManager.VILEMAW_SPAWN_TIME:
		%VilemawLabel.text = "Vilemaw: " + _fmt_time(t)
	else:
		%VilemawLabel.text = "Vilemaw Respawn: " + _fmt_time(t)


func _fmt_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]
