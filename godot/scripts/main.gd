extends Node
## 말랑 왕국 — 지도(World) + 화면 UI 연결, 테스트용 캡처
var world
var ui
var tt

func _ready() -> void:
	world = preload("res://scripts/world.gd").new()
	add_child(world)
	ui = preload("res://scripts/ui.gd").new()
	ui.world = world
	add_child(ui)
	world.tapped.connect(ui.on_tap)
	var args := OS.get_cmdline_user_args()
	if "--shots" in args: _shots(args[args.find("--shots") + 1])
	if "--ribshots" in args: _ribshots(args[args.find("--ribshots") + 1])
	if "--touchtest" in args:
		tt = preload("res://scripts/touch_test.gd").new(); tt.run(self)

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _shots(dir: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await shot(dir + "/g0_intro.png")
	G.reset(); G.S.started = true
	if ui.intro: ui.intro.queue_free()
	ui.intro = null; G.set_goal(0)
	# 보여주기용 왕국
	G.S.land = 4; G.S.level = 15; G.S.gold = 12500
	var A := func(c, r): return r * D.COLS + c
	var ks := ["cottage_o", "cottage_b", "cottage_s", "bakery", "guild", "wizard", "tavern", "school"]
	for n in ks.size(): G.S.tiles[A.call(24 + n, 25)] = {"t": "bld", "b": ks[n], "startAt": 0, "doneAt": 0, "taxAt": 1e12}
	var ds := ["oak", "pine", "tulip", "fountain", "maple", "lamp"]
	for n in ds.size(): G.S.tiles[A.call(24 + n, 32)] = {"t": "bld", "b": ds[n], "startAt": 0, "doneAt": 0}
	for c in range(24, 34): G.S.tiles[A.call(c, 27)] = {"t": "bld", "b": "road_stone", "startAt": 0, "doneAt": 0}
	for c in [27, 28, 29]: G.S.tiles[A.call(c, 30)] = {"t": "plot", "crop": "pumpkin", "plantedAt": 0, "readyAt": G.S.gt - 10}
	G.S.tiles[A.call(24, 25)].taxAt = 0
	for e in [[25, 29, "pond"], [32, 29, "griffin"], [32, 31, "dragon"]]: G.S.tiles[A.call(e[0], e[1])] = {"t": "bld", "b": e[2], "startAt": 0, "doneAt": 0}
	G.S.tiles[A.call(26, 31)] = {"t": "bld", "b": "school", "startAt": G.S.gt - 1000, "doneAt": G.S.gt + 3000}
	G.land_changed.emit(); G.tiles_changed.emit(); G.changed.emit(); ui.update_hud()
	await get_tree().create_timer(1.0).timeout
	await shot(dir + "/g1_kingdom.png")
	world.cam.zoom = Vector2(2.4, 2.4); world.cam.position = D.P(28.5, 28)
	await get_tree().create_timer(0.6).timeout
	await shot(dir + "/g2_zoom.png")
	world.fit_all()
	await get_tree().create_timer(0.6).timeout
	await shot(dir + "/g3_all.png")
	world.fit_cam(); ui.shop_tab = "house"; ui.open_shop(false)
	await get_tree().create_timer(0.8).timeout
	await shot(dir + "/g4_shop.png")
	ui.close_sheet(); ui.say([{"t": "테스트 대사예요. 몽실이가 말해요.", "rw": [["coin", 330], ["star", 95]]}])
	await get_tree().create_timer(0.6).timeout
	await shot(dir + "/g5_talk.png")
	ui._next_talk(); ui.lv_queue.append([16, 3]); ui._show_lv()
	await get_tree().create_timer(0.8).timeout
	await shot(dir + "/g6_lvup.png")
	ui.lv_box.visible = false
	world.cam.zoom = Vector2(1.6, 1.6); world.cam.position = D.P(28, 26.5)
	G.S.star = {"i": 31 * D.COLS + 25, "exp": G.S.gt + 9999}
	await get_tree().create_timer(3.0).timeout
	for wk in world.walkers.slice(0, 2): world.greet(wk)
	await get_tree().create_timer(0.5).timeout
	await shot(dir + "/g7_people.png")
	G.S.gt = floor(G.S.gt / D.DAY) * D.DAY + 22 * D.H
	await get_tree().create_timer(0.6).timeout
	await shot(dir + "/g8_night.png")
	G.S.gt = floor(G.S.gt / D.DAY) * D.DAY + 11 * D.H; G.set_goal(D.GOALS.size()); ui.open_quests()
	await get_tree().create_timer(0.8).timeout
	await shot(dir + "/g9_quests.png")
	ui.close_sheet(); G.S.gold = 99999; ui.start_land_preview()
	await get_tree().create_timer(0.8).timeout
	await shot(dir + "/g10_buy.png")
	ui.end_land_preview(); world.fit_cam()
	await get_tree().create_timer(0.5).timeout
	await shot(dir + "/g11_normal.png")
	get_tree().quit()

func _ribshots(dir: String) -> void:
	await get_tree().create_timer(1.0).timeout
	G.reset(); G.S.started = true
	if ui.intro: ui.intro.queue_free()
	ui.intro = null; G.set_goal(D.GOALS.size()); G.S.level = 10; ui.update_hud(); ui.toast_p.visible = false; G.S.daily = G.today()
	for col in ["coral", "pink"]:
		ui.rib_color = col
		ui.shop_tab = "house"; ui.open_shop(false)
		await get_tree().create_timer(0.7).timeout
		await shot(dir + "/rib_%s_shop.png" % col)
		ui.close_sheet(); ui.shop_tab = "house"; ui.open_shop(true)
		await get_tree().create_timer(0.7).timeout
		await shot(dir + "/rib_%s_long.png" % col)
		ui.close_sheet(); ui.open_quests()
		await get_tree().create_timer(0.7).timeout
		await shot(dir + "/rib_%s_quest.png" % col)
		ui.close_sheet()
	get_tree().quit()
