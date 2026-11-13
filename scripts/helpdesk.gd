class_name Helpdesk
extends RefCounted
## Conteúdo e regras dos chamados de suporte (sem UI, coberto por tests/test_logic.gd).


# ====================================================================
# Senha: política da empresa
# ====================================================================

const SPECIALS := "!@#$%&*?-_+=."

## Lista os problemas de uma senha segundo a política. Vazia = senha válida.
static func password_problems(pw: String, full_name: String) -> Array[String]:
	var out: Array[String] = []
	if pw.length() < 10:
		out.append("tem só %d caracteres (mínimo 10)" % pw.length())
	var up := false
	var low := false
	var digit := false
	var special := false
	for ch in pw:
		if ch >= "A" and ch <= "Z": up = true
		elif ch >= "a" and ch <= "z": low = true
		elif ch >= "0" and ch <= "9": digit = true
		elif SPECIALS.contains(ch): special = true
	if not up: out.append("não tem letra MAIÚSCULA")
	if not low: out.append("não tem letra minúscula")
	if not digit: out.append("não tem número")
	if not special: out.append("não tem símbolo (ex.: ! @ # $)")
	var lower := pw.to_lower()
	for part in full_name.to_lower().split(" ", false):
		if part.length() >= 3 and lower.contains(part):
			out.append("contém o nome do usuário (\"%s\")" % part)
	for weak in ["123", "senha", "empresa", "qwerty", "abc"]:
		if lower.contains(weak):
			out.append("contém sequência fácil (\"%s\")" % weak)
			break
	return out


# ====================================================================
# Hardware: sintoma → componente com defeito (conteúdo do 1º semestre)
# ====================================================================

const HARDWARE := [
	{"part": "Memória RAM mal encaixada", "fix": "Desligar, tirar a memória, limpar os contatos com borracha e encaixar de novo até travar.",
	 "symptom": "Liga, as ventoinhas giram, mas o PC dá vários BIPES e não aparece nada na tela."},
	{"part": "Fonte de alimentação", "fix": "Conferir o cabo de força e a chave da fonte; se continuar, trocar a fonte.",
	 "symptom": "Aperto o botão e não acontece NADA: nenhuma luz, nenhuma ventoinha, nenhum barulho."},
	{"part": "Cabo de vídeo do monitor", "fix": "Encaixar firme o cabo HDMI/VGA no monitor e no PC e escolher a entrada certa no monitor.",
	 "symptom": "O PC liga normal (luz acesa e ventoinha girando), mas o monitor diz \"Sem sinal\"."},
	{"part": "Cooler sujo (superaquecimento)", "fix": "Limpar a poeira do cooler e das saídas de ar; conferir a pasta térmica.",
	 "symptom": "O PC desliga sozinho depois de uns minutos e a lateral do gabinete fica muito quente."},
	{"part": "Bateria da placa-mãe", "fix": "Trocar a bateria redonda (CR2032) da placa-mãe e acertar data e hora.",
	 "symptom": "Toda vez que ligo, a data e a hora voltam para 01/01/2000."},
	{"part": "HD com defeito", "fix": "Fazer backup URGENTE dos arquivos e trocar o HD (de preferência por um SSD).",
	 "symptom": "O PC está lentíssimo para abrir arquivos e faz um barulho de \"tec... tec...\" lá dentro."},
	{"part": "Teclado desconectado", "fix": "Reconectar o teclado na porta USB (ou trocar as pilhas, se for sem fio).",
	 "symptom": "A tela de senha aparece, mas nenhuma tecla funciona e as luzes do teclado estão apagadas."},
]


# ====================================================================
# Impressora: problemas e ações
# ====================================================================

const PRINTER_ISSUES := {
	"jam": {"msg": "Atolamento de papel na bandeja 2", "fix": "Remover o papel atolado"},
	"paper": {"msg": "Bandeja vazia: coloque papel A4", "fix": "Repor papel A4"},
	"toner": {"msg": "Toner preto vazio", "fix": "Trocar o cartucho de toner"},
	"offline": {"msg": "Windows: impressora OFFLINE", "fix": "Colocar a impressora online"},
	"queue": {"msg": "Fila travada: 14 documentos aguardando", "fix": "Limpar a fila de impressão"},
}
const PRINTER_JOKES := ["Reinstalar o Windows", "Dar um tapa na impressora"]


# ====================================================================
# Gerenciador de tarefas: processos (essencial = não pode finalizar)
# ====================================================================

const PROCESSES_ESSENTIAL := [
	{"name": "explorer.exe", "desc": "Área de trabalho do Windows", "cpu": 2, "ram": 90},
	{"name": "svchost.exe", "desc": "Serviços do Windows", "cpu": 1, "ram": 60},
	{"name": "MsMpEng.exe", "desc": "Antivírus (Defender)", "cpu": 3, "ram": 150},
	{"name": "winlogon.exe", "desc": "Logon do Windows", "cpu": 0, "ram": 8},
	{"name": "audiodg.exe", "desc": "Áudio do sistema", "cpu": 1, "ram": 20},
]
const PROCESSES_NORMAL := [
	{"name": "teams.exe", "desc": "Microsoft Teams", "cpu": 4, "ram": 380},
	{"name": "outlook.exe", "desc": "E-mail", "cpu": 2, "ram": 210},
	{"name": "excel.exe", "desc": "Planilha aberta", "cpu": 3, "ram": 260},
	{"name": "spotify.exe", "desc": "Música", "cpu": 1, "ram": 160},
]
const PROCESSES_CULPRIT := [
	{"name": "chrome.exe", "desc": "Navegador com 87 abas", "cpu": 62, "ram": 6200},
	{"name": "atualizador.exe", "desc": "Atualizador travado", "cpu": 95, "ram": 120},
	{"name": "bitminer.exe", "desc": "Programa desconhecido", "cpu": 99, "ram": 900},
	{"name": "render_video.exe", "desc": "Exportação de vídeo esquecida", "cpu": 88, "ram": 3100},
	{"name": "jogo_cracked.exe", "desc": "Jogo pirata com malware", "cpu": 74, "ram": 1800},
]


# ====================================================================
# E-mails: legítimo ou golpe (phishing)
# ====================================================================

const EMAILS := [
	{"phish": true, "from": "suporte@micros0ft-seguranca.com", "subject": "URGENTE: sua conta será bloqueada em 1h",
	 "body": "Clique no link e confirme sua senha para evitar o bloqueio.", "why": "Domínio falso (micros0ft com zero), urgência e pede senha."},
	{"phish": true, "from": "financeiro@empresa-pagamentos.net", "subject": "Boleto em atraso - abra o anexo",
	 "body": "Segue boleto_atrasado.pdf.exe para pagamento imediato.", "why": "Anexo .exe disfarçado de PDF e domínio de fora da empresa."},
	{"phish": true, "from": "premios@sorteio-oficial.club", "subject": "Parabéns! Você ganhou um iPhone",
	 "body": "Informe CPF e cartão para pagar só o frete.", "why": "Prêmio que você não pediu + pedido de dados pessoais e cartão."},
	{"phish": true, "from": "diretor.geral@gmail.com", "subject": "Preciso de um favor rápido e sigiloso",
	 "body": "Compre 5 cartões-presente e me mande os códigos. Não comente com ninguém.", "why": "Golpe do falso chefe: e-mail pessoal, segredo e pedido de dinheiro."},
	{"phish": true, "from": "noreply@banco-do-brasiI.com", "subject": "Atualize seu cadastro",
	 "body": "Seu acesso expira hoje. Entre em http://bb-atualiza.xyz", "why": "\"brasiI\" com i maiúsculo no lugar do L e link para site estranho."},
	{"phish": false, "from": "rh@empresa.com.br", "subject": "Calendário de feriados do ano",
	 "body": "Confira no portal interno o calendário de feriados e pontes.", "why": "Remetente do domínio da empresa, sem pedir senha nem dados."},
	{"phish": false, "from": "ti@empresa.com.br", "subject": "Manutenção programada no sábado",
	 "body": "O sistema ERP ficará fora do ar sábado das 8h às 12h.", "why": "Aviso informativo do domínio oficial, sem links nem pedidos."},
	{"phish": false, "from": "reunioes@empresa.com.br", "subject": "Convite: reunião de equipe às 15h",
	 "body": "Sala 7B. Pauta: metas do trimestre.", "why": "Convite interno comum, sem anexos executáveis."},
]


# ====================================================================
# Cabos: dispositivo → porta correta
# ====================================================================

const PORTS := ["HDMI", "USB", "RJ45 (rede)", "P2 verde (áudio)", "Energia (tomada)", "VGA azul"]
const DEVICES := [
	{"name": "Monitor novo", "ports": ["HDMI"], "tip": "Monitores modernos usam HDMI (vídeo + áudio digital)."},
	{"name": "Teclado", "ports": ["USB"], "tip": "Teclado e mouse ligam na porta USB."},
	{"name": "Mouse", "ports": ["USB"], "tip": "Teclado e mouse ligam na porta USB."},
	{"name": "Cabo de rede azul", "ports": ["RJ45 (rede)"], "tip": "O cabo de rede tem conector RJ45, com trava."},
	{"name": "Caixinha de som", "ports": ["P2 verde (áudio)"], "tip": "Saída de áudio é o P2 verde."},
	{"name": "Fonte do PC", "ports": ["Energia (tomada)"], "tip": "O cabo de força vai na fonte e na tomada/estabilizador."},
	{"name": "Projetor antigo", "ports": ["VGA azul", "HDMI"], "tip": "Projetores antigos usam VGA (azul); muitos aceitam HDMI."},
	{"name": "Impressora", "ports": ["USB", "RJ45 (rede)"], "tip": "Impressora pode ser ligada por USB ou pela rede."},
]


# ====================================================================
# util

static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
