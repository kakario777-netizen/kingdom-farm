extends CanvasLayer
## 화면 UI: 상단 바 · 목표 카드 · 확대 버튼 · 창(상점·정보) · 대화 · 레벨업 · 알림 · 놓기 막대 · 시작 화면 · 손가락 안내
const L := Color("#4a2a17")
const L2 := Color("#2e1a0e")
const CREAM := Color("#fff6e4")
const INK := Color("#4e2e1c")
const INK_SOFT := Color("#7a5238")
const COLS := {"pink": [Color("#ff8ab4"), Color("#e8457f")], "yellow": [Color("#ffd84a"), Color("#f0a21a")],
	"mint": [Color("#45d6a0"), Color("#1fae7c")], "purple": [Color("#9d78ff"), Color("#7650e6")],
	"white": [Color("#fdf6ea"), Color("#e2d0b4")], "red": [Color("#ff6464"), Color("#d93636")], "orange": [Color("#ff9a48"), Color("#e2641e")]}

var world
var root: Control
var hud: HBoxContainer
var gold_l: Label
var mojo_l: Label
var clock_l: Label
var lv_l: Label
var xp_bar: ProgressBar
var name_l: Label
var sub_l: Label
var face_r: TextureRect
var goal_btn: Button
var goal_ic: TextureRect
var goal_t: Label
var goal_p: Label
var sheet_bg: Control
var sheet: PanelContainer
var sheet_title: Label
var sheet_rib: TextureRect
var rib_color := "coral"
var sheet_body: VBoxContainer
var sheet_scroll: ScrollContainer
var live_l: Label = null
var live_fn: Callable
var talk_box: Control
var talk_txt: Label
var talk_btn: Button
var talk_extra: HBoxContainer
var talk_queue: Array = []
var talk_fn: Callable
var talking := false
var lv_box: Control
var lv_queue: Array = []
var toast_p: PanelContainer
var toast_l: Label
var place_bar: PanelContainer
var all_btn: Button
var shop_btn: Button
var buy_bar: PanelContainer
var buy_l: Label
var buy_btn: Button
var place_l: Label
var place_cancel: Button
var hand: Control
var intro: Control
var shop_tab := "house"
var _live_t := 0.0
var _hud_t := 0.0

func _ready() -> void:
	layer = 5
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var th := Theme.new(); th.default_font = D.font; th.default_font_size = 16
	th.set_color("font_color", "Label", INK)
	root.theme = th
	_build_hud(); _build_goal(); _build_zoom(); _build_sheet(); _build_talk(); _build_lv(); _build_toast(); _build_place(); _build_buy(); _build_hand()
	G.changed.connect(update_hud)
	G.castle_up.connect(confetti)
	G.toast.connect(toast)
	G.level_up.connect(func(lv, mj):
		lv_queue.append([lv, mj])
		if not lv_box.visible: get_tree().create_timer(0.45).timeout.connect(_show_lv))
	update_hud()
	if not G.S.started: show_intro()
	else: G.check_daily()
	SND.start_bgm()


# =============== 그림 UI 도우미 (GPT 크레파스 그림, 늘리지 않고 비율 그대로) ===============
var _tex_cache := {}
func gtex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var path := "res://ui/g/%s.webp" % id
		_tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[id]

func gaspect(id: String) -> float:
	var t := gtex(id)
	return float(t.get_width()) / float(t.get_height()) if t else 1.0

## 그림 한 장(비율 유지). w나 h 중 하나만 주면 나머지는 비율로
func gimg(id: String, w := -1.0, h := -1.0) -> TextureRect:
	var r := TextureRect.new(); r.texture = gtex(id); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var a := gaspect(id)
	if w > 0 and h < 0: h = w / a
	elif h > 0 and w < 0: w = h * a
	r.custom_minimum_size = Vector2(w, h); r.size = Vector2(w, h)
	return r

## 글자가 칸 너비를 넘으면 글자 크기를 줄여서 맞춤
func fit(l: Label, maxw: float, size: int, minsize := 10) -> Label:
	var fs := size
	while fs > minsize and D.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw: fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	return l

## 칸(x,y,w,h) 정중앙에 글자
func clab(text: String, size: int, col: Color, box: Rect2, outline := 0, ocol := L, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := lab(text, size, col, outline, ocol)
	l.horizontal_alignment = align; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = box.position; l.size = box.size; l.clip_text = false
	fit(l, box.size.x, size, min(8, size))
	l.clip_text = true
	return l

# 버튼 그림 후보: [그림, 가로/세로 비율(측정값)]. 글자 길이에 맞는 가장 짧은 그림을 고름(늘리지 않음)
const BTN_IMGS := {
	"yellow": ["btn_quest_claim", "btn_buy_land", "btn_collect", "btn_levelup_ok"],
	"mint": ["btn_yes", "btn_start_job"],
	"white": ["btn_place_cancel", "btn_no"],
	"pink": ["btn_next", "btn_start"],
	"purple": ["btn_finish_now"],
	"red": ["btn_start"], "orange": ["btn_collect"],
}

# =============== 스타일 도우미 ===============
func sbox(bg: Color, border := L, bw := 3, radius := 16, bottom := -1, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.border_width_bottom = bottom if bottom >= 0 else bw
	s.set_corner_radius_all(radius); s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Color(0.16, 0.08, 0.02, 0.28); s.shadow_size = shadow; s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 10; s.content_margin_right = 10; s.content_margin_top = 4; s.content_margin_bottom = 4
	return s

func lab(text: String, size := 16, col := INK, outline := 0, ocol := L) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", ocol); l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 젤리 버튼: 몸통 + 아래 두꺼운 턱 + 위쪽 광택
## 그림 버튼: 글자 길이에 맞는 버튼 그림을 골라 비율 그대로 씀. 아래 25%는 턱이라 글자는 윗면 가운데
func jbtn(text: String, color := "pink", size := 17, ic: Texture2D = null) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE; b.text = ""
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var h: float = round(size * 2.5)
	var tw: float = D.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pick: String = BTN_IMGS.get(color, BTN_IMGS["pink"])[0]
	for id in BTN_IMGS.get(color, BTN_IMGS["pink"]):
		pick = id
		if (h * gaspect(id)) * 0.78 >= tw: break
	var w := h * gaspect(pick)
	var left := 0.27 if pick == "btn_finish_now" else 0.08
	b.custom_minimum_size = Vector2(w, h)
	var bg := gimg(pick, w, h); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); b.add_child(bg)
	var light := color in ["yellow", "white", "orange"]
	var fc := Color("#5a3010") if light else Color.WHITE
	var l := clab(text, size, fc, Rect2(w * left, 0, w * (0.92 - left), h * 0.76), 0 if light else 5, L)
	l.name = "T"; b.add_child(l)
	b.set_meta("lab", l)
	b.button_down.connect(func(): bg.modulate = Color(0.88, 0.88, 0.88); SND.play("click", -4.0))
	b.button_up.connect(func(): bg.modulate = Color.WHITE)
	b.draw.connect(func(): bg.modulate = Color(0.72, 0.72, 0.72, 0.9) if b.disabled else bg.modulate)
	return b

## 정해진 그림 버튼(아이콘 들어간 그림): 글자칸 x0~x1(그림 비율)
func ibtn(id: String, text: String, h := 40.0, x0 := 0.3, x1 := 0.95, light := true) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var w := h * gaspect(id); b.custom_minimum_size = Vector2(w, h)
	var bg := gimg(id, w, h); b.add_child(bg)
	var l := clab(text, 15, Color("#5a3010") if light else Color.WHITE, Rect2(w * x0, 0, w * (x1 - x0), h * 0.76), 0 if light else 5, L)
	b.add_child(l); b.set_meta("lab", l)
	b.button_down.connect(func(): bg.modulate = Color(0.88, 0.88, 0.88); SND.play("click", -4.0))
	b.button_up.connect(func(): bg.modulate = Color.WHITE)
	b.draw.connect(func(): bg.modulate = Color(0.72, 0.72, 0.72, 0.9) if b.disabled else bg.modulate)
	return b

## 버튼 글자 바꾸기(그림 버튼용)
func set_btext(b: Button, t: String) -> void:
	var l: Label = b.get_meta("lab", null)
	if l: l.text = t; fit(l, l.size.x, int(l.get_theme_font_size("font_size")) + 4)

func round_btn(glyph: String, color := "white") -> Button:
	var id: String = {"+": "btn_zoom_in", "−": "btn_zoom_out", "⌂": "btn_zoom_home", "✕": "btn_close", "⚙": "hud_settings_btn"}.get(glyph, "btn_zoom_home")
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(44, 44)
	var bg := gimg(id, 44, 44); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); b.add_child(bg)
	b.button_down.connect(func(): bg.modulate = Color(0.88, 0.88, 0.88); SND.play("click", -4.0))
	b.button_up.connect(func(): bg.modulate = Color.WHITE)
	return b

func panel(bg := CREAM, radius := 18, bw := 3, shadow := 5) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sbox(bg, L, bw, radius, bw + 3, shadow)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p

func capsule(dark := true) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sbox(Color("#5c3c28") if dark else CREAM, L2 if dark else L, 3, 22, 5, 3)
	s.content_margin_left = 6; s.content_margin_right = 12; s.content_margin_top = 2; s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	return p

## 동전·물방울·별 아이콘(벡터라 어떤 해상도에서도 선명)
## 아이콘(그림): coin·mojo·star·sickle·shop 등
func icon(kind: String, sz := 28.0) -> Control:
	var id: String = {"coin": "ic_coin", "mojo": "ic_gem", "star": "ic_xp", "sickle": "ic_sickle", "shop": "ic_shop"}.get(kind, "ic_" + kind)
	return gimg(id, sz, sz)

func pic(tex: Texture2D, sz := 64.0, grass := true) -> Control:
	var box := PanelContainer.new()
	var s := StyleBoxFlat.new(); s.set_corner_radius_all(14); s.anti_aliasing = true
	s.bg_color = Color("#bfe89c") if grass else Color(1, 1, 1, 0); s.border_color = Color(0.29, 0.16, 0.09, 0.5)
	if grass: s.set_border_width_all(2)
	s.content_margin_left = 3; s.content_margin_right = 3; s.content_margin_top = 3; s.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", s); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new(); tr.texture = tex; tr.custom_minimum_size = Vector2(sz, sz)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.add_child(tr)
	return box

# =============== 상단 바 ===============
func _build_hud() -> void:
	# 화면 832×384 기준 고정 배치(겹침 없음). 글자·아이콘은 그림마다 잰 칸의 정중앙
	hud = HBoxContainer.new(); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.visible = false; root.add_child(hud)
	var top := Control.new(); top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top)
	# 초상(누르면 내 왕국)
	var me := Control.new(); me.position = Vector2(8, 4); me.size = Vector2(44, 44); top.add_child(me)
	face_r = TextureRect.new(); face_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; face_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face_r.position = Vector2(6, 6); face_r.size = Vector2(32, 32); face_r.mouse_filter = Control.MOUSE_FILTER_IGNORE; me.add_child(face_r)
	var ring := gimg("portrait_ring", 44, 44); me.add_child(ring)
	me.gui_input.connect(func(e):
		if _tap(e): open_me())
	name_l = lab("", 1); sub_l = lab("", 1)
	# 레벨 별 + 경험치
	var bd := gimg("hud_level_badge", 42, 42); bd.position = Vector2(56, 5); top.add_child(bd)
	lv_l = clab("1", 17, Color.WHITE, Rect2(0, 2, 42, 40), 5, L); bd.add_child(lv_l)
	var xf := gimg("hud_xp_frame", 96, -1); xf.position = Vector2(100, 26 - xf.size.y / 2); top.add_child(xf)
	xp_bar = ProgressBar.new(); xp_bar.show_percentage = false; xp_bar.position = Vector2(xf.size.x * 0.031, xf.size.y * 0.17); xp_bar.size = Vector2(xf.size.x * 0.938, xf.size.y * 0.66)
	var fill := StyleBoxTexture.new(); fill.texture = gtex("hud_xp_fill")
	xp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new()); xp_bar.add_theme_stylebox_override("fill", fill); xf.add_child(xp_bar)
	# 골드·보석·시계 (홈 중심·글자칸은 그림을 재서 얻은 비율)
	var cap := func(id: String, x: float, w: float, hole: Vector2, hd: float, ic: String, tx0: float, tx1: float) -> Label:
		var c := gimg(id, w, -1); c.position = Vector2(x, 26 - c.size.y / 2); top.add_child(c)
		var i := gimg(ic, hd, hd); i.position = Vector2(c.size.x * hole.x - hd / 2, c.size.y * hole.y - hd / 2); c.add_child(i)
		var l := clab("0", 18, INK, Rect2(c.size.x * tx0, 0, c.size.x * (tx1 - tx0), c.size.y)); c.add_child(l)
		return l
	gold_l = cap.call("hud_gold", 202, 150, Vector2(0.14, 0.514), 25, "ic_coin", 0.224, 0.86)
	mojo_l = cap.call("hud_gem", 358, 104, Vector2(0.19, 0.511), 25, "ic_gem", 0.311, 0.86)
	clock_l = cap.call("hud_clock", 468, 124, Vector2(0.155, 0.503), 22, "ic_clock", 0.245, 0.86)
	# 설정(오른쪽 위)
	var st := round_btn("⚙"); st.anchor_left = 1; st.anchor_right = 1; st.offset_left = -54; st.offset_right = -10; st.offset_top = 4; st.offset_bottom = 48
	st.pressed.connect(open_dev); top.add_child(st)

func _tap(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

var _last_gold := -1.0
func update_hud() -> void:
	var S := G.S
	var g: float = floor(S.gold)
	gold_l.text = D.comma(g); mojo_l.text = str(S.mojo); lv_l.text = str(S.level)
	fit(gold_l, gold_l.size.x, 18); fit(mojo_l, mojo_l.size.x, 18)
	if _last_gold >= 0 and g != _last_gold: _bump(gold_l.get_parent())
	_last_gold = g
	var a := D.lv_xp(S.level); var b := D.lv_xp(S.level + 1)
	xp_bar.value = 100.0 * (S.xp - a) / max(1, b - a)
	name_l.text = S.name; sub_l.text = "%s · %s" % [_ruler_name(), D.LANDS[S.land].n]
	face_r.texture = D.face(S.ruler)
	_update_clock(); _update_goal()

func _bump(n: Control) -> void:
	n.pivot_offset = n.size / 2
	var tw := n.create_tween(); tw.tween_property(n, "scale", Vector2(1.15, 1.15), 0.12); tw.tween_property(n, "scale", Vector2.ONE, 0.18)

func _ruler_name() -> String:
	for r in D.RULERS:
		if r.k == G.S.ruler: return r.n
	return "왕"

func _update_clock() -> void:
	var gt: float = G.S.gt
	var day := int(gt / D.DAY) + 1; var h := int(fmod(gt, D.DAY) / D.H); var m := int(fmod(gt, D.H) / D.M)
	clock_l.text = "%d일차 %02d:%02d" % [day, h, m] + (" ×%d" % G.S.speed if float(G.S.speed) != 1.0 else "")
	fit(clock_l, clock_l.size.x, 13)

# =============== 목표 카드 ===============
func _build_goal() -> void:
	goal_btn = Button.new(); goal_btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: goal_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	goal_btn.position = Vector2(10, 56); goal_btn.custom_minimum_size = Vector2(220, 60); goal_btn.size = Vector2(220, 60)
	var bg := gimg("hud_goal_card", 220, 60); goal_btn.add_child(bg)
	goal_ic = TextureRect.new(); goal_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; goal_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goal_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; goal_ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	goal_ic.size = Vector2(34, 34); goal_ic.position = Vector2(220 * 0.184 - 17, 60 * 0.541 - 17); goal_btn.add_child(goal_ic)
	goal_t = clab("", 13, INK, Rect2(220 * 0.335, 60 * 0.534 - 20, 220 * 0.6, 20), 0, L, HORIZONTAL_ALIGNMENT_LEFT); goal_btn.add_child(goal_t)
	goal_p = clab("", 12, INK_SOFT, Rect2(220 * 0.335, 60 * 0.534, 220 * 0.6, 18), 0, L, HORIZONTAL_ALIGNMENT_LEFT); goal_btn.add_child(goal_p)
	goal_btn.pressed.connect(_on_goal)
	root.add_child(goal_btn)

func _update_goal() -> void:
	if not G.S.started:
		goal_btn.visible = false; return
	var g := G.goal_now()
	goal_btn.visible = true
	if g.is_empty():
		var dn := G.quests_done()
		goal_t.text = "왕국 목표"; goal_p.text = ("%d개 완료! 보상 받기" % dn) if dn else "눌러서 목표 보기"; goal_ic.texture = D.thumb("castle1")
		goal_p.add_theme_color_override("font_color", Color("#c2560c") if dn else INK_SOFT)
	else:
		goal_t.text = g.t
		var gk: String = "plot" if g.ic == "plot" else ("crop_corn_icon" if g.ic == "corn" else g.ic)
		var gtx: Texture2D = gtex("ic_coin") if g.ic == "coin" else (gtex("ic_gem") if g.ic == "mojo" else D.thumb(gk))
		goal_ic.texture = gtx if gtx else gtex("ic_quest")
		goal_p.text = "완료! 눌러서 보상 받기" if G.goal_ready() else "%d / %d" % [G.goal_prog(), int(g.n)]
		goal_p.add_theme_color_override("font_color", Color("#c2560c") if G.goal_ready() else INK_SOFT)
	fit(goal_t, goal_t.size.x, 13); fit(goal_p, goal_p.size.x, 12)

func _on_goal() -> void:
	if talking: return
	var g := G.goal_now()
	if g.is_empty(): open_quests(); return
	if G.goal_ready(): claim_goal()
	else: say([{"t": g.d, "btn": "알겠어요"}])

func claim_goal() -> void:
	var g := G.goal_now()
	if g.is_empty() or not G.goal_ready(): return
	var rw := []
	if g.get("g"): rw.append(["coin", int(g.g)])
	rw.append(["star", int(g.x)])
	say([{"t": "훌륭해요, 폐하! '%s' 완료예요." % g.t, "rw": rw, "btn": "받기", "fn": func():
		SND.play("goal"); G.S.gold += float(g.get("g", 0)); G.pop.emit(D.CI, ("+%d" % g.g) if g.get("g") else "목표 완료", "gd"); G.gain_xp(int(g.x), D.CI); G.set_goal(G.S.goal + 1)
		var n := G.goal_now()
		if not n.is_empty(): say([{"t": n.d, "btn": "알겠어요"}])
		else: say([{"t": "기본은 모두 익히셨어요! 이제 이 왕국은 온전히 폐하의 것이에요."}, {"t": "이제부터는 왕국 목표가 3개씩 생겨요. 레벨을 올려 새 작물과 가게를 열고, 빈 땅을 알뜰하게 채워보세요!", "btn": "시작!"}, {"t": "왼쪽 위 목표 카드를 누르면 목표를 볼 수 있어요.", "btn": "알겠어요"}])
		G.done_action()}])

# =============== 확대 버튼 ===============
func _build_zoom() -> void:
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8)
	vb.anchor_left = 1; vb.anchor_right = 1; vb.anchor_top = 1; vb.anchor_bottom = 1
	vb.offset_left = -54; vb.offset_top = -256; vb.offset_right = -10; vb.offset_bottom = -90
	var zi := round_btn("+"); zi.pressed.connect(func(): world.zoom_at(1.25, root.size / 2))
	var zo := round_btn("−"); zo.pressed.connect(func(): world.zoom_at(0.8, root.size / 2))
	var zf := round_btn("⌂"); var fit_all := [false]
	zf.pressed.connect(func():
		fit_all[0] = not fit_all[0]
		if fit_all[0] and world.full_view(): world.fit_all()
		else:
			fit_all[0] = false; world.fit_cam())
	for b in [zi, zo, zf]: vb.add_child(b)
	root.add_child(vb)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10)
	hb.anchor_left = 1; hb.anchor_right = 1; hb.anchor_top = 1; hb.anchor_bottom = 1
	hb.grow_horizontal = Control.GROW_DIRECTION_BEGIN; hb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hb.offset_right = -10; hb.offset_bottom = -12
	all_btn = big_btn("모두 수확", "mint", "sickle"); all_btn.visible = false
	all_btn.pressed.connect(func(): SND.play("harvest"); G.collect_all())
	shop_btn = big_btn("상점", "yellow", "shop"); shop_btn.pressed.connect(func(): open_shop(false))
	hb.add_child(all_btn); hb.add_child(shop_btn)
	root.add_child(hb)

## 아이콘 달린 큰 버튼(우하단)
## 우하단 큰 버튼: 그림 그대로(150×64), 글자는 그림 옆 빈칸 정중앙(그림마다 잰 값)
func big_btn(text: String, color: String, ic: String) -> Button:
	var id := "btn_harvest_all" if ic == "sickle" else "btn_shop"
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(150, 64)
	var bg := gimg(id, 150, 64); b.add_child(bg)
	var cx := 0.654 if ic == "sickle" else 0.665; var cy := 0.49 if ic == "sickle" else 0.417
	var x0 := 0.34 if ic == "sickle" else 0.36; var wd := (cx - x0) * 2.0
	var l := clab(text, 19, Color.WHITE if ic == "sickle" else Color("#6e4418"), Rect2(150 * x0, 64 * cy - 14, 150 * wd, 28), 6 if ic == "sickle" else 0, Color("#46782a"))
	b.add_child(l)
	b.button_down.connect(func(): bg.modulate = Color(0.9, 0.9, 0.9); SND.play("click", -4.0))
	b.button_up.connect(func(): bg.modulate = Color.WHITE)
	return b

# =============== 큰 창(시트) ===============
var sheet_over: Control
var sheet_kind := "shop"
const WIN_KIND := {"shop": "shop", "seed": "seed", "quest": "quest", "settings": "settings", "building": "building", "castle": "castle", "profile": "profile", "levelup": "levelup", "confirm": "confirm"}
func _build_sheet() -> void:
	sheet_bg = Control.new(); sheet_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sheet_bg.visible = false
	var dim := ColorRect.new(); dim.color = Color(0.23, 0.14, 0.09, 0.35); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if _tap(e): close_sheet())
	sheet_bg.add_child(dim)
	sheet = PanelContainer.new(); sheet.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var win := TextureRect.new(); win.name = "Win"; win.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; win.stretch_mode = TextureRect.STRETCH_SCALE
	win.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; win.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_bg.add_child(win)
	sheet_bg.add_child(sheet)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); sheet.add_child(vb)
	sheet_scroll = ScrollContainer.new(); sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sheet_scroll)
	sheet_body = VBoxContainer.new(); sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sheet_body.add_theme_constant_override("separation", 10)
	var mb := MarginContainer.new(); mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]: mb.add_theme_constant_override("margin_" + k, 4)
	mb.add_child(sheet_body); sheet_scroll.add_child(mb)
	# 리본·닫기는 창 위에 겹쳐 얹는 층
	sheet_over = Control.new(); sheet_over.mouse_filter = Control.MOUSE_FILTER_IGNORE; sheet_bg.add_child(sheet_over)
	sheet_rib = TextureRect.new(); sheet_rib.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; sheet_rib.stretch_mode = TextureRect.STRETCH_SCALE
	sheet_rib.mouse_filter = Control.MOUSE_FILTER_IGNORE; sheet_rib.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; sheet_over.add_child(sheet_rib)
	sheet_title = lab("", 20, Color.WHITE, 6, L); sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sheet_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sheet_over.add_child(sheet_title)
	var close := round_btn("✕"); close.name = "Close"; close.custom_minimum_size = Vector2(36, 36); close.size = Vector2(36, 36)
	close.pressed.connect(close_sheet); sheet_over.add_child(close)
	root.add_child(sheet_bg)

func open_sheet(title: String, kind := "") -> VBoxContainer:
	if kind != "": sheet_kind = kind
	var k: String = WIN_KIND.get(sheet_kind, "shop")
	if not sheet_bg.visible: SND.play("open", -3.0)
	for c in sheet_body.get_children(): c.queue_free()
	live_l = null
	sheet_bg.visible = true
	var vs := root.size
	# 창 그림 비율 그대로: 화면에 들어가는 가장 큰 크기(위 자원칸은 가리지 않게 y≥62)
	var a := gaspect("win_" + k)
	var maxw: float = min(740.0, vs.x - 24); var maxh: float = min(vs.y - 74, 320.0)
	var w: float = min(maxw, maxh * a); var h: float = w / a
	var x: float = (vs.x - w) / 2; var y: float = vs.y - h - 8
	var win: TextureRect = sheet_bg.get_node("Win"); win.texture = gtex("win_" + k); win.position = Vector2(x, y); win.size = Vector2(w, h)
	# 안쪽 판(그림마다 잰 값 ≈ 좌우 3.5%, 위 10%, 아래 9.5%)에서 조금 더 안쪽
	sheet.position = Vector2(x + w * 0.05, y + h * 0.12); sheet.size = Vector2(w * 0.9, h * 0.8)
	sheet.custom_minimum_size = sheet.size
	# 리본: 창 윗선 가운데, 비율 그대로. 제목은 리본 가운데 띠 안
	var rib: Texture2D = gtex("rib_" + k)
	if rib == null: rib = gtex("rib_shop")
	var rh := 48.0; var rw := rh * float(rib.get_width()) / rib.get_height()
	sheet_rib.texture = rib; sheet_rib.position = Vector2(x + (w - rw) / 2, y - rh * 0.55); sheet_rib.size = Vector2(rw, rh)
	sheet_title.text = title; sheet_title.position = Vector2(x + (w - rw) / 2 + rw * 0.24, y - rh * 0.55 + rh * 0.16); sheet_title.size = Vector2(rw * 0.52, rh * 0.46)
	fit(sheet_title, sheet_title.size.x, 20, 11)
	var close: Control = sheet_over.get_node("Close"); close.position = Vector2(x + w - 36 - w * 0.025, y + h * 0.03)
	for n in [win, sheet, sheet_over]:
		n.pivot_offset = Vector2(x + w / 2, y + h / 2) - (n.position if n != sheet_over else Vector2.ZERO)
	sheet_over.position = Vector2.ZERO
	for n in [win, sheet]:
		n.scale = Vector2(0.92, 0.92); n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sheet_scroll.scroll_vertical = 0
	return sheet_body

func close_sheet() -> void:
	if sheet_bg.visible: SND.play("close", -4.0)
	sheet_bg.visible = false; live_l = null

func is_sheet_open() -> bool: return sheet_bg.visible

func row(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h

func grid() -> HFlowContainer:
	var f := HFlowContainer.new(); f.add_theme_constant_override("h_separation", 10); f.add_theme_constant_override("v_separation", 10); return f

func card(tex: Texture2D, title: String, sub: String, earn: String, lock_lv: int, on: Callable) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var W := 116.0; var H := W / gaspect("card_item")
	b.custom_minimum_size = Vector2(W, H)
	var locked: bool = lock_lv > 0 and int(G.S.level) < lock_lv
	var bg := gimg("card_item_locked" if locked else "card_item", W, H); b.add_child(bg)
	# 그림: 풀밭 받침(세로 40~62%) 위에 바닥을 맞춤
	var pic := TextureRect.new(); pic.texture = tex; pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = Vector2(W * 0.12, H * 0.06); pic.size = Vector2(W * 0.76, H * 0.48); b.add_child(pic)
	if locked: pic.modulate = Color(1, 1, 1, 0.5)
	b.add_child(clab(title, 14, INK, Rect2(W * 0.08, H * 0.63, W * 0.84, H * 0.11)))
	b.add_child(clab(sub, 11, INK_SOFT, Rect2(W * 0.08, H * 0.745, W * 0.84, H * 0.09)))
	b.add_child(clab(earn, 11, Color("#c2560c"), Rect2(W * 0.08, H * 0.835, W * 0.84, H * 0.09)))
	if locked:
		b.disabled = true
		var lk := gimg("ic_lock", 24, 24); lk.position = Vector2(W - 30, 6); b.add_child(lk)
		b.add_child(clab("Lv.%d" % lock_lv, 11, Color.WHITE, Rect2(W - 44, 30, 40, 14), 4, L))
	b.pressed.connect(on)
	b.button_down.connect(func(): bg.modulate = Color(0.93, 0.93, 0.93))
	b.button_up.connect(func(): bg.modulate = Color.WHITE)
	b.modulate.a = 0.0
	b.ready.connect(func():
		var tw := b.create_tween(); tw.tween_interval(0.04 * b.get_index()); tw.tween_property(b, "modulate:a", 1.0, 0.18))
	return b

## 상점 탭(같은 크기 6개): 켜짐·꺼짐 그림
func tab_btn(text: String, on: bool) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var h := 32.0; var w := h * gaspect("tab_on")
	b.custom_minimum_size = Vector2(w, h)
	b.add_child(gimg("tab_on" if on else "tab_off", w, h))
	b.add_child(clab(text, 15, INK, Rect2(w * 0.08, 0, w * 0.84, h)))
	b.button_down.connect(func(): SND.play("click", -4.0))
	return b

func info(tex: Texture2D, lines: Array, btns: Array) -> HBoxContainer:
	var h := row(14)
	h.add_child(pic(tex, 96))
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vb.add_theme_constant_override("separation", 4); h.add_child(vb)
	for l in lines: vb.add_child(l)
	var r := row(8)
	for b in btns: r.add_child(b)
	vb.add_child(r)
	return h

func live(fn: Callable) -> Label:
	live_l = lab("", 22, Color("#c2560c")); live_fn = fn; live_l.text = fn.call(); return live_l

# =============== 대화 ===============
func _build_talk() -> void:
	talk_box = Control.new(); talk_box.set_anchors_preset(Control.PRESET_FULL_RECT); talk_box.visible = false
	var block := ColorRect.new(); block.color = Color(0, 0, 0, 0); block.set_anchors_preset(Control.PRESET_FULL_RECT); talk_box.add_child(block)
	var who := gimg("pt_advisor", 116, -1); who.anchor_top = 1; who.anchor_bottom = 1
	who.offset_left = 8; who.offset_right = 8 + who.size.x; who.offset_top = -who.size.y - 4; who.offset_bottom = -4
	talk_box.add_child(who)
	var tw := who.create_tween().set_loops(); var t0 := who.offset_top
	tw.tween_property(who, "offset_top", t0 - 5, 1.2).set_trans(Tween.TRANS_SINE); tw.tween_property(who, "offset_top", t0, 1.2).set_trans(Tween.TRANS_SINE)
	# 대화판 그림(비율 그대로): 이름표·본문 칸은 그림을 잰 비율
	var W := 470.0; var H := W / gaspect("talk_box")
	var p := Control.new(); p.anchor_top = 1; p.anchor_bottom = 1; p.offset_left = 130; p.offset_right = 130 + W; p.offset_top = -H - 8; p.offset_bottom = -8
	p.size = Vector2(W, H); talk_box.add_child(p)
	p.add_child(gimg("talk_box", W, H))
	var nm := clab("몽실 대신", 13, Color.WHITE, Rect2(W * 0.051, H * 0.026, W * 0.32, H * 0.205), 5, Color("#c0506a")); p.add_child(nm)
	talk_txt = lab("", 15); talk_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; talk_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	talk_txt.position = Vector2(W * 0.05, H * 0.26); talk_txt.size = Vector2(W * 0.9, H * 0.42); p.add_child(talk_txt)
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 8); r.alignment = BoxContainer.ALIGNMENT_END
	r.position = Vector2(W * 0.05, H * 0.66); r.size = Vector2(W * 0.9, H * 0.28); p.add_child(r)
	talk_extra = row(6); talk_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL; talk_extra.alignment = BoxContainer.ALIGNMENT_BEGIN; r.add_child(talk_extra)
	talk_btn = jbtn("다음", "pink", 14); talk_btn.pressed.connect(_next_talk); talk_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r.add_child(talk_btn)
	root.add_child(talk_box)

var _say_n := 0
func say(lines: Array) -> void:
	talk_queue = lines.duplicate(); _say_n += 1; _show_line()

func _next_talk() -> void:
	var f := talk_fn; talk_fn = Callable()
	var n0 := _say_n
	if talk_queue.is_empty():
		talk_box.visible = false; talking = false
	if f.is_valid(): f.call()
	if _say_n != n0: return
	if not talk_queue.is_empty(): _show_line()

func _show_line() -> void:
	var l: Dictionary = talk_queue.pop_front()
	talk_txt.text = l.t; set_btext(talk_btn, l.get("btn", "다음"))
	talk_fn = l.get("fn", Callable())
	for c in talk_extra.get_children(): c.queue_free()
	for rw in l.get("rw", []): talk_extra.add_child(reward_chip(rw[0], rw[1]))
	var p: Control = talk_txt.get_parent()
	p.pivot_offset = p.size / 2; p.scale = Vector2(0.9, 0.9)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	talk_box.visible = true; talking = true

func reward_chip(kind: String, n: int) -> Control:
	var h := 28.0; var w := h * gaspect("reward_chip")
	var c := gimg("reward_chip", w, h); c.custom_minimum_size = Vector2(w, h)
	var i := icon(kind, 20); i.position = Vector2(w * 0.185 - 10, h * 0.507 - 10); c.add_child(i)
	c.add_child(clab(D.comma(n), 14, INK, Rect2(w * 0.3, 0, w * 0.64, h)))
	return c

# =============== 레벨업 ===============
func _build_lv() -> void:
	lv_box = Control.new(); lv_box.set_anchors_preset(Control.PRESET_FULL_RECT); lv_box.visible = false
	var dim := ColorRect.new(); dim.color = Color(0.23, 0.14, 0.09, 0.4); dim.set_anchors_preset(Control.PRESET_FULL_RECT); lv_box.add_child(dim)
	var rays := Control.new(); rays.set_anchors_preset(Control.PRESET_CENTER); rays.mouse_filter = Control.MOUSE_FILTER_IGNORE; lv_box.add_child(rays)
	rays.draw.connect(func():
		for k in 18:
			var a := k * TAU / 18.0
			rays.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 420, Vector2(cos(a + 0.17), sin(a + 0.17)) * 420]), Color(1, 0.93, 0.6, 0.28)))
	var rt := rays.create_tween().set_loops(); rt.tween_property(rays, "rotation", TAU, 14.0).from(0.0)
	root.add_child(lv_box)

func confetti() -> void:
	var cs := [Color("#ff6f9f"), Color("#ffc93c"), Color("#4fcfa8"), Color("#8b6cff"), Color("#6cc7ff")]
	for k in 46:
		var r := ColorRect.new(); r.color = cs[k % 5]; r.size = Vector2(9, 13); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(randf() * root.size.x, -20); r.rotation = randf() * TAU; r.pivot_offset = r.size / 2
		root.add_child(r)
		var d := randf_range(1.4, 2.4)
		var tw := r.create_tween().set_parallel()
		tw.tween_property(r, "position:y", root.size.y + 30, d).set_delay(randf() * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "position:x", r.position.x + randf_range(-60, 60), d).set_delay(randf() * 0.5)
		tw.tween_property(r, "rotation", r.rotation + randf_range(-8, 8), d)
		tw.chain().tween_callback(r.queue_free)

func _show_lv() -> void:
	if lv_queue.is_empty(): return
	var q: Array = lv_queue.pop_front(); var lv: int = q[0]; var mj: int = q[1]
	for c in lv_box.get_children():
		if c is PanelContainer: c.queue_free()
	var p := panel(Color("#fffaf0"), 26, 4, 10)
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH; p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new(); vb.alignment = BoxContainer.ALIGNMENT_CENTER; vb.add_theme_constant_override("separation", 8); p.add_child(vb)
	var t := lab("레벨 %d!" % lv, 40, Color("#ffd84a"), 12); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var r := row(6); r.alignment = BoxContainer.ALIGNMENT_CENTER; r.add_child(reward_chip("mojo", mj)); vb.add_child(r)
	var un := []
	for k in D.CROP_ORDER:
		if int(D.CROPS[k].lv) == lv: un.append([("crop_%s_2" % k), D.CROPS[k].n])
	for k in D.BUILD_ORDER:
		if int(D.BUILDS[k].lv) == lv: un.append([k, D.BUILDS[k].n])
	if un.size():
		var s := lab("새로 열렸어요", 15, INK_SOFT); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(s)
		var ur := row(14); ur.alignment = BoxContainer.ALIGNMENT_CENTER; vb.add_child(ur)
		for u in un.slice(0, 5):
			var c := VBoxContainer.new(); c.add_child(pic(D.thumb(u[0]), 54, false)); var nl := lab(u[1], 13); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; c.add_child(nl); ur.add_child(c)
	var ok := jbtn("좋아요!", "yellow", 22); ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; ok.custom_minimum_size.x = 170
	ok.pressed.connect(func():
		lv_box.visible = false
		if lv_queue.size(): get_tree().create_timer(0.2).timeout.connect(_show_lv))
	vb.add_child(ok)
	lv_box.add_child(p)
	lv_box.visible = true
	SND.play("levelup")
	confetti()
	await get_tree().process_frame
	p.pivot_offset = p.size / 2; p.scale = Vector2(0.5, 0.5)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rays: Control = lv_box.get_child(1); rays.position = root.size / 2

# =============== 알림·놓기 막대 ===============
func _build_toast() -> void:
	var w := 360.0; var h := w / gaspect("ui_toast")
	toast_p = PanelContainer.new(); toast_p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	toast_p.anchor_left = 0.5; toast_p.anchor_right = 0.5; toast_p.offset_left = -w / 2; toast_p.offset_right = w / 2; toast_p.offset_top = 60; toast_p.offset_bottom = 60 + h
	toast_p.visible = false; toast_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Control.new(); c.custom_minimum_size = Vector2(w, h); toast_p.add_child(c)
	c.add_child(gimg("ui_toast", w, h))
	toast_l = clab("", 15, Color.WHITE, Rect2(w * 0.1, 0, w * 0.8, h)); c.add_child(toast_l)
	root.add_child(toast_p)

var _toast_n := 0
func toast(msg: String) -> void:
	toast_l.text = msg; fit(toast_l, toast_l.size.x, 15); toast_p.visible = true; _toast_n += 1
	var n := _toast_n
	toast_p.modulate.a = 1.0
	get_tree().create_timer(2.2).timeout.connect(func():
		if n == _toast_n: toast_p.visible = false)

func _build_place() -> void:
	var w := 420.0; var h := w / gaspect("place_bar")
	place_bar = PanelContainer.new(); place_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	place_bar.anchor_left = 0.5; place_bar.anchor_right = 0.5; place_bar.offset_left = -w / 2; place_bar.offset_right = w / 2; place_bar.offset_top = 62; place_bar.offset_bottom = 62 + h
	var c := Control.new(); c.custom_minimum_size = Vector2(w, h); place_bar.add_child(c)
	c.add_child(gimg("place_bar", w, h))
	place_l = clab("", 14, INK, Rect2(w * 0.05, 0, w * 0.68, h), 0, L, HORIZONTAL_ALIGNMENT_LEFT); c.add_child(place_l)
	place_cancel = jbtn("그만", "white", 13); place_cancel.position = Vector2(w * 0.955 - place_cancel.custom_minimum_size.x, (h - place_cancel.custom_minimum_size.y) / 2)
	place_cancel.pressed.connect(stop_placing); c.add_child(place_cancel)
	place_bar.visible = false
	root.add_child(place_bar)

func start_placing(p: Dictionary) -> void:
	G.placing = p; close_sheet()
	var nm: String = "밭" if p.kind == "plot" else (D.BUILDS[G.S.tiles[p.from].b].n if p.kind == "move" else D.BUILDS[p.k].n)
	var multi: bool = p.kind == "plot" or (p.kind == "new" and D.BUILDS[p.k].cat in ["deco", "road", "fence"])
	place_l.text = ("%s 옮길 풀밭을 눌러주세요" % nm) if p.kind == "move" else ("%s 놓을 풀밭을 눌러주세요" % nm) + (" · 여러 개 가능" if multi else "")
	fit(place_l, place_l.size.x, 14); place_bar.visible = true

func stop_placing() -> void:
	G.placing = {}; place_bar.visible = false

func place_at(i: int) -> void:
	var p := G.placing
	if p.kind == "plot":
		if not G.make_plot(i): stop_placing()
	elif p.kind == "move":
		G.move_to(p.from, i); stop_placing()
	else:
		var ok := G.do_build(i, p.k)
		if not ok or not (D.BUILDS[p.k].cat in ["deco", "road", "fence"]): stop_placing()

# =============== 지도 누르기 ===============
func on_tap(i: int) -> void:
	if talking or is_sheet_open() or lv_box.visible or intro: return
	var c := i % D.COLS; var r := i / D.COLS; G.sel = i
	if G.catch_star(i): return
	if not G.unlocked(c, r):
		stop_placing()
		if G.is_next(c, r): start_land_preview()
		return
	var T: Dictionary = G.S.tiles[i]
	if not G.placing.is_empty():
		if T.t == "grass": place_at(i)
		else: toast("빈 풀밭을 눌러주세요")
		return
	match T.t:
		"grass":
			if G.goal_now().get("k", "") == "plots": shop_tab = "farm"
			open_shop(true)
		"castle": open_castle()
		"plot":
			match G.crop_state(T):
				"empty": open_seeds()
				"ready": G.harvest(i)
				"dead": T.erase("crop"); G.pop.emit(i, "시든 작물 정리", ""); G.done_action()
				_: open_growing()
		"bld":
			match G.bld_state(T):
				"build": open_building()
				"tax": G.collect_tax(i)
				"done": G.collect_job(i)
				"open": open_job()
				"work": open_working()
				"idle": open_tax()
				_: open_deco()

# =============== 창 종류 ===============
func open_seeds() -> void:
	var b := open_sheet("무엇을 심을까요?", "seed"); var gr := grid(); b.add_child(gr)
	for k in D.CROP_ORDER:
		var C: Dictionary = D.CROPS[k]; var kk: String = k
		gr.add_child(card(D.thumb("crop_%s_2" % k), C.n, "%s · %s" % [D.fmt(C.t), ("%dG" % C.cost) if C.cost else "무료"], "+%dG · +%dXP" % [C.g, C.x], int(C.lv),
			func():
				if G.plant(G.sel, kk): close_sheet()))

func mojo_btn(i: int) -> Button:
	var cost := G.mojo_cost(G.remain_of(G.S.tiles[i]))
	var b := ibtn("btn_finish_now", "%d개 바로 완성" % cost, 42, 0.27, 0.95, false)
	b.disabled = G.S.mojo < cost
	b.pressed.connect(func():
		if G.finish_now(i, cost): close_sheet())
	return b

func edit_btns(i: int) -> Array:
	var B: Dictionary = D.BUILDS[G.S.tiles[i].b]
	var mv := ibtn("btn_move", "옮기기", 40, 0.32, 0.95); mv.pressed.connect(func(): start_placing({"kind": "move", "from": i}))
	var sl := ibtn("btn_sell", "팔기 %dG" % int(B.cost / 4), 40, 0.32, 0.95); sl.pressed.connect(func(): G.sell(i); close_sheet())
	return [mv, sl]

func open_growing() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var C: Dictionary = D.CROPS[T.crop]
	var b := open_sheet("%s 자라는 중" % C.n, "seed")
	var cl := jbtn("뽑아내기", "white", 15); cl.pressed.connect(func(): G.clear_crop(i); close_sheet())
	b.add_child(info(D.thumb("crop_%s_2" % T.crop), [lab("남은 시간", 18), live(func(): return G.remain_txt(float(T.readyAt) - G.S.gt)), lab("다 자란 뒤 오래 두면 시들어요", 13, INK_SOFT)], [mojo_btn(i), cl]))

func open_building() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	var b := open_sheet("%s 공사 중" % B.n, "building")
	b.add_child(info(D.thumb(T.b), [lab("완성까지", 18), live(func(): return G.remain_txt(float(T.doneAt) - G.S.gt))], [mojo_btn(i)]))

func open_tax() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	var b := open_sheet(B.n, "building")
	b.add_child(info(D.thumb(T.b), [lab(B.d, 14, INK_SOFT), lab("다음 세금 +%dG" % B.g, 18), live(func(): return G.remain_txt(float(T.taxAt) - G.S.gt))], [mojo_btn(i)] + edit_btns(i)))

func open_job() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	var b := open_sheet("%s · 영업 중" % B.n, "building")
	var go := jbtn("일 시작하기", "mint", 16); go.pressed.connect(func(): G.start_job(i); close_sheet())
	b.add_child(info(D.thumb(T.b), [lab(B.item, 18), lab("만드는 데 %s · 완성하면 +%dG, +%dXP" % [D.fmt(B.jt), B.g, B.jx], 13, INK_SOFT)], [go] + edit_btns(i)))

func open_working() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	var b := open_sheet("%s · %s 만드는 중" % [B.n, B.item], "building")
	b.add_child(info(D.thumb(T.b), [lab("완성까지", 18), live(func(): return G.remain_txt(float(T.job.doneAt) - G.S.gt))], [mojo_btn(i)]))

func open_deco() -> void:
	var i := G.sel; var T: Dictionary = G.S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	var b := open_sheet(B.n, "building")
	b.add_child(info(D.thumb(T.b), [lab(B.get("d", ""), 15, INK_SOFT)], edit_btns(i)))

func expand_btn() -> Button:
	var n: Dictionary = D.LANDS[G.S.land + 1]
	var up: bool = n.n != D.LANDS[G.S.land].n
	var b := ibtn("btn_expand", ("%s로" % n.n if up else "땅 넓히기") + " %sG" % D.comma(n.cost), 42, 0.28, 0.95, false)
	b.disabled = G.S.level < int(n.lv) or G.S.gold < float(n.cost)
	b.disabled = false
	b.pressed.connect(start_land_preview)
	return b

func open_castle() -> void:
	var b := open_sheet(G.S.name, "castle")
	var lines := [lab("%s · 레벨 %d" % [D.LANDS[G.S.land].n, G.S.level], 19), lab("다음 레벨까지 %s XP · 밭 %d/%d" % [D.comma(D.lv_xp(G.S.level + 1) - G.S.xp), G.cnt(func(T): return T.t == "plot"), G.plot_cap()], 13, INK_SOFT)]
	var btns := [expand_btn()] if G.S.land + 1 < D.LANDS.size() else []
	b.add_child(info(D.thumb("castle%d" % G.castle_tier()), lines, btns))
	var s := lab("모조 얻는 법: 매일 출석 +2 · 레벨업 +3~10 · 목표 보상", 13, INK_SOFT); s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.add_child(s)

func open_expand() -> void:
	if G.S.land + 1 >= D.LANDS.size(): return
	var n: Dictionary = D.LANDS[G.S.land + 1]
	var b := open_sheet("땅 넓히기", "castle")
	b.add_child(info(D.thumb("castle%d" % G.castle_tier()), [lab("%d×%d 크기로 넓혀요" % [n.w, n.h], 19), lab("레벨 %d 이상 · %sG" % [n.lv, D.comma(n.cost)], 14, INK_SOFT)], [expand_btn()]))

# =============== 땅 사기 미리보기 ===============
func _build_buy() -> void:
	var w := 520.0; var h := w / gaspect("buy_bar")
	buy_bar = PanelContainer.new(); buy_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	buy_bar.anchor_left = 0; buy_bar.anchor_right = 0; buy_bar.anchor_top = 1; buy_bar.anchor_bottom = 1
	buy_bar.offset_left = 10; buy_bar.offset_right = 10 + w; buy_bar.offset_top = -h - 10; buy_bar.offset_bottom = -10
	var c := Control.new(); c.custom_minimum_size = Vector2(w, h); buy_bar.add_child(c)
	c.add_child(gimg("buy_bar", w, h))
	buy_l = clab("", 14, INK, Rect2(w * 0.11, 0, w * 0.5, h), 0, L, HORIZONTAL_ALIGNMENT_LEFT); c.add_child(buy_l)
	buy_btn = jbtn("구매하기", "yellow", 13)
	buy_btn.pressed.connect(func():
		var up: bool = D.LANDS[G.S.land + 1].n != D.LANDS[G.S.land].n
		if G.expand():
			SND.play("expand"); end_land_preview()
			if not up: confetti())
	var cancel := jbtn("취소", "white", 13); cancel.pressed.connect(end_land_preview)
	var cw: float = cancel.custom_minimum_size.x; var bw: float = buy_btn.custom_minimum_size.x
	cancel.position = Vector2(w * 0.955 - cw, (h - cancel.custom_minimum_size.y) / 2)
	buy_btn.position = Vector2(w * 0.955 - cw - 6 - bw, (h - buy_btn.custom_minimum_size.y) / 2)
	c.add_child(buy_btn); c.add_child(cancel)
	buy_bar.visible = false
	root.add_child(buy_bar)

func start_land_preview() -> void:
	if G.S.land + 1 >= D.LANDS.size(): return
	close_sheet(); stop_placing()
	var n: Dictionary = D.LANDS[G.S.land + 1]
	var short := ""
	if G.S.level < int(n.lv): short = " · 레벨 %d 필요" % int(n.lv)
	elif G.S.gold < float(n.cost): short = " · 골드 %s 모자라요" % D.comma(float(n.cost) - floor(G.S.gold))
	buy_l.text = "새 땅 %d×%d · %sG%s" % [n.w, n.h, D.comma(n.cost), short]
	buy_btn.disabled = short != ""
	fit(buy_l, buy_l.size.x, 14); world.set_preview(true); buy_bar.visible = true
	all_btn.get_parent().visible = false

func end_land_preview() -> void:
	buy_bar.visible = false; world.set_preview(false)
	all_btn.get_parent().visible = true

func open_shop(here: bool) -> void:
	var b := open_sheet("여기에 무엇을 지을까요?" if here else "상점", "shop")
	var tabs := row(5); b.add_child(tabs)
	for tb in D.TABS + [["land", "땅"]]:
		var k: String = tb[0]
		var t := tab_btn(tb[1], k == shop_tab)
		t.pressed.connect(func(): shop_tab = k; open_shop(here))
		tabs.add_child(t)
	var gr := grid(); b.add_child(gr)
	if shop_tab == "land":
		if G.S.land + 1 >= D.LANDS.size():
			gr.add_child(lab("지금은 여기까지 넓힐 수 있어요", 16, INK_SOFT)); return
		var nl: Dictionary = D.LANDS[G.S.land + 1]
		var lc := card(D.thumb("castle%d" % G.castle_tier()), "땅 넓히기", "%d×%d · %sG" % [nl.w, nl.h, D.comma(nl.cost)], ("%s 업그레이드" % nl.n) if nl.n != D.LANDS[G.S.land].n else "새 땅에 팻말을 박아 보여드려요", int(nl.lv), start_land_preview)
		gr.add_child(lc); return
	if shop_tab == "farm":
		var n := G.cnt(func(T): return T.t == "plot")
		var c := card(D.thumb("plot"), "밭", "%dG" % D.PLOT_COST, "%d / %d개" % [n, G.plot_cap()], 0, func():
			if here:
				if G.make_plot(G.sel): close_sheet()
			else: start_placing({"kind": "plot"}))
		c.disabled = n >= G.plot_cap(); gr.add_child(c)
		return
	for k in D.BUILD_ORDER:
		var B: Dictionary = D.BUILDS[k]
		var ok: bool = (B.cat in ["road", "fence"]) if shop_tab == "road" else B.cat == shop_tab
		if not ok: continue
		var earn: String = B.d if B.cat == "house" else ("%s · %s · +%dG" % [B.item, D.fmt(B.jt), B.g] if B.cat == "shop" else "+%dXP" % B.x)
		var kk: String = k
		gr.add_child(card(D.thumb(k), B.n, "%sG" % D.comma(B.cost) + (" · 공사 %s" % D.fmt(B.t) if float(B.t) > 0 else ""), earn, int(B.lv), func():
			if here:
				if G.do_build(G.sel, kk): close_sheet()
			else: start_placing({"kind": "new", "k": kk})))

func open_quests() -> void:
	G.ensure_quests()
	var b := open_sheet("왕국 목표", "quest")
	for k in G.S.quests.size():
		var q: Dictionary = G.S.quests[k]; var kk: int = k
		var p := panel(Color("#fffaf0"), 18, 3, 3); b.add_child(p)
		var h := row(12); p.add_child(h)
		h.add_child(pic(D.thumb(q.ic), 50))
		var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vb.add_theme_constant_override("separation", 4); h.add_child(vb)
		vb.add_child(lab(q.t, 17))
		var pb := ProgressBar.new(); pb.show_percentage = false; pb.custom_minimum_size = Vector2(0, 14); pb.value = 100.0 * G.q_prog(q) / float(q.n)
		var bg := sbox(Color("#ead5b4"), L, 2, 8); bg.content_margin_top = 0; bg.content_margin_bottom = 0
		var fl := sbox(Color("#ffcf3a"), Color("#ffcf3a"), 0, 8); fl.content_margin_top = 0; fl.content_margin_bottom = 0
		pb.add_theme_stylebox_override("background", bg); pb.add_theme_stylebox_override("fill", fl); vb.add_child(pb)
		var rw := row(6); vb.add_child(rw)
		rw.add_child(reward_chip("coin", int(q.g))); rw.add_child(reward_chip("star", int(q.x)))
		if int(q.mj): rw.add_child(reward_chip("mojo", int(q.mj)))
		var done := G.q_done(q)
		var cb := jbtn("받기" if done else "%d/%d" % [G.q_prog(q), int(q.n)], "yellow" if done else "white", 17)
		cb.disabled = not done; cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cb.pressed.connect(func(): SND.play("quest"); G.claim_quest(kk); open_quests())
		h.add_child(cb)
	b.add_child(lab("목표를 이루면 새 목표가 생겨요 · 빈 풀밭 %d칸" % G.cnt(func(T): return T.t == "grass"), 13, INK_SOFT))

func open_me() -> void:
	if intro: return
	var b := open_sheet(G.S.name, "profile")
	var how := jbtn("튜토리얼 목표 보기", "white", 15); how.pressed.connect(func(): close_sheet(); _on_goal())
	b.add_child(info(D.thumb("pt_" + G.S.ruler), [lab("%s 폐하의 왕국" % _ruler_name(), 19), lab("레벨 %d · 경험치 %s · %d일차" % [G.S.level, D.comma(G.S.xp), int(G.S.gt / D.DAY) + 1], 13, INK_SOFT)], [how]))

func _opt_btn(label: String, key: String, def: bool) -> Button:
	if not G.S.has("opts"): G.S.opts = {}
	var on: bool = bool(G.S.opts.get(key, def))
	var b := jbtn("%s %s" % [label, "켜짐" if on else "꺼짐"], "mint" if on else "white", 15)
	b.pressed.connect(func():
		G.S.opts[key] = not bool(G.S.opts.get(key, def)); G.save_game(); SND.start_bgm()
		if key == "fullview" and not G.S.opts[key]: world.fit_cam()
		open_dev())
	return b

func open_dev() -> void:
	var b := open_sheet("설정", "settings")
	var r0 := row(); b.add_child(r0)
	r0.add_child(_opt_btn("배경음", "bgm", true)); r0.add_child(_opt_btn("효과음", "sfx", true)); r0.add_child(_opt_btn("섬 전체 보기", "fullview", false))
	b.add_child(lab("섬 전체 보기를 켜면 숲 너머까지 마음껏 축소할 수 있어요", 13, INK_SOFT))
	if not G.DEV: return
	b.add_child(lab("테스트 모드", 16))
	b.add_child(lab("시간 속도 (×1 = 리얼타임)", 14, INK_SOFT))
	var r := row(); b.add_child(r)
	for v in [1, D.DEV_SPEED, 60, 600]:
		var sb := jbtn("×%d" % v, "purple" if int(G.S.speed) == v else "white", 15); var vv: int = v
		sb.pressed.connect(func(): G.S.speed = vv; G.save_game(); update_hud(); open_dev()); r.add_child(sb)
	var r2 := row(); b.add_child(r2)
	var gb := jbtn("골드 +1000", "yellow", 15); gb.pressed.connect(func(): G.S.gold += 1000; G.done_action()); r2.add_child(gb)
	var mb := jbtn("모조 +5", "purple", 15); mb.pressed.connect(func(): G.S.mojo += 5; G.done_action()); r2.add_child(mb)
	var lb := jbtn("레벨 +1", "pink", 15); lb.pressed.connect(func(): close_sheet(); G.gain_xp(D.lv_xp(G.S.level + 1) - int(G.S.xp)); G.done_action()); r2.add_child(lb)
	var r3 := row(); b.add_child(r3)
	var stb := jbtn("반짝별 부르기", "white", 15); stb.pressed.connect(func(): G.S.star = {}; G.S.nextStar = G.S.gt; G.star_tick(); close_sheet(); toast("반짝별이 떨어졌어요! 찾아서 눌러보세요")); r3.add_child(stb)
	var sk := jbtn("1시간 건너뛰기", "white", 15); sk.pressed.connect(func(): G.S.gt += D.H; G.done_action()); r3.add_child(sk)
	var sg := jbtn("튜토리얼 건너뛰기", "white", 15); sg.pressed.connect(func(): G.set_goal(D.GOALS.size()); close_sheet()); r3.add_child(sg)
	var rs := jbtn("왕국 초기화", "red", 15); rs.pressed.connect(func(): close_sheet(); G.reset(); show_intro()); r3.add_child(rs)
	b.add_child(lab("말랑 왕국 고도판 v1.5", 12, INK_SOFT))

# =============== 손가락 안내 ===============
func _build_hand() -> void:
	hand = Control.new(); hand.mouse_filter = Control.MOUSE_FILTER_IGNORE; hand.size = Vector2(40, 46); hand.visible = false
	hand.draw.connect(func():
		# 검지로 가리키는 하얀 장갑 (손끝이 (8,0))
		var o := L
		hand.draw_rect(Rect2(3, 0, 11, 26), o, true); hand.draw_circle(Vector2(8.5, 3), 5.5, o)
		hand.draw_rect(Rect2(3, 16, 30, 22), o, true); hand.draw_circle(Vector2(18, 38), 15, o)
		hand.draw_rect(Rect2(5.5, 2, 6, 24), Color.WHITE, true); hand.draw_circle(Vector2(8.5, 3.5), 3, Color.WHITE)
		hand.draw_rect(Rect2(5.5, 18, 25, 18), Color.WHITE, true); hand.draw_circle(Vector2(18, 37), 12.5, Color.WHITE)
		for x in [14.0, 20.0, 26.0]: hand.draw_line(Vector2(x, 19), Vector2(x, 27), Color(0.29, 0.16, 0.09, 0.5), 1.4, true))
	root.add_child(hand)

func goal_target():
	var g := G.goal_now()
	if g.is_empty() or talking or is_sheet_open() or lv_box.visible or not G.S.started or intro: return null
	if buy_bar.visible and g.k != "expand": return null
	if G.goal_ready(): return goal_btn
	var cur: Dictionary = D.RECTS[G.S.land]
	var find := func(fn: Callable):
		for r in range(cur.y0, cur.y1):
			for c in range(cur.x0, cur.x1):
				var i: int = r * D.COLS + c
				if fn.call(G.S.tiles[i]): return i
		return -1
	var grass_near := func():
		var best := -1; var bd := 1e9
		for r in range(cur.y0, cur.y1):
			for c in range(cur.x0, cur.x1):
				var i: int = r * D.COLS + c
				if G.S.tiles[i].t != "grass": continue
				var d := Vector2(c - D.CX - 0.5, r - D.CY - 2.5).length()
				if d < bd: bd = d; best = i
		return best
	var first := func(states: Array):
		for st in states:
			var i: int = find.call(func(T): return T.t == "plot" and G.crop_state(T) == st)
			if i >= 0: return i
		return -1
	match g.k:
		"corn": return first.call(["ready", "empty", "grow"])
		"plots": return grass_near.call()
		"mojo": return first.call(["grow", "ready", "empty"])
		"pine", "cottage", "road":
			var need: String = {"pine": "pine", "cottage": "cottage_o", "road": "road_dirt"}[g.k]
			if not G.placing.is_empty() and G.placing.get("k", "") != need: return place_cancel
			return grass_near.call() if not G.placing.is_empty() else shop_btn
		"tax":
			var i: int = find.call(func(T): return T.t == "bld" and G.bld_state(T) == "tax")
			if i < 0: i = find.call(func(T): return T.t == "bld" and G.bld_state(T) == "build")
			if i < 0: i = find.call(func(T): return T.t == "bld" and D.BUILDS[T.b].cat == "house")
			return i
		"expand": return buy_btn if buy_bar.visible else D.CI
	return null

func hand_point():
	var tg = goal_target()
	if tg == null or (tg is int and tg < 0): return null
	if tg is int:
		var T: Dictionary = G.S.tiles[tg]
		if T.t == "grass" or T.t == "plot": return world.tile_screen(tg, 0)
		return world.tile_screen(tg, 0) + Vector2(0, -18) if T.t != "castle" else world.tile_screen(tg)
	var c: Control = tg
	var r := c.get_global_rect()
	return r.position + Vector2(r.size.x / 2, r.size.y * 0.55)

func _process(delta: float) -> void:
	_hud_t += delta
	if _hud_t > 0.5:
		_hud_t = 0.0; _update_clock(); _update_goal()
		var show: bool = G.S.started and G.ready_count() > 0 and not intro
		if show != all_btn.visible: all_btn.visible = show
	if all_btn.visible:
		all_btn.pivot_offset = all_btn.size / 2
		var k := 1.0 + 0.04 * sin(Time.get_ticks_msec() / 220.0); all_btn.scale = Vector2(k, k)
	if live_l and is_instance_valid(live_l):
		_live_t += delta
		if _live_t > 0.25: _live_t = 0.0; live_l.text = live_fn.call()
	var p = hand_point()
	hand.visible = p != null
	if p != null:
		var poke: float = absf(sin(Time.get_ticks_msec() / 260.0)) * 6.0
		hand.position = p - Vector2(8, 0) + Vector2(poke * 0.4, poke)

# =============== 시작 화면 ===============
func show_intro() -> void:
	if intro: intro.queue_free()
	intro = Control.new(); intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new(); bg.texture = gtex("bg_title"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; intro.add_child(bg)
	root.add_child(intro)
	_intro_title()

func _intro_box() -> VBoxContainer:
	for c in intro.get_children():
		if c is VBoxContainer: c.queue_free()
	var vb := VBoxContainer.new(); vb.set_anchors_preset(Control.PRESET_FULL_RECT); vb.alignment = BoxContainer.ALIGNMENT_CENTER; vb.add_theme_constant_override("separation", 10)
	intro.add_child(vb); return vb

func _center(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; return c

func _intro_title() -> void:
	var vb := _intro_box()
	var lg := gimg("logo_board", 400, -1); var lt := clab("말랑 왕국", 46, Color("#ff8ab4"), Rect2(lg.size.x * 0.17, lg.size.y * 0.2, lg.size.x * 0.66, lg.size.y * 0.6), 10, L); lg.add_child(lt)
	var lw := Control.new(); lw.custom_minimum_size = lg.size; lw.add_child(lg); vb.add_child(_center(lw))
	var s := lab("작은 왕국을 말랑말랑 키워봐요", 18); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(s)
	var go := jbtn("시작하기", "pink", 24); go.custom_minimum_size = Vector2(200, 56); go.name = "GoStart"; go.pressed.connect(_intro_ruler); vb.add_child(_center(go))

func _intro_ruler() -> void:
	var vb := _intro_box()
	var t := lab("누가 왕국을 다스릴까요?", 24); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var r := row(12); r.alignment = BoxContainer.ALIGNMENT_CENTER; vb.add_child(r)
	for ru in D.RULERS:
		var k: String = ru.k
		var b := card(D.thumb("pt_" + k), ru.n, "", "", 0, func(): G.S.ruler = k; _intro_ruler())
		b.custom_minimum_size = Vector2(110, 140)
		if G.S.ruler == k: b.add_theme_stylebox_override("normal", sbox(Color("#fff1c9"), L, 4, 18, 7, 3))
		r.add_child(b)
	var go := jbtn("다음", "pink", 22); go.custom_minimum_size = Vector2(170, 52); go.name = "GoName"; go.pressed.connect(_intro_name); vb.add_child(_center(go))

func _intro_name() -> void:
	var vb := _intro_box()
	vb.add_child(_center(pic(D.thumb("pt_" + G.S.ruler), 110, false)))
	var t := lab("왕국 이름을 지어주세요", 22); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var le := LineEdit.new(); le.text = G.S.name; le.max_length = 10; le.alignment = HORIZONTAL_ALIGNMENT_CENTER; le.custom_minimum_size = Vector2(280, 48)
	le.add_theme_font_size_override("font_size", 22); le.add_theme_color_override("font_color", INK)
	le.add_theme_stylebox_override("normal", sbox(Color.WHITE, L, 3, 16)); le.add_theme_stylebox_override("focus", sbox(Color.WHITE, Color("#ff8ab4"), 3, 16))
	vb.add_child(_center(le))
	var go := jbtn("건국하기!", "pink", 24); go.custom_minimum_size = Vector2(200, 56); go.name = "GoPlay"; vb.add_child(_center(go))
	go.pressed.connect(func():
		var v := le.text.strip_edges(); G.S.name = v if v != "" else "말랑 왕국"; G.S.started = true; G.set_goal(0)
		intro.queue_free(); intro = null; G.check_daily(); G.save_game(); update_hud(); world.fit_cam()
		say([{"t": "어서 오세요, %s 폐하! 저는 이 나라의 대신 몽실이에요." % _ruler_name()},
			{"t": "%s은 아직 작고 조용하지만, 폐하와 함께라면 금방 북적북적해질 거예요." % G.S.name},
			{"t": "건국 기념으로 모조 10개를 드릴게요. 모조를 쓰면 기다리지 않고 바로 완성할 수 있어요.", "rw": [["mojo", 10]]},
			{"t": D.GOALS[0].d, "btn": "해볼게요!"}]))


# 9조각 그림 판: 텍스처 여백 m(그림 픽셀)을 k배로 줄여 그림 → 고해상도 그림을 선명하게 씀
class NineTex extends Control:
	var tex: Texture2D
	var m := 100
	var k := 0.33
	func _draw() -> void:
		var tw := tex.get_width(); var th := tex.get_height(); var d := m * k
		var xs := [0.0, d, size.x - d, size.x]; var ys := [0.0, d, size.y - d, size.y]
		var us := [0, m, tw - m, tw]; var vs := [0, m, th - m, th]
		for i in 3:
			for j in 3:
				draw_texture_rect_region(tex, Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j]), Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()
