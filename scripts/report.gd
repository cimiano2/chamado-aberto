class_name Report
extends RefCounted
## Relatório de desempenho em HTML (abre em qualquer navegador e pode ser impresso em PDF).
## Inclui um código de verificação: se alguém editar os números, o código não confere mais.

const VERSION := "1.0"
const SALT := "papeis-horizonte/chamado-aberto"
const KIND_NAMES := {
	"hardware": "Defeito de hardware", "printer": "Impressora", "password": "Troca de senha",
	"slow": "PC lento (Gerenciador de Tarefas)", "phishing": "E-mail suspeito", "cables": "Conectar cabos",
	"files": "Arquivo sumiu", "install": "Instalar programa", "cleanup": "Disco cheio",
	"extensions": "Abrir arquivo (extensões)", "shortcuts": "Atalhos de teclado",
}


## Dados canônicos do relatório (o código de verificação é calculado sobre eles).
static func data(profile: Dictionary, ts: TicketSystem, mode: String, restarts: int) -> Dictionary:
	var g := ts.grade()
	return {
		"versao": VERSION,
		"aluno": profile.get("name", ""),
		"turma": profile.get("class_code", ""),
		"modo": mode,
		"gerado_em": Time.get_datetime_string_from_system(false, true),
		"dias": ts.day,
		"pontos": ts.score,
		"nota": g.nota,
		"resolucao": snappedf(g.resolution, 0.001),
		"precisao": snappedf(g.accuracy, 0.001),
		"agilidade": snappedf(g.agility, 0.001),
		"resolvidos": ts.resolved,
		"estourados": ts.expired,
		"erros": ts.mistakes,
		"melhor_sequencia": ts.best_combo,
		"satisfacao": int(ts.satisfaction),
		"tempo_jogado_s": int(ts.play_seconds),
		"reinicios": restarts,
		"por_tipo": ts.stats,
		"chamados": ts.history,
	}


## Linha canônica: os números principais + a soma dos pontos de todos os chamados.
## A página verificar.html refaz a mesma conta em JavaScript.
static func canonical(d: Dictionary) -> String:
	var sum_points := 0
	for e in d.get("chamados", []):
		sum_points += int(e.points)
	return "%s|%s|%s|%d|%.1f|%d|%d|%d|%d|%d|%d|%s" % [
		d.get("aluno", ""), d.get("turma", ""), d.get("modo", ""), int(d.get("pontos", 0)),
		float(d.get("nota", 0.0)), int(d.get("resolvidos", 0)), int(d.get("estourados", 0)),
		int(d.get("erros", 0)), int(d.get("reinicios", 0)), d.get("chamados", []).size(), sum_points, SALT]


static func verification_code(d: Dictionary) -> String:
	return canonical(d).sha256_text().substr(0, 12).to_upper()


static func file_name(profile: Dictionary) -> String:
	var n: String = profile.get("name", "aluno").to_lower().strip_edges()
	var safe := ""
	for ch in n:
		safe += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return "relatorio_chamado_aberto_%s.html" % safe


static func html(d: Dictionary) -> String:
	var code := verification_code(d)
	d = d.duplicate(true)
	d["codigo"] = code
	var rows := ""
	for kind in KIND_NAMES:
		var st: Dictionary = d.por_tipo.get(kind, {"resolved": 0, "clean": 0, "mistakes": 0, "expired": 0})
		var total: int = st.resolved + st.expired
		var acc := "%d%%" % int(100.0 * st.clean / st.resolved) if st.resolved > 0 else "—"
		rows += "<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%s</td></tr>\n" % [
			KIND_NAMES[kind], total, st.resolved, st.clean, st.expired, acc]
	var calls := ""
	for e in d.chamados:
		var cls := "ok" if e.result == "resolvido" and e.mistakes == 0 else ("bad" if e.result == "estourado" else "warn")
		calls += "<tr class='%s'><td>%d</td><td>Dia %d, %s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%.0fs</td><td>%d</td></tr>\n" % [
			cls, e.id, e.day, e.clock, _esc(e.dept), _esc(e.employee), KIND_NAMES.get(e.kind, e.kind),
			e.result, e.mistakes, e.work_s, e.points]
	var weak := _weak_points(d)
	return """<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<title>Relatório — %s</title>
<style>
body{font-family:system-ui,Segoe UI,Arial,sans-serif;max-width:900px;margin:24px auto;padding:0 16px;color:#181425;background:#fff}
h1{margin:0 0 4px;font-size:24px} .sub{color:#5a6988;margin:0 0 18px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin:16px 0}
.card{border:2px solid #181425;border-radius:6px;padding:10px;background:#f4f4f4}
.card b{display:block;font-size:26px} .card span{color:#5a6988;font-size:13px}
.nota b{color:#124e89;font-size:34px}
table{border-collapse:collapse;width:100%%;margin:8px 0 18px;font-size:14px}
th,td{border:1px solid #c0cbdc;padding:5px 7px;text-align:left} th{background:#262b44;color:#fff}
tr.ok td{background:#eaf7e6} tr.bad td{background:#fde8e8} tr.warn td{background:#fff6dd}
.code{font-family:monospace;font-size:18px;background:#181425;color:#fee761;padding:6px 10px;border-radius:4px}
.box{border-left:4px solid #feae34;background:#fff6dd;padding:8px 12px;margin:10px 0}
small{color:#5a6988}
</style></head><body>
<h1>Relatório de desempenho — Chamado Aberto</h1>
<p class="sub">Papéis Horizonte Ltda. · Suporte de TI · gerado em %s</p>
<p><b>Aluno(a):</b> %s &nbsp; · &nbsp; <b>Turma:</b> %s &nbsp; · &nbsp; <b>Modo:</b> %s</p>
<div class="cards">
 <div class="card nota"><span>Nota (0 a 10)</span><b>%.1f</b></div>
 <div class="card"><span>Pontos</span><b>%d</b></div>
 <div class="card"><span>Chamados resolvidos</span><b>%d</b></div>
 <div class="card"><span>Prazos estourados</span><b>%d</b></div>
 <div class="card"><span>Erros</span><b>%d</b></div>
 <div class="card"><span>Melhor sequência sem erro</span><b>%d</b></div>
</div>
<p><b>Como a nota é calculada:</b> 40%% taxa de resolução (%d%%) + 40%% precisão — resolvidos sem erro (%d%%) + 20%% agilidade (%d%%).<br>
<small>Dias jogados: %d · Satisfação final dos usuários: %d%% · Tempo de jogo: %d min · Reinícios da sessão: %d</small></p>
%s
<h2>Desempenho por tipo de chamado</h2>
<table><tr><th>Tipo</th><th>Recebidos</th><th>Resolvidos</th><th>Sem erro</th><th>Estourados</th><th>Precisão</th></tr>
%s</table>
<h2>Todos os chamados</h2>
<table><tr><th>#</th><th>Quando</th><th>Setor</th><th>Usuário</th><th>Tipo</th><th>Resultado</th><th>Erros</th><th>Tempo</th><th>Pontos</th></tr>
%s</table>
<p>Código de verificação: <span class="code">%s</span><br>
<small>O professor confere em <b>cimiano2.github.io/chamado-aberto/verificar.html</b>. Se algum número do relatório for alterado, o código deixa de conferir.</small></p>
<script type="application/json" id="dados">%s</script>
</body></html>""" % [_esc(d.aluno), d.gerado_em, _esc(d.aluno), _esc(d.turma if d.turma != "" else "—"), d.modo,
		d.nota, d.pontos, d.resolvidos, d.estourados, d.erros, d.melhor_sequencia,
		int(d.resolucao * 100), int(d.precisao * 100), int(d.agilidade * 100),
		d.dias, d.satisfacao, int(d.tempo_jogado_s / 60), d.reinicios, weak, rows, calls, code,
		JSON.stringify(d).replace("</", "<\\/")]


## Verifica um relatório: extrai o JSON embutido e recalcula o código.
static func verify_html(text: String) -> Dictionary:
	var a := text.find("<script type=\"application/json\" id=\"dados\">")
	if a < 0:
		return {"ok": false, "msg": "Arquivo não parece um relatório do jogo."}
	a = text.find(">", a) + 1
	var b := text.find("</script>", a)
	var d = JSON.parse_string(text.substr(a, b - a).replace("<\\/", "</"))
	if typeof(d) != TYPE_DICTIONARY:
		return {"ok": false, "msg": "Dados do relatório corrompidos."}
	var ok: bool = verification_code(d) == d.get("codigo", "")
	return {"ok": ok, "data": d, "msg": "Relatório autêntico." if ok else "ATENÇÃO: o relatório foi alterado."}


static func _weak_points(d: Dictionary) -> String:
	var tips := []
	for kind in d.por_tipo:
		var st: Dictionary = d.por_tipo[kind]
		var total: int = st.resolved + st.expired
		if total >= 2 and (st.mistakes > st.resolved or st.expired * 2 >= total):
			tips.append(KIND_NAMES.get(kind, kind))
	if tips.is_empty():
		return "<div class='box'>Nenhum ponto fraco evidente. Bom trabalho!</div>"
	return "<div class='box'><b>Pontos para revisar:</b> %s.</div>" % ", ".join(tips)


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


## Entrega o arquivo: na web, baixa pelo navegador; no computador, salva em Documentos e abre.
static func deliver(html_text: String, file: String) -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(html_text.to_utf8_buffer(), file, "text/html")
		return "Relatório baixado: %s" % file
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dir == "":
		dir = OS.get_user_data_dir()
	var path := dir.path_join(file)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		path = OS.get_user_data_dir().path_join(file)
		f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(html_text)
	f.close()
	OS.shell_open(path)
	return "Relatório salvo em %s" % path
