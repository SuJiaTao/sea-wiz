extends RefCounted
class_name ToneSweep

# Builds short synthesized sounds: a tone gliding between two pitches under a
# thud of noise, like a generator spinning down or up.

const MIX_RATE: int = 22050
const PEAK: float = 32767.0
const THUD_TIME: float = 0.12


static func make(from_hz: float, to_hz: float, seconds: float, noise: float = 0.4) -> AudioStreamWAV:
	var frames := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for frame in frames:
		var t := float(frame) / MIX_RATE
		var progress := t / seconds
		phase += TAU * lerpf(from_hz, to_hz, progress) / MIX_RATE
		var envelope := sin(PI * minf(progress * 8.0, 1.0) * 0.5) * (1.0 - progress)
		var thud := (randf() * 2.0 - 1.0) * noise * maxf(1.0 - t / THUD_TIME, 0.0)
		var sample := (sin(phase) * 0.6 + sin(phase * 2.0) * 0.2) * envelope + thud
		data.encode_s16(frame * 2, int(clampf(sample, -1.0, 1.0) * PEAK))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
