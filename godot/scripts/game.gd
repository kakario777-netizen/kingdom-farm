extends Node
## 게임 상태와 규칙 (웹판 규칙 그대로)
signal changed            # 상단 바·목표 갱신
signal tiles_changed      # 지도 다시 그리기
signal land_changed
signal toast(msg: String)
signal pop(i: int, text: String, kind: String)
signal level_up(lv: int, mj: int)

const DEV := true
const SAVE_PATH := "user://save.json"
var S: Dictionary = {}
var placing: Dictionary = {}   # {kind:"plot"|"new"|"move", k, from}
var sel := -1
var _save_t := 0.0

func _ready() -> void:
	if not load_game():
		S = fresh()

func fresh() -> Dictionary:
	var tiles: Array = []
	tiles.resize(D.COLS * D.ROWS)
	for i in tiles.size(): tiles[i] = {"t": "grass"}
	for dc in [0, 1]:
		for dr in [0, 1]:
			tiles[(D.CY + dr) * D.COLS + D.CX + dc] = {"t": "castle"}
	for c in [D.CX - 1, D.CX, D.CX + 1]:
		tiles[(D.CY + 2) * D.COLS + c] = {"t": "plot"}
	return {"v": 1, "gt": 8.0 * D.H, "real": Time.get_unix_time_from_system(), "gold": 250.0, "xp": 0, "level": 1, "mojo": 10, "land": 0,
		"speed": D.DEV_SPEED if DEV else 1, "tiles": tiles, "daily": "", "name": "말랑 왕국", "ruler": "king", "started": false,
		"goal": 0, "gbase": 0, "st": {}}

func save_game() -> void:
	S.real = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("tiles"): return false
	S = d
	S.level = int(S.level); S.mojo = int(S.mojo); S.land = int(S.land); S.goal = int(S.goal); S.xp = int(S.xp)
	# 꺼져 있던 동안 흐른 시간
	var away: float = max(0.0, Time.get_unix_time_from_system() - float(S.get("real", 0)))
	S.gt = float(S.gt) + min(away, 7.0 * D.DAY) * float(S.speed)
	return true

func reset() -> void:
	S = fresh(); placing = {}; save_game()
	tiles_changed.emit(); land_changed.emit(); changed.emit()

func _process(delta: float) -> void:
	if S.is_empty() or not S.started: return
	S.gt = float(S.gt) + delta * float(S.speed)
	_save_t += delta
	if _save_t > 5.0:
		_save_t = 0.0; save_game()

# ---------- 땅 ----------
func rect(n: int) -> Dictionary: return D.RECTS[min(n, D.RECTS.size() - 1)]
func in_r(R: Dictionary, c: int, r: int) -> bool: return c >= R.x0 and c < R.x1 and r >= R.y0 and r < R.y1
func unlocked(c: int, r: int) -> bool: return in_r(D.RECTS[S.land], c, r)
func is_next(c: int, r: int) -> bool:
	return S.land + 1 < D.RECTS.size() and in_r(D.RECTS[S.land + 1], c, r)
func tile(i: int) -> Dictionary: return S.tiles[i]
func cnt(fn: Callable) -> int:
	var n := 0
	var R: Dictionary = D.RECTS[S.land]
	for r in range(R.y0, R.y1):
		for c in range(R.x0, R.x1):
			if fn.call(S.tiles[r * D.COLS + c]): n += 1
	return n
func plot_cap() -> int: return 5 + int(S.level / 2)
func castle_tier() -> int: return 4 if S.land >= 8 else 3 if S.land >= 4 else 2 if S.land >= 2 else 1
func stv(k: String) -> int: return int(S.st.get(k, 0))
func inc(k: String, n: int = 1) -> void: S.st[k] = stv(k) + n

# ---------- 상태 ----------
func crop_state(T: Dictionary) -> String:
	if not T.get("crop"): return "empty"
	if S.gt < T.readyAt: return "grow"
	var C: Dictionary = D.CROPS[T.crop]
	var spoil: float = max(float(C.t) * 1.5, 20.0 * D.M)
	return "ready" if S.gt < float(T.readyAt) + spoil else "dead"

func bld_state(T: Dictionary) -> String:
	var B: Dictionary = D.BUILDS[T.b]
	if S.gt < float(T.doneAt): return "build"
	if B.cat == "house": return "tax" if S.gt >= float(T.taxAt) else "idle"
	if B.cat == "shop":
		if not T.get("job"): return "open"
		return "done" if S.gt >= float(T.job.doneAt) else "work"
	return "deco"

func remain_of(T: Dictionary) -> float:
	if T.t == "plot": return float(T.readyAt) - S.gt
	match bld_state(T):
		"build": return float(T.doneAt) - S.gt
		"work": return float(T.job.doneAt) - S.gt
		"idle": return float(T.taxAt) - S.gt
	return 0.0

func prog(a: float, b: float) -> float: return clamp((S.gt - a) / max(1.0, b - a), 0.0, 1.0)
func mojo_cost(rem: float) -> int: return int(clamp(ceil(rem / (1.5 * D.H)), 1, 8))
func remain_txt(s: float) -> String:
	var t := D.fmt(s)
	if float(S.speed) != 1.0: t += " · 실제 " + D.fmt(s / float(S.speed))
	return t

# ---------- 행동 ----------
func pay(n: float) -> bool:
	if S.gold < n:
		toast.emit("골드가 %s 모자라요" % D.comma(n - floor(S.gold))); return false
	S.gold -= n; return true

func gain_xp(x: int, i: int = -1) -> void:
	S.xp = int(S.xp) + x
	if i >= 0: pop.emit(i, "+%d XP" % x, "xp")
	while S.xp >= D.lv_xp(S.level + 1):
		S.level += 1
		var mj := int(D.LV_MOJO.get(str(S.level), 3))
		S.mojo += mj
		level_up.emit(S.level, mj)

func harvest(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var C: Dictionary = D.CROPS[T.crop]
	S.gold += C.g; pop.emit(i, "+%d" % C.g, "gd")
	if T.crop == "corn": inc("corn")
	inc("harvest"); inc("c_" + T.crop)
	gain_xp(int(C.x), i); T.erase("crop")
	done_action()

func plant(i: int, k: String) -> bool:
	var C: Dictionary = D.CROPS[k]
	if not pay(C.cost): return false
	var T: Dictionary = S.tiles[i]
	T.crop = k; T.plantedAt = S.gt; T.readyAt = S.gt + float(C.t)
	pop.emit(i, ("-%d" % C.cost) if C.cost else "심었어요", "gd" if C.cost else "")
	done_action(); return true

func collect_tax(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	S.gold += B.g; pop.emit(i, "+%d" % B.g, "gd"); inc("tax")
	gain_xp(max(1, int(round(float(B.g) / 10.0))), i); T.taxAt = S.gt + float(B.every)
	done_action()

func collect_job(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	S.gold += B.g; pop.emit(i, "+%d" % B.g, "gd"); inc("job"); gain_xp(int(B.jx), i); T.erase("job")
	done_action()

func start_job(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	T.job = {"startAt": S.gt, "doneAt": S.gt + float(B.jt)}; pop.emit(i, "일 시작!", ""); done_action()

func make_plot(i: int) -> bool:
	if cnt(func(T): return T.t == "plot") >= plot_cap():
		toast.emit("밭은 지금 %d개까지예요. 레벨이 오르면 늘어나요" % plot_cap()); return false
	if not pay(D.PLOT_COST): return false
	S.tiles[i] = {"t": "plot"}; inc("plots"); pop.emit(i, "-%d" % D.PLOT_COST, "gd"); gain_xp(5, i)
	done_action(); return true

func do_build(i: int, k: String) -> bool:
	var B: Dictionary = D.BUILDS[k]
	if S.level < B.lv:
		toast.emit("레벨 %d부터 지을 수 있어요" % B.lv); return false
	if not pay(B.cost): return false
	var T := {"t": "bld", "b": k, "startAt": S.gt, "doneAt": S.gt + float(B.t)}
	if B.cat == "house": T.taxAt = T.doneAt + float(B.every)
	S.tiles[i] = T; pop.emit(i, "-%s" % D.comma(B.cost), "gd"); gain_xp(int(B.x), i)
	if k == "pine": inc("pine")
	if B.cat == "house": inc("cottage")
	inc("b_" + k)
	if B.cat == "deco": inc("deco")
	if B.cat == "road": inc("road")
	if float(B.t) > 0: toast.emit("%s 공사 시작! %s 뒤에 완성돼요" % [B.n, D.fmt(B.t)])
	done_action(); return true

func finish_now(i: int, cost: int) -> bool:
	if S.mojo < cost:
		toast.emit("모조가 모자라요"); return false
	S.mojo -= cost; inc("mojo")
	var T: Dictionary = S.tiles[i]
	if T.t == "plot": T.readyAt = S.gt
	else:
		var B: Dictionary = D.BUILDS[T.b]
		match bld_state(T):
			"build":
				T.doneAt = S.gt
				if B.cat == "house": T.taxAt = S.gt + float(B.every)
			"work": T.job.doneAt = S.gt
			"idle": T.taxAt = S.gt
	pop.emit(i, "뿅! 완성", "mj"); done_action(); return true

func sell(i: int) -> void:
	var B: Dictionary = D.BUILDS[S.tiles[i].b]; var g := int(B.cost / 4)
	S.gold += g; pop.emit(i, "+%d" % g, "gd"); S.tiles[i] = {"t": "grass"}; done_action()

func move_to(from: int, to: int) -> void:
	S.tiles[to] = S.tiles[from]; S.tiles[from] = {"t": "grass"}; pop.emit(to, "옮겼어요", ""); done_action()

func clear_crop(i: int) -> void:
	S.tiles[i].erase("crop"); done_action()

func expand() -> bool:
	if S.land + 1 >= D.LANDS.size(): return false
	var n: Dictionary = D.LANDS[S.land + 1]
	if S.level < n.lv: return false
	if not pay(n.cost): return false
	var up: bool = n.n != D.LANDS[S.land].n
	S.land += 1; inc("expand"); gain_xp(int(round(float(n.cost) / 20.0)))
	toast.emit(("%s(으)로 업그레이드했어요!" % n.n) if up else "왕국이 넓어졌어요!")
	land_changed.emit(); done_action(); return true

func done_action() -> void:
	save_game(); tiles_changed.emit(); changed.emit()

func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d-%d-%d" % [d.year, d.month, d.day]

func check_daily() -> void:
	if S.daily != today():
		S.daily = today(); S.mojo += 2; save_game()
		get_tree().create_timer(0.6).timeout.connect(func(): toast.emit("오늘의 출석 선물! 모조 +2"))

# ---------- 튜토리얼 목표 ----------
func goal_now() -> Dictionary:
	return D.GOALS[S.goal] if S.goal < D.GOALS.size() else {}
func goal_prog() -> int:
	var g := goal_now()
	return min(int(g.n), stv(g.k) - int(S.gbase)) if g else 0
func goal_ready() -> bool:
	var g := goal_now()
	return not g.is_empty() and goal_prog() >= int(g.n)
func set_goal(n: int) -> void:
	S.goal = n
	var g := goal_now()
	if g: S.gbase = stv(g.k)
	save_game(); changed.emit()
