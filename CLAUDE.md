# Chamado Aberto

Jogo educativo 2D em pixel art isométrica, **Godot 4.3** (GL Compatibility), para alunos do
1º semestre do técnico em informática. O aluno é o técnico de TI da *Papéis Horizonte Ltda.* e
resolve chamados de suporte (minijogos) antes que o prazo estoure. Modo Avaliação gera nota de
0 a 10 e relatório com código de verificação. Publicado no GitHub Pages pelo CI
(`.github/workflows/web.yml`); executáveis Windows/Linux exportados à mão.

Detalhes para jogadores e professor: `README.md`.

## Estrutura

- `scripts/main.gd` — fluxo (menu, expediente, atendimento, pausa, fim), câmera, escala, toque
- `scripts/office_map.gd` — salas, mesas, colisão, rota (AStarGrid2D), desenho isométrico
- `scripts/ticket_system.gd` — chamados, prazos, pontuação, nota (sem interface)
- `scripts/helpdesk.gd` — conteúdo dos casos; `scripts/tasks/` — minijogos
- `scripts/report.gd` + `web/verificar.html` — relatório e conferência pelo professor
- `art/*/build.py` — geram a pixel art em `assets/sprites/` (rodar `art/atlas/build.py` por último)
- `tests/` — testes headless e geradores de captura

## Comandos

```bash
godot --headless --path . --import
godot --headless --path . -s tests/test_logic.gd
godot --headless --path . -s tests/test_game.gd
godot --headless --fixed-fps 60 --path . -s tests/test_camera.gd
xvfb-run -a godot --path . -s tests/screenshot.gd -- <pasta>        # capturas de todas as telas
xvfb-run -a -s "-screen 0 2600x1500x24" godot --path . --resolution 1366x768 -s tests/scale_check.gd -- <pasta> 1366x768
xvfb-run -a godot --path . -s tests/profile.gd                       # FPS e draw calls
```

Todos os testes devem passar antes de um commit; mudança visível é conferida com captura.

## Regras do projeto

- Arte, música e personagens **originais**: não copiar franquias, séries ou jogos famosos.
- Problemas de suporte do dia a dia, sem conteúdo de redes (os alunos ainda não viram).
- Penalidades leves (erro −10, prazo estourado −20). Se mudar pontuação ou nota, atualizar
  juntos: código, `README.md`, ajuda do menu (`scripts/menu.gd`) e testes.
- Mundo em pixel art sempre em escala inteira de pixels reais (evita tremor); textos em
  Atkinson Hyperlegible; jogável por teclado, mouse e toque.
- Mudar `Report.SALT` (`scripts/report.gd`) ou o formato do relatório invalida relatórios já entregues.

## Agentes e skills (`.claude/`)

Agentes: `godot-gdscript-specialist`, `accessibility-specialist`, `qa-tester`, `game-designer`.
Skills: `/balance-check`, `/playtest-report`. Adaptados do Claude Code Game Studios (MIT) —
ver `.claude/THIRD_PARTY.md`.
