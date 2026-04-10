extends CanvasLayer

func _ready() -> void:
	visible = false
	GameManager.game_ended.connect(_on_game_ended)
	%PlayAgainButton.pressed.connect(_on_play_again)
	%MainMenuButton.pressed.connect(_on_main_menu)


func _on_game_ended(winning_team: int) -> void:
	visible = true
	var team_name := "Blue" if winning_team == GameManager.Team.BLUE else "Red"
	%ResultLabel.text = "VICTORY"
	%TeamLabel.text = team_name + " Team Wins!"
	%TimeLabel.text = "Game time: " + GameManager.get_game_time_string()


func _on_play_again() -> void:
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/ChampionSelect.tscn")
