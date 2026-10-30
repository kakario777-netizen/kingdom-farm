extends Node2D
## 지도: 바닥(풀 텍스처·절벽·땅 경계·길) + 높이순으로 정렬된 그림들 + 표시(뱃지·진행바) + 카메라·터치
signal tapped(i: int)

var cam: Camera2D
var ground_poly: Polygon2D
var ground: Node2D       # 길·성 바닥·잠긴 땅 색
var marks: Node2D        # 놓기 안내(깜빡임)
var objs: Node2D         # 높이순 정렬
var over: Node2D         # 뱃지·진행바
var pops: Node2D
var cells := {}          # i -> {node, sig, h, big}
var wilds := {}          # 안 열린 땅의 숲 그림
var _sig_t := 0.0
var ZMIN := 0.3
const ZMAX := 2.6
var _touches := {}
var _drag_from := Vector2.ZERO
var _drag_cam := Vector2.ZERO
var _moved := false
var _pinch_d := 0.0
var _pinch_z := 1.0
var t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_island()
	ground = Node2D.new(); add_child(ground); ground.draw.connect(_draw_ground)
	marks = Node2D.new(); add_child(marks); marks.draw.connect(_draw_marks)
	objs = Node2D.new(); objs.y_sort_enabled = true; add_child(objs)
	over = Node2D.new(); add_child(over); over.draw.connect(_draw_over)
	pops = Node2D.new(); add_child(pops)
	cam = Camera2D.new(); add_child(cam); cam.make_current()
	G.tiles_changed.connect(refresh)
	G.land_changed.connect(func(): ground.queue_redraw(); refresh(); fit_cam())
	G.pop.connect(_pop)
	_build_wild()
	refresh()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var vs := get_viewport_rect().size
	var x0 := D.P(0, D.ROWS).x; var x1 := D.P(D.COLS, 0).x
	ZMIN = min(0.3, vs.x / (x1 - x0) * 0.9)
	fit_cam()

# ---------------- 바닥 ----------------
func _grass_texture() -> ImageTexture:
	var N := 512
	var img := Image.create(N, N, true, Image.FORMAT_RGBA8)
	img.fill(Color("#9bd86e"))
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	# 큰 얼룩
	for n in 60:
		var cx := rng.randi_range(0, N); var cy := rng.randi_range(0, N); var rx := rng.randi_range(30, 90); var ry := rx * 0.55
		var col := Color(0.24, 0.5, 0.16, 0.06) if rng.randf() < 0.5 else Color(1, 1, 0.8, 0.07)
		for y in range(-int(ry), int(ry)):
			for x in range(-rx, rx):
				if (x * x) / float(rx * rx) + (y * y) / float(ry * ry) < 1.0:
					var px := posmod(cx + x, N); var py := posmod(cy + y, N)
					img.set_pixel(px, py, img.get_pixel(px, py).blend(col))
	# 풀잎
	for n in 9000:
		var x := rng.randi_range(0, N - 1); var y := rng.randi_range(0, N - 1); var h := rng.randi_range(3, 7)
		var dark := rng.randf() < 0.55
		var col := Color(0.23, 0.5, 0.17, 0.35 + rng.randf() * 0.3) if dark else Color(0.83, 0.96, 0.67, 0.45 + rng.randf() * 0.4)
		var lean := rng.randf_range(-0.5, 0.5)
		for k in h:
			var px := posmod(x + int(lean * k), N); var py := posmod(y - k, N)
			img.set_pixel(px, py, img.get_pixel(px, py).blend(col))
	# 작은 꽃
	var fcs := [Color.WHITE, Color("#ffe066"), Color("#ff9cc0"), Color("#c9b6ff")]
	for n in 140:
		var x := rng.randi_range(4, N - 5); var y := rng.randi_range(4, N - 5); var fc: Color = fcs[rng.randi() % 4]
		for o in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			img.set_pixel(x + o.x, y + o.y, fc); img.set_pixel(x + o.x + 1, y + o.y, fc)
		img.set_pixel(x, y, Color("#ffb02e"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_island() -> void:
	var C := D.COLS; var R := D.ROWS
	# 절벽(남·동쪽 가장자리)
	var cliff := Node2D.new(); add_child(cliff)
	cliff.draw.connect(func():
		for side in 2:
			var a := D.P(0, R) if side == 0 else D.P(C, 0)
			var b := D.P(C, R)
			var col := Color("#c48a55") if side == 0 else Color("#9c6638")
			cliff.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 46), a + Vector2(0, 46)]), col)
			cliff.draw_colored_polygon(PackedVector2Array([a + Vector2(0, 30), b + Vector2(0, 30), b + Vector2(0, 46), a + Vector2(0, 46)]), col.darkened(0.18))
			cliff.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 8), a + Vector2(0, 8)]), Color("#5fae45") if side == 0 else Color("#4f9a37"))
			for k in range(0, 60):
				var p := a.lerp(b, k / 60.0)
				cliff.draw_line(p + Vector2(0, 14 + (k % 3) * 4), p + Vector2(4, 24 + (k % 3) * 4), Color(0.43, 0.27, 0.16, 0.45), 1.4, true)
	)
	ground_poly = Polygon2D.new()
	ground_poly.texture = _grass_texture()
	ground_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var pts := PackedVector2Array([D.P(0, 0), D.P(C, 0), D.P(C, R), D.P(0, R)])
	ground_poly.polygon = pts
	var uv := PackedVector2Array()
	for p in pts: uv.append(p * 1.6)
	ground_poly.uv = uv
	add_child(ground_poly)

func _quad(n: Node2D, u0: float, v0: float, u1: float, v1: float, col: Color) -> void:
	if u1 <= u0 or v1 <= v0: return
	n.draw_colored_polygon(PackedVector2Array([D.P(u0, v0), D.P(u1, v0), D.P(u1, v1), D.P(u0, v1)]), col)

func _rect_minus(n: Node2D, outer: Dictionary, inner: Dictionary, col: Color) -> void:
	# outer 사각형에서 inner 사각형을 뺀 부분을 칠함
	_quad(n, outer.x0, outer.y0, outer.x1, inner.y0, col)
	_quad(n, outer.x0, inner.y1, outer.x1, outer.y1, col)
	_quad(n, outer.x0, inner.y0, inner.x0, inner.y1, col)
	_quad(n, inner.x1, inner.y0, outer.x1, inner.y1, col)

func _draw_ground() -> void:
	var all := {"x0": 0, "y0": 0, "x1": D.COLS, "y1": D.ROWS}
	var cur: Dictionary = D.RECTS[G.S.land]
	var nxt: Dictionary = D.RECTS[min(G.S.land + 1, D.RECTS.size() - 1)]
	_rect_minus(ground, all, nxt, Color(0.84, 0.93, 0.81, 0.5))
	if nxt != cur: _rect_minus(ground, nxt, cur, Color(0.94, 0.98, 1.0, 0.34))
	# 성 바닥
	_quad(ground, D.CX, D.CY, D.CX + 2, D.CY + 2, Color("#efe2c9"))
	# 길
	for r in range(cur.y0, cur.y1):
		for c in range(cur.x0, cur.x1):
			var T: Dictionary = G.S.tiles[r * D.COLS + c]
			if T.t == "bld" and D.BUILDS.has(T.b) and D.BUILDS[T.b].cat == "road":
				_draw_road(c, r, T.b)
	# 지금 땅 경계(점선)
	if nxt != cur:
		var pts := [D.P(cur.x0, cur.y0), D.P(cur.x1, cur.y0), D.P(cur.x1, cur.y1), D.P(cur.x0, cur.y1), D.P(cur.x0, cur.y0)]
		for k in 4: ground.draw_dashed_line(pts[k], pts[k + 1], Color(1, 1, 1, 0.8), 2.4, 8.0, true)

func _road_mask(c: int, r: int) -> int:
	var m := 0
	var same := func(cc: int, rr: int) -> bool:
		if cc < 0 or rr < 0 or cc >= D.COLS or rr >= D.ROWS: return false
		var T: Dictionary = G.S.tiles[rr * D.COLS + cc]
		return (T.t == "bld" and D.BUILDS.has(T.b) and D.BUILDS[T.b].cat == "road") or T.t == "castle"
	if same.call(c, r - 1): m |= 1
	if same.call(c + 1, r): m |= 2
	if same.call(c, r + 1): m |= 4
	if same.call(c - 1, r): m |= 8
	return m

func _draw_road(c: int, r: int, k: String) -> void:
	var B: Dictionary = D.BUILDS[k]; var m := _road_mask(c, r)
	var sq := func(a: float, b: float, col: Color):
		_quad(ground, c + a, r + a, c + b, r + b, col)
		if m & 1: _quad(ground, c + a, r, c + b, r + 0.5, col)
		if m & 2: _quad(ground, c + 0.5, r + a, c + 1, r + b, col)
		if m & 4: _quad(ground, c + a, r + 0.5, c + b, r + 1, col)
		if m & 8: _quad(ground, c, r + a, c + 0.5, r + b, col)
	sq.call(0.15, 0.85, Color(B.col[1]).darkened(0.15))
	sq.call(0.2, 0.8, Color(B.col[0]))
	var rng := RandomNumberGenerator.new(); rng.seed = r * D.COLS + c + 99
	for n in 9:
		var p := D.P(c + 0.25 + rng.randf() * 0.5, r + 0.25 + rng.randf() * 0.5)
		var stone := k == "road_stone"
		var col := Color(1, 1, 1, 0.35) if stone else Color(B.col[1])
		ground.draw_set_transform(p, 0, Vector2(1, 0.52))
		ground.draw_circle(Vector2.ZERO, 5.0 if stone else 2.0, col)
		ground.draw_set_transform(Vector2.ZERO)

func _draw_marks() -> void:
	if G.placing.is_empty(): return
	var cur: Dictionary = D.RECTS[G.S.land]
	var a := 0.22 + 0.1 * sin(t * 4.0)
	for r in range(cur.y0, cur.y1):
		for c in range(cur.x0, cur.x1):
			if G.S.tiles[r * D.COLS + c].t != "grass": continue
			_quad(marks, c + 0.08, r + 0.08, c + 0.92, r + 0.92, Color(1, 1, 1, a))

# ---------------- 그림(높이순) ----------------
func _cell(i: int) -> Node2D:
	var c := i % D.COLS; var r := i / D.COLS
	var n := Node2D.new(); n.position = D.P(c + 0.5, r + 0.5)
	objs.add_child(n)
	return n

func _build_wild() -> void:
	# 아직 안 열린 땅의 숲·바위(정해진 무늬)
	for i in D.COLS * D.ROWS:
		var w := _wild_at(i)
		if w == "": continue
		var n := _cell(i)
		var s := D.make_sprite(w); n.add_child(s)
		wilds[i] = n
	_update_wild_alpha()

func _wild_at(i: int) -> String:
	var h := _hash(i * 13 + 7); var h2 := _hash(i * 7 + 3)
	if h < 0.11: return "wpine" if h2 < 0.5 else "wpine2"
	if h < 0.17: return "woak" if h2 < 0.6 else "woak2"
	if h < 0.205: return "wrock"
	if h < 0.24: return "wbush"
	if h < 0.25: return "wlog" if h2 < 0.5 else "wmush"
	return ""

func _hash(i: int) -> float:
	return float(((i * 2654435761) & 0xFFFFFFFF) % 1000) / 1000.0

func _update_wild_alpha() -> void:
	for i in wilds:
		var n: Node2D = wilds[i]
		var c: int = i % D.COLS; var r: int = i / D.COLS
		n.visible = not G.unlocked(c, r)
		n.modulate.a = 0.92 if G.is_next(c, r) else 0.82

func _sig(i: int, T: Dictionary) -> String:
	match T.t:
		"castle": return ("c%d" % G.castle_tier()) if i == D.CI else "x"
		"plot":
			if not T.get("crop"): return "p"
			var st := G.crop_state(T)
			return "p:" + _crop_key(T) + ":" + st
		"bld":
			var B: Dictionary = D.BUILDS[T.b]
			if B.cat == "road": return "x"
			return "b:" + T.b + ":" + ("build" if G.bld_state(T) == "build" else "ok") + (":%d" % _fence_mask(i) if B.cat == "fence" else "")
	return "x"

func _crop_key(T: Dictionary) -> String:
	var st := G.crop_state(T)
	if st == "grow":
		var p := G.prog(T.plantedAt, T.readyAt)
		if p < 0.34: return "crop_sprout"
		return "crop_%s_%d" % [T.crop, 1 if p < 0.72 else 2]
	return "crop_%s_2" % T.crop

func refresh() -> void:
	ground.queue_redraw()
	_update_wild_alpha()
	var cur: Dictionary = D.RECTS[G.S.land]
	for i in cells.keys():
		if not G.in_r(cur, i % D.COLS, i / D.COLS):
			cells[i].node.queue_free(); cells.erase(i)
	for r in range(cur.y0, cur.y1):
		for c in range(cur.x0, cur.x1):
			var i := r * D.COLS + c
			var T: Dictionary = G.S.tiles[i]
			var sg := _sig(i, T)
			var e = cells.get(i)
			if e and e.sig == sg: continue
			if e:
				e.node.queue_free(); cells.erase(i)
			if sg == "x": continue
			var n := _cell(i)
			var h := 30.0; var big := false
			if T.t == "castle":
				n.position = D.P(D.CX + 1, D.CY + 1)
				n.add_child(D.make_sprite("castle%d" % G.castle_tier())); h = 150.0; big = true
			elif T.t == "plot":
				n.add_child(D.make_sprite("plot"))
				if T.get("crop"):
					var st := G.crop_state(T)
					var cs := D.make_sprite(_crop_key(T)); cs.position = Vector2(0, -4)
					if st == "dead": cs.modulate = Color(0.75, 0.6, 0.45)
					n.add_child(cs)
			else:
				var B: Dictionary = D.BUILDS[T.b]
				if B.cat == "fence":
					var f := Node2D.new(); n.add_child(f)
					var k: String = T.b; var m := _fence_mask(i)
					f.draw.connect(func(): _draw_fence(f, k, m)); h = 24.0
				else:
					var s := D.make_sprite(T.b)
					if s.texture == null: s = D.make_sprite("fountain")
					n.add_child(s); h = D.spr_h(T.b)
					if G.bld_state(T) == "build": s.modulate = Color(1, 1, 1, 0.45)
			cells[i] = {"node": n, "sig": sg, "h": h, "big": big}

func _fence_mask(i: int) -> int:
	var c := i % D.COLS; var r := i / D.COLS; var m := 0
	var same := func(cc: int, rr: int) -> bool:
		if cc < 0 or rr < 0 or cc >= D.COLS or rr >= D.ROWS: return false
		var T: Dictionary = G.S.tiles[rr * D.COLS + cc]
		return T.t == "bld" and D.BUILDS.has(T.b) and D.BUILDS[T.b].cat == "fence"
	if same.call(c, r - 1): m |= 1
	if same.call(c + 1, r): m |= 2
	if same.call(c, r + 1): m |= 4
	if same.call(c - 1, r): m |= 8
	return m

func _draw_fence(n: Node2D, k: String, m: int) -> void:
	var col := Color(D.BUILDS[k].col); var ol := Color(0.29, 0.16, 0.09)
	var post := func(u: float, v: float):
		var p := D.P(u, v) - D.P(0.5, 0.5)
		n.draw_rect(Rect2(p + Vector2(-2.5, -20), Vector2(5, 20)), ol)
		n.draw_rect(Rect2(p + Vector2(-1.5, -19), Vector2(3, 18)), col)
	var rail := func(u0: float, v0: float, u1: float, v1: float):
		var a := D.P(u0, v0) - D.P(0.5, 0.5); var b := D.P(u1, v1) - D.P(0.5, 0.5)
		for z in [8.0, 15.0]:
			n.draw_line(a - Vector2(0, z), b - Vector2(0, z), ol, 4.0, true)
			n.draw_line(a - Vector2(0, z), b - Vector2(0, z), col, 2.2, true)
	if m & 1: rail.call(0.5, 0.5, 0.5, 0.0)
	if m & 8: rail.call(0.5, 0.5, 0.0, 0.5)
	if m == 0: rail.call(0.2, 0.5, 0.8, 0.5)
	post.call(0.5, 0.5)
	if m & 2: rail.call(0.5, 0.5, 1.0, 0.5)
	if m & 4: rail.call(0.5, 0.5, 0.5, 1.0)

# ---------------- 표시 ----------------
func _draw_over() -> void:
	var cur: Dictionary = D.RECTS[G.S.land]
	for r in range(cur.y0, cur.y1):
		for c in range(cur.x0, cur.x1):
			var i := r * D.COLS + c
			var T: Dictionary = G.S.tiles[i]
			if T.t == "plot" and T.get("crop"):
				var st := G.crop_state(T)
				if st == "ready":
					for n in 3:
						var ph := fmod(t * 0.8 + n / 3.0, 1.0)
						_star(D.P(c + 0.2 + n * 0.3, r + 0.5, 10 + ph * 30), 3.5, Color(1, 0.96, 0.66, 1.0 - ph))
				elif st == "dead":
					_badge(D.P(c + 0.5, r + 0.5, 30), "dead")
			elif T.t == "bld":
				var B: Dictionary = D.BUILDS[T.b]
				if B.cat in ["road", "fence", "deco"] and G.bld_state(T) != "build": continue
				var top := D.P(c + 0.5, r + 0.5, D.spr_h(T.b) + 14)
				match G.bld_state(T):
					"build": _bar(D.P(c + 0.5, r + 0.5, 22), G.prog(T.startAt, T.doneAt))
					"tax": _badge(top, "coin")
					"done": _badge(top, "box")
					"work": _bar(D.P(c + 0.5, r + 0.5, 22), G.prog(T.job.startAt, T.job.doneAt))
					"open": _sign(D.P(c + 0.85, r + 0.85, 4))

func _star(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5; var rr := s if k % 2 == 0 else s * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	over.draw_colored_polygon(pts, col)

func _badge(p: Vector2, kind: String) -> void:
	p.y += sin(t * 4.0) * 2.5
	over.draw_circle(p + Vector2(0, 16), 7, Color(0, 0, 0, 0.15))
	over.draw_circle(p, 14, Color("#4a2a17"))
	over.draw_circle(p, 12, Color.WHITE)
	match kind:
		"coin":
			over.draw_circle(p, 9, Color("#e09a20")); over.draw_circle(p, 7.5, Color("#ffc93c"))
			over.draw_string(D.font, p + Vector2(-4, 4.5), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b06a10"))
		"box":
			over.draw_rect(Rect2(p + Vector2(-8, -7), Vector2(16, 14)), Color("#ff8fb5"))
			over.draw_rect(Rect2(p + Vector2(-1.5, -7), Vector2(3, 14)), Color.WHITE)
			over.draw_rect(Rect2(p + Vector2(-8, -1.5), Vector2(16, 3)), Color.WHITE)
		"dead":
			over.draw_string(D.font, p + Vector2(-5, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c0392b"))

func _bar(p: Vector2, f: float) -> void:
	over.draw_rect(Rect2(p + Vector2(-23, -5), Vector2(46, 10)), Color("#4a2a17"))
	over.draw_rect(Rect2(p + Vector2(-21, -3), Vector2(42, 6)), Color("#ead5b4"))
	over.draw_rect(Rect2(p + Vector2(-21, -3), Vector2(max(4.0, 42.0 * f), 6)), Color("#ffcf3a"))

func _sign(p: Vector2) -> void:
	over.draw_rect(Rect2(p + Vector2(-0.8, -2), Vector2(1.6, 9)), Color("#8a5a3a"))
	over.draw_rect(Rect2(p + Vector2(-12, -10), Vector2(24, 10)), Color("#4a2a17"))
	over.draw_rect(Rect2(p + Vector2(-11, -9), Vector2(22, 8)), Color("#fff36b"))
	over.draw_string(D.font, p + Vector2(-10, -2.3), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#4a2a17"))

func _pop(i: int, text: String, kind: String) -> void:
	var c := i % D.COLS; var r := i / D.COLS
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 17)
	var col := Color.WHITE
	match kind:
		"gd": col = Color("#ffd23c")
		"mj": col = Color("#c7b6ff")
		"xp": col = Color("#9df0c0")
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#4a2a17"))
	l.add_theme_constant_override("outline_size", 6)
	l.position = D.P(c + 0.5, r + 0.5, 50 + (18 if kind == "xp" else 0)) - Vector2(40, 0)
	l.size = Vector2(80, 24); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pops.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 34, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

# ---------------- 카메라 ----------------
func view_rect() -> Dictionary:
	return D.RECTS[min(G.S.land + 1, D.RECTS.size() - 1)]

func fit_cam() -> void:
	if not cam: return
	var R := view_rect()
	var pts := [D.P(R.x0, R.y0), D.P(R.x1, R.y0), D.P(R.x1, R.y1), D.P(R.x0, R.y1)]
	var mn := Vector2(1e9, 1e9); var mx := Vector2(-1e9, -1e9)
	for p in pts: mn = mn.min(p); mx = mx.max(p)
	mn.y -= 120; mx.y += 20
	var vs := get_viewport_rect().size
	var top := 56.0
	var z: float = clamp(min(vs.x / (mx.x - mn.x), (vs.y - top) / (mx.y - mn.y)), 0.3, 1.6)
	cam.zoom = Vector2(z, z)
	cam.position = (mn + mx) / 2 - Vector2(0, top / 2 / z)
	_clamp_cam()

func fit_all() -> void:
	var vs := get_viewport_rect().size
	var x0 := D.P(0, D.ROWS).x; var x1 := D.P(D.COLS, 0).x
	var y0 := -60.0; var y1 := (D.COLS + D.ROWS) * D.H2 + 110
	var z: float = max(ZMIN, min(vs.x / (x1 - x0), vs.y / (y1 - y0)))
	cam.zoom = Vector2(z, z); cam.position = Vector2((x0 + x1) / 2, (y0 + y1) / 2)

func _clamp_cam() -> void:
	var x0 := D.P(0, D.ROWS).x; var x1 := D.P(D.COLS, 0).x
	var y1 := (D.COLS + D.ROWS) * D.H2 + 60
	cam.position.x = clamp(cam.position.x, x0, x1)
	cam.position.y = clamp(cam.position.y, -40.0, y1)

func zoom_at(f: float, screen_p: Vector2) -> void:
	var before := screen_to_world(screen_p)
	var nz: float = clamp(cam.zoom.x * f, ZMIN, ZMAX)
	cam.zoom = Vector2(nz, nz)
	cam.position += before - screen_to_world(screen_p)
	_clamp_cam()

func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p

func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p

func tile_screen(i: int, z: float = 0.0) -> Vector2:
	var c := i % D.COLS; var r := i / D.COLS
	if G.S.tiles[i].t == "castle": return world_to_screen(D.P(D.CX + 1, D.CY + 1, 70))
	return world_to_screen(D.P(c + 0.5, r + 0.5, z))

# ---------------- 터치 ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag_from = e.position; _drag_cam = cam.position; _moved = false
			elif _touches.size() == 2:
				var v: Array = _touches.values()
				_pinch_d = max(1.0, (v[0] - v[1]).length()); _pinch_z = cam.zoom.x; _moved = true
		else:
			var was := _touches.size()
			_touches.erase(e.index)
			if was == 1 and not _moved:
				pick(screen_to_world(e.position))
			if _touches.size() == 1:
				_drag_from = _touches.values()[0]; _drag_cam = cam.position
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var v: Array = _touches.values()
			var d: float = max(1.0, (v[0] - v[1]).length())
			var mid: Vector2 = (v[0] + v[1]) / 2
			var f: float = _pinch_z * d / _pinch_d / cam.zoom.x
			zoom_at(f, mid)
		elif _touches.size() == 1:
			var dv: Vector2 = e.position - _drag_from
			if dv.length() > 9: _moved = true
			if _moved:
				cam.position = _drag_cam - dv / cam.zoom.x; _clamp_cam()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_at(1.12, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_at(0.89, e.position)

func pick(w: Vector2) -> void:
	if G.placing.is_empty():
		var list: Array = []
		for i in cells:
			var e: Dictionary = cells[i]
			list.append(i)
		list.sort_custom(func(a, b): return cells[a].node.position.y > cells[b].node.position.y)
		for i in list:
			var e: Dictionary = cells[i]
			if e.h < 34: continue
			var p: Vector2 = e.node.position
			var hw: float = D.W2 * (1.9 if e.big else 0.62)
			if w.x > p.x - hw and w.x < p.x + hw and w.y > p.y - e.h - 8 and w.y < p.y + (D.H2 * 2 if e.big else D.H2 * 0.6):
				tapped.emit(i); return
	var u := (w.x / D.W2 + w.y / D.H2) / 2.0; var v := (w.y / D.H2 - w.x / D.W2) / 2.0
	var c := int(floor(u)); var r := int(floor(v))
	if c < 0 or r < 0 or c >= D.COLS or r >= D.ROWS: return
	tapped.emit(r * D.COLS + c)

func _process(delta: float) -> void:
	t += delta
	over.queue_redraw()
	if not G.placing.is_empty(): marks.queue_redraw()
	elif marks.get_meta("on", false): marks.queue_redraw()
	marks.set_meta("on", not G.placing.is_empty())
	_sig_t += delta
	if _sig_t > 0.5:
		_sig_t = 0.0; refresh_states()

func refresh_states() -> void:
	# 작물 자람·공사 끝 같은 시간 변화 반영
	var cur: Dictionary = D.RECTS[G.S.land]
	for r in range(cur.y0, cur.y1):
		for c in range(cur.x0, cur.x1):
			var i := r * D.COLS + c
			var e = cells.get(i)
			var sg := _sig(i, G.S.tiles[i])
			if (e == null and sg != "x") or (e != null and e.sig != sg):
				refresh(); return
