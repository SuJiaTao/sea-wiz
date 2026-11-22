extends AbstractWeatherEffect
class_name DeckRainWeather

# Rain drumming on the deck and the mount's steel: a seamless loop that comes
# in with the rain and grows with how hard it falls.

## Level as the first rain starts, and in the heaviest downpour.
const LIGHT_DB: float = -18.0
const HEAVY_DB: float = -4.0
const SILENT_DB: float = -60.0

@export var player: AudioStreamPlayer


func _ready() -> void:
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
	player.volume_db = SILENT_DB


func _apply(profile: WeatherProfile, strength: float, _delta: float) -> void:
	var share := clampf(profile.rain_rate / SeaStateWeather.FULL_RAIN_RATE, 0.0, 1.0) * strength
	if share <= 0.0:
		if player.playing:
			player.stop()
		return
	player.volume_db = lerpf(LIGHT_DB, HEAVY_DB, share)
	if not player.playing:
		player.play(randf() * player.stream.get_length())
