extends Resource
class_name FlybySound

## A recorded jet pass and when in it the jet is closest.

@export var stream: AudioStream
## Seconds into the recording at the loudest point, when the jet goes by.
@export var closest_at: float = 3.0
