extends TaskBase
## "Recebi e-mails estranhos": classificar 3 e-mails como legítimos ou golpe.

const COUNT := 3

var emails: Array = []
var index := 0
var _from: Label
var _subject: Label
var _body: Label
var _counter: Label


func _init() -> void:
	task_title = "E-mail suspeito"
	explain = "Sinais de golpe: remetente de fora ou com letra trocada, urgência, pedido de senha ou dados, anexo .exe e prêmios que você não pediu."


func build() -> void:
	var phish := Helpdesk.EMAILS.filter(func(e): return e.phish)
	var legit := Helpdesk.EMAILS.filter(func(e): return not e.phish)
	Helpdesk.shuffle(phish, rng)
	Helpdesk.shuffle(legit, rng)
	emails = [phish[0], phish[1], legit[0]]
	Helpdesk.shuffle(emails, rng)
	_counter = make_label("", &"MutedLabel")
	add_child(_counter)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f4f4")
	style.border_color = Color("181425")
	style.set_border_width_all(3)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	_from = make_label("", &"", 16, Color("3a4466"))
	_subject = make_label("", &"", 20, Color("181425"))
	_body = make_label("", &"", 17, Color("262b44"))
	_body.custom_minimum_size = Vector2(740, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [_from, _subject, _body]:
		v.add_child(l)
	var r := row(12)
	add_child(r)
	r.add_child(make_button("Legítimo", _on_answer.bind(false), true, Vector2(240, 48)))
	r.add_child(make_button("Golpe (phishing)", _on_answer.bind(true), true, Vector2(240, 48)))
	_show()


func _show() -> void:
	var e: Dictionary = emails[index]
	_counter.text = "E-mail %d de %d" % [index + 1, COUNT]
	_from.text = "De: " + e.from
	_subject.text = e.subject
	_body.text = e.body


func _on_answer(is_phish: bool) -> void:
	if is_solved:
		return
	var e: Dictionary = emails[index]
	if is_phish != e.phish:
		wrong(("É golpe! " if e.phish else "Esse é legítimo. ") + e.why)
		return
	index += 1
	if index >= COUNT:
		solve("Golpes identificados! Oriente o usuário a nunca informar senha por e-mail.")
	else:
		say(("Isso, é golpe: " if e.phish else "Isso, é legítimo: ") + e.why)
		_show()
