extends RefCounted
## 손가락 터치만으로 튜토리얼 8단계 완주 테스트 (진짜 화면 터치 이벤트를 넣음)
var m

func tap_at(p0: Vector2) -> void:
	var p: Vector2 = m.get_viewport().get_screen_transform() * p0   # 화면(창) 좌표로
	var a := InputEventScreenTouch.new(); a.index = 0; a.position = p; a.pressed = true
	Input.parse_input_event(a)
	await m.get_tree().process_frame
	var b := InputEventScreenTouch.new(); b.index = 0; b.position = p; b.pressed = false
	Input.parse_input_event(b)
	await m.get_tree().create_timer(0.25).timeout

func tap_ctrl(c: Control) -> void:
	await tap_at(c.get_global_rect().get_center())

func find_btn(n: Node, txt: String) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and (c.text == txt or c.text.begins_with(txt)) and not c.disabled: return c
		var r := find_btn(c, txt)
		if r: return r
	return null

func find_card(n: Node, title: String) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and not c.disabled:
			for l in c.find_children("*", "Label", true, false):
				if l.text == title: return c
		var r := find_card(c, title)
		if r: return r
	return null

func run(main) -> void:
	m = main
	var ui = main.ui
	await m.get_tree().create_timer(0.8).timeout
	G.reset(); ui.show_intro()
	await m.get_tree().create_timer(0.5).timeout
	printerr("TT start"); await tap_ctrl(ui.intro.find_child("GoStart", true, false)); printerr("TT ruler")
	await tap_ctrl(ui.intro.find_child("GoName", true, false))
	await tap_ctrl(ui.intro.find_child("GoPlay", true, false))
	var want := {0: "옥수수", 1: "밭", 2: "밀", 3: "소나무", 4: "주황 오두막", 7: "흙길"}
	var tab := {3: "장식", 4: "집", 7: "길·울타리"}
	var stuck := 0
	var lastg := -1
	for k in 300:
		if G.S.goal != lastg: lastg = G.S.goal; printerr("  목표 ", lastg, " (", k, ")")
		if G.S.goal >= D.GOALS.size(): break
		await m.get_tree().create_timer(0.15).timeout
		if ui.lv_box.visible:
			await tap_ctrl(find_btn(ui.lv_box, "좋아요")); continue
		if ui.talking:
			await tap_ctrl(ui.talk_btn); continue
		if ui.is_sheet_open():
			var g: int = G.S.goal
			if tab.has(g) and find_btn(ui.sheet, tab[g]): await tap_ctrl(find_btn(ui.sheet, tab[g]))
			await m.get_tree().create_timer(0.3).timeout
			var c: Button = find_card(ui.sheet, want.get(g, "")) if want.has(g) else null
			if g == 2 and c == null: c = find_btn(ui.sheet, "모조")
			if g == 6: c = find_btn(ui.sheet, "땅 넓히기")
			if c: await tap_ctrl(c)
			else:
				if g == 5: G.S.gt += 600   # 세금이 쌓일 때까지 기다림
				printerr("  창[", ui.sheet_title.text, "] 고를 것 없음 → 닫기"); await tap_ctrl(find_btn(ui.sheet, "✕"))
			continue
		var p = ui.hand_point()
		if p == null:
			G.S.gt += 600; continue
		var before := JSON.stringify([G.S.goal, G.S.gold, G.S.tiles.hash(), ui.is_sheet_open(), ui.talking, G.placing])
		await tap_at(p)
		var after := JSON.stringify([G.S.goal, G.S.gold, G.S.tiles.hash(), ui.is_sheet_open(), ui.talking, G.placing])
		if before == after:
			stuck += 1; printerr("  반응 없음: 목표 ", G.S.goal, " 위치 ", p)
			G.S.gt += 3600
	printerr("TOUCHTEST goal=", G.S.goal, "/", D.GOALS.size(), " 무반응=", stuck)
	m.get_tree().quit()
