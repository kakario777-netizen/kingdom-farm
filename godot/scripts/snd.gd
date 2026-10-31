extends Node
## 소리: 배경음 + 효과음(Kenney Interface Sounds·Jingles CC0, TinyWorlds huh CC0, 배경음 relaxed village CC-BY 4.0)
const MAP := {"click": "click_002", "tap": "select_001", "open": "open_001", "close": "close_001", "tab": "tick_002",
	"coin": "glass_001", "coin2": "glass_002", "harvest": "pluck_001", "plant": "drop_002", "build": "confirmation_001",
	"place": "bong_001", "error": "error_004", "mojo": "maximize_004", "star": "glass_005", "toggle": "switch_002",
	"pickup": "drop_001", "drop": "back_001", "levelup": "jingles_STEEL00", "goal": "jingles_STEEL04", "quest": "jingles_STEEL09",
	"expand": "jingles_PIZZA00", "huh": "huh", "confirm2": "confirmation_002"}
var cache := {}
var players: Array[AudioStreamPlayer] = []
var bgm: AudioStreamPlayer
var _last := {}
var _huh_t := -10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in 10:
		var p := AudioStreamPlayer.new(); add_child(p); players.append(p)
	bgm = AudioStreamPlayer.new(); add_child(bgm)
	var s: AudioStreamMP3 = load("res://sfx/bgm.mp3")
	s.loop = true; bgm.stream = s; bgm.volume_db = -12.0

func opt(k: String) -> bool:
	return bool(G.S.get("opts", {}).get(k, true)) if not G.S.is_empty() else true

func start_bgm() -> void:
	if opt("bgm") and not bgm.playing: bgm.play()
	elif not opt("bgm"): bgm.stop()

func _stream(name: String) -> AudioStream:
	if cache.has(name): return cache[name]
	var f: String = MAP.get(name, name)
	var path := "res://sfx/%s.ogg" % f
	if not ResourceLoader.exists(path): path = "res://sfx/%s.wav" % f
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	cache[name] = st
	return st

func play(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not opt("sfx"): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < 0.05: return
	_last[name] = now
	var st := _stream(name)
	if st == null: return
	for p in players:
		if not p.playing:
			p.stream = st; p.volume_db = vol; p.pitch_scale = pitch; p.play(); return
	players[0].stream = st; players[0].volume_db = vol; players[0].pitch_scale = pitch; players[0].play()

## 주민 반응 "으응?" — 3가지 높이 중 하나, 1초에 한 번만
func huh() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _huh_t < 1.0: return false
	_huh_t = now
	play("huh", 0.0, [0.86, 1.05, 1.28][randi() % 3])
	return true
