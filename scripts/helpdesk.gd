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
	{"part": "Pilhas do mouse sem fio", "fix": "Trocar as pilhas do mouse (ou recarregar) e conferir se o receptor USB está encaixado.",
	 "symptom": "O ponteiro do mouse anda aos pulinhos, trava e às vezes some da tela."},
	{"part": "Bateria do notebook", "fix": "A bateria está gasta: usar na tomada por enquanto e pedir uma bateria nova.",
	 "symptom": "O notebook só funciona ligado na tomada; tirando o carregador ele apaga na hora."},
	{"part": "Pen drive com defeito", "fix": "Testar em outra porta e outro PC; se não aparecer em nenhum, o pen drive estragou (recuperar do backup).",
	 "symptom": "O pen drive não aparece em nenhum computador, e a luzinha dele não acende."},
	{"part": "Monitor desligado no botão", "fix": "Ligar o monitor no botão dele (a luz fica azul/verde) e conferir o cabo de energia.",
	 "symptom": "O PC está ligado, mas a luz do monitor está apagada e a tela totalmente escura."},
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
	{"name": "winword.exe", "desc": "Documento aberto", "cpu": 2, "ram": 180},
	{"name": "acrobat.exe", "desc": "PDF aberto", "cpu": 1, "ram": 140},
]
const PROCESSES_CULPRIT := [
	{"name": "chrome.exe", "desc": "Navegador com 87 abas", "cpu": 62, "ram": 6200},
	{"name": "atualizador.exe", "desc": "Atualizador travado", "cpu": 95, "ram": 120},
	{"name": "bitminer.exe", "desc": "Programa desconhecido", "cpu": 99, "ram": 900},
	{"name": "render_video.exe", "desc": "Exportação de vídeo esquecida", "cpu": 88, "ram": 3100},
	{"name": "jogo_cracked.exe", "desc": "Jogo pirata com malware", "cpu": 74, "ram": 1800},
	{"name": "toolbar_promo.exe", "desc": "Barra de ferramentas instalada sem querer", "cpu": 67, "ram": 640},
	{"name": "video_4k_loop.exe", "desc": "Vídeo em 4K tocando escondido", "cpu": 81, "ram": 2400},
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
	{"phish": true, "from": "entregas@correios-rastreio.top", "subject": "Sua encomenda foi taxada",
	 "body": "Pague R$ 19,90 pelo link para liberar a entrega hoje.", "why": "Domínio estranho (.top) e cobrança urgente por link: golpe da encomenda."},
	{"phish": true, "from": "ti-suporte@empresa-com-br.net", "subject": "Sua caixa de e-mail está cheia",
	 "body": "Faça login aqui para ganhar mais espaço: http://empresa-login.net", "why": "Imita o domínio da empresa (empresa-com-br.net) e pede login num site de fora."},
	{"phish": true, "from": "rh.folha@outlook.com", "subject": "Atualize seus dados bancários até hoje",
	 "body": "Envie agência, conta e senha do banco para receber o salário.", "why": "RH de verdade não usa e-mail pessoal nem pede senha do banco."},
	{"phish": false, "from": "rh@empresa.com.br", "subject": "Holerite disponível no portal",
	 "body": "Seu holerite de outubro já está no portal do colaborador.", "why": "Domínio oficial e manda usar o portal interno, sem pedir dados."},
	{"phish": false, "from": "financeiro@empresa.com.br", "subject": "Prazo de reembolso de despesas",
	 "body": "Lembrete: envie os comprovantes até sexta pelo sistema interno.", "why": "Remetente oficial e aviso de rotina, sem links suspeitos."},
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
	{"name": "Fone de ouvido", "ports": ["P2 verde (áudio)", "USB"], "tip": "Fone com plugue P2 vai na saída verde; alguns são USB."},
	{"name": "Pen drive", "ports": ["USB"], "tip": "Pen drive é USB."},
	{"name": "Webcam", "ports": ["USB"], "tip": "Webcams de mesa ligam na USB."},
	{"name": "Nobreak (energia do PC)", "ports": ["Energia (tomada)"], "tip": "O cabo de força do PC vai no nobreak, que protege contra quedas de energia."},
]


# ====================================================================
# Arquivo sumiu: situação → onde recuperar
# ====================================================================

const FILES := [
	{"case": "Apaguei a planilha hoje de manhã sem querer (apertei Delete).", "answer": "Procurar na Lixeira e restaurar",
	 "why": "Arquivo apagado com Delete vai para a Lixeira: dá para restaurar."},
	{"case": "Salvei por cima do relatório certo com uma versão errada.", "answer": "Restaurar uma versão anterior do arquivo",
	 "why": "O Windows/OneDrive guarda versões anteriores: clique com o direito > Restaurar versões anteriores."},
	{"case": "O HD do meu PC queimou e o técnico disse que não liga mais.", "answer": "Recuperar do backup do servidor",
	 "why": "Quando o disco estraga, só o backup salva os arquivos. Por isso o backup é tão importante!"},
	{"case": "Salvei o arquivo ontem, mas não lembro em qual pasta.", "answer": "Pesquisar o nome no Explorador de Arquivos",
	 "why": "O arquivo não sumiu, só está em outra pasta: use a busca do Explorador ou a lista de recentes."},
	{"case": "Esvaziei a Lixeira semana passada e o arquivo estava lá.", "answer": "Recuperar do backup do servidor",
	 "why": "Depois de esvaziar a Lixeira, o caminho seguro é o backup."},
	{"case": "O arquivo estava no pen drive e o pen drive sumiu.", "answer": "Recuperar do backup do servidor",
	 "why": "Pen drive se perde fácil: arquivos importantes devem ficar também no servidor/nuvem."},
	{"case": "Fechei o Word sem salvar e o documento sumiu.", "answer": "Abrir o Word e usar Recuperar documentos não salvos",
	 "why": "Os editores guardam rascunhos automáticos: Arquivo > Informações > Recuperar documentos não salvos."},
]
const FILE_OPTIONS := ["Procurar na Lixeira e restaurar", "Restaurar uma versão anterior do arquivo",
	"Recuperar do backup do servidor", "Pesquisar o nome no Explorador de Arquivos",
	"Abrir o Word e usar Recuperar documentos não salvos", "Formatar o computador"]


# ====================================================================
# Instalar programa: passos na ordem certa (e armadilhas para evitar)
# ====================================================================

const INSTALLS := [
	{"program": "Leitor de PDF", "steps": ["Conferir se o PC tem os requisitos", "Baixar do site oficial do fabricante",
		"Executar o instalador como administrador", "Desmarcar as ofertas de programas extras", "Abrir um PDF para testar"]},
	{"program": "LibreOffice", "steps": ["Conferir se o PC tem os requisitos", "Baixar do site oficial libreoffice.org",
		"Executar o instalador como administrador", "Escolher a instalação típica", "Abrir o Writer para testar"]},
	{"program": "Zoom (videochamada)", "steps": ["Baixar do site oficial zoom.us", "Executar o instalador",
		"Fazer login com a conta da empresa", "Testar câmera e microfone", "Fixar o atalho na barra de tarefas"]},
	{"program": "Antivírus da empresa", "steps": ["Desinstalar o antivírus antigo", "Reiniciar o computador",
		"Baixar o antivírus do servidor da empresa", "Instalar e atualizar as vacinas", "Fazer uma verificação completa"]},
	{"program": "Driver da impressora", "steps": ["Anotar o modelo da impressora", "Baixar o driver no site do fabricante",
		"Instalar o driver", "Conectar a impressora", "Imprimir uma página de teste"]},
]
const INSTALL_TRAPS := ["Baixar de um site de \"programas grátis\" desconhecido", "Desativar o antivírus para instalar mais rápido",
	"Usar um \"crack\" para não pagar a licença", "Aceitar todas as barras de ferramentas extras",
	"Instalar sem perguntar ao chefe se pode"]


# ====================================================================
# Disco cheio: o que pode apagar (seguro) e o que não pode
# ====================================================================

const CLEANUP_SAFE := [
	{"name": "Lixeira", "gb": 6.0}, {"name": "Arquivos temporários", "gb": 4.5},
	{"name": "Cache do navegador", "gb": 2.5}, {"name": "Instaladores antigos em Downloads", "gb": 5.0},
	{"name": "Arquivos de atualizações antigas do Windows", "gb": 7.0}, {"name": "Miniaturas de imagens", "gb": 1.0},
]
const CLEANUP_UNSAFE := [
	{"name": "Pasta Documentos do usuário", "gb": 12.0, "why": "são os arquivos de trabalho do usuário!"},
	{"name": "C:\\Windows\\System32", "gb": 9.0, "why": "é o coração do Windows: o PC para de ligar."},
	{"name": "C:\\Arquivos de Programas", "gb": 15.0, "why": "apagar programas assim quebra tudo; desinstale pelo Painel."},
	{"name": "Relatórios do Financeiro", "gb": 8.0, "why": "são documentos da empresa!"},
	{"name": "Área de Trabalho do usuário", "gb": 6.0, "why": "o usuário guarda arquivos importantes ali."},
]


# ====================================================================
# Extensões: qual programa abre o arquivo
# ====================================================================

const EXT_PROGRAMS := ["Word / Writer (texto)", "Excel / Calc (planilha)", "PowerPoint / Impress (slides)",
	"Leitor de PDF", "Visualizador de imagens", "Player de vídeo", "Descompactador (zip)", "Bloco de Notas"]
const EXTENSIONS := [
	{"file": "contrato_cliente.docx", "program": "Word / Writer (texto)"},
	{"file": "orcamento_2025.xlsx", "program": "Excel / Calc (planilha)"},
	{"file": "apresentacao_vendas.pptx", "program": "PowerPoint / Impress (slides)"},
	{"file": "nota_fiscal_0193.pdf", "program": "Leitor de PDF"},
	{"file": "logo_empresa.png", "program": "Visualizador de imagens"},
	{"file": "foto_evento.jpg", "program": "Visualizador de imagens"},
	{"file": "treinamento_seguranca.mp4", "program": "Player de vídeo"},
	{"file": "fotos_da_obra.zip", "program": "Descompactador (zip)"},
	{"file": "leia-me.txt", "program": "Bloco de Notas"},
	{"file": "lista_clientes.csv", "program": "Excel / Calc (planilha)"},
	{"file": "ata_reuniao.odt", "program": "Word / Writer (texto)"},
	{"file": "relatorio_mensal.ods", "program": "Excel / Calc (planilha)"},
]


# ====================================================================
# Atalhos de teclado
# ====================================================================

const SHORTCUTS := [
	{"q": "Copiar o texto selecionado", "a": "Ctrl + C"}, {"q": "Colar o que foi copiado", "a": "Ctrl + V"},
	{"q": "Recortar (mover) o texto", "a": "Ctrl + X"}, {"q": "Desfazer a última ação", "a": "Ctrl + Z"},
	{"q": "Salvar o arquivo", "a": "Ctrl + S"}, {"q": "Imprimir", "a": "Ctrl + P"},
	{"q": "Selecionar tudo", "a": "Ctrl + A"}, {"q": "Procurar uma palavra no documento", "a": "Ctrl + F"},
	{"q": "Bloquear o PC ao sair da mesa", "a": "Windows + L"}, {"q": "Alternar entre janelas abertas", "a": "Alt + Tab"},
	{"q": "Abrir o Gerenciador de Tarefas", "a": "Ctrl + Shift + Esc"}, {"q": "Mostrar a área de trabalho", "a": "Windows + D"},
	{"q": "Abrir o Explorador de Arquivos", "a": "Windows + E"}, {"q": "Tirar um print de parte da tela", "a": "Windows + Shift + S"},
]


# ====================================================================
# Sorteio sem repetir os casos recentes
# ====================================================================

static var _recent := {}


## Sorteia `count` índices de 0..size-1 evitando os usados recentemente em `key`.
static func pick_fresh(key: String, size: int, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var recent: Array = _recent.get(key, [])
	var pool: Array = range(size).filter(func(i): return not recent.has(i))
	if pool.size() < count:
		pool = range(size)
		recent = []
	shuffle(pool, rng)
	var out: Array[int] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	recent.append_array(out)
	# lembra no máximo metade dos casos, para sempre sobrar variedade
	while recent.size() > maxi(1, size / 2):
		recent.pop_front()
	_recent[key] = recent
	return out


# ====================================================================
# util

static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
