extends CanvasLayer

@onready var winner_label: Label = %WinnerLabel
@onready var continue_button: Button = %ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)

func set_winner(team_id: int) -> void:
	winner_label.text = "TEAM %d WINS!" % (team_id + 1)

func _on_continue() -> void:
	GameManager.return_to_main_menu()
