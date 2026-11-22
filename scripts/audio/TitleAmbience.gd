extends AudioStreamPlayer
class_name TitleAmbience

# The night sea under the title: a seamless loop that plays while the title
# is up and fades out as the screen goes dark.

const LEVEL_DB: float = -6.0

@export var title: TitleScreen


func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


func _process(_delta: float) -> void:
	if not title.visible:
		if playing:
			stop()
		return
	volume_db = LEVEL_DB + linear_to_db(maxf(1.0 - title.darkness(), 0.0001))
	if not playing:
		play(randf() * stream.get_length())
