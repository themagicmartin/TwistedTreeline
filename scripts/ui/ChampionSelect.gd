extends Control
# ChampionSelect — MVP solo-only version.
# Pick Garen, press Ready, game starts.

const CHAMPION_SCENES := {
	"Garen": "res://scenes/Champions/Garen.tscn",
	#"Ashe":  "res://scenes/Champions/Ashe.tscn",
	#"Annie": "res://scenes/Champions/Annie.tscn",
}

var selected_champion: String = ""


func _ready() -> void:
	%GarenCard.pressed.connect(func(): _select_champion("Garen"))
	#%AsheCard.pressed.connect(func():  _select_champion("Ashe"))
	#%AnnieCard.pressed.connect(func(): _select_champion("Annie"))

	%ReadyButton.pressed.connect(_on_ready_pressed)


func _select_champion(champ_name: String) -> void:
	selected_champion = champ_name
	%SelectionLabel.text = "Selected: " + champ_name
	%ReadyButton.disabled = false


func _on_ready_pressed() -> void:
	if selected_champion.is_empty():
		return
	GameManager.state = GameManager.GameState.IN_GAME
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
