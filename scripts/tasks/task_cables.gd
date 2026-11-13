extends TaskBase
## "Mudei de mesa e nada funciona": ligar cada dispositivo na porta certa do PC.

const COUNT := 4

var devices: Array = []
var index := 0
var _device_label: Label
var _counter: Label


func _init() -> void:
	task_title = "Conectar os cabos"
	explain = "Ligue cada equipamento na porta certa da parte de trás do computador."


func build() -> void:
	var all := Helpdesk.DEVICES.duplicate()
	Helpdesk.shuffle(all, rng)
	devices = all.slice(0, COUNT)
	_counter = make_label("", &"MutedLabel")
	add_child(_counter)
	_device_label = make_label("", &"HeadingLabel", 22, WARN)
	add_child(_device_label)
	add_child(make_label("Portas do computador:", &"MutedLabel"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var colors := {"HDMI": Color("2a2a33"), "USB": Color("0099db"), "RJ45 (rede)": Color("feae34"),
		"P2 verde (áudio)": Color("63c74d"), "Energia (tomada)": Color("e43b44"), "VGA azul": Color("124e89")}
	for i in Helpdesk.PORTS.size():
		var port: String = Helpdesk.PORTS[i]
		var b := make_button(port, _on_port.bind(port), true, Vector2(250, 52))
		tint_button(b, colors[port])
		grid.add_child(b)
	_show()


func _show() -> void:
	_counter.text = "Equipamento %d de %d" % [index + 1, COUNT]
	_device_label.text = "Onde ligar: %s?" % devices[index].name


func _on_port(port: String) -> void:
	if is_solved:
		return
	var d: Dictionary = devices[index]
	if not d.ports.has(port):
		wrong("%s não vai em %s. %s" % [d.name, port, d.tip])
		return
	index += 1
	if index >= COUNT:
		solve("Tudo conectado e funcionando na mesa nova!")
	else:
		say("%s ligado em %s." % [d.name, port])
		_show()
