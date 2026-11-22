extends AbstractWeatherEffect
class_name RainSoundWeather

# A seamless loop of rain, such as on the deck or on the sea around the ship,
# that comes in with the rain and grows with how hard it falls.

const SILENT_DB: float = -60.0

@export var player: AudioStreamPlayer
## Level as the first rain starts, and in the heaviest downpour.
@export var light_db: float = -18.0
@export var heavy_db: float = -4.0


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
	player.volume_db = lerpf(light_db, heavy_db, share)
	if not player.playing:
		player.play(randf() * player.stream.get_length())
