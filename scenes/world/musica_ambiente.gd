extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		if stream.loop_end <= 0:
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)
	if not playing:
		play()

func _on_finished() -> void:
	play()
