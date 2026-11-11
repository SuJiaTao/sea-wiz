extends HUDPanel
class_name SupplyManifestHUD

const TITLE := "RESUPPLY MANIFEST  /  SELECT 1 OF %d"
const REPLACE_TITLE := "SLOTS FULL  /  REPLACE FOR %s"
const DISCARD_LABEL := "3   KEEP CURRENT, DISCARD %s"
const HINT := "PRESS 1 / 2 / 3"
const SELECT_TONE: AudioStream = preload("res://audio/supply/supply_select.wav")
const PANEL_WIDTH: float = 520.0
const PANEL_TOP: float = 0.56
const TITLE_HEIGHT: float = 34.0
const ROW_HEIGHT: float = 50.0
const PADDING := Vector2(18, 26)
const DESCRIPTION_DROP: float = 18.0
const CATEGORY_INSET: float = 110.0
const TITLE_FONT: int = 14
const LABEL_FONT: int = 15
const DESCRIPTION_FONT: int = 11
const BACKING := Color(0.0, 0.05, 0.0, 0.55)

@export var manifest: SupplyManifest

var _tone: AudioStreamPlayer


func _ready() -> void:
	_tone = AudioStreamPlayer.new()
	_tone.stream = SELECT_TONE
	add_child(_tone)
	manifest.closed.connect(_on_closed)


func _draw() -> void:
	if get_tree().paused or not manifest.is_open():
		return
	var offers := manifest.offers
	var rows := offers.size() + (1 if manifest.is_replacing() else 0)
	var height := TITLE_HEIGHT + ROW_HEIGHT * rows + PADDING.y
	var panel := Rect2(
		Vector2((size.x - PANEL_WIDTH) * 0.5, size.y * PANEL_TOP), Vector2(PANEL_WIDTH, height)
	)
	draw_rect(panel, BACKING)
	draw_rect(panel, DIM, false)
	var origin := panel.position + PADDING
	var title := REPLACE_TITLE % manifest.pending.label if manifest.is_replacing() else TITLE % offers.size()
	_text(origin, title, TITLE_FONT)
	_text(origin + Vector2(PANEL_WIDTH - CATEGORY_INSET - PADDING.x, 0), HINT, DESCRIPTION_FONT, FAINT)
	for index in offers.size():
		var row := origin + Vector2(0, TITLE_HEIGHT + ROW_HEIGHT * index)
		var offer := offers[index]
		_text(row, "%d   %s" % [index + 1, offer.label], LABEL_FONT)
		_text(row + Vector2(PANEL_WIDTH - CATEGORY_INSET - PADDING.x, 0), offer.category.to_upper(), DESCRIPTION_FONT, FAINT)
		_text(row + Vector2(0, DESCRIPTION_DROP), offer.description, DESCRIPTION_FONT, DIM)
	if manifest.is_replacing():
		var last := origin + Vector2(0, TITLE_HEIGHT + ROW_HEIGHT * offers.size())
		_text(last, DISCARD_LABEL % manifest.pending.label, LABEL_FONT, DIM)


func _on_closed(_choice: Upgrade) -> void:
	_tone.play()
