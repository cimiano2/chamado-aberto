# Chamado Aberto

Jogo 2D educativo feito em **Godot 4.3**. Você é o **técnico de TI** do 7º andar de uma grande empresa: anda pelo escritório **com o teclado**, chega nas mesas com chamado aberto e resolve o problema antes que o prazo (SLA) estoure. Cada problema é um conceito de **sistemas operacionais**.

![Escritório](docs/jogo.png)

## Como jogar

| Tecla | Ação |
|---|---|
| `WASD` / setas | andar |
| `E` (ou `Espaço`/`Enter`) | atender o chamado da mesa à sua frente |
| `1`–`9` | escolher opções dentro do atendimento |
| `Enter` | confirmar (quando houver botão principal) |
| `Esc` | sair do atendimento sem resolver |
| `P` | pausa para o café |

- A **seta amarela** em volta do técnico aponta para o chamado mais urgente, e o minimapa mostra todos.
- O prazo do chamado que você está atendendo **para**, mas o dos outros continua correndo.
- Chamados da **Diretoria** têm prioridade alta: prazo menor e mais pontos.
- O expediente vai das 09:00 às 18:00 (5 minutos reais). A cada dia os chamados chegam mais rápido.
- Se a **satisfação dos usuários** zerar, você é chamado na sala do gerente.

## Os chamados

![Minijogo de paginação](docs/minijogo.png)

| Chamado | Minijogo | Conceito de SO |
|---|---|---|
| "Meu computador está muito lento" | escolher a ordem de execução | Escalonamento de CPU: **FCFS, SJF, Prioridade** |
| "Aparece 'memória insuficiente'" | escolher a página que sai | Substituição de páginas: **FIFO, LRU, Ótimo** |
| "Dois sistemas travaram esperando um pelo outro" | achar uma sequência segura | Deadlock: **algoritmo do banqueiro** |
| "O servidor de arquivos está lento" | atender os cilindros na ordem | Escalonamento de disco: **SSTF, LOOK, C-LOOK** |
| "Não consigo acessar a pasta" | marcar rwx de dono/grupo/outros | Permissões **chmod** (octal e simbólico) |
| "O programa não abre por falta de memória" | escolher a lacuna | Alocação contígua: **First, Best, Worst fit** |

Os valores são sorteados a cada atendimento. Quando você erra, o jogo explica **por que** a resposta não segue o algoritmo.

## Rodando

- **Sem instalar nada:** baixe o executável (Windows/Linux) ou jogue a versão web publicada pelo GitHub Pages.
- **No Godot:** instale o [Godot 4.3](https://godotengine.org/download), importe o `project.godot` e aperte **F5**.

### Testes (headless)

```bash
godot --headless --path . --import
godot --headless --path . -s tests/test_logic.gd
godot --headless --path . -s tests/test_game.gd
```

`test_logic.gd` confere os algoritmos contra os exemplos clássicos do livro (ex.: FIFO = 15 faltas, LRU = 12, Ótimo = 9; SSTF = 236 cilindros). `test_game.gd` abre cada tipo de chamado e o resolve **pelo teclado**, inclusive com um erro proposital.

## Estrutura

```
scenes/main.tscn              mundo, HUD, painel de atendimento e menus
scripts/main.gd               fluxo do jogo (título, expediente, atendimento, fim do dia)
scripts/ticket_system.gd      fila de chamados, relógio, SLA e satisfação (sem UI)
scripts/office_map.gd         andar do escritório: salas, mesas, funcionários, colisão
scripts/player.gd             técnico controlado pelo teclado
scripts/guide.gd              seta para o chamado mais urgente
scripts/minimap.gd            minimapa
scripts/os_logic.gd           algoritmos de SO (puros, testados)
scripts/tasks/task_base.gd    base dos minijogos (teclas 1–9 / Enter)
scripts/tasks/task_*.gd       os seis minijogos
resources/theme.tres          tema visual
fonts/                        JetBrains Mono (licença OFL)
tests/                        testes headless e gerador de capturas
```

Todo o visual (escritório, técnico e funcionários) é desenhado em código e original.
