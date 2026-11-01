extends HUDPanel
class_name ScoreHUD

const ORIGIN := Vector2(28, 140)
const LINE_GAP: float = 20.0
const SCORE_SIZE: int = 18
const DETAIL_SIZE: int = 12
const COMBO_BAR := Vector2(90, 8)
const COMBO_BAR_OFFSET := Vector2(70, -9)
const POPUP_OFFSET := Vector2(70, -46)
const POPUP_RISE: float = 26.0
const POPUP_STACK: float = 18.0
const POPUP_TIME: float = 1.4
const POPUP_FADE: float = 0.5
const POPUP_SIZE: int = 14
const MAX_POPUPS: int = 4
const SUMMARY_LIFT: float = 20.0
const SUMMARY_SIZE: int = 20
const SCORE_DIGITS := "%07d"

@export var score: ScoreKeeper

var _popups: Array[ScorePopup] = []


func _ready() -> void:
	score.scored.connect(_on_scored)


func _on_scored(points: int, label: String, multiplier: int) -> void:
	var text := "+%d  %s" % [points, label]
	if multiplier > 1:
		text += "  x%d" % multiplier
	_popups.push_front(ScorePopup.new(text))
	if _popups.size() > MAX_POPUPS:
		_popups.pop_back()


func _update_hud(delta: float) -> void:
	for popup in _popups:
		popup.age += delta
	_popups = _popups.filter(func(popup: ScorePopup) -> bool: return popup.age < POPUP_TIME)


func _draw() -> void:
	_draw_tally()
	_draw_popups()
	if score.finished:
		_draw_summary()


func _draw_tally() -> void:
	_text(ORIGIN, "SCORE  " + SCORE_DIGITS % score.score, SCORE_SIZE)
	_text(ORIGIN + Vector2(0, LINE_GAP), "BEST   " + SCORE_DIGITS % maxi(score.best, score.score), DETAIL_SIZE, DIM)
	var combo := score.combo
	if combo.multiplier <= 1:
		return
	var line := ORIGIN + Vector2(0, LINE_GAP * 2.0)
	_text(line, "CHAIN x%d" % combo.multiplier, DETAIL_SIZE)
	_bar(line + COMBO_BAR_OFFSET, COMBO_BAR, combo.fraction_left())


func _draw_popups() -> void:
	var anchor := size * 0.5 + POPUP_OFFSET
	for index in _popups.size():
		var popup := _popups[index]
		var fade := clampf((POPUP_TIME - popup.age) / POPUP_FADE, 0.0, 1.0)
		var at := anchor - Vector2(0, POPUP_RISE * popup.age / POPUP_TIME + POPUP_STACK * index)
		_text(at, popup.text, POPUP_SIZE, Color(MAIN, MAIN.a * fade))


func _draw_summary() -> void:
	var line := "FINAL SCORE  %d" % score.score
	if score.new_best:
		line += "   NEW BEST"
	_center(size.y * 0.5 + SUMMARY_LIFT, line, SUMMARY_SIZE)
