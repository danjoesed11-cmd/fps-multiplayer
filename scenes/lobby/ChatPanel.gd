class_name ChatPanel
extends Control

@onready var message_log: RichTextLabel = %MessageLog
@onready var input_field: LineEdit = %InputField
@onready var send_button: Button = %SendButton

var _max_messages := 100

func _ready() -> void:
	EventBus.chat_message_received.connect(_on_message_received)
	send_button.pressed.connect(_on_send)
	input_field.text_submitted.connect(_on_text_submitted)

func _on_send() -> void:
	var text := input_field.text.strip_edges()
	if text.is_empty():
		return
	_send_message(text, "all")
	input_field.text = ""

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_send_message(text.strip_edges(), "all")
	input_field.text = ""

func _send_message(text: String, channel: String) -> void:
	var my_name := PlayerRegistry.get_display_name(multiplayer.get_unique_id())
	_broadcast_chat.rpc_id(1, my_name, text, channel)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_chat(sender_name: String, message: String, channel: String) -> void:
	if multiplayer.is_server():
		_receive_chat.rpc(sender_name, message, channel)
	else:
		EventBus.chat_message_received.emit(sender_name, message, channel)

@rpc("authority", "call_local", "reliable")
func _receive_chat(sender_name: String, message: String, channel: String) -> void:
	EventBus.chat_message_received.emit(sender_name, message, channel)

func _on_message_received(sender: String, message: String, _channel: String) -> void:
	message_log.append_text("\n[b]%s:[/b] %s" % [sender, message])
	while message_log.get_line_count() > _max_messages:
		var lines := message_log.text.split("\n")
		message_log.text = "\n".join(lines.slice(1))
