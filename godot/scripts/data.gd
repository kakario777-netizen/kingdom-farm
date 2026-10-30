extends Node
## 게임 데이터(웹판에서 그대로 뽑은 표) + 3D 렌더 그림 묶음
var J: Dictionary = {}
var CROPS: Dictionary
var BUILDS: Dictionary
var GOALS: Array
var LANDS: Array
var RECTS: Array
var LV_XP: Array
var LV_MOJO: Dictionary
var CROP_ORDER: Array
var BUILD_ORDER: Array
var TABS: Array
var RULERS: Array
var CHARS: Dictionary
var COLS := 58
var ROWS := 58
var CX := 28
var CY := 28
var CI := 0
var PLOT_COST := 250
var DEV_SPEED := 20
const W2 := 48.0
const H2 := 24.0
const M := 60
const H := 3600
const DAY := 86400

var atlas: Dictionary = {}
var sheets: Array[Texture2D] = []
var font: FontFile
# 3D 그림이 아직 없는 건물 → 비슷한 그림으로 대신
const ALIAS := {}

func _init() -> void:
	var f := FileAccess.open("res://data/game_data.json", FileAccess.READ)
	J = JSON.parse_string(f.get_as_text())
	CROPS = J.CROPS; BUILDS = J.BUILDS; GOALS = J.GOALS; LANDS = J.LANDS; RECTS = J.RECTS
	LV_XP = J.LV_XP; LV_MOJO = J.LV_MOJO; CROP_ORDER = J.CROP_ORDER; BUILD_ORDER = J.BUILD_ORDER
	TABS = J.TABS; RULERS = J.RULERS; CHARS = J.CHARS
	COLS = int(J.COLS); ROWS = int(J.ROWS); CX = int(J.CX); CY = int(J.CY); PLOT_COST = int(J.PLOT_COST); DEV_SPEED = int(J.DEV_SPEED)
	CI = CY * COLS + CX
	var a := FileAccess.open("res://sprites/atlas.json", FileAccess.READ)
	var aj: Dictionary = JSON.parse_string(a.get_as_text())
	atlas = aj.s
	for n in aj.sheets:
		sheets.append(load("res://sprites/" + n))
	font = load("res://fonts/Jua-Regular.ttf")

static func P(u: float, v: float, z: float = 0.0) -> Vector2:
	return Vector2((u - v) * W2, (u + v) * H2 - z)

func key_of(k: String) -> String:
	if atlas.has(k): return k
	return ALIAS.get(k, "")

func has_spr(k: String) -> bool:
	return key_of(k) != ""

## 그림 하나를 Sprite2D 로 (발밑 기준점이 원점)
func make_sprite(k: String) -> Sprite2D:
	var s := Sprite2D.new()
	set_sprite(s, k)
	return s

func set_sprite(s: Sprite2D, k: String) -> void:
	var kk := key_of(k)
	if kk == "":
		s.texture = null; return
	var e: Array = atlas[kk]
	var res: float = e[7]
	s.texture = sheets[int(e[0])]
	s.region_enabled = true
	s.region_rect = Rect2(e[1], e[2], e[3], e[4])
	s.centered = false
	s.offset = Vector2(-float(e[5]), -float(e[6]))
	s.scale = Vector2.ONE / res
	s.set_meta("k", kk)

## 그림의 화면 높이(누르기 판정용)
func spr_h(k: String) -> float:
	var kk := key_of(k)
	if kk == "": return 0.0
	var e: Array = atlas[kk]
	return float(e[6]) / float(e[7]) - 8.0

## 카드·초상화용 잘라낸 그림
func thumb(k: String) -> AtlasTexture:
	var kk := key_of(k)
	if kk == "": return null
	var e: Array = atlas[kk]
	var t := AtlasTexture.new()
	t.atlas = sheets[int(e[0])]
	t.region = Rect2(e[1], e[2], e[3], e[4])
	return t

func face(k: String) -> AtlasTexture:
	var kk := key_of("pt_" + k)
	if kk == "": return null
	var e: Array = atlas[kk]
	var t := AtlasTexture.new()
	t.atlas = sheets[int(e[0])]
	var w: float = e[3]; var h: float = e[4]
	t.region = Rect2(float(e[1]) + w * 0.2, e[2], w * 0.6, h * 0.58)
	return t

func lv_xp(l: int) -> int:
	if l < LV_XP.size(): return int(LV_XP[l])
	return int(LV_XP[-1]) + (l - LV_XP.size() + 1) * 120000

func fmt(s: float) -> String:
	var t := int(max(0, ceil(s)))
	if t >= DAY:
		var d := t / DAY; var h := (t % DAY) / H
		return "%d일 %d시간" % [d, h] if h else "%d일" % d
	if t >= H:
		var h := t / H; var m := (t % H) / M
		return "%d시간 %d분" % [h, m] if m else "%d시간" % h
	if t >= M:
		var m := t / M; var x := t % M
		return "%d분 %d초" % [m, x] if (x and m < 10) else "%d분" % m
	return "%d초" % t

func comma(n: float) -> String:
	var s := str(int(n)); var out := ""; var neg := s.begins_with("-")
	if neg: s = s.substr(1)
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out
