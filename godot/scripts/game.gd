extends Node
## 게임 상태와 규칙 (웹판 규칙 그대로)
signal changed            # 상단 바·목표 갱신
signal tiles_changed      # 지도 다시 그리기
signal land_changed
signal toast(msg: String)
signal pop(i: int, text: String, kind: String)
signal level_up(lv: int, mj: int)
signal castle_up

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
		"goal": 0, "gbase": 0, "st": {}, "quests": [], "star": {}, "nextStar": 8.0 * D.H + 40.0 * D.M}

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
	star_tick()
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
		SND.play("error"); toast.emit("골드가 %s 모자라요" % D.comma(n - floor(S.gold))); return false
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
	S.gold += C.g; pop.emit(i, "+%d" % C.g, "gd"); SND.play("harvest"); SND.play("coin", -6.0)
	if T.crop == "corn": inc("corn")
	inc("harvest"); inc("c_" + T.crop)
	gain_xp(int(C.x), i); T.erase("crop")
	done_action()

func plant(i: int, k: String) -> bool:
	var C: Dictionary = D.CROPS[k]
	if not pay(C.cost): return false
	var T: Dictionary = S.tiles[i]
	T.crop = k; T.plantedAt = S.gt; T.readyAt = S.gt + float(C.t); SND.play("plant")
	pop.emit(i, ("-%d" % C.cost) if C.cost else "심었어요", "gd" if C.cost else "")
	done_action(); return true

func collect_tax(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	S.gold += B.g; pop.emit(i, "+%d" % B.g, "gd"); inc("tax"); SND.play("coin")
	gain_xp(max(1, int(round(float(B.g) / 10.0))), i); T.taxAt = S.gt + float(B.every)
	done_action()

func collect_job(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	S.gold += B.g; pop.emit(i, "+%d" % B.g, "gd"); inc("job"); SND.play("coin2"); gain_xp(int(B.jx), i); T.erase("job")
	done_action()

func start_job(i: int) -> void:
	var T: Dictionary = S.tiles[i]; var B: Dictionary = D.BUILDS[T.b]
	T.job = {"startAt": S.gt, "doneAt": S.gt + float(B.jt)}; pop.emit(i, "일 시작!", ""); done_action()

func make_plot(i: int) -> bool:
	if cnt(func(T): return T.t == "plot") >= plot_cap():
		toast.emit("밭은 지금 %d개까지예요. 레벨이 오르면 늘어나요" % plot_cap()); return false
	if not pay(D.PLOT_COST): return false
	S.tiles[i] = {"t": "plot"}; inc("plots"); SND.play("place"); pop.emit(i, "-%d" % D.PLOT_COST, "gd"); gain_xp(5, i)
	done_action(); return true

func do_build(i: int, k: String) -> bool:
	var B: Dictionary = D.BUILDS[k]
	if S.level < B.lv:
		SND.play("error"); toast.emit("레벨 %d부터 지을 수 있어요" % B.lv); return false
	if not pay(B.cost): return false
	var T := {"t": "bld", "b": k, "startAt": S.gt, "doneAt": S.gt + float(B.t)}
	if B.cat == "house": T.taxAt = T.doneAt + float(B.every)
	S.tiles[i] = T; pop.emit(i, "-%s" % D.comma(B.cost), "gd"); SND.play("build" if float(B.t) > 0 else "place"); gain_xp(int(B.x), i)
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
	pop.emit(i, "뿅! 완성", "mj"); SND.play("mojo"); done_action(); return true

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
	if up: castle_up.emit()
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

# ---------- 왕국 목표(튜토리얼 뒤 3개씩) ----------
func q_prog(q: Dictionary) -> int: return int(clamp(stv(q.k) - int(q.base), 0, int(q.n)))
func q_done(q: Dictionary) -> bool: return q_prog(q) >= int(q.n)
func has_cat(c: String) -> bool: return cnt(func(T): return T.t == "bld" and D.BUILDS[T.b].cat == c and bld_state(T) != "build") > 0

func new_quest() -> Dictionary:
	var lv: int = S.level
	var used: Array = []
	for q in S.get("quests", []): used.append(q.type)
	var crops: Array = []
	for k in D.CROP_ORDER:
		if int(D.CROPS[k].lv) <= lv and float(D.CROPS[k].t) <= 6.0 * D.H: crops.append(k)
	var unbuilt: Array = []
	for k in D.BUILD_ORDER:
		var B: Dictionary = D.BUILDS[k]
		if B.cat in ["house", "shop"] and int(B.lv) <= lv and cnt(func(T): return T.t == "bld" and T.b == k) == 0: unbuilt.append(k)
	unbuilt.sort_custom(func(a, b): return float(D.BUILDS[a].cost) < float(D.BUILDS[b].cost))
	var opts: Array = []
	opts.append({"type": "harvest", "k": "harvest", "n": 8 + lv * 2, "t": "작물 %d번 거두기" % (8 + lv * 2), "ic": "crop_wheat_2"})
	opts.append({"type": "deco", "k": "deco", "n": 3 + lv / 2, "t": "장식 %d개 놓기" % (3 + lv / 2), "ic": "tulip"})
	opts.append({"type": "road", "k": "road", "n": 4 + lv, "t": "길 %d칸 깔기" % (4 + lv), "ic": "plot"})
	if crops.size():
		var c: String = crops[randi() % crops.size()]; var n := 3 + lv / 3
		opts.append({"type": "crop", "k": "c_" + c, "n": n, "t": "%s %d번 거두기" % [D.CROPS[c].n, n], "ic": "crop_%s_2" % c})
	if has_cat("house"): opts.append({"type": "tax", "k": "tax", "n": 4 + lv, "t": "세금 %d번 걷기" % (4 + lv), "ic": "cottage_o"})
	if has_cat("shop"): opts.append({"type": "job", "k": "job", "n": 1 + lv / 8, "t": "가게 상품 %d번 완성하기" % (1 + lv / 8), "ic": "bakery"})
	if unbuilt.size():
		var b: String = unbuilt[0]
		opts.append({"type": "build", "k": "b_" + b, "n": 1, "t": "%s 짓기" % D.BUILDS[b].n, "ic": b, "bonus": int(round(float(D.BUILDS[b].cost) * 0.15))})
	var pool := opts.filter(func(o): return not (o.type in used))
	if pool.is_empty(): pool = opts
	var q: Dictionary = pool[randi() % pool.size()]
	q.base = stv(q.k); q.g = 50 + lv * 35 + int(q.get("bonus", 0)); q.x = 15 + lv * 10
	q.mj = 2 if q.type == "build" else (1 if randf() < 0.25 else 0)
	return q

func ensure_quests() -> void:
	if not S.has("quests") or S.quests == null: S.quests = []
	while S.quests.size() < 3: S.quests.append(new_quest())

func quests_done() -> int:
	ensure_quests()
	return S.quests.filter(func(q): return q_done(q)).size()

func claim_quest(k: int) -> void:
	var q: Dictionary = S.quests[k]
	if not q_done(q): return
	S.gold += float(q.g); S.mojo += int(q.mj)
	pop.emit(D.CI, "+%d" % q.g, "gd"); gain_xp(int(q.x), D.CI)
	if q.mj: pop.emit(D.CI, "모조 +%d" % q.mj, "mj")
	S.quests.remove_at(k); S.quests.insert(k, new_quest())
	done_action()

# ---------- 모두 거두기 ----------
func ready_count() -> int:
	return cnt(func(T): return (T.t == "plot" and crop_state(T) == "ready") or (T.t == "bld" and bld_state(T) in ["tax", "done"]))

func collect_all() -> void:
	var n := 0
	var R: Dictionary = D.RECTS[S.land]
	for r in range(R.y0, R.y1):
		for c in range(R.x0, R.x1):
			var i: int = r * D.COLS + c; var T: Dictionary = S.tiles[i]
			if T.t == "plot" and crop_state(T) == "ready": harvest(i); n += 1
			elif T.t == "bld":
				var st := bld_state(T)
				if st == "tax": collect_tax(i); n += 1
				elif st == "done": collect_job(i); n += 1
	if n: toast.emit("%d곳을 한 번에 거뒀어요" % n)

# ---------- 반짝별 ----------
func star_tick() -> void:
	var st: Dictionary = S.get("star", {})
	if st.size() and S.gt > float(st.exp):
		S.star = {}; S.nextStar = S.gt + randf_range(D.H, 3 * D.H)
	if S.get("star", {}).is_empty() and S.gt >= float(S.get("nextStar", 0)):
		var R: Dictionary = D.RECTS[S.land]; var ok: Array = []
		for r in range(R.y0, R.y1):
			for c in range(R.x0, R.x1):
				if S.tiles[r * D.COLS + c].t != "castle": ok.append(r * D.COLS + c)
		S.star = {"i": ok[randi() % ok.size()], "exp": S.gt + 40.0 * D.M}

func catch_star(i: int) -> bool:
	var st: Dictionary = S.get("star", {})
	if st.is_empty() or int(st.i) != i: return false
	SND.play("star"); S.star = {}; S.mojo += 1; S.nextStar = S.gt + randf_range(D.H, 3 * D.H)
	pop.emit(i, "모조 +1", "mj"); toast.emit("반짝별을 잡았어요! 모조 +1"); done_action(); return true

# ---------- 밤낮 ----------
func night_amt() -> float:
	var hf: float = fmod(S.gt, D.DAY) / D.H
	if hf >= 20 or hf < 5: return 1.0
	if hf >= 18: return (hf - 18) / 2.0
	if hf < 7: return (7 - hf) / 2.0
	return 0.0
